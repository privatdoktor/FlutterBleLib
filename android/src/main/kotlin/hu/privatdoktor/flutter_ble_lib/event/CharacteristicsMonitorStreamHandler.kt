package hu.privatdoktor.flutter_ble_lib.event

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger

import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler

import org.json.JSONException
import java.util.*

class CharacteristicsMonitorStreamHandler(
    binaryMessenger: BinaryMessenger?,
    deviceIdentifier: String
) : EventChannel.StreamHandler {
//    private val eventChannel: EventChannel
    @JvmField
    val name: String = ""
    @JvmField
    val deviceId: String = ""
    private var eventSink: EventSink? = null
//    private val characteristicResponseJsonConverter = SingleCharacteristicResponseJsonConverter()
//    private val bleErrorJsonConverter = BleErrorJsonConverter()

    override fun onListen(o: Any, eventSink: EventSink) {
        this.eventSink = eventSink
    }

    override fun onCancel(o: Any) {
        eventSink = null
    }

//    @Throws(JSONException::class)
//    fun onCharacteristicsUpdate(characteristic: SingleCharacteristicResponse?) {
//        eventSink?.success(characteristicResponseJsonConverter.toJson(characteristic))
//    }
//
//    fun end() {
//        eventSink?.endOfStream()
//    }
//
//    fun onError(error: BleError, transactionId: String?) {
//        eventSink?.error(
//            error.errorCode.code.toString(),
//            error.reason,
//            bleErrorJsonConverter.toJson(error, transactionId)
//        )
//    }
//
//    init {
//        name = ChannelName.MONITOR_CHARACTERISTIC + "/" + UUID.randomUUID().toString().toUpperCase()
//        deviceId = deviceIdentifier
//        eventChannel = EventChannel(binaryMessenger, name)
//        eventChannel.setStreamHandler(this)
//    }
}