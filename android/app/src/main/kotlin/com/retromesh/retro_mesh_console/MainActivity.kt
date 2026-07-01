package com.retromesh.retro_mesh_console

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.hardware.display.DisplayManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.retromesh.console/projection"
    private var presentationDialog: android.app.Presentation? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CastingAdapter(this, flutterEngine.dartExecutor.binaryMessenger)
        AudioAdapter(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retromesh.console/wifi").setMethodCallHandler { call, result ->
            if (call.method == "getWifiRssi") {
                try {
                    val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
                    val info = wifiManager.connectionInfo
                    if (info != null && info.rssi != -127) {
                        result.success(info.rssi)
                    } else {
                        result.success(null)
                    }
                } catch (e: Exception) {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
        val textureRegistry = flutterEngine.renderer
        val textureEntry = textureRegistry.createSurfaceTexture()
        val surface = android.view.Surface(textureEntry.surfaceTexture())
        NativeRender.setFlutterSurface(surface)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.retromesh.console/texture").setMethodCallHandler { call, result ->
            if (call.method == "getTextureId") {
                result.success(textureEntry.id())
            } else {
                result.notImplemented()
            }
        }
    }
}

object NativeRender {
    init {
        System.loadLibrary("native_render")
    }
    external fun setFlutterSurface(surface: android.view.Surface?)
    external fun setTvSurface(surface: android.view.Surface?)
}
