package com.vibeplay.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import android.content.ContentUris
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Hosts the Flutter UI and exposes a small native bridge ("vibeplay/media") that
 * queries Android's MediaStore directly (no file picker) and loads album artwork.
 *
 * Extends AudioServiceActivity so just_audio_background can run the media session
 * and foreground service from the same Flutter engine.
 */
class MainActivity : AudioServiceActivity() {

    private val channelName = "vibeplay/media"
    private val executor = Executors.newFixedThreadPool(3)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioExtensions = setOf("mp3", "m4a", "wav", "aac", "flac")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "querySongs" -> runAsync(result) { querySongs() }
                    "scanStorage" -> runAsync(result) { scanStorage() }
                    "getArtwork" -> {
                        val id = call.argument<Number>("id")?.toLong() ?: -1L
                        val albumId = call.argument<Number>("albumId")?.toLong() ?: -1L
                        val size = call.argument<Number>("size")?.toInt() ?: 200
                        runAsync(result) { loadArtwork(id, albumId, size) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("NATIVE_ERROR", e.message, null) }
            }
        }
    }

    private fun audioCollection(): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
    }

    /** Reads every music file known to MediaStore (mp3, m4a, wav, aac, flac). */
    @Suppress("DEPRECATION")
    private fun querySongs(): List<Map<String, Any?>> {
        val songs = ArrayList<Map<String, Any?>>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.IS_RINGTONE,
            MediaStore.Audio.Media.IS_NOTIFICATION,
            MediaStore.Audio.Media.IS_ALARM
        )
        val sortOrder = MediaStore.Audio.Media.DATE_ADDED + " DESC"

        contentResolver.query(audioCollection(), projection, null, null, sortOrder)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durationCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val addedCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val nameCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val ringtoneCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.IS_RINGTONE)
            val notificationCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.IS_NOTIFICATION)
            val alarmCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.IS_ALARM)

            while (c.moveToNext()) {
                val displayName = c.getString(nameCol) ?: ""
                val ext = displayName.substringAfterLast('.', "").lowercase()
                if (ext !in audioExtensions) continue
                if (c.getInt(ringtoneCol) == 1 || c.getInt(notificationCol) == 1 || c.getInt(alarmCol) == 1) continue

                val duration = c.getLong(durationCol)
                // Skip very short clips (message tones, UI sounds). 0 means "unknown" so keep those.
                if (duration in 1..4999) continue

                val rawTitle = c.getString(titleCol)
                val title = if (rawTitle.isNullOrBlank()) displayName.substringBeforeLast('.') else rawTitle
                val rawArtist = c.getString(artistCol)
                val artist = if (rawArtist.isNullOrBlank() || rawArtist == "<unknown>") "Unknown Artist" else rawArtist
                val rawAlbum = c.getString(albumCol)
                val album = if (rawAlbum.isNullOrBlank() || rawAlbum == "<unknown>") "Unknown Album" else rawAlbum

                songs.add(
                    mapOf(
                        "id" to c.getLong(idCol),
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "albumId" to c.getLong(albumIdCol),
                        "duration" to duration,
                        "dateAdded" to c.getLong(addedCol)
                    )
                )
            }
        }
        return songs
    }

    /**
     * Walks /storage/emulated/0 for audio files that MediaStore does not know about yet
     * and asks Android's media scanner to index them. Returns how many files were submitted.
     */
    @Suppress("DEPRECATION")
    private fun scanStorage(): Int {
        val known = HashSet<String>()
        contentResolver.query(
            audioCollection(),
            arrayOf(MediaStore.Audio.Media.DATA),
            null,
            null,
            null
        )?.use { c ->
            val dataCol = c.getColumnIndex(MediaStore.Audio.Media.DATA)
            if (dataCol >= 0) {
                while (c.moveToNext()) {
                    val path = c.getString(dataCol)
                    if (path != null) known.add(path)
                }
            }
        }

        val unknown = ArrayList<String>()
        try {
            walk(Environment.getExternalStorageDirectory(), known, unknown, 0)
        } catch (e: Exception) {
            // Directory listing can be restricted on some devices; MediaStore results still work.
        }
        if (unknown.isEmpty()) return 0

        val latch = CountDownLatch(unknown.size)
        MediaScannerConnection.scanFile(applicationContext, unknown.toTypedArray(), null) { _, _ ->
            latch.countDown()
        }
        latch.await(25, TimeUnit.SECONDS)
        return unknown.size
    }

    private fun walk(dir: File, known: Set<String>, out: MutableList<String>, depth: Int) {
        if (depth > 12 || out.size > 5000) return
        val children = dir.listFiles() ?: return
        if (File(dir, ".nomedia").exists()) return
        for (f in children) {
            val name = f.name
            if (name.startsWith(".")) continue
            if (f.isDirectory) {
                if (depth == 0 && name == "Android") continue
                walk(f, known, out, depth + 1)
            } else {
                val ext = name.substringAfterLast('.', "").lowercase()
                if (ext in audioExtensions && !known.contains(f.absolutePath)) {
                    out.add(f.absolutePath)
                }
            }
        }
    }

    /** Returns JPEG bytes of the artwork for a song, or null when it has none. */
    private fun loadArtwork(id: Long, albumId: Long, size: Int): ByteArray? {
        var bitmap: Bitmap? = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val songUri = ContentUris.withAppendedId(audioCollection(), id)
                bitmap = contentResolver.loadThumbnail(songUri, Size(size, size), null)
            } catch (e: Exception) {
                bitmap = null
            }
        }

        if (bitmap == null && albumId > 0) {
            try {
                val artUri = ContentUris.withAppendedId(
                    Uri.parse("content://media/external/audio/albumart"),
                    albumId
                )
                contentResolver.openInputStream(artUri)?.use { stream ->
                    bitmap = BitmapFactory.decodeStream(stream)
                }
            } catch (e: Exception) {
                bitmap = null
            }
        }

        val source = bitmap ?: return null
        val longest = maxOf(source.width, source.height)
        val scaled = if (longest > size * 2) {
            val ratio = size.toFloat() / longest.toFloat()
            Bitmap.createScaledBitmap(
                source,
                maxOf(1, (source.width * ratio).toInt()),
                maxOf(1, (source.height * ratio).toInt()),
                true
            )
        } else {
            source
        }

        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 88, out)
        return out.toByteArray()
    }
}
