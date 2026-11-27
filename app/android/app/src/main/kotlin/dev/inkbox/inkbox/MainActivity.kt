package dev.inkbox.inkbox

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Base64
import android.util.Log
import android.view.KeyEvent
import android.view.WindowManager
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.zip.ZipFile
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val methodChannelName = "dev.inkbox/platform"
    private val eventChannelName = "dev.inkbox/events"

    private val reqPickDocuments = 9001
    private val reqPickDirectory = 9002
    private val reqPickDocumentsDetailed = 9003
    private val reqExportBackup = 9004
    private val reqImportBackup = 9005
    private val reqWorkingDirectory = 9006
    private val reqPickDocumentUris = 9007
    private val libraryStorage by lazy { LibraryStorage(applicationContext) }

    private data class PendingPicker(
        val code: Int,
        val result: MethodChannel.Result,
        val backupFile: File?
    )

    private var volumeKeyPagingEnabled = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsInitializing = false
    private var currentTtsEngine: String = ""
    private var pendingSpeakAction: ((Boolean) -> Unit)? = null
    private var pendingSpeakTimeout: Runnable? = null
    private var mediaPlayer: MediaPlayer? = null
    private var activeAudioPlaybackId: String? = null
    private var activeUtteranceId: String? = null
    private var pendingAudioResult: MethodChannel.Result? = null
    private var audioPrepared = false
    private var audioPaused = false
    private var audioSpeed = 1f
    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioFocusHeld = false
    private val keystoreAlias = "inkbox_tts_secrets_key"
    private val securePrefsName = "inkbox_secure_prefs"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ttsInitializing = true
        var createdRef: TextToSpeech? = null
        createdRef = TextToSpeech(this) { status ->
            mainHandler.post {
                if (tts === createdRef) {
                    onInit(status)
                }
            }
        }
        tts = createdRef
        if (savedInstanceState == null) acceptIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        acceptIncomingIntent(intent)
    }

    override fun onDestroy() {
        if (!isFinishing && pendingPicker != null) {
            retainedPickerEngine = flutterEngine
        }
        pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingSpeakTimeout = null
        pendingSpeakAction?.invoke(false)
        pendingSpeakAction = null
        stopLocalSpeech()
        tts?.shutdown()
        tts = null
        releaseMediaPlayer()
        if (isFinishing) cancelPendingPicker()
        if (retainedPickerEngine == null) eventSink = null
        super.onDestroy()
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? = retainedPickerEngine.also {
        retainedPickerEngine = null
    }

    override fun shouldDestroyEngineWithHost(): Boolean = retainedPickerEngine !== flutterEngine

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun configureTtsListener(instance: TextToSpeech?) {
        instance?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                emitEvent("tts_start", mapOf("utteranceId" to (utteranceId ?: "")))
            }

            override fun onDone(utteranceId: String?) {
                finishUtterance("tts_done", utteranceId)
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                finishUtterance("tts_error", utteranceId, errorCode)
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                finishUtterance("tts_error", utteranceId)
            }
        })
    }

    private fun containsCjk(text: String): Boolean {
        for (ch in text) {
            if (ch.code in 0x4E00..0x9FFF || ch.code in 0x3400..0x4DBF) return true
        }
        return false
    }

    private fun resolveTtsLocale(languageTag: String?): Locale {
        return when (languageTag?.trim()) {
            "zh-CN" -> Locale.CHINA
            "zh-TW" -> Locale.TAIWAN
            "zh-HK" -> Locale("zh", "HK")
            "en-US" -> Locale.US
            "ja-JP" -> Locale.JAPAN
            "system", "", null -> Locale.getDefault()
            else -> Locale.forLanguageTag(languageTag)
        }
    }

    private fun clampTtsText(raw: String): String {
        val maxLen = (TextToSpeech.getMaxSpeechInputLength() - 64).coerceAtLeast(500)
        if (raw.length <= maxLen) return raw
        val window = raw.substring(0, maxLen)
        val lastStop = window.indexOfLast { it == '。' || it == '！' || it == '？' || it == '\n' || it == '.' }
        return if (lastStop >= maxLen / 2) window.substring(0, lastStop + 1) else window
    }

    override fun onInit(status: Int) {
        ttsInitializing = false
        pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingSpeakTimeout = null
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
            configureTtsListener(tts)
        } else {
            ttsReady = false
            currentTtsEngine = "__init_failed__"
        }
        val action = pendingSpeakAction
        pendingSpeakAction = null
        action?.invoke(ttsReady)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(platformEvents)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "workingDirectory" -> runLibraryTask(result) {
                        libraryStorage.workingDirectory()
                    }

                    "releaseWatchedDirectory" -> runLibraryTask(result) {
                        val uri = requireNotNull(call.argument<String>("uri"))
                        libraryStorage.releaseWatchedDirectory(Uri.parse(uri))
                        null
                    }

                    "pruneWorkingDirectories" -> runLibraryTask(result) {
                        libraryStorage.pruneWorkingDirectories(
                            call.argument<List<String>>("references").orEmpty(),
                            call.argument<List<String>>("watched").orEmpty()
                        )
                        null
                    }

                    "pickWorkingDirectory" -> {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                            )
                        }
                        launchPicker(intent, reqWorkingDirectory, result)
                    }

                    "storeLibraryPath", "openLibraryDocument", "libraryDocumentExists",
                    "deleteLibraryDocument", "releaseMediaTemp" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("ARG", "Missing media path", null)
                            return@setMethodCallHandler
                        }
                        runLibraryTask(result) {
                            when (call.method) {
                                "storeLibraryPath" -> libraryStorage.store(path)
                                "openLibraryDocument" -> libraryStorage.open(
                                    Uri.parse(path),
                                    call.argument<String>("extension")
                                )
                                "libraryDocumentExists" -> libraryStorage.exists(Uri.parse(path))
                                "deleteLibraryDocument" -> libraryStorage.delete(Uri.parse(path))
                                else -> {
                                    libraryStorage.release(path)
                                    null
                                }
                            }
                        }
                    }

                    "setKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }

                    "setVolumeKeyPaging" -> {
                        volumeKeyPagingEnabled = call.argument<Boolean>("enabled") ?: false
                        result.success(null)
                    }

                    "setScreenBrightness" -> {
                        val brightness = call.argument<Double>("brightness")
                        val lp = window.attributes
                        lp.screenBrightness = brightness?.toFloat()?.coerceIn(0.01f, 1.0f)
                            ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        window.attributes = lp
                        result.success(null)
                    }

                    "getScreenBrightness" -> {
                        val cur = window.attributes.screenBrightness
                        val normalized = if (cur >= 0f) {
                            cur.toDouble().coerceIn(0.02, 1.0)
                        } else {
                            val raw = try {
                                Settings.System.getInt(
                                    contentResolver,
                                    Settings.System.SCREEN_BRIGHTNESS,
                                    128
                                )
                            } catch (_: Exception) {
                                128
                            }
                            normalizedSystemBrightness(raw)
                        }
                        result.success(normalized)
                    }

                    "pickDocuments", "pickDocumentsDetailed", "pickDocumentUris" -> {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            type = "*/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        }
                        val code = when (call.method) {
                            "pickDocumentsDetailed" -> reqPickDocumentsDetailed
                            "pickDocumentUris" -> reqPickDocumentUris
                            else -> reqPickDocuments
                        }
                        launchPicker(intent, code, result)
                    }

                    "pickPersistentDirectory" -> {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                            )
                        }
                        launchPicker(intent, reqPickDirectory, result)
                    }

                    "pickLocalBackupExport" -> {
                        val name = call.argument<String>("name") ?: "InkBox.zip"
                        val picker = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            type = "application/zip"
                            putExtra(Intent.EXTRA_TITLE, name)
                        }
                        launchPicker(picker, reqExportBackup, result)
                    }

                    "exportLocalBackup" -> {
                        val destination = call.argument<String>("destination")
                        val uri = destination?.let(backupDestinations::remove)
                        val path = call.argument<String>("path")
                        if (uri == null || path.isNullOrBlank()) {
                            result.error("BACKUP_IO", "Missing backup destination or file", null)
                        } else {
                            transferBackup(uri, File(path), true, result)
                        }
                    }

                    "cancelLocalBackupExport" -> {
                        val uri = call.argument<String>("destination")?.let(backupDestinations::remove)
                        runLibraryTask(result) {
                            if (uri != null && documentLength(uri) == 0L) {
                                DocumentsContract.deleteDocument(contentResolver, uri)
                            }
                            null
                        }
                    }

                    "importLocalBackup" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("ARG", "Missing backup path", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream")
                            )
                        }
                        launchPicker(
                            intent,
                            reqImportBackup,
                            result,
                            File(path)
                        )
                    }

                    "scanPersistentDirectory" -> {
                        val treeUriStr = call.argument<String>("treeUri")
                        if (treeUriStr.isNullOrBlank()) {
                            result.success(emptyList<Map<String, Any>>())
                            return@setMethodCallHandler
                        }
                        runLibraryTask(result, "SCAN") {
                            val treeUri = Uri.parse(treeUriStr)
                            if (contentResolver.persistedUriPermissions.none {
                                    it.uri == treeUri && it.isReadPermission
                                }) {
                                throw SecurityException("Folder access expired")
                            }
                            scanTreeUri(treeUri)
                        }
                    }

                    "stageDocumentUri" -> {
                        val uriStr = call.argument<String>("uri")
                        val fileNameHint = call.argument<String>("fileName")
                        if (uriStr.isNullOrBlank()) {
                            result.error("ARG", "Missing uri", null)
                            return@setMethodCallHandler
                        }
                        runLibraryTask(result, "IO") {
                            val outcome = stageDocument(Uri.parse(uriStr), fileNameHint)
                            outcome.file?.absolutePath ?: error(outcome.error ?: "ERR_STREAM_OPEN")
                        }
                    }

                    "speakText" -> {
                        val rawText = call.argument<String>("text") ?: ""
                        val text = clampTtsText(rawText)
                        val rate = (call.argument<Double>("rate") ?: 1.0).toFloat().coerceIn(0.4f, 2.5f)
                        val pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat().coerceIn(0.5f, 2.0f)
                        val language = call.argument<String>("language")
                        val requestedEngine = call.argument<String>("engine")?.trim() ?: ""
                        val requestedVoice = call.argument<String>("voiceName")?.trim() ?: ""

                        fun performSpeak(): String? {
                            val active = tts ?: return null
                            if (!ttsReady || text.isBlank()) return null
                            var voiceApplied = false
                            if (requestedVoice.isNotEmpty()) {
                                try {
                                    val match = active.voices?.firstOrNull { it.name == requestedVoice }
                                    if (match != null) {
                                        active.voice = match
                                        voiceApplied = true
                                    }
                                } catch (_: Exception) {
                                }
                            }
                            if (!voiceApplied) {
                                try {
                                    val targetLocale = resolveTtsLocale(language)
                                    val avail = active.isLanguageAvailable(targetLocale)
                                    if (avail >= TextToSpeech.LANG_AVAILABLE) {
                                        active.language = targetLocale
                                    } else if (containsCjk(text)) {
                                        active.language = Locale.CHINA
                                    } else {
                                        active.language = targetLocale
                                    }
                                } catch (_: Exception) {
                                }
                            }
                            releaseMediaPlayer()
                            if (!requestSpeechAudioFocus()) return null
                            val uid = UUID.randomUUID().toString()
                            activeUtteranceId = uid
                            return try {
                                active.setSpeechRate(rate)
                                active.setPitch(pitch)
                                if (active.speak(text, TextToSpeech.QUEUE_FLUSH, null, uid) == TextToSpeech.SUCCESS) {
                                    uid
                                } else {
                                    stopLocalSpeech()
                                    null
                                }
                            } catch (error: Exception) {
                                Log.w(TAG, "Unable to start local speech", error)
                                stopLocalSpeech()
                                null
                            }
                        }

                        // Cancel any superseded pending speak callback cleanly
                        pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
                        pendingSpeakTimeout = null
                        pendingSpeakAction?.invoke(false)
                        pendingSpeakAction = null

                        if (text.isBlank()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        if (requestedEngine != currentTtsEngine || (!ttsReady && !ttsInitializing)) {
                            stopLocalSpeech()
                            tts?.shutdown()
                            ttsReady = false
                            ttsInitializing = true
                            currentTtsEngine = requestedEngine

                            var created: TextToSpeech? = null
                            val listener = TextToSpeech.OnInitListener { status ->
                                mainHandler.post {
                                    if (tts === created) onInit(status)
                                }
                            }
                            created = if (requestedEngine.isEmpty()) {
                                TextToSpeech(this, listener)
                            } else {
                                TextToSpeech(this, listener, requestedEngine)
                            }
                            tts = created
                        }

                        fun replyToSpeak(ready: Boolean) {
                            if (!ready) {
                                result.error("ERR_TTS_UNAVAILABLE", "TTS engine unavailable", null)
                                return
                            }
                            val id = performSpeak()
                            if (id != null) {
                                result.success(id)
                            } else {
                                result.error("ERR_TTS_SPEAK_FAILED", "TTS speak failed", null)
                            }
                        }
                        if (ttsReady) {
                            replyToSpeak(true)
                        } else {
                            pendingSpeakAction = ::replyToSpeak
                            val watchdog = Runnable {
                                ttsInitializing = false
                                pendingSpeakAction = null
                                pendingSpeakTimeout = null
                                result.error("ERR_TTS_TIMEOUT", "TTS init timeout", null)
                            }
                            pendingSpeakTimeout = watchdog
                            mainHandler.postDelayed(watchdog, 5000L)
                        }
                    }

                    "stopTts" -> {
                        pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
                        pendingSpeakTimeout = null
                        pendingSpeakAction?.invoke(false)
                        pendingSpeakAction = null
                        stopLocalSpeech()
                        result.success(null)
                    }

                    "getTtsEngines" -> {
                        val engines = try {
                            tts?.engines?.map { e ->
                                mapOf("name" to e.name, "label" to e.label)
                            } ?: emptyList()
                        } catch (_: Exception) {
                            emptyList()
                        }
                        if (engines.isNotEmpty()) {
                            result.success(engines)
                        } else {
                            val fallbackList = try {
                                packageManager.queryIntentServices(
                                    Intent("android.intent.action.TTS_SERVICE"),
                                    0
                                ).map { ri ->
                                    mapOf(
                                        "name" to (ri.serviceInfo?.packageName ?: ""),
                                        "label" to ri.loadLabel(packageManager).toString()
                                    )
                                }.filter { (it["name"] ?: "").isNotEmpty() }
                            } catch (_: Exception) {
                                emptyList()
                            }
                            result.success(fallbackList)
                        }
                    }

                    "getTtsVoices" -> {
                        val requestedEngine = call.argument<String>("engine")?.trim() ?: ""
                        val langFilter = call.argument<String>("language")?.trim() ?: ""
                        if (requestedEngine == currentTtsEngine &&
                            ttsReady &&
                            tts != null
                        ) {
                            val voices = try {
                                tts?.voices?.toList() ?: emptyList()
                            } catch (_: Exception) {
                                emptyList()
                            }
                            result.success(formatVoices(voices, langFilter))
                        } else {
                            var tempTts: TextToSpeech? = null
                            var replied = false
                            val watchdog = Runnable {
                                if (!replied) {
                                    replied = true
                                    try {
                                        tempTts?.shutdown()
                                    } catch (_: Exception) {
                                    }
                                    tempTts = null
                                    result.success(emptyList<Map<String, Any>>())
                                }
                            }
                            mainHandler.postDelayed(watchdog, 3000L)
                            val probeListener = TextToSpeech.OnInitListener { status ->
                                mainHandler.post {
                                    mainHandler.removeCallbacks(watchdog)
                                    if (!replied) {
                                        replied = true
                                        val raw = if (status == TextToSpeech.SUCCESS) {
                                            try {
                                                tempTts?.voices?.toList() ?: emptyList()
                                            } catch (_: Exception) {
                                                emptyList()
                                            }
                                        } else {
                                            emptyList()
                                        }
                                        try {
                                            tempTts?.shutdown()
                                        } catch (_: Exception) {
                                        }
                                        tempTts = null
                                        result.success(formatVoices(raw, langFilter))
                                    } else {
                                        try {
                                            tempTts?.shutdown()
                                        } catch (_: Exception) {
                                        }
                                        tempTts = null
                                    }
                                }
                            }
                            tempTts = try {
                                if (requestedEngine.isEmpty()) {
                                    TextToSpeech(this, probeListener)
                                } else {
                                    TextToSpeech(this, probeListener, requestedEngine)
                                }
                            } catch (_: Exception) {
                                mainHandler.removeCallbacks(watchdog)
                                if (!replied) {
                                    replied = true
                                    result.success(emptyList<Map<String, Any>>())
                                }
                                null
                            }
                        }
                    }

                    "playAudioFile" -> {
                        val path = call.argument<String>("path").orEmpty()
                        val speed = (call.argument<Double>("speed") ?: 1.0).toFloat().coerceIn(0.4f, 2.5f)
                        val id = call.argument<String>("playbackId") ?: UUID.randomUUID().toString()
                        prepareSpeechAudio(path, speed, id, result)
                    }

                    "pauseAudio" -> {
                        pauseSpeechAudio()
                        result.success(null)
                    }

                    "resumeAudio" -> {
                        val player = mediaPlayer
                        if (player != null && audioPrepared && audioPaused) {
                            try {
                                check(requestSpeechAudioFocus()) { "Unable to obtain audio focus" }
                                audioPaused = false
                                startSpeechAudio(player)
                            } catch (error: Exception) {
                                val id = activeAudioPlaybackId.orEmpty()
                                failSpeechAudio(id, error)
                            }
                        } else if (player != null) {
                            audioPaused = false
                        }
                        result.success(null)
                    }

                    "stopAudio" -> {
                        releaseMediaPlayer()
                        result.success(null)
                    }

                    "setAudioSpeed" -> {
                        audioSpeed = (call.argument<Double>("speed") ?: 1.0).toFloat().coerceIn(0.4f, 2.5f)
                        val player = mediaPlayer
                        if (player != null && audioPrepared && !audioPaused) {
                            try {
                                player.playbackParams = player.playbackParams.setSpeed(audioSpeed)
                            } catch (error: Exception) {
                                Log.w(TAG, "Unable to adjust speech audio speed", error)
                            }
                        }
                        result.success(null)
                    }

                    "saveSecret", "readSecret", "deleteSecret" -> {
                        val key = call.argument<String>("key").orEmpty()
                        runLibraryTask(result, "SECRET_IO", secretExecutor) {
                            require(key.isNotBlank())
                            when (call.method) {
                                "saveSecret" -> {
                                    saveEncryptedSecret(key, call.argument<String>("value").orEmpty())
                                    null
                                }
                                "readSecret" -> readEncryptedSecret(key)
                                else -> {
                                    removeStoredSecret(key)
                                    null
                                }
                            }
                        }
                    }

                    "openSystemTtsSettings" -> {
                        try {
                            startActivity(Intent("com.android.settings.TTS_SETTINGS"))
                        } catch (_: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_SETTINGS))
                            } catch (_: Exception) {
                            }
                        }
                        result.success(null)
                    }

                    "getPdfPageCount" -> {
                        val path = call.argument<String>("path").orEmpty()
                        runLibraryTask(result, "PDF_IO", pdfExecutor) {
                            withPdf(path) { it.pageCount }
                        }
                    }

                    "renderPdfPage" -> {
                        val path = call.argument<String>("path").orEmpty()
                        val index = call.argument<Int>("pageIndex") ?: 0
                        val scale = (call.argument<Double>("scale") ?: 2.0).coerceIn(0.8, 3.5)
                        runLibraryTask(result, "PDF_IO", pdfExecutor) {
                            withPdf(path) { renderer ->
                                if (index !in 0 until renderer.pageCount) return@withPdf null
                                renderer.openPage(index).use { page ->
                                    val boundedScale = minOf(scale, 2400.0 / page.width, 3400.0 / page.height)
                                    val width = (page.width * boundedScale).toInt().coerceAtLeast(1)
                                    val height = (page.height * boundedScale).toInt().coerceAtLeast(1)
                                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                    try {
                                        Canvas(bitmap).drawColor(Color.WHITE)
                                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                        ByteArrayOutputStream().use { stream ->
                                            if (bitmap.compress(Bitmap.CompressFormat.PNG, 92, stream)) {
                                                stream.toByteArray()
                                            } else null
                                        }
                                    } finally {
                                        bitmap.recycle()
                                    }
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumeKeyPagingEnabled && event.action == KeyEvent.ACTION_DOWN) {
            if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                emitEvent("volume_key", mapOf("direction" to "up"))
                return true
            } else if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                emitEvent("volume_key", mapOf("direction" to "down"))
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun launchPicker(
        intent: Intent,
        code: Int,
        result: MethodChannel.Result,
        backupFile: File? = null
    ) {
        if (pendingPicker != null) {
            result.error("BUSY", "Another picker is already active", null)
            return
        }
        pendingPicker = PendingPicker(code, result, backupFile)
        try {
            startActivityForResult(intent, code)
        } catch (error: Exception) {
            pendingPicker = null
            result.error("PICKER", error.message, null)
        }
    }

    private fun cancelPendingPicker() {
        val picker = pendingPicker ?: return
        pendingPicker = null
        when (picker.code) {
            reqPickDocuments, reqPickDocumentUris -> picker.result.success(emptyList<String>())
            reqPickDocumentsDetailed -> picker.result.success(
                mapOf("paths" to emptyList<String>(), "errors" to emptyList<String>())
            )
            reqImportBackup -> picker.result.success(false)
            else -> picker.result.success(null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val picker = pendingPicker?.takeIf { it.code == requestCode } ?: return
        if (resultCode != Activity.RESULT_OK || data == null) {
            cancelPendingPicker()
            return
        }
        val callback = picker.result
        pendingPicker = null

        when (requestCode) {
            reqPickDocuments, reqPickDocumentsDetailed, reqPickDocumentUris -> {
                val uris = LinkedHashSet<Uri>()
                val clip = data.clipData
                if (clip != null && clip.itemCount > 0) {
                    for (i in 0 until clip.itemCount) {
                        clip.getItemAt(i)?.uri?.let { uris.add(it) }
                    }
                } else {
                    data.data?.let { uris.add(it) }
                }

                if (requestCode == reqPickDocumentUris) {
                    callback.success(uris.map(Uri::toString))
                    return
                }
                runLibraryTask(callback, "IO") {
                    val paths = mutableListOf<String>()
                    val errors = mutableListOf<String>()
                    for (uri in uris) {
                        val outcome = stageDocument(uri, null)
                        if (outcome.file != null) {
                            paths.add(outcome.file.absolutePath)
                        } else {
                            errors.add(outcome.error ?: "ERR_STREAM_OPEN")
                        }
                    }
                    if (requestCode == reqPickDocumentsDetailed) {
                        mapOf("paths" to paths, "errors" to errors)
                    } else {
                        paths
                    }
                }
            }

            reqPickDirectory -> {
                val treeUri = data.data
                if (treeUri != null) {
                    val acquired = try {
                        libraryStorage.takeTreePermission(treeUri, data.flags, false)
                    } catch (error: Exception) {
                        callback.error("SCAN", "ERR_STREAM_OPEN", null)
                        return
                    }
                    runLibraryTask(callback, "SCAN", onFailure = {
                        runCatching { libraryStorage.releaseTreePermission(treeUri, acquired) }
                    }) {
                        val doc = DocumentFile.fromTreeUri(applicationContext, treeUri)
                            ?.takeIf { it.isDirectory && it.canRead() } ?: error("ERR_STREAM_OPEN")
                        mapOf("uri" to treeUri.toString(), "name" to (doc.name ?: treeUri.toString()))
                    }
                } else {
                    callback.success(null)
                }
            }

            reqWorkingDirectory -> {
                val uri = data.data
                if (uri == null) {
                    callback.success(null)
                } else {
                    val acquired = try {
                        libraryStorage.takeTreePermission(uri, data.flags, true)
                    } catch (error: Exception) {
                        callback.error("ERR_WORK_DIRECTORY", "ERR_WORK_DIRECTORY", null)
                        return
                    }
                    runLibraryTask(callback, "ERR_WORK_DIRECTORY", onFailure = {
                        runCatching { libraryStorage.releaseTreePermission(uri, acquired) }
                    }) { libraryStorage.selectWorkingDirectory(uri) }
                }
            }

            reqExportBackup -> {
                val destination = data.data?.let { uri ->
                    UUID.randomUUID().toString().also { backupDestinations[it] = uri }
                }
                callback.success(destination)
            }

            reqImportBackup -> {
                val uri = data.data
                val backupFile = picker.backupFile
                if (uri == null || backupFile == null) {
                    callback.success(false)
                    return
                }
                transferBackup(uri, backupFile, false, callback)
            }
        }
    }

    private fun transferBackup(uri: Uri, file: File, exporting: Boolean, result: MethodChannel.Result) {
        runLibraryTask(result, "BACKUP_IO") {
            val initialSize = if (exporting) documentLength(uri) else null
            try {
                if (exporting) {
                    // ACTION_CREATE_DOCUMENT selects a new document. Guard against providers returning an existing one.
                    val empty = initialSize == 0L || (initialSize == null &&
                        contentResolver.openInputStream(uri)?.use { it.read() == -1 } == true)
                    check(empty) { "Could not verify an empty backup destination" }
                    file.inputStream().use { input ->
                        val output = openTruncatedOutputStream(uri)
                            ?: error("Could not open the backup destination")
                        output.use { input.copyTo(it, 64 * 1024) }
                    }
                } else {
                    val input = contentResolver.openInputStream(uri)
                        ?: error("Could not open the backup file")
                    input.use { stream ->
                        file.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            var copied = 0L
                            while (true) {
                                val count = stream.read(buffer)
                                if (count < 0) break
                                copied += count
                                check(copied <= maxBackupTransferBytes) { "Backup file is too large" }
                                output.write(buffer, 0, count)
                            }
                        }
                    }
                }
                true
            } catch (error: Throwable) {
                if (exporting && initialSize == 0L) {
                    runCatching { DocumentsContract.deleteDocument(contentResolver, uri) }
                }
                throw error
            }
        }
    }

    private fun documentLength(uri: Uri): Long? = runCatching {
        contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
        }
    }.getOrNull()

    private fun openTruncatedOutputStream(uri: Uri): java.io.OutputStream? {
        try {
            contentResolver.openOutputStream(uri, "wt")?.let { return it }
        } catch (_: IllegalArgumentException) {
        } catch (_: UnsupportedOperationException) {
        } catch (_: java.io.FileNotFoundException) {
        }
        val pfd = try {
            contentResolver.openFileDescriptor(uri, "rw")
        } catch (_: Exception) {
            null
        } ?: return null
        return try {
            ParcelFileDescriptor.AutoCloseOutputStream(pfd).also { it.channel.truncate(0L) }
        } catch (e: Exception) {
            runCatching { pfd.close() }
            throw e
        }
    }

    private data class StagedCopyResult(val file: File?, val error: String? = null)

    private fun runLibraryTask(
        result: MethodChannel.Result,
        code: String = "LIBRARY_IO",
        executor: ThreadPoolExecutor = libraryExecutor,
        onFailure: () -> Unit = {},
        task: () -> Any?
    ) {
        try {
            executor.execute {
                try {
                    val value = task()
                    mainHandler.post { result.success(value) }
                } catch (error: Throwable) {
                    onFailure()
                    mainHandler.post { result.error(code, error.message, null) }
                }
            }
        } catch (_: RejectedExecutionException) {
            onFailure()
            result.error(code, "ERR_BUSY", null)
        }
    }

    private fun acceptIncomingIntent(incoming: Intent?) {
        if (incoming?.action != Intent.ACTION_VIEW) return
        val uri = incoming.data ?: return
        incoming.action = null
        incoming.data = null
        pendingIncomingUris.addLast(uri)
        flushIncomingFiles()
    }

    private fun normalizedSystemBrightness(raw: Int): Double {
        val res = resources.getIdentifier("config_screenBrightnessSettingMaximum", "integer", "android")
        val configuredMax = if (res != 0) runCatching { resources.getInteger(res) }.getOrDefault(0) else 0
        val maximum = when {
            configuredMax > 255 && raw <= configuredMax -> configuredMax
            raw <= 255 -> 255
            else -> return 0.5
        }
        return (raw.toDouble() / maximum).coerceIn(0.02, 1.0)
    }

    private fun stageDocument(uri: Uri, nameHint: String?): StagedCopyResult {
        val providerName = nameHint?.takeIf { it.isNotBlank() } ?: queryDisplayName(uri)
        val rawName = (providerName ?: uri.lastPathSegment?.substringAfterLast('/')?.substringAfterLast(':'))
            ?.trim()?.takeIf { it.isNotEmpty() && it != "." && it != ".." && it != ".staging" }
            ?: "import_" + System.currentTimeMillis()
        val safeName = rawName.map {
            if (it.isISOControl() || it in "\\/:*?\"<>|") '_' else it
        }.joinToString("")
        val extension = safeName.substringAfterLast('.', "").lowercase(Locale.ROOT)
        if (extension.isNotEmpty() && extension !in importExtensions) {
            return StagedCopyResult(null, "$safeName: ERR_UNSUPPORTED_TYPE")
        }

        val staging = runCatching { libraryStorage.temporaryDirectory() }.getOrElse {
            return StagedCopyResult(null, "$safeName: ERR_STREAM_OPEN")
        }
        val tempFile = File(staging, ".staging")
        var committed = false
        return try {
            val input = runCatching { contentResolver.openInputStream(uri) }.getOrNull()
                ?: contentResolver.openFileDescriptor(uri, "r")?.let { ParcelFileDescriptor.AutoCloseInputStream(it) }
                ?: return StagedCopyResult(null, "$safeName: ERR_STREAM_OPEN")
            val copied = input.use { stream -> tempFile.outputStream().use { stream.copyTo(it, 64 * 1024) } }
            if (copied == 0L) return StagedCopyResult(null, "$safeName: ERR_FILE_EMPTY")

            val finalName = if (extension.isNotEmpty()) {
                safeName
            } else {
                val mime = contentResolver.getType(uri)?.substringBefore(';')?.trim()?.lowercase(Locale.ROOT)
                val detected = sniffExtensionFromFile(tempFile, mime)
                    ?: return StagedCopyResult(null, "$safeName: ERR_UNSUPPORTED_TYPE")
                safeName.trimEnd('.') + "." + detected
            }
            val target = File(staging, finalName)
            if (!tempFile.renameTo(target)) {
                tempFile.copyTo(target)
                tempFile.delete()
            }
            committed = true
            StagedCopyResult(target)
        } catch (error: Exception) {
            Log.w(TAG, "Document staging failed", error)
            StagedCopyResult(null, "$safeName: ERR_STREAM_OPEN")
        } finally {
            if (!committed) staging.deleteRecursively()
        }
    }

    private fun java.io.InputStream.readPrefix(limit: Int): ByteArray {
        val bytes = ByteArray(limit)
        var size = 0
        while (size < limit) {
            val count = read(bytes, size, limit - size)
            if (count <= 0) break
            size += count
        }
        return bytes.copyOf(size)
    }

    private fun sniffExtensionFromFile(file: File, mime: String?): String? {
        val header = file.inputStream().use { it.readPrefix(4096) }
        fun prefix(vararg bytes: Int) =
            header.size >= bytes.size && bytes.indices.all { (header[it].toInt() and 0xff) == bytes[it] }

        if (prefix(0x25, 0x50, 0x44, 0x46, 0x2d)) return "pdf"
        if (prefix(0x50, 0x4b, 0x03, 0x04) || prefix(0x50, 0x4b, 0x05, 0x06)) {
            return ZipFile(file).use { zip ->
                val epubMime = zip.getEntry("mimetype")?.let { entry ->
                    zip.getInputStream(entry).use { it.readPrefix(32).toString(Charsets.US_ASCII).trim() }
                }
                if (zip.getEntry("META-INF/container.xml") != null || epubMime == "application/epub+zip") {
                    "epub"
                } else if (zip.getEntry("[Content_Types].xml") != null || zip.getEntry("AndroidManifest.xml") != null) {
                    null
                } else if (zip.entries().asSequence().any { !it.isDirectory &&
                        it.name.substringAfterLast('.', "").lowercase(Locale.ROOT) in imageExtensions }) {
                    "cbz"
                } else null
            }
        }
        if (prefix(0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c)) return "cb7"
        if (prefix(0x52, 0x61, 0x72, 0x21, 0x1a, 0x07)) return "cbr"
        if (header.size >= 68 && String(header, 60, 8, Charsets.US_ASCII) in setOf("BOOKMOBI", "TEXtREAd")) {
            return "mobi"
        }
        if (mime?.startsWith("image/") == true || mime?.startsWith("audio/") == true ||
            mime?.startsWith("video/") == true) return null
        val text = when {
            prefix(0xff, 0xfe) -> header.toString(Charsets.UTF_16LE)
            prefix(0xfe, 0xff) -> header.toString(Charsets.UTF_16BE)
            else -> header.toString(Charsets.UTF_8)
        }
        val sample = if (file.length() > header.size) text.trimEnd('\uFFFD') else text
        if (sample.any { (it.isISOControl() && it !in "\t\n\r\u000C") || it == '\uFFFD' }) return null
        if (sample.contains("<FictionBook", ignoreCase = true)) return "fb2"
        return when (mime) {
            "text/markdown", "text/x-markdown" -> "md"
            "application/json", "text/json" -> "json"
            null, "text/plain", "application/octet-stream" -> "txt"
            else -> null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val name = c.getString(idx)
                        if (!name.isNullOrBlank()) return name
                    }
                }
            }
        } catch (_: Exception) {
            // Fall through to DocumentFile / lastPathSegment
        }
        try {
            val docName = DocumentFile.fromSingleUri(this, uri)?.name
            if (!docName.isNullOrBlank()) return docName
        } catch (_: Exception) {
            // Fall through
        }
        return null
    }

    private fun scanTreeUri(treeUri: Uri): List<Map<String, Any>> {
        val root = DocumentFile.fromTreeUri(this, treeUri)
            ?.takeIf { it.isDirectory && it.canRead() }
            ?: error("Could not read the selected folder")
        val allowed = setOf("epub", "txt", "pdf", "mobi", "azw3", "fb2", "md", "cbz", "zip", "cbr", "rar", "cb7", "7z")
        val results = mutableListOf<Map<String, Any>>()
        val scannedDirectories = mutableSetOf<Uri>()

        fun walk(dir: DocumentFile, depth: Int) {
            if (depth > 4 || !scannedDirectories.add(dir.uri)) return
            for (child in dir.listFiles()) {
                val name = child.name ?: continue
                if (name.startsWith(".")) continue
                if (child.isDirectory) {
                    walk(child, depth + 1)
                } else if (child.isFile) {
                    val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
                    if (ext in allowed) {
                        results.add(
                            mapOf(
                                "uri" to child.uri.toString(),
                                "name" to name,
                                "ext" to ext,
                                "size" to child.length()
                            )
                        )
                    }
                }
            }
        }
        walk(root, 0)
        return results
    }

    private val speechAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    private val focusListener = AudioManager.OnAudioFocusChangeListener { state ->
        mainHandler.post {
            if (state >= 0 || !audioFocusHeld) return@post
            activeAudioPlaybackId?.let { id ->
                pauseSpeechAudio()
                emitEvent("audio_pause", mapOf("playbackId" to id))
            }
            activeUtteranceId?.let { id ->
                stopLocalSpeech()
                emitEvent("tts_pause", mapOf("utteranceId" to id))
            }
        }
    }

    private fun requestSpeechAudioFocus(): Boolean {
        if (audioFocusHeld) return true
        val manager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        val response = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(speechAttributes)
                .setWillPauseWhenDucked(true)
                .setOnAudioFocusChangeListener(focusListener, mainHandler)
                .build()
            audioFocusRequest = request
            manager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
        audioFocusHeld = response == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        if (!audioFocusHeld) abandonSpeechAudioFocus()
        return audioFocusHeld
    }

    private fun abandonSpeechAudioFocus() {
        val held = audioFocusHeld
        audioFocusHeld = false
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val previous = audioFocusRequest
            audioFocusRequest = null
            previous?.let { am.abandonAudioFocusRequest(it) }
        } else if (held) {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(focusListener)
        }
    }

    private fun stopLocalSpeech() {
        val hadSpeech = activeUtteranceId != null
        activeUtteranceId = null
        tts?.stop()
        if (hadSpeech) abandonSpeechAudioFocus()
    }

    private fun finishUtterance(type: String, id: String?, errorCode: Int? = null) {
        if (id == null) return
        mainHandler.post {
            if (id != activeUtteranceId) return@post
            activeUtteranceId = null
            abandonSpeechAudioFocus()
            val payload = mutableMapOf<String, Any>("utteranceId" to id)
            if (errorCode != null) payload["errorCode"] = errorCode
            emitEvent(type, payload)
        }
    }

    private fun prepareSpeechAudio(path: String, speed: Float, id: String, result: MethodChannel.Result) {
        stopLocalSpeech()
        pendingSpeakTimeout?.let(mainHandler::removeCallbacks)
        pendingSpeakTimeout = null
        pendingSpeakAction?.invoke(false)
        pendingSpeakAction = null
        releaseMediaPlayer()
        pendingAudioResult = result
        activeAudioPlaybackId = id
        audioSpeed = speed
        try {
            val player = MediaPlayer()
            mediaPlayer = player
            player.setAudioAttributes(speechAttributes)
            player.setOnPreparedListener { prepared ->
                if (mediaPlayer !== prepared) return@setOnPreparedListener
                audioPrepared = true
                try {
                    if (!audioPaused) {
                        check(requestSpeechAudioFocus()) { "Unable to obtain audio focus" }
                        startSpeechAudio(prepared)
                        emitEvent("audio_start", mapOf("playbackId" to id))
                    }
                    pendingAudioResult?.success(true)
                    pendingAudioResult = null
                } catch (error: Exception) {
                    failSpeechAudio(id, error)
                }
            }
            player.setOnCompletionListener {
                if (mediaPlayer !== it) return@setOnCompletionListener
                releaseMediaPlayer()
                emitEvent("audio_done", mapOf("playbackId" to id))
            }
            player.setOnErrorListener { failed, what, extra ->
                if (mediaPlayer === failed) failSpeechAudio(id, IllegalStateException("MediaPlayer error $what/$extra"))
                true
            }
            player.setDataSource(path)
            player.prepareAsync()
        } catch (error: Exception) {
            failSpeechAudio(id, error)
        }
    }

    private fun startSpeechAudio(player: MediaPlayer) {
        try {
            // A nonzero PlaybackParams speed starts a prepared/paused player at that speed.
            player.playbackParams = player.playbackParams.setSpeed(audioSpeed)
        } catch (error: Exception) {
            Log.w(TAG, "Playback speed unavailable", error)
        }
        if (!player.isPlaying) player.start()
    }

    private fun pauseSpeechAudio() {
        val player = mediaPlayer ?: return
        audioPaused = true
        if (audioPrepared) {
            try {
                if (player.isPlaying) player.pause()
            } catch (error: Exception) {
                failSpeechAudio(activeAudioPlaybackId.orEmpty(), error)
            }
        }
        abandonSpeechAudioFocus()
    }

    private fun failSpeechAudio(id: String, error: Exception) {
        Log.w(TAG, "Speech audio playback failed", error)
        val notified = pendingAudioResult != null
        releaseMediaPlayer()
        if (!notified) emitEvent("audio_error", mapOf("playbackId" to id))
    }

    private fun formatVoices(
        rawVoices: Collection<android.speech.tts.Voice>,
        langFilter: String
    ): List<Map<String, Any>> {
        val langPrefix = if (langFilter.isEmpty() || langFilter == "system") {
            ""
        } else {
            langFilter.split('-', '_').firstOrNull()?.lowercase(Locale.ROOT) ?: ""
        }
        val filtered = if (langPrefix.isEmpty()) {
            rawVoices.toList()
        } else {
            val matched = rawVoices.filter {
                it.locale.language.lowercase(Locale.ROOT) == langPrefix
            }
            matched.ifEmpty { rawVoices.toList() }
        }
        val sorted = filtered.sortedWith(
            compareBy<android.speech.tts.Voice>(
                { it.isNetworkConnectionRequired },
                { -(it.quality) },
                { it.name }
            )
        )
        return sorted.map { v ->
            mapOf(
                "name" to v.name,
                "locale" to v.locale.toLanguageTag(),
                "quality" to v.quality,
                "requiresNetwork" to v.isNetworkConnectionRequired
            )
        }
    }

    private fun releaseMediaPlayer() {
        val previous = mediaPlayer
        mediaPlayer = null
        activeAudioPlaybackId = null
        audioPrepared = false
        audioPaused = false
        pendingAudioResult?.success(false)
        pendingAudioResult = null
        if (previous != null) {
            runCatching { previous.release() }
            abandonSpeechAudioFocus()
        }
    }

    private fun <T> withPdf(path: String, read: (PdfRenderer) -> T): T {
        val descriptor = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = try {
            PdfRenderer(descriptor)
        } catch (error: Throwable) {
            runCatching { descriptor.close() }
            throw error
        }
        return renderer.use(read)
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore")
        ks.load(null)
        val existing = ks.getKey(keystoreAlias, null) as? SecretKey
        if (existing != null) return existing
        val keyGen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(
            keystoreAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        keyGen.init(spec)
        return keyGen.generateKey()
    }

    private fun saveEncryptedSecret(key: String, value: String) {
        fun encrypt() {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
            val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            val ivB64 = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
            val dataB64 = Base64.encodeToString(encrypted, Base64.NO_WRAP)
            check(getSharedPreferences(securePrefsName, Context.MODE_PRIVATE)
                .edit().putString(key, "$ivB64:$dataB64").commit()) { "Could not store encrypted credential" }
        }
        try {
            encrypt()
        } catch (error: Exception) {
            if (!isInvalidKey(error)) throw error
            resetSecretKey()
            encrypt()
        }
    }

    private fun readEncryptedSecret(key: String): String? {
        return try {
            val stored = getSharedPreferences(securePrefsName, Context.MODE_PRIVATE)
                .getString(key, null) ?: return null
            val parts = stored.split(':')
            require(parts.size == 2)
            val iv = Base64.decode(parts[0], Base64.NO_WRAP)
            val data = Base64.decode(parts[1], Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(data), Charsets.UTF_8)
        } catch (error: Exception) {
            when {
                isInvalidKey(error) -> resetSecretKey()
                error is AEADBadTagException || error is IllegalArgumentException ||
                        error is java.security.InvalidAlgorithmParameterException -> removeStoredSecret(key)
                else -> throw error
            }
            Log.w(TAG, "Removed an unreadable encrypted credential", error)
            null
        }
    }

    private fun isInvalidKey(error: Exception): Boolean =
        generateSequence<Throwable>(error) { it.cause }.any {
            it is KeyPermanentlyInvalidatedException || it is UnrecoverableKeyException
        }

    private fun resetSecretKey() {
        val store = KeyStore.getInstance("AndroidKeyStore")
        store.load(null)
        store.deleteEntry(keystoreAlias)
        check(getSharedPreferences(securePrefsName, Context.MODE_PRIVATE).edit().clear().commit())
    }

    private fun removeStoredSecret(key: String) {
        check(getSharedPreferences(securePrefsName, Context.MODE_PRIVATE).edit().remove(key).commit())
    }

    private fun emitEvent(type: String, payload: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to type, "payload" to payload))
        }
    }

    private companion object {
        const val TAG = "InkBoxPlatform"
        const val maxBackupTransferBytes = 17L * 1024 * 1024 * 1024
        var pendingPicker: PendingPicker? = null
        var retainedPickerEngine: FlutterEngine? = null
        var eventSink: EventChannel.EventSink? = null
        val pendingIncomingUris = ArrayDeque<Uri>()
        val backupDestinations = mutableMapOf<String, Uri>()
        val imageExtensions = setOf("jpg", "jpeg", "png", "gif", "webp", "bmp", "avif")
        val importExtensions = setOf("epub", "txt", "pdf", "mobi", "azw3", "fb2", "md", "cbz", "zip",
            "cbr", "rar", "cb7", "7z", "json")
        val libraryExecutor = taskExecutor(3, 128)
        val pdfExecutor = taskExecutor(1, 32)
        val secretExecutor = taskExecutor(1, 16)
        val platformEvents = object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                flushIncomingFiles()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        }

        fun flushIncomingFiles() {
            val sink = eventSink ?: return
            while (pendingIncomingUris.isNotEmpty()) {
                val uri = pendingIncomingUris.removeFirst()
                sink.success(mapOf("type" to "open_file", "payload" to mapOf("uri" to uri.toString())))
            }
        }

        private fun taskExecutor(workers: Int, pending: Int) = ThreadPoolExecutor(
            workers, workers, 30, TimeUnit.SECONDS, ArrayBlockingQueue(pending)
        ).apply { allowCoreThreadTimeOut(true) }
    }
}
