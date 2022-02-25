package hu.privatdoktor.flutter_ble_lib.event

import android.os.Handler
import android.os.Looper
import com.welie.blessed.ConnectionState
import hu.privatdoktor.flutter_ble_lib.ChannelName
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger
import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler
import org.json.JSONException
import org.json.JSONObject
import java.util.*

class ConnectionStateStreamHandler(
    binaryMessenger: BinaryMessenger?,
    val deviceId: String
) : EventChannel.StreamHandler {
    val name: String =  ChannelName.CONNECTION_STATE_CHANGE_EVENTS + "/" + deviceId.uppercase(Locale.getDefault())
    private val eventChannel: EventChannel = EventChannel(binaryMessenger, name)
    private var eventSink: EventSink? = null

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(o: Any, eventSink: EventSink) {
        this.eventSink = eventSink
    }

    override fun onCancel(o: Any) {
        eventSink = null
    }

    fun onNewConnectionState(connectionState: ConnectionState) {
        assert(Looper.getMainLooper().isCurrentThread())

        val connectionStateStr =
        when (connectionState) {
            ConnectionState.CONNECTING -> "connecting"
            ConnectionState.CONNECTED -> "connected"
            ConnectionState.DISCONNECTING -> "disconnecting"
            ConnectionState.DISCONNECTED -> "disconnected"
        }

        val payload = mapOf<String, String>(
            "peripheralIdentifier" to deviceId,
            "connectionState" to connectionStateStr
        )

        try {
            val jsonStr = JSONObject(payload).toString()
            eventSink?.success(jsonStr)
        } catch (e: JSONException) {
            eventSink?.error("-1", e.message, e.stackTrace)
        }
    }

    fun end() {
        onComplete()
    }

    fun onComplete() {
        eventSink?.endOfStream()
    }


}