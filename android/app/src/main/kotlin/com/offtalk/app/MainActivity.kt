package com.offtalk.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
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
                        val simInfo = mutableMapOf<String, String?>()

                        if (ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.READ_PHONE_STATE
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            val telephonyManager =
                                getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

                            simInfo["simPresent"] =
                                (telephonyManager.simState == TelephonyManager.SIM_STATE_READY).toString()

                            try {
                                @Suppress("DEPRECATION")
                                simInfo["iccid"] = telephonyManager.simSerialNumber
                            } catch (e: SecurityException) {
                                simInfo["iccid"] = null
                            }

                            try {
                                @Suppress("DEPRECATION")
                                simInfo["imsi"] = telephonyManager.subscriberId
                            } catch (e: SecurityException) {
                                simInfo["imsi"] = null
                            }

                            try {
                                @Suppress("DEPRECATION")
                                simInfo["phoneNumber"] = telephonyManager.line1Number
                            } catch (e: SecurityException) {
                                simInfo["phoneNumber"] = null
                            }

                            simInfo["simOperator"] = telephonyManager.simOperatorName
                            simInfo["simCountry"] = telephonyManager.simCountryIso
                            simInfo["deviceId"] = Build.SERIAL
                        } else {
                            simInfo["error"] = "PERMISSION_DENIED"
                            simInfo["simPresent"] = "false"
                        }

                        result.success(simInfo)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
