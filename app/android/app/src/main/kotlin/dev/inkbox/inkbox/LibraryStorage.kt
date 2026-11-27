package dev.inkbox.inkbox

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
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
            val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
            context.cacheDir.listFiles()?.filter {
                (it.name.startsWith("inkbox-backup-") || it.name.startsWith("backup-")) &&
                    it.lastModified() in 1 until cutoff
            }?.forEach { it.deleteRecursively() }
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

    fun takeTreePermission(uri: Uri, flags: Int, writable: Boolean): Int {
        val permissions = Intent.FLAG_GRANT_READ_URI_PERMISSION or
            (if (writable) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
        val before = permissionFlags(uri)
        if (before and permissions == permissions) return 0
        val required = permissions or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        check(flags and required == required) { if (writable) "ERR_WORK_DIRECTORY" else "ERR_STREAM_OPEN" }
        resolver.takePersistableUriPermission(uri, permissions)
        return permissions and before.inv()
    }

    fun releaseTreePermission(uri: Uri, flags: Int) {
        if (flags != 0) resolver.releasePersistableUriPermission(uri, flags)
    }

    private fun permissionFlags(uri: Uri): Int {
        val permission = resolver.persistedUriPermissions.firstOrNull { it.uri == uri } ?: return 0
        return (if (permission.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
            (if (permission.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
    }

    @Synchronized
    fun selectWorkingDirectory(uri: Uri): Map<String, String> {
        val directory = writableTree(uri) ?: error("ERR_WORK_DIRECTORY")
        val managed = preferences.getStringSet("managed", emptySet()).orEmpty() + uri.toString()
        check(preferences.edit().putString("current", uri.toString()).putStringSet("managed", managed).commit()) {
            "ERR_WORK_DIRECTORY"
        }
        return mapOf("uri" to uri.toString(), "name" to (directory.name ?: uri.toString()))
    }

    @Synchronized
    fun releaseWatchedDirectory(uri: Uri) {
        val managed = preferences.getStringSet("managed", emptySet()).orEmpty()
        if (uri.toString() !in managed) releaseTreePermission(uri, permissionFlags(uri))
    }

    @Synchronized
    fun pruneWorkingDirectories(references: List<String>, watched: List<String>) {
        val live = references.mapNotNull { reference ->
            runCatching {
                val uri = Uri.parse(reference)
                DocumentsContract.buildTreeDocumentUri(requireNotNull(uri.authority),
                    DocumentsContract.getTreeDocumentId(uri)).toString()
            }.getOrNull()
        }.toSet() + preferences.getString("current", null)
        val managed = preferences.getStringSet("managed", emptySet()).orEmpty().toMutableSet()
        for (reference in managed.toList()) {
            if (reference in live) continue
            val uri = Uri.parse(reference)
            val keep = if (reference in watched) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0
            if (runCatching { releaseTreePermission(uri, permissionFlags(uri) and keep.inv()) }.isSuccess) {
                managed.remove(reference)
            }
        }
        preferences.edit().putStringSet("managed", managed).apply()
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
                while (cursor.moveToNext()) cursor.getString(0)?.let { add(it.lowercase(Locale.ROOT)) }
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
        if (!document.canRead()) return false
        if (document.isDirectory) return true
        val size = resolver.query(uri, arrayOf(Document.COLUMN_SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
        }
        size != 0L
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
            materialize(uri, target, document.isDirectory, paths, mutableSetOf(), 0)
            return paths
        } catch (error: Exception) {
            directory.deleteRecursively()
            throw error
        }
    }

    private fun materialize(
        uri: Uri, target: File, isDirectory: Boolean, paths: MutableMap<String, String>,
        visitedIds: MutableSet<String>, depth: Int
    ) {
        val id = DocumentsContract.getDocumentId(uri)
        check(depth <= 64 && visitedIds.add(id)) { "ERR_STREAM_OPEN" }
        paths[uri.toString()] = target.absolutePath
        if (!isDirectory) {
            val stream = resolver.openInputStream(uri) ?: error("ERR_STREAM_OPEN")
            stream.use { input -> target.outputStream().use { input.copyTo(it, 64 * 1024) } }
            return
        }
        check(target.mkdir())
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, id)
        val fields = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )
        val names = mutableSetOf<String>()
        resolver.query(children, fields, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val childId = cursor.getString(0) ?: continue
                if (childId in visitedIds) continue
                val childUri = DocumentsContract.buildDocumentUriUsingTree(uri, childId)
                val name = safeName(cursor.getString(1) ?: "document")
                var uniqueName = name
                var index = 2
                while (!names.add(uniqueName.lowercase(Locale.ROOT))) {
                    val stem = name.substringBeforeLast('.', name)
                    val extension = name.removePrefix(stem)
                    uniqueName = "${stem}_${index++}$extension"
                }
                materialize(childUri, File(target, uniqueName), cursor.getString(2) == Document.MIME_TYPE_DIR,
                    paths, visitedIds, depth + 1)
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
        val cleaned = name.map { if (it == '/' || it == '\\' || it.isISOControl()) '_' else it }.joinToString("")
        return cleaned.takeUnless { it.isBlank() || it == "." || it == ".." } ?: "document"
    }

    private companion object {
        val sessionId: String = UUID.randomUUID().toString()
        val cleanedPreviousSession = AtomicBoolean(false)
    }
}
