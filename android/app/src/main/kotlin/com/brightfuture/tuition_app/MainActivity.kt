package com.brightfuture.tuition_app

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Sends parent SMS from this phone's SIM for the TutorDesk "device" transport.
 *
 * Dart calls `send` with {id, phone, body}; the call completes when Android
 * reports the message as sent (or failed) for every part. Delivery reports
 * arrive later and are pushed to Dart as `delivered` {id}.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "tutordesk/sms"
    private val actionSent = "com.brightfuture.tuition_app.SMS_SENT"
    private val actionDelivered = "com.brightfuture.tuition_app.SMS_DELIVERED"
    private val permissionRequest = 4107

    private lateinit var channel: MethodChannel
    private var pendingPermission: MethodChannel.Result? = null
    private var requestCode = 0

    /** Outstanding sends keyed by message id: parts left, first error, Dart result. */
    private class Pending(var partsLeft: Int, val result: MethodChannel.Result, var error: String? = null)
    private val pending = mutableMapOf<String, Pending>()
    private val deliveredParts = mutableMapOf<String, Int>()

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getStringExtra("id") ?: return
            when (intent.action) {
                actionSent -> {
                    val p = pending[id] ?: return
                    if (resultCode != Activity.RESULT_OK && p.error == null) p.error = sendError(resultCode)
                    p.partsLeft -= 1
                    if (p.partsLeft <= 0) {
                        pending.remove(id)
                        if (p.error == null) p.result.success(mapOf("status" to "sent"))
                        else p.result.success(mapOf("status" to "failed", "reason" to p.error))
                    }
                }
                actionDelivered -> {
                    val left = (deliveredParts[id] ?: 1) - 1
                    if (left > 0) {
                        deliveredParts[id] = left
                    } else {
                        deliveredParts.remove(id)
                        channel.invokeMethod("delivered", mapOf("id" to id))
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasPermission())
                "requestPermission" -> {
                    if (hasPermission()) {
                        result.success(true)
                    } else {
                        pendingPermission?.success(false)
                        pendingPermission = result
                        requestPermissions(arrayOf(Manifest.permission.SEND_SMS), permissionRequest)
                    }
                }
                "send" -> send(
                    call.argument<String>("id")!!,
                    call.argument<String>("phone")!!,
                    call.argument<String>("body")!!,
                    result,
                )
                else -> result.notImplemented()
            }
        }
        val filter = IntentFilter().apply {
            addAction(actionSent)
            addAction(actionDelivered)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
        }
        for ((_, p) in pending) p.result.success(mapOf("status" to "failed", "reason" to "App closed before the phone confirmed sending"))
        pending.clear()
        super.onDestroy()
    }

    private fun hasPermission() =
        checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code != permissionRequest) return
        pendingPermission?.success(results.isNotEmpty() && results[0] == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }

    private fun send(id: String, phone: String, body: String, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.success(mapOf("status" to "failed", "reason" to "SMS permission not granted on the sending phone"))
            return
        }
        if (pending.containsKey(id)) {
            result.success(mapOf("status" to "failed", "reason" to "Already sending this message"))
            return
        }
        try {
            val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = sms.divideMessage(body)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            fun intent(action: String) = PendingIntent.getBroadcast(
                this,
                requestCode++,
                Intent(action).setPackage(packageName).putExtra("id", id),
                flags,
            )
            val sent = ArrayList(parts.map { intent(actionSent) })
            val delivered = ArrayList(parts.map { intent(actionDelivered) })
            pending[id] = Pending(parts.size, result)
            deliveredParts[id] = parts.size
            sms.sendMultipartTextMessage(phone, null, parts, sent, delivered)
            // Some devices never fire the sent intent; don't leave Dart waiting forever.
            Handler(Looper.getMainLooper()).postDelayed({
                pending.remove(id)?.result?.success(
                    mapOf("status" to "failed", "reason" to "Phone did not confirm sending within 60 seconds"),
                )
            }, 60_000)
        } catch (e: Exception) {
            pending.remove(id)
            deliveredParts.remove(id)
            result.success(mapOf("status" to "failed", "reason" to (e.message ?: "Could not send SMS")))
        }
    }

    private fun sendError(code: Int) = when (code) {
        SmsManager.RESULT_ERROR_NO_SERVICE -> "No mobile network on the sending phone"
        SmsManager.RESULT_ERROR_RADIO_OFF -> "Sending phone is in airplane mode"
        SmsManager.RESULT_ERROR_NULL_PDU -> "SMS could not be encoded"
        SmsManager.RESULT_ERROR_LIMIT_EXCEEDED -> "Phone's SMS sending limit reached"
        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Operator rejected the SMS (check SIM balance or plan)"
        else -> "Phone could not send the SMS (code $code)"
    }
}
