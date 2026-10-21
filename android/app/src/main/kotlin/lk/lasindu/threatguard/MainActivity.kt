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
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "threatguard/sms"

        /**
         * Carries text shared into the app from another application.
         *
         * WhatsApp, Messenger, Instagram and Gmail encrypt their message
         * stores and expose no read API, so the Android share sheet is the
         * only legitimate way a third-party security app can be handed their
         * content. This is the same mechanism Signal and Bitdefender use.
         */
        private const val SHARE_CHANNEL = "threatguard/share"
        private const val READ_SMS_REQUEST_CODE = 1001
        private const val MAX_SMS_MESSAGES = 100
    }

    private val smsQueryExecutor: ExecutorService =
        Executors.newSingleThreadExecutor()

    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingPermissionResult: MethodChannel.Result? = null

    /** Events pushed to Dart when a share intent arrives. */
    private var shareSink: EventChannel.EventSink? = null

    /** Retains a share received before Dart was ready to listen. */
    private var pendingShare: Map<String, Any?>? = null

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

                "consumePendingShare" -> {
                    val share = pendingShare
                    pendingShare = null
                    result.success(share)
                }

                else -> result.notImplemented()
            }
        }

        // Streaming channel for shares that arrive while the app is running.
        EventChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            SHARE_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                shareSink = events

                // Deliver anything that arrived before Dart subscribed, so a
                // cold start from the share sheet is never lost.
                pendingShare?.let { share ->
                    events?.success(share)
                    pendingShare = null
                }
            }

            override fun onCancel(arguments: Any?) {
                shareSink = null
            }
        })
    }

    /**
     * Receives ACTION_SEND and ACTION_PROCESS_TEXT payloads.
     *
     * The originating package name is captured so Dart can label the channel
     * accurately ("Checked from WhatsApp") instead of guessing.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    override fun onResume() {
        super.onResume()

        // A cold start from the share sheet arrives here rather than in
        // onNewIntent, because the activity is created with that intent.
        intent?.let { handleShareIntent(it) }
    }

    private fun handleShareIntent(intent: Intent) {
        val action = intent.action

        val text: String? = when (action) {
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)

            Intent.ACTION_PROCESS_TEXT ->
                intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()

            else -> null
        }

        if (text.isNullOrBlank()) return

        val payload = mapOf(
            "text" to text,
            "sourcePackage" to intent.`package`,
            // The referrer identifies the sending app on modern Android.
            "referrer" to intent.getStringExtra(Intent.EXTRA_REFERRER_NAME)
        )

        // Clear the action so a resume does not re-deliver the same share.
        intent.action = null

        val sink = shareSink
        if (sink != null) {
            sink.success(payload)
        } else {
            pendingShare = payload
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

                    while (it.moveToNext() && messages.size < MAX_SMS_MESSAGES) {
                        val id = if (it.isNull(idIndex)) {
                            null
                        } else {
                            it.getString(idIndex)
                        }

                        val body = if (it.isNull(bodyIndex)) {
                            null
                        } else {
                            it.getString(bodyIndex)
                        }

                        val date = if (it.isNull(dateIndex)) {
                            null
                        } else {
                            it.getLong(dateIndex)
                        }

                        if (id.isNullOrBlank() || body.isNullOrBlank() || date == null) {
                            continue
                        }

                        val sender = if (addressIndex >= 0 && !it.isNull(addressIndex)) {
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