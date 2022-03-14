package hu.privatdoktor.flutter_ble_lib.event

import android.bluetooth.BluetoothAdapter
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger
import hu.privatdoktor.flutter_ble_lib.ChannelName


fun bluetoothStateStrFrom(state: Int) : String {
    return when (state) {
        BluetoothAdapter.STATE_OFF -> "PoweredOff"
        BluetoothAdapter.STATE_ON -> "PoweredOn"
        BluetoothAdapter.STATE_TURNING_OFF, BluetoothAdapter.STATE_TURNING_ON -> "Resetting"
        else -> "Unknown"
    }
}

class AdapterStateStreamHandler(
    binaryMessenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private var adapterStateSink: EventSink? = null

    private val eventChannel = EventChannel(binaryMessenger, ChannelName.ADAPTER_STATE_CHANGES)
    private var eventSink: EventSink? = null

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(o: Any?, eventSink: EventSink) {
        adapterStateSink = eventSink
    }

    override fun onCancel(o: Any?) {
        adapterStateSink = null
    }

    fun onNewAdapterState(state: Int) {
        adapterStateSink?.success(bluetoothStateStrFrom(state))
    }
}