package com.retromesh.retro_mesh_console

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.Gravity
import android.widget.TextView
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.framework.CastContext
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class CastingAdapter(
    private val activity: Activity,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, "com.retromesh.console/casting")
    private val eventChannel = EventChannel(messenger, "com.retromesh.console/casting_events")

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    private val displayManager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private var mediaRouter: MediaRouter? = null
    private var mediaRouteSelector: MediaRouteSelector? = null

    private var presentationDialog: Presentation? = null
    private var currentTarget: JSONObject? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)

        // Initialize AndroidX MediaRouter scanner
        try {
            mediaRouter = MediaRouter.getInstance(activity)
            mediaRouteSelector = MediaRouteSelector.Builder()
                .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
                .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
                .build()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Listen for standard HDMI/Miracast presentation screens from DisplayManager
        displayManager.registerDisplayListener(object : DisplayManager.DisplayListener {
            override fun onDisplayAdded(displayId: Int) { 
                updateDevices()
                if (currentTarget != null && presentationDialog == null) {
                    projectGameplayCanvas()
                }
            }
            override fun onDisplayRemoved(displayId: Int) { updateDevices() }
            override fun onDisplayChanged(displayId: Int) { updateDevices() }
        }, handler)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScanning" -> {
                startScanning()
                result.success(null)
            }
            "stopScanning" -> {
                stopScanning()
                result.success(null)
            }
            "connectToDevice" -> {
                val args = call.arguments as? Map<String, Any>
                if (args != null) {
                    currentTarget = JSONObject(args)
                    connectToDevice(currentTarget!!)
                }
                result.success(null)
            }
            "projectGameplayCanvas" -> {
                projectGameplayCanvas()
                result.success(null)
            }
            "disconnect" -> {
                disconnect()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        updateDevices()
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    private fun startScanning() {
        handler.post {
            try {
                mediaRouter?.let { router ->
                    mediaRouteSelector?.let { selector ->
                        router.addCallback(selector, mediaRouterCallback, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            updateDevices()
        }
    }

    private fun stopScanning() {
        handler.post {
            try {
                mediaRouter?.removeCallback(mediaRouterCallback)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private val mediaRouterCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) { updateDevices() }
        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) { updateDevices() }
        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) { updateDevices() }
    }

    private fun updateDevices() {
        val targets = JSONArray()

        // 1. Google Cast routes discovery
        try {
            mediaRouter?.let { router ->
                for (route in router.routes) {
                    if (route.isDefault || route.isSystemRoute) continue
                    val extras = route.extras
                    val isCast = extras != null && extras.getString("com.google.android.gms.cast.EXTRA_SESSION_ID") != null
                    
                    val obj = JSONObject()
                    obj.put("id", route.id)
                    obj.put("name", route.name)
                    obj.put("protocolType", if (isCast) "googleCast" else "androidPresentation")
                    targets.put(obj)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Miracast / Presentation Displays discovery
        try {
            val displays = displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            for (display in displays) {
                var exists = false
                for (i in 0 until targets.length()) {
                    val target = targets.getJSONObject(i)
                    if (target.getString("id") == display.displayId.toString()) {
                        exists = true
                        break
                    }
                }
                if (!exists) {
                    val obj = JSONObject()
                    obj.put("id", display.displayId.toString())
                    obj.put("name", display.name)
                    obj.put("protocolType", "androidPresentation")
                    targets.put(obj)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        handler.post {
            eventSink?.success(targets.toString())
        }
    }

    private fun connectToDevice(target: JSONObject) {
        val protocolType = target.optString("protocolType", "androidPresentation")
        val id = target.getString("id")

        try {
            // Programmatic selection of Google Cast or Miracast route
            mediaRouter?.let { router ->
                val route = router.routes.firstOrNull { it.id == id }
                if (route != null) {
                    router.selectRoute(route)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun projectGameplayCanvas() {
        handler.post {
            val target = currentTarget
            val protocolType = target?.optString("protocolType") ?: "androidPresentation"
            
            if (protocolType == "googleCast") {
                try {
                    // Initialize the session manager and request stream loading on Cast receiver
                    val castContext = CastContext.getSharedInstance(activity)
                    val sessionManager = castContext.sessionManager
                    val currentSession = sessionManager.currentCastSession
                    if (currentSession != null && currentSession.isConnected) {
                        // Cast session exists. Remote Presentation setup would launch here.
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            
            // For both androidPresentation and fallback googleCast local mirror rendering:
            // Locate secondary display and spawn native Presentation Dialog
            val displays = displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            if (displays.isNotEmpty()) {
                // Select display matching current target or fallback to first display
                val displayId = target?.optString("id")?.toIntOrNull()
                val externalDisplay = displays.firstOrNull { it.displayId == displayId } ?: displays[0]
                
                presentationDialog = object : Presentation(activity, externalDisplay) {
                    override fun onCreate(savedInstanceState: Bundle?) {
                        super.onCreate(savedInstanceState)
                        val tvTextView = TextView(context).apply {
                            text = "Retro Mesh Console: Projection Active\nWebGL TV Viewport Projected via Adapter Subsystem"
                            gravity = Gravity.CENTER
                            textSize = 22f
                            setTextColor(android.graphics.Color.WHITE)
                            setBackgroundColor(android.graphics.Color.BLACK)
                        }
                        setContentView(tvTextView)
                    }
                }
                presentationDialog?.show()
            }
        }
    }

    private fun disconnect() {
        handler.post {
            presentationDialog?.dismiss()
            presentationDialog = null
            currentTarget = null
            
            try {
                mediaRouter?.let { router ->
                    router.selectRoute(router.defaultRoute)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
