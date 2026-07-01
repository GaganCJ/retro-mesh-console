package com.retromesh.retro_mesh_console

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.widget.ImageView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class CastingAdapter(
    private val activity: Activity,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val methodChannel = MethodChannel(messenger, "com.retromesh.console/projection")
    private val handler = Handler(Looper.getMainLooper())
    private val displayManager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    
    private var presentationDialog: Presentation? = null
    private var presentationImageView: ImageView? = null
    private var frameBitmap: Bitmap? = null

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openSystemCastMenu" -> {
                openSystemCastMenu()
                result.success(null)
            }
            "startTVProjection" -> {
                val success = startTVProjection()
                result.success(success)
            }
            "stopTVProjection" -> {
                stopTVProjection()
                result.success(null)
            }
            "sendFrame" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes != null) {
                    renderFrame(bytes)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun openSystemCastMenu() {
        handler.post {
            val intentsToTry = listOf(
                Intent("miui.intent.action.WIFI_DISPLAY_SETTINGS"),
                Intent("android.settings.WIFI_DISPLAY_SETTINGS"),
                Intent("android.settings.CAST_SETTINGS")
            )

            var success = false
            for (intent in intentsToTry) {
                try {
                    if (intent.resolveActivity(activity.packageManager) != null) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity.startActivity(intent)
                        success = true
                        break
                    }
                } catch (e: Exception) {
                    // Try next intent
                }
            }
            
            if (!success) {
                try {
                    val fallback = Intent("android.settings.CAST_SETTINGS")
                    fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(fallback)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private fun startTVProjection(): Boolean {
        var success = false
        handler.post {
            try {
                val displays = displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                if (displays.isNotEmpty()) {
                    val externalDisplay = displays[0]
                    
                    if (presentationDialog != null) {
                        presentationDialog?.dismiss()
                    }
                    
                    presentationDialog = object : Presentation(activity, externalDisplay) {
                        override fun onCreate(savedInstanceState: Bundle?) {
                            super.onCreate(savedInstanceState)
                            
                            val container = android.widget.FrameLayout(context).apply {
                                setBackgroundColor(android.graphics.Color.BLACK)
                            }
                            
                            val imageView = ImageView(context).apply {
                                scaleType = ImageView.ScaleType.FIT_XY // We manually control aspect ratio
                            }
                            
                            container.addView(imageView, android.widget.FrameLayout.LayoutParams(
                                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                                android.view.ViewGroup.LayoutParams.MATCH_PARENT
                            ).apply {
                                gravity = android.view.Gravity.CENTER
                            })
                            
                            // Force 4:3 Aspect Ratio (e.g. 256x224 scaled to 4:3 CRT look)
                            container.addOnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
                                val w = right - left
                                val h = bottom - top
                                val targetW: Int
                                val targetH: Int
                                if (w * 3 > h * 4) { // TV is wider than 4:3 (e.g. 16:9)
                                    targetH = h
                                    targetW = h * 4 / 3
                                } else {
                                    targetW = w
                                    targetH = w * 3 / 4
                                }
                                val params = imageView.layoutParams
                                if (params.width != targetW || params.height != targetH) {
                                    params.width = targetW
                                    params.height = targetH
                                    imageView.layoutParams = params
                                }
                            }
                            
                            presentationImageView = imageView
                            setContentView(container)
                        }
                    }
                    presentationDialog?.show()
                    success = true
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        
        try {
            val displays = displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            if (displays.isNotEmpty()) {
                success = true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return success
    }

    private fun stopTVProjection() {
        handler.post {
            try {
                presentationDialog?.dismiss()
                presentationDialog = null
                presentationImageView = null
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun renderFrame(bytes: ByteArray) {
        if (presentationDialog == null || presentationImageView == null) return
        
        try {
            // Re-use bitmap to avoid GC churn at 60fps
            if (frameBitmap == null) {
                // Mock width and height from libretro.dart
                frameBitmap = Bitmap.createBitmap(256, 224, Bitmap.Config.ARGB_8888)
            }
            
            frameBitmap?.let { bitmap ->
                bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(bytes))
                handler.post {
                    if (presentationImageView?.drawable == null) {
                        val drawable = android.graphics.drawable.BitmapDrawable(activity.resources, bitmap)
                        drawable.isFilterBitmap = false // Nearest-neighbor for crisp retro pixels
                        presentationImageView?.setImageDrawable(drawable)
                    }
                    presentationImageView?.invalidate()
                }
            }
        } catch (e: Exception) {
            // Ignore frame drop errors silently
        }
    }
}
