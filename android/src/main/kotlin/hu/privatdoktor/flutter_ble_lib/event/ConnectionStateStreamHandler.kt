package hu.privatdoktor.flutter_ble_lib.event

import android.os.Handler
import android.os.Looper
import hu.privatdoktor.flutter_ble_lib.ChannelName
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger
import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler

import org.json.JSONException
import java.util.*

class ConnectionStateStreamHandler(binaryMessenger: BinaryMessenger?, deviceId: String) :
    EventChannel.StreamHandler {
    private val eventChannel: EventChannel
    @JvmField
    val name: String
    private var eventSink: EventSink? = null
//    private val connectionStateChangeJsonConverter = ConnectionStateChangeJsonConverter()

    init {
        name = ChannelName.CONNECTION_STATE_CHANGE_EVENTS + "/" + deviceId.uppercase(Locale.getDefault())
        eventChannel = EventChannel(binaryMessenger, name)
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(o: Any, eventSink: EventSink) {
        this.eventSink = eventSink
    }

    override fun onCancel(o: Any) {
        eventSink = null
    }

//    fun onNewConnectionState(connectionState: ConnectionStateChange?) {
//        assert(Looper.getMainLooper().isCurrentThread())
//        try {
//            eventSink?.success(
//                connectionStateChangeJsonConverter.toJson(
//                    connectionState
//                )
//            )
//        } catch (e: JSONException) {
//            eventSink?.error("-1", e.message, e.stackTrace)
//        }
//    }

    fun end() {
        onComplete()
    }

    fun onComplete() {
        eventSink?.endOfStream()
    }


}