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
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Base64
import android.view.KeyEvent
import android.view.WindowManager
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.KeyStore
import java.util.Locale
import java.util.UUID
import java.util.zip.ZipFile
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
    private val libraryStorage by lazy { LibraryStorage(applicationContext) }

    private data class PendingPicker(
        val code: Int,
        val result: MethodChannel.Result,
        val backupFile: File?
    )

    private var pendingPicker: PendingPicker? = null
    private var eventSink: EventChannel.EventSink? = null
    private var volumeKeyPagingEnabled = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsInitializing = false
    private var currentTtsEngine: String = ""
    private var pendingSpeakAction: ((Boolean) -> Unit)? = null
    private var pendingSpeakTimeout: Runnable? = null
    private var pendingIncomingUri: Uri? = null

    private var mediaPlayer: MediaPlayer? = null
    private var activeAudioPlaybackId: String? = null
    private var audioFocusRequest: AudioFocusRequest? = null
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
        if (intent?.action == Intent.ACTION_VIEW && intent.data != null) {
            pendingIncomingUri = intent.data
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_VIEW && intent.data != null) {
            stageAndEmitIncomingFile(intent.data!!)
        }
    }

    override fun onDestroy() {
        pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingSpeakTimeout = null
        pendingSpeakAction = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        releaseMediaPlayer(abandonFocus = true)
        super.onDestroy()
    }

    private fun configureTtsListener(instance: TextToSpeech?) {
        instance?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                emitEvent("tts_start", mapOf("utteranceId" to (utteranceId ?: "")))
            }

            override fun onDone(utteranceId: String?) {
                emitEvent("tts_done", mapOf("utteranceId" to (utteranceId ?: "")))
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                emitEvent(
                    "tts_error",
                    mapOf("utteranceId" to (utteranceId ?: ""), "errorCode" to errorCode)
                )
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                emitEvent("tts_error", mapOf("utteranceId" to (utteranceId ?: "")))
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
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    pendingIncomingUri?.let {
                        pendingIncomingUri = null
                        stageAndEmitIncomingFile(it)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "workingDirectory" -> runLibraryTask(result) {
                        libraryStorage.workingDirectory()
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
                            (raw / 255.0).coerceIn(0.05, 1.0)
                        }
                        result.success(normalized)
                    }

                    "pickDocuments", "pickDocumentsDetailed" -> {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            type = "*/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        }
                        val code = if (call.method == "pickDocumentsDetailed") {
                            reqPickDocumentsDetailed
                        } else {
                            reqPickDocuments
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

                    "exportLocalBackup", "importLocalBackup" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("ARG", "Missing backup path", null)
                            return@setMethodCallHandler
                        }
                        val exporting = call.method == "exportLocalBackup"
                        val intent = Intent(
                            if (exporting) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT
                        ).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = if (exporting) "application/zip" else "*/*"
                            if (exporting) {
                                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                                putExtra(Intent.EXTRA_TITLE, File(path).name)
                            } else {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                putExtra(
                                    Intent.EXTRA_MIME_TYPES,
                                    arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream")
                                )
                            }
                        }
                        launchPicker(
                            intent,
                            if (exporting) reqExportBackup else reqImportBackup,
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
                        Thread {
                            try {
                                val treeUri = Uri.parse(treeUriStr)
                                if (contentResolver.persistedUriPermissions.none {
                                        it.uri == treeUri && it.isReadPermission
                                    }) {
                                    throw SecurityException("Folder access expired")
                                }
                                val items = scanTreeUri(treeUri)
                                mainHandler.post { result.success(items) }
                            } catch (error: Exception) {
                                mainHandler.post { result.error("SCAN", error.message, null) }
                            }
                        }.start()
                    }

                    "stageDocumentUri" -> {
                        val uriStr = call.argument<String>("uri")
                        val fileNameHint = call.argument<String>("fileName")
                        if (uriStr.isNullOrBlank()) {
                            result.error("ARG", "Missing uri", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val outcome = stageDocument(Uri.parse(uriStr), fileNameHint)
                            mainHandler.post {
                                if (outcome.file != null) {
                                    result.success(outcome.file.absolutePath)
                                } else {
                                    result.error("IO", outcome.error ?: "Failed to copy document", null)
                                }
                            }
                        }.start()
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
                            active.setSpeechRate(rate)
                            active.setPitch(pitch)
                            val uid = UUID.randomUUID().toString()
                            val rc = active.speak(text, TextToSpeech.QUEUE_FLUSH, null, uid)
                            return if (rc == TextToSpeech.SUCCESS) uid else null
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
                            tts?.stop()
                            tts?.shutdown()
                            tts = null
                            ttsReady = false
                            ttsInitializing = true
                            currentTtsEngine = requestedEngine

                            var responded = false
                            fun deliverSpeakResult(ok: Boolean, timedOut: Boolean = false) {
                                if (responded) return
                                responded = true
                                pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
                                pendingSpeakTimeout = null
                                mainHandler.post {
                                    when {
                                        timedOut -> result.error("ERR_TTS_TIMEOUT", "TTS init timeout", null)
                                        !ok -> result.error("ERR_TTS_UNAVAILABLE", "TTS engine unavailable", null)
                                        else -> {
                                            val uid = performSpeak()
                                            if (uid != null) {
                                                result.success(uid)
                                            } else {
                                                result.error("ERR_TTS_SPEAK_FAILED", "TTS speak failed", null)
                                            }
                                        }
                                    }
                                }
                            }

                            pendingSpeakAction = { ok -> deliverSpeakResult(ok) }
                            val watchdog = Runnable {
                                if (!responded) {
                                    ttsInitializing = false
                                    pendingSpeakAction = null
                                    deliverSpeakResult(ok = false, timedOut = true)
                                }
                            }
                            pendingSpeakTimeout = watchdog
                            mainHandler.postDelayed(watchdog, 5000L)

                            var createdRef: TextToSpeech? = null
                            val initCb = TextToSpeech.OnInitListener { st ->
                                mainHandler.post {
                                    if (tts === createdRef) {
                                        onInit(st)
                                    }
                                }
                            }
                            createdRef = if (requestedEngine.isEmpty()) {
                                TextToSpeech(this, initCb)
                            } else {
                                TextToSpeech(this, initCb, requestedEngine)
                            }
                            tts = createdRef
                        } else if (ttsInitializing) {
                            var responded = false
                            val watchdog = Runnable {
                                if (!responded) {
                                    responded = true
                                    ttsInitializing = false
                                    pendingSpeakAction = null
                                    result.error("ERR_TTS_TIMEOUT", "TTS init timeout", null)
                                }
                            }
                            pendingSpeakTimeout = watchdog
                            mainHandler.postDelayed(watchdog, 5000L)

                            pendingSpeakAction = { ok ->
                                if (!responded) {
                                    responded = true
                                    pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
                                    pendingSpeakTimeout = null
                                    mainHandler.post {
                                        if (!ok) {
                                            result.error("ERR_TTS_UNAVAILABLE", "TTS engine unavailable", null)
                                        } else {
                                            val uid = performSpeak()
                                            if (uid != null) {
                                                result.success(uid)
                                            } else {
                                                result.error("ERR_TTS_SPEAK_FAILED", "TTS speak failed", null)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            val uid = performSpeak()
                            if (uid != null) {
                                result.success(uid)
                            } else {
                                result.error("ERR_TTS_SPEAK_FAILED", "TTS speak failed", null)
                            }
                        }
                    }

                    "stopTts" -> {
                        pendingSpeakTimeout?.let { mainHandler.removeCallbacks(it) }
                        pendingSpeakTimeout = null
                        pendingSpeakAction?.invoke(false)
                        pendingSpeakAction = null
                        tts?.stop()
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
                        if ((requestedEngine.isEmpty() || requestedEngine == currentTtsEngine) &&
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
                        val path = call.argument<String>("path") ?: ""
                        val speed = (call.argument<Double>("speed") ?: 1.0).toFloat().coerceIn(0.4f, 2.5f)
                        val playbackId = call.argument<String>("playbackId") ?: UUID.randomUUID().toString()
                        val file = File(path)
                        if (!file.exists() || file.length() <= 0) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            releaseMediaPlayer(abandonFocus = false)
                            requestSpeechAudioFocus()
                            val mp = MediaPlayer()
                            mp.setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_MEDIA)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .build()
                            )
                            mp.setDataSource(file.absolutePath)
                            mp.prepare()
                            mp.setOnCompletionListener {
                                if (mediaPlayer !== mp) return@setOnCompletionListener
                                releaseMediaPlayer(abandonFocus = true)
                                emitEvent("audio_done", mapOf("playbackId" to playbackId))
                            }
                            mp.setOnErrorListener { _, what, extra ->
                                if (mediaPlayer !== mp) return@setOnErrorListener true
                                releaseMediaPlayer(abandonFocus = true)
                                emitEvent(
                                    "audio_error",
                                    mapOf("playbackId" to playbackId, "what" to what, "extra" to extra)
                                )
                                true
                            }
                            mediaPlayer = mp
                            activeAudioPlaybackId = playbackId
                            mp.start()
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                try {
                                    val params = mp.playbackParams
                                    mp.playbackParams = params.setSpeed(speed)
                                } catch (_: Exception) {
                                }
                            }
                            emitEvent("audio_start", mapOf("playbackId" to playbackId))
                            result.success(true)
                        } catch (_: Exception) {
                            releaseMediaPlayer(abandonFocus = true)
                            emitEvent("audio_error", mapOf("playbackId" to playbackId))
                            result.success(false)
                        }
                    }

                    "pauseAudio" -> {
                        try {
                            mediaPlayer?.takeIf { it.isPlaying }?.pause()
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }

                    "resumeAudio" -> {
                        try {
                            requestSpeechAudioFocus()
                            mediaPlayer?.takeIf { !it.isPlaying }?.start()
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }

                    "stopAudio" -> {
                        releaseMediaPlayer(abandonFocus = true)
                        result.success(null)
                    }

                    "setAudioSpeed" -> {
                        val speed = (call.argument<Double>("speed") ?: 1.0).toFloat().coerceIn(0.4f, 2.5f)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                mediaPlayer?.let { mp ->
                                    val wasPlaying = mp.isPlaying
                                    val params = mp.playbackParams
                                    mp.playbackParams = params.setSpeed(speed)
                                    if (!wasPlaying && mp.isPlaying) {
                                        mp.pause()
                                    }
                                }
                            } catch (_: Exception) {
                            }
                        }
                        result.success(null)
                    }

                    "saveSecret" -> {
                        val key = call.argument<String>("key") ?: ""
                        val value = call.argument<String>("value") ?: ""
                        if (key.isNotEmpty()) {
                            saveEncryptedSecret(key, value)
                        }
                        result.success(null)
                    }

                    "readSecret" -> {
                        val key = call.argument<String>("key") ?: ""
                        result.success(if (key.isNotEmpty()) readEncryptedSecret(key) else null)
                    }

                    "deleteSecret" -> {
                        val key = call.argument<String>("key") ?: ""
                        if (key.isNotEmpty()) {
                            getSharedPreferences(securePrefsName, Context.MODE_PRIVATE)
                                .edit()
                                .remove(key)
                                .apply()
                        }
                        result.success(null)
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
                        val path = call.argument<String>("path") ?: ""
                        Thread {
                            val count = try {
                                ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
                                    PdfRenderer(pfd).use { it.pageCount }
                                }
                            } catch (_: Exception) {
                                0
                            }
                            mainHandler.post { result.success(count) }
                        }.start()
                    }

                    "renderPdfPage" -> {
                        val path = call.argument<String>("path") ?: ""
                        val pageIndex = call.argument<Int>("pageIndex") ?: 0
                        val scale = (call.argument<Double>("scale") ?: 2.0).toFloat().coerceIn(0.8f, 3.5f)
                        Thread {
                            val pngBytes = try {
                                ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
                                    PdfRenderer(pfd).use { renderer ->
                                        if (pageIndex < 0 || pageIndex >= renderer.pageCount) {
                                            null
                                        } else {
                                            renderer.openPage(pageIndex).use { page ->
                                                val w = (page.width * scale).toInt().coerceIn(64, 2400)
                                                val h = (page.height * scale).toInt().coerceIn(64, 3400)
                                                val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                                                Canvas(bmp).drawColor(Color.WHITE)
                                                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                                val bos = ByteArrayOutputStream()
                                                bmp.compress(Bitmap.CompressFormat.PNG, 92, bos)
                                                bmp.recycle()
                                                bos.toByteArray()
                                            }
                                        }
                                    }
                                }
                            } catch (_: Exception) {
                                null
                            }
                            mainHandler.post { result.success(pngBytes) }
                        }.start()
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

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val picker = pendingPicker?.takeIf { it.code == requestCode } ?: return
        val callback = picker.result
        pendingPicker = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            when (requestCode) {
                reqPickDocuments -> callback.success(emptyList<String>())
                reqPickDocumentsDetailed -> callback.success(
                    mapOf("paths" to emptyList<String>(), "errors" to emptyList<String>())
                )
                reqExportBackup, reqImportBackup -> callback.success(false)
                else -> callback.success(null)
            }
            return
        }

        when (requestCode) {
            reqPickDocuments, reqPickDocumentsDetailed -> {
                val uris = LinkedHashSet<Uri>()
                val clip = data.clipData
                if (clip != null && clip.itemCount > 0) {
                    for (i in 0 until clip.itemCount) {
                        clip.getItemAt(i)?.uri?.let { uris.add(it) }
                    }
                } else {
                    data.data?.let { uris.add(it) }
                }

                Thread {
                    val paths = mutableListOf<String>()
                    val errors = mutableListOf<String>()
                    for (uri in uris) {
                        val outcome = stageDocument(uri, null)
                        if (outcome.file != null) {
                            paths.add(outcome.file.absolutePath)
                        } else {
                            errors.add(outcome.error ?: "无法读取所选文件 ($uri)")
                        }
                    }
                    mainHandler.post {
                        if (requestCode == reqPickDocumentsDetailed) {
                            callback.success(mapOf("paths" to paths, "errors" to errors))
                        } else {
                            callback.success(paths)
                        }
                    }
                }.start()
            }

            reqPickDirectory -> {
                val treeUri = data.data
                if (treeUri != null) {
                    try {
                        contentResolver.takePersistableUriPermission(
                            treeUri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                    } catch (error: SecurityException) {
                        callback.error("SCAN", error.message, null)
                        return
                    }
                    val doc = DocumentFile.fromTreeUri(this, treeUri)
                    callback.success(
                        mapOf(
                            "uri" to treeUri.toString(),
                            "name" to (doc?.name ?: treeUri.lastPathSegment ?: "本地目录")
                        )
                    )
                } else {
                    callback.success(null)
                }
            }

            reqWorkingDirectory -> {
                val uri = data.data
                if (uri == null) {
                    callback.success(null)
                } else {
                    runLibraryTask(callback) { libraryStorage.selectWorkingDirectory(uri, data.flags) }
                }
            }

            reqExportBackup, reqImportBackup -> {
                val uri = data.data
                val backupFile = picker.backupFile
                if (uri == null || backupFile == null) {
                    callback.success(false)
                    return
                }
                transferBackup(uri, backupFile, requestCode == reqExportBackup, callback)
            }
        }
    }

    private fun transferBackup(uri: Uri, file: File, exporting: Boolean, result: MethodChannel.Result) {
        Thread {
            val existedWithContent = if (exporting) {
                runCatching {
                    DocumentFile.fromSingleUri(this, uri)?.length()?.let { it > 0L } == true
                }.getOrDefault(false)
            } else {
                false
            }
            try {
                if (exporting) {
                    file.inputStream().use { input ->
                        val output = openTruncatedOutputStream(uri)
                            ?: error("Could not open the backup destination")
                        output.use { input.copyTo(it, 64 * 1024) }
                    }
                } else {
                    val input = contentResolver.openInputStream(uri)
                        ?: error("Could not open the backup file")
                    input.use { stream ->
                        file.outputStream().use { stream.copyTo(it, 64 * 1024) }
                    }
                }
                mainHandler.post { result.success(true) }
            } catch (error: Exception) {
                if (exporting && !existedWithContent) {
                    runCatching { DocumentsContract.deleteDocument(contentResolver, uri) }
                }
                mainHandler.post { result.error("BACKUP_IO", error.message, null) }
            }
        }.start()
    }

    private fun openTruncatedOutputStream(uri: Uri): java.io.OutputStream? {
        try {
            contentResolver.openOutputStream(uri, "wt")?.let { return it }
        } catch (_: IllegalArgumentException) {
        } catch (_: UnsupportedOperationException) {
        }
        val pfd = try {
            contentResolver.openFileDescriptor(uri, "rw")
        } catch (_: Exception) {
            null
        } ?: return null
        return try {
            val fos = java.io.FileOutputStream(pfd.fileDescriptor)
            fos.channel.truncate(0L)
            object : java.io.FilterOutputStream(fos) {
                override fun write(b: ByteArray, off: Int, len: Int) {
                    out.write(b, off, len)
                }

                override fun close() {
                    try {
                        super.close()
                    } finally {
                        pfd.close()
                    }
                }
            }
        } catch (e: Exception) {
            runCatching { pfd.close() }
            throw e
        }
    }

    private data class StagedCopyResult(val file: File?, val error: String? = null)

    private fun runLibraryTask(result: MethodChannel.Result, task: () -> Any?) {
        Thread {
            try {
                val value = task()
                mainHandler.post { result.success(value) }
            } catch (error: Exception) {
                mainHandler.post { result.error("LIBRARY_IO", error.message, null) }
            }
        }.start()
    }

    private fun stageAndEmitIncomingFile(uri: Uri) {
        emitEvent("open_file", mapOf("uri" to uri.toString()))
    }

    private fun stageDocument(uri: Uri, nameHint: String?): StagedCopyResult {
        val staging = runCatching { libraryStorage.temporaryDirectory() }.getOrElse {
            return StagedCopyResult(null, it.message)
        }
        val tmpFile = File(staging, ".staging")
        var success = false
        return try {
            val rawName = sequenceOf(nameHint, queryDisplayName(uri))
                .mapNotNull { it?.trim() }
                .firstOrNull { it.isNotEmpty() }
                ?: "import_${System.currentTimeMillis()}"

            // Strip any SAF document path prefixes like "primary:Download/book.epub"
            val decodedName = Uri.decode(rawName)
                .substringAfterLast('/')
                .substringAfterLast('\\')
                .substringAfterLast(':')
                .trim()
                .ifEmpty { "import_${System.currentTimeMillis()}" }

            // Copy stream into staging temp file first (with ParcelFileDescriptor fallback)
            var bytesCopied = 0L
            val stream = try {
                contentResolver.openInputStream(uri)
            } catch (_: Exception) {
                null
            }
            if (stream != null) {
                stream.use { input ->
                    FileOutputStream(tmpFile).use { output ->
                        bytesCopied = input.copyTo(output, 64 * 1024)
                        output.flush()
                    }
                }
            } else {
                contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                    FileInputStream(pfd.fileDescriptor).use { input ->
                        FileOutputStream(tmpFile).use { output ->
                            bytesCopied = input.copyTo(output, 64 * 1024)
                            output.flush()
                        }
                    }
                } ?: return StagedCopyResult(null, "$decodedName: 无法打开文件流，请检查存储权限或确认文件已在本地")
            }

            if (bytesCopied <= 0L || !tmpFile.exists() || tmpFile.length() <= 0L) {
                tmpFile.delete()
                return StagedCopyResult(null, "$decodedName: 文件内容为空 (0 字节)，若为云盘占位文件请先下载到本地")
            }

            // Ensure a known file extension (fallback to MIME type or magic bytes)
            val knownExts = setOf("epub", "txt", "pdf", "mobi", "azw3", "fb2", "md", "cbz", "zip", "cbr", "rar", "cb7", "7z", "json")
            var safeName = decodedName.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim()
            val curExt = safeName.substringAfterLast('.', "").lowercase(Locale.ROOT)
            if (curExt !in knownExts) {
                val inferred = inferExtensionFromMime(contentResolver.getType(uri))
                    ?: sniffExtensionFromFile(tmpFile)
                if (inferred != null) {
                    safeName = "$safeName.$inferred"
                }
            }

            if (safeName.isEmpty() || safeName == "." || safeName == ".." || safeName == ".staging") {
                safeName = "import_${System.currentTimeMillis()}"
            }
            val target = File(staging, safeName)
            if (!tmpFile.renameTo(target)) {
                tmpFile.copyTo(target)
                tmpFile.delete()
            }
            success = true
            StagedCopyResult(target)
        } catch (e: Exception) {
            StagedCopyResult(null, "文件复制失败: ${e.message ?: e.javaClass.simpleName}")
        } finally {
            if (!success) staging.deleteRecursively()
        }
    }

    private fun inferExtensionFromMime(mime: String?): String? {
        return when (mime?.lowercase(Locale.ROOT)?.substringBefore(';')?.trim()) {
            "application/epub+zip" -> "epub"
            "application/pdf" -> "pdf"
            "text/plain" -> "txt"
            "text/markdown", "text/x-markdown" -> "md"
            "application/x-mobipocket-ebook", "application/vnd.amazon.ebook" -> "mobi"
            "application/x-fictionbook+xml", "application/x-fictionbook" -> "fb2"
            "application/x-cbz", "application/vnd.comicbook+zip" -> "cbz"
            "application/zip" -> "zip"
            "application/x-cbr", "application/vnd.comicbook-rar", "application/x-rar-compressed" -> "cbr"
            "application/x-cb7", "application/x-7z-compressed" -> "cb7"
            "application/json", "text/json" -> "json"
            else -> null
        }
    }

    private fun sniffExtensionFromFile(file: File): String? {
        val header = ByteArray(128)
        val n = try {
            FileInputStream(file).use { it.read(header) }
        } catch (_: Exception) {
            return null
        }
        if (n < 4) return "txt"
        // %PDF-
        if (header[0] == 0x25.toByte() && header[1] == 0x50.toByte() &&
            header[2] == 0x44.toByte() && header[3] == 0x46.toByte()
        ) {
            return "pdf"
        }
        // ZIP-based: EPUB vs CBZ/ZIP
        if (header[0] == 0x50.toByte() && header[1] == 0x4B.toByte() &&
            (header[2] == 0x03.toByte() || header[2] == 0x05.toByte())
        ) {
            val isEpub = try {
                ZipFile(file).use { zf ->
                    zf.getEntry("META-INF/container.xml") != null || zf.getEntry("mimetype") != null
                }
            } catch (_: Exception) {
                false
            }
            return if (isEpub) "epub" else "cbz"
        }
        // 7z
        if (n >= 6 && header[0] == 0x37.toByte() && header[1] == 0x7A.toByte() &&
            header[2] == 0xBC.toByte() && header[3] == 0xAF.toByte()
        ) {
            return "cb7"
        }
        // RAR
        if (header[0] == 0x52.toByte() && header[1] == 0x61.toByte() &&
            header[2] == 0x72.toByte() && header[3] == 0x21.toByte()
        ) {
            return "cbr"
        }
        // MOBI ("BOOKMOBI" at offset 60)
        if (n >= 68) {
            val magic = String(header, 60, 8, Charsets.US_ASCII)
            if (magic == "BOOKMOBI" || magic == "TEXtREAd") return "mobi"
        }
        // FB2 XML
        val headText = String(header, 0, n, Charsets.UTF_8)
        if (headText.contains("<FictionBook", ignoreCase = true)) return "fb2"
        return "txt"
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
        return uri.lastPathSegment
    }

    private fun scanTreeUri(treeUri: Uri): List<Map<String, Any>> {
        val root = DocumentFile.fromTreeUri(this, treeUri)
            ?.takeIf { it.isDirectory && it.canRead() }
            ?: error("Could not read the selected folder")
        val allowed = setOf("epub", "txt", "pdf", "mobi", "azw3", "fb2", "md", "cbz", "zip", "cbr", "rar", "cb7", "7z")
        val results = mutableListOf<Map<String, Any>>()

        fun walk(dir: DocumentFile, depth: Int) {
            if (depth > 4) return
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

    private fun requestSpeechAudioFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attrs)
                .build()
            audioFocusRequest = req
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
    }

    private fun abandonSpeechAudioFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
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

    private fun releaseMediaPlayer(abandonFocus: Boolean) {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.reset()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
        activeAudioPlaybackId = null
        if (abandonFocus) {
            abandonSpeechAudioFocus()
        }
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
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
            val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            val ivB64 = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
            val dataB64 = Base64.encodeToString(encrypted, Base64.NO_WRAP)
            getSharedPreferences(securePrefsName, Context.MODE_PRIVATE)
                .edit()
                .putString(key, "$ivB64:$dataB64")
                .apply()
        } catch (_: Exception) {
        }
    }

    private fun readEncryptedSecret(key: String): String? {
        return try {
            val stored = getSharedPreferences(securePrefsName, Context.MODE_PRIVATE)
                .getString(key, null) ?: return null
            val parts = stored.split(':')
            if (parts.size != 2) return null
            val iv = Base64.decode(parts[0], Base64.NO_WRAP)
            val data = Base64.decode(parts[1], Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(data), Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    private fun emitEvent(type: String, payload: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to type, "payload" to payload))
        }
    }
}
