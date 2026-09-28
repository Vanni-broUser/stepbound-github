package com.genericlab.stepbound

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Answers `lib/report/device_info.dart`: what the phone and the
    // installed build are, for the head of an error report.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stepbound/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "info") {
                    result.success(deviceInfo())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun deviceInfo(): Map<String, Any?> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        val memory = ActivityManager.MemoryInfo().also {
            (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(it)
        }
        val mb = 1024L * 1024L
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "system" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "memory" to "${memory.availMem / mb} MB liberi di ${memory.totalMem / mb}",
            "versionName" to info.versionName,
            "versionCode" to versionCode,
        )
    }
}
