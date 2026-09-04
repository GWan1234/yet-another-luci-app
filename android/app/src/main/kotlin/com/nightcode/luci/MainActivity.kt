package com.nightcode.luci

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.view.WindowCompat
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.activity.enableEdgeToEdge
import androidx.activity.SystemBarStyle
import android.graphics.Color
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    private val PERMISSION_CHANNEL = "com.nightcode.luci/local_network_permission"
    private val LOCAL_NETWORK_PERMISSION_CODE = 1001
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Modern Jetpack Edge-to-Edge initialization for Android 15+ (API 35+) compliance
        try {
            enableEdgeToEdge(
                statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
                navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT)
            )
        } catch (_: Exception) {
            // Fallback for custom legacy framework environments
        }
        super.onCreate(savedInstanceState)
        
        // Unlock high refresh rate (90Hz/120Hz/144Hz) for ultra-smooth 120fps scrolling
        unlockHighRefreshRate()

        // Enable edge-to-edge layout & display cutout handling without using deprecated APIs
        setupEdgeToEdge()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkLocalNetworkPermission" -> {
                    val status = checkLocalNetworkPermissionStatus()
                    result.success(status)
                }
                "requestLocalNetworkPermission" -> {
                    if (Build.VERSION.SDK_INT >= 37) { // Android 17+ / API 37+
                        val permission = "android.permission.ACCESS_LOCAL_NETWORK"
                        if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(this, arrayOf(permission), LOCAL_NETWORK_PERMISSION_CODE)
                        }
                    } else {
                        // Automatically granted on Android 16 and lower
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkLocalNetworkPermissionStatus(): Boolean {
        return if (Build.VERSION.SDK_INT >= 37) {
            ContextCompat.checkSelfPermission(this, "android.permission.ACCESS_LOCAL_NETWORK") == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCAL_NETWORK_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onResume() {
        super.onResume()
        unlockHighRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            unlockHighRefreshRate()
        }
    }

    private fun unlockHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val display = this.display
                val supportedModes = display?.supportedModes
                val maxMode = supportedModes?.maxByOrNull { it.refreshRate }
                if (maxMode != null) {
                    val lp = window.attributes
                    lp.preferredDisplayModeId = maxMode.modeId
                    window.attributes = lp
                }
            } catch (_: Exception) {
                // High refresh rate API unsupported or managed by OS
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                @Suppress("DEPRECATION")
                val display = windowManager.defaultDisplay
                val supportedModes = display?.supportedModes
                val maxMode = supportedModes?.maxByOrNull { it.refreshRate }
                if (maxMode != null) {
                    val lp = window.attributes
                    lp.preferredDisplayModeId = maxMode.modeId
                    window.attributes = lp
                }
            } catch (_: Exception) {
                // High refresh rate API unsupported or managed by OS
            }
        }
    }
    
    private fun setupEdgeToEdge() {
        try {
            WindowCompat.setDecorFitsSystemWindows(window, false)

            // Configure modern display cutout mode (LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS for API 35+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val lp = window.attributes
                if (Build.VERSION.SDK_INT >= 35) { // Android 15+
                    lp.layoutInDisplayCutoutMode = android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                } else {
                    @Suppress("DEPRECATION")
                    lp.layoutInDisplayCutoutMode = android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
                window.attributes = lp
            }
            
            // Use WindowInsetsController with null-safety for light/dark status and navigation bar styling
            val controller = WindowCompat.getInsetsController(window, window.decorView)
            controller?.let {
                it.isAppearanceLightStatusBars = false
                it.isAppearanceLightNavigationBars = false
            }
        } catch (_: Exception) {
            // Defensive fallback ensuring zero startup crashes on non-standard device hardware/ROMs
        }
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW || level == android.content.ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            flutterEngine?.systemChannel?.sendMemoryPressureWarning()
        }
    }

    override fun onLowMemory() {
        super.onLowMemory()
        flutterEngine?.systemChannel?.sendMemoryPressureWarning()
    }
}
