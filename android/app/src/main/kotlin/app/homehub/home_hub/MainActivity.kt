package app.homehub.home_hub

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.max

private const val TASK_IMAGE_CHANNEL = "app.homehub/task_images"
private const val PREFERENCES_CHANNEL = "app.homehub/preferences"
private const val FONT_PREFERENCE_FILE = "homehub_preferences"
private const val FONT_SIZE_KEY = "font_size"

class MainActivity : FlutterActivity() {
    private var imagePickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_IMAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickAndCompress") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (imagePickerResult != null) {
                    result.error("picker_busy", "An image selection is already open", null)
                    return@setMethodCallHandler
                }
                imagePickerResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "image/*"
                }
                startActivityForResult(intent, 7071)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PREFERENCES_CHANNEL)
            .setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences(FONT_PREFERENCE_FILE, MODE_PRIVATE)
                when (call.method) {
                    "getFontSize" -> result.success(preferences.getString(FONT_SIZE_KEY, "normal"))
                    "setFontSize" -> {
                        val value = call.arguments as? String
                        if (value !in setOf("small", "normal", "large")) {
                            result.error("invalid_font_size", "Unsupported font size", null)
                        } else {
                            preferences.edit().putString(FONT_SIZE_KEY, value).apply()
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android, still used for FlutterActivity result routing")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7071) return
        val callback = imagePickerResult ?: return
        imagePickerResult = null
        if (resultCode != RESULT_OK || data?.data == null) {
            callback.success(null)
            return
        }
        try {
            val result = compressImage(data.data!!)
            callback.success(result)
        } catch (error: Exception) {
            callback.error("image_read_failed", "Could not prepare this image", null)
        }
    }

    private fun compressImage(uri: Uri): Map<String, Any> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > 1920) sample *= 2
        val source = contentResolver.openInputStream(uri).use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        }
            ?: throw IllegalArgumentException("Unsupported image")
        val maxDimension = 1920.0
        val scale = minOf(1.0, maxDimension / max(source.width, source.height))
        val bitmap = if (scale < 1.0) Bitmap.createScaledBitmap(source,
            (source.width * scale).toInt(), (source.height * scale).toInt(), true) else source
        var quality = 88
        var output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
        while (output.size() > 500 * 1024 && quality > 45) {
            quality -= 7
            output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
        }
        var finalBitmap = bitmap
        while (output.size() > 500 * 1024 && finalBitmap.width > 640) {
            finalBitmap = Bitmap.createScaledBitmap(finalBitmap, finalBitmap.width * 3 / 4,
                finalBitmap.height * 3 / 4, true)
            output = ByteArrayOutputStream()
            finalBitmap.compress(Bitmap.CompressFormat.JPEG, 48, output)
        }
        if (source !== bitmap) source.recycle()
        if (finalBitmap !== bitmap) bitmap.recycle()
        val bytes = output.toByteArray()
        return mapOf("bytes" to bytes, "width" to finalBitmap.width, "height" to finalBitmap.height)
    }
}
