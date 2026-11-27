package dev.inkbox.inkbox

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.util.Locale
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

internal class LibraryStorage(private val context: Context) {
    private val resolver = context.contentResolver
    private val preferences = context.getSharedPreferences("inkbox_library_storage", Context.MODE_PRIVATE)
    private val cacheRoot = File(context.cacheDir, "inkbox_media")
    private val scratch = File(cacheRoot, sessionId)

    init {
        if (cleanedPreviousSession.compareAndSet(false, true)) {
            cacheRoot.listFiles()?.filter { it != scratch }?.forEach { it.deleteRecursively() }
        }
    }

    fun temporaryDirectory(): File {
        return File(scratch, UUID.randomUUID().toString()).also {
            check(it.mkdirs()) { "Could not create temporary media directory" }
        }
    }

    fun release(path: String) {
        val directory = File(path).canonicalFile.parentFile ?: return
        if (directory.parentFile == scratch.canonicalFile) {
            directory.deleteRecursively()
        }
    }

    private fun writableTree(uri: Uri): DocumentFile? {
        if (resolver.persistedUriPermissions.none {
                it.uri == uri && it.isReadPermission && it.isWritePermission
            }) return null
        return DocumentFile.fromTreeUri(context, uri)
            ?.takeIf { it.isDirectory && it.canRead() && it.canWrite() }
    }

    fun workingDirectory(): Map<String, String>? {
        val uri = preferences.getString("current", null)?.let(Uri::parse) ?: return null
        val directory = writableTree(uri) ?: return null
        return mapOf("uri" to uri.toString(), "name" to (directory.name ?: uri.toString()))
    }

    fun selectWorkingDirectory(uri: Uri, flags: Int): Map<String, String> {
        val permissions = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        check((flags and permissions) == permissions) { "ERR_WORK_DIRECTORY" }
        resolver.takePersistableUriPermission(uri, permissions)
        val directory = writableTree(uri) ?: error("ERR_WORK_DIRECTORY")
        val managed = preferences.getStringSet("managed", emptySet()).orEmpty() + uri.toString()
        check(preferences.edit().putString("current", uri.toString()).putStringSet("managed", managed).commit())
        return mapOf("uri" to uri.toString(), "name" to (directory.name ?: uri.toString()))
    }

    @Synchronized
    fun store(localPath: String): Map<String, String> {
        val uri = preferences.getString("current", null)?.let(Uri::parse)
            ?: error("ERR_WORK_DIRECTORY")
        val root = writableTree(uri) ?: error("ERR_WORK_DIRECTORY")
        val source = File(localPath).absoluteFile
        check(source.isFile || source.isDirectory) { "ERR_FILE_NOT_FOUND" }
        val paths = mutableMapOf<String, String>()

        fun copy(parent: DocumentFile, file: File, name: String) {
            val target = if (file.isDirectory) {
                parent.createDirectory(name)
            } else {
                val extension = file.extension.lowercase(Locale.ROOT)
                val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
                    ?: "application/octet-stream"
                parent.createFile(mime, name)
            } ?: error("Could not create a file in the working directory")
            paths[file.absolutePath] = target.uri.toString()
            if (file.isDirectory) {
                val children = file.listFiles() ?: error("Could not read ${file.name}")
                for (child in children) {
                    check(child.canonicalFile == File(file.canonicalFile, child.name)) { "Unsupported file link" }
                    copy(target, child, child.name)
                }
            } else {
                val stream = resolver.openOutputStream(target.uri, "w") ?: error("ERR_STREAM_OPEN")
                stream.use { output -> file.inputStream().use { it.copyTo(output, 64 * 1024) } }
            }
        }

        val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
        val field = DocumentsContract.Document.COLUMN_DISPLAY_NAME
        val existingNames = resolver.query(children, arrayOf(field), null, null, null)?.use { cursor ->
            buildSet {
                while (cursor.moveToNext()) add(cursor.getString(0).lowercase(Locale.ROOT))
            }
        }.orEmpty()
        val name = if (source.name.lowercase(Locale.ROOT) in existingNames) {
            val suffix = UUID.randomUUID().toString().take(6)
            if (source.isDirectory || source.extension.isEmpty()) {
                "${source.name}_$suffix"
            } else {
                "${source.nameWithoutExtension}_$suffix.${source.extension}"
            }
        } else {
            source.name
        }
        try {
            copy(root, source, name)
            return paths
        } catch (error: Exception) {
            paths[source.absolutePath]?.let { delete(Uri.parse(it)) }
            throw error
        }
    }

    fun exists(uri: Uri): Boolean = runCatching {
        val document = DocumentFile.fromSingleUri(context, uri) ?: return false
        document.canRead() && (document.isDirectory || document.length() > 0)
    }.getOrDefault(false)

    fun open(uri: Uri, extension: String?): Map<String, String> {
        val document = DocumentFile.fromSingleUri(context, uri) ?: error("ERR_FILE_NOT_FOUND")
        check(document.canRead()) { "ERR_FILE_NOT_FOUND" }
        val directory = temporaryDirectory()
        val name = safeName(document.name ?: "document")
        val expected = extension?.lowercase(Locale.ROOT)?.takeIf { it.matches(Regex("[a-z0-9]+")) }
        val target = File(directory, if (!document.isDirectory && expected != null &&
            !name.endsWith(".$expected", ignoreCase = true)) "$name.$expected" else name)
        try {
            val paths = mutableMapOf<String, String>()
            materialize(uri, target, document.isDirectory, paths)
            return paths
        } catch (error: Exception) {
            directory.deleteRecursively()
            throw error
        }
    }

    private fun materialize(uri: Uri, target: File, isDirectory: Boolean, paths: MutableMap<String, String>) {
        paths[uri.toString()] = target.absolutePath
        if (!isDirectory) {
            val stream = resolver.openInputStream(uri) ?: error("ERR_STREAM_OPEN")
            stream.use { input -> target.outputStream().use { input.copyTo(it, 64 * 1024) } }
            return
        }
        check(target.mkdir())
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, DocumentsContract.getDocumentId(uri))
        val fields = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )
        resolver.query(children, fields, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val childUri = DocumentsContract.buildDocumentUriUsingTree(uri, cursor.getString(0))
                val child = File(target, safeName(cursor.getString(1)))
                check(!child.exists()) { "Duplicate document name" }
                materialize(childUri, child, cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR, paths)
            }
        } ?: error("ERR_STREAM_OPEN")
    }

    fun delete(uri: Uri): Boolean = runCatching {
        val treeId = DocumentsContract.getTreeDocumentId(uri)
        val tree = DocumentsContract.buildTreeDocumentUri(requireNotNull(uri.authority), treeId)
        val managed = preferences.getStringSet("managed", emptySet()).orEmpty()
        if (tree.toString() !in managed || DocumentsContract.getDocumentId(uri) == treeId) return false
        DocumentsContract.deleteDocument(resolver, uri)
    }.getOrDefault(false)

    private fun safeName(name: String): String {
        val cleaned = name.replace('/', '_').replace('\\', '_')
        return cleaned.takeUnless { it.isBlank() || it == "." || it == ".." } ?: "document"
    }

    private companion object {
        val sessionId: String = UUID.randomUUID().toString()
        val cleanedPreviousSession = AtomicBoolean(false)
    }
}
