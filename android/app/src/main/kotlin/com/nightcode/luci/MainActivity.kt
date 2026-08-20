package com.nightcode.luci

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Unlock high refresh rate (90Hz/120Hz/144Hz) for ultra-smooth 120fps scrolling
        unlockHighRefreshRate()

        // Enable edge-to-edge display without using deprecated APIs
        setupEdgeToEdge()
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
        // Enable edge-to-edge layout
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Use WindowInsetsController instead of deprecated window flags
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller?.let {
            // Make status bar and navigation bar transparent without deprecated APIs
            it.isAppearanceLightStatusBars = false
            it.isAppearanceLightNavigationBars = false
        }
        
        // For Android 15+ (API 35+), use the modern EdgeToEdge API
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            enableModernEdgeToEdge()
        }
    }
    
    private fun enableModernEdgeToEdge() {
        try {
            // Use reflection to call EdgeToEdge.enable() for Android 15+
            val edgeToEdgeClass = Class.forName("androidx.activity.EdgeToEdge")
            val enableMethod = edgeToEdgeClass.getMethod("enable", androidx.activity.ComponentActivity::class.java)
            enableMethod.invoke(null, this)
        } catch (e: Exception) {
            // Fallback is already handled by setupEdgeToEdge()
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Edge-to-edge is now handled natively without intercepting Flutter calls
        // This prevents deprecated API usage while maintaining compatibility
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
