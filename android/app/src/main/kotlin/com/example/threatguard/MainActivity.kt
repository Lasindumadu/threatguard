package com.example.threatguard

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "threatguard/sms"
        private const val READ_SMS_REQUEST_CODE = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readSmsMessages" -> readSmsMessages(result)
                "requestSmsPermission" -> {
                    requestSmsPermissionIfNeeded()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        requestSmsPermissionIfNeeded()
    }

    private fun requestSmsPermissionIfNeeded() {
        if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                arrayOf(Manifest.permission.READ_SMS),
                READ_SMS_REQUEST_CODE
            )
        }
    }

    private fun readSmsMessages(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.error(
                "PERMISSION_DENIED",
                "READ_SMS permission has not been granted.",
                null
            )
            return
        }

        val messages = mutableListOf<Map<String, Any?>>()

        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )

        val cursor = contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        )

        cursor?.use {
            val idIndex = it.getColumnIndex(Telephony.Sms._ID)
            val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
            val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)

            while (it.moveToNext()) {
                messages.add(
                    mapOf(
                        "id" to it.getString(idIndex),
                        "sender" to it.getString(addressIndex),
                        "body" to it.getString(bodyIndex),
                        "date" to it.getLong(dateIndex)
                    )
                )
            }
        }

        result.success(messages)
    }
}