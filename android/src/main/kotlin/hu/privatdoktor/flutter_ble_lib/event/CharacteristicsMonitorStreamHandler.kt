package hu.privatdoktor.flutter_ble_lib.event

import android.bluetooth.BluetoothGattCharacteristic
import com.welie.blessed.BluetoothPeripheral
import hu.privatdoktor.flutter_ble_lib.BleError
import hu.privatdoktor.flutter_ble_lib.BleErrorCode
import hu.privatdoktor.flutter_ble_lib.ChannelName
import hu.privatdoktor.flutter_ble_lib.Client
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger

import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler

import org.json.JSONException
import org.json.JSONObject
import java.util.*

class CharacteristicsMonitorStreamHandler(
    binaryMessenger: BinaryMessenger,
    val deviceIdentifier: String,
    serviceUuid: String,
    characteristicUuid: String
) : EventChannel.StreamHandler {
    private val eventChannel: EventChannel
    private var eventSink: EventSink? = null
    private var cleanUpClosure: (() -> Unit)? = null

    val name: String

    init {
        name = "${ChannelName.MONITOR_CHARACTERISTIC}/${serviceUuid}/${characteristicUuid}"
        eventChannel = EventChannel(binaryMessenger, name)
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(o: Any?, eventSink: EventSink) {
        this.eventSink = eventSink
    }

    override fun onCancel(o: Any?) {
        eventSink = null
        cleanUpClosure?.invoke()
        cleanUpClosure = null
    }

    fun onCharacteristicsUpdate(
        peripheral: BluetoothPeripheral,
        serviceUuid: String,
        characteristic: BluetoothGattCharacteristic
    ) {
        val payload = Client.singleCharacteristicWithValueResponse(
            peripheral = peripheral,
            serviceUuidStr = serviceUuid,
            characteristic = characteristic
        )
        try {
            val jsonStr = JSONObject(payload).toString()
            eventSink?.success(jsonStr)
        } catch (e: Throwable) {
            eventSink?.error(
                BleErrorCode.UnknownError.toString(),
                e.localizedMessage,
                e.stackTrace
            )
        }
    }

    fun end() {
        eventSink?.endOfStream()
        eventSink = null
        cleanUpClosure?.invoke()
        cleanUpClosure = null
    }

    fun onError(error: BleError) {
        eventSink?.error(
            error.errorCode.code.toString(),
            error.reason,
            error.toJsonString()
        )
    }

    fun afterCancelDo(cleanUpClosure: () -> Unit) {
        this.cleanUpClosure = cleanUpClosure
    }


}