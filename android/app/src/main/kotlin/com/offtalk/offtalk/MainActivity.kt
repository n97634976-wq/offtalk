package com.offtalk.offtalk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.TelephonyManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SIM_CHANNEL = "com.offtalk/sim"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSimInfo" -> {
                        try {
                            val info = getSimInfo()
                            result.success(info)
                        } catch (e: Exception) {
                            result.error("SIM_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getSimInfo(): Map<String, String?> {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val info = mutableMapOf<String, String?>()

        info["simPresent"] = if (tm.simState == TelephonyManager.SIM_STATE_READY) "true" else "false"
        info["simOperator"] = tm.simOperatorName ?: ""
        info["simCountry"] = tm.simCountryIso ?: ""

        // Try to read phone number and SIM identifiers (requires READ_PHONE_STATE)
        val hasPermission = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED

        if (hasPermission) {
            try {
                info["phoneNumber"] = tm.line1Number ?: ""
            } catch (e: SecurityException) {
                info["phoneNumber"] = ""
            }

            try {
                info["iccid"] = tm.simSerialNumber ?: ""
            } catch (e: SecurityException) {
                info["iccid"] = ""
            }

            try {
                info["imsi"] = tm.subscriberId ?: ""
            } catch (e: SecurityException) {
                info["imsi"] = ""
            }

            try {
                info["deviceId"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    tm.imei ?: ""
                } else {
                    @Suppress("DEPRECATION")
                    tm.deviceId ?: ""
                }
            } catch (e: SecurityException) {
                info["deviceId"] = ""
            }
        } else {
            info["phoneNumber"] = ""
            info["iccid"] = ""
            info["imsi"] = ""
            info["deviceId"] = ""
        }

        return info
    }
}
