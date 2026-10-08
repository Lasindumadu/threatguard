package lk.lasindu.threatguard

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "threatguard/sms"
        private const val READ_SMS_REQUEST_CODE = 1001
    }

    private val smsQueryExecutor: ExecutorService =
        Executors.newSingleThreadExecutor()

    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readSmsMessages" -> readSmsMessages(result)

                "requestSmsPermission" -> requestSmsPermission(result)

                "checkSmsPermission" -> {
                    result.success(
                        checkSelfPermission(Manifest.permission.READ_SMS) ==
                            PackageManager.PERMISSION_GRANTED
                    )
                }

                "isSmsPermissionPermanentlyDenied" -> {
                    result.success(isSmsPermissionPermanentlyDenied())
                }

                "openAppSettings" -> {
                    openAppSettings()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "PERMISSION_REQUEST_IN_PROGRESS",
                "An SMS permission request is already in progress.",
                null
            )
            return
        }

        pendingPermissionResult = result

        requestPermissions(
            arrayOf(Manifest.permission.READ_SMS),
            READ_SMS_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != READ_SMS_REQUEST_CODE) {
            return
        }

        val result = pendingPermissionResult
        pendingPermissionResult = null

        if (result == null) {
            return
        }

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED

        result.success(granted)
    }

    private fun isSmsPermissionPermanentlyDenied(): Boolean {
        if (checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        return !shouldShowRequestPermissionRationale(
            Manifest.permission.READ_SMS
        )
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName")
        )

        startActivity(intent)
    }

    private fun readSmsMessages(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "PERMISSION_DENIED",
                "READ_SMS permission has not been granted.",
                null
            )
            return
        }

        smsQueryExecutor.execute {
            val messages = mutableListOf<Map<String, Any?>>()

            try {
                val projection = arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE
                )

                val cursor = contentResolver.query(
                    Telephony.Sms.Inbox.CONTENT_URI,
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

                    if (idIndex < 0 || bodyIndex < 0 || dateIndex < 0) {
                        throw IllegalStateException(
                            "Required SMS columns are unavailable."
                        )
                    }

                    while (it.moveToNext()) {
                        val id = it.getString(idIndex)
                        val body = it.getString(bodyIndex)
                        val date = it.getLong(dateIndex)

                        if (id == null || body == null) {
                            continue
                        }

                        val sender = if (addressIndex >= 0) {
                            it.getString(addressIndex)
                        } else {
                            null
                        }

                        messages.add(
                            mapOf(
                                "id" to id,
                                "sender" to sender,
                                "body" to body,
                                "date" to date
                            )
                        )
                    }
                }

                mainHandler.post {
                    result.success(messages)
                }
            } catch (securityException: SecurityException) {
                mainHandler.post {
                    result.error(
                        "SMS_ACCESS_ERROR",
                        "ThreatGuard could not access SMS messages.",
                        null
                    )
                }
            } catch (exception: Exception) {
                mainHandler.post {
                    result.error(
                        "SMS_READ_ERROR",
                        "ThreatGuard could not read SMS messages.",
                        null
                    )
                }
            }
        }
    }

    override fun onDestroy() {
        smsQueryExecutor.shutdownNow()
        super.onDestroy()
    }
}