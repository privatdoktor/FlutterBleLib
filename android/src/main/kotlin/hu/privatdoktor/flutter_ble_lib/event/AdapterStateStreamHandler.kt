package hu.privatdoktor.flutter_ble_lib.event

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger
//import hu.privatdoktor.flutter_ble_lib.converter.ConnectionStateChangeJsonConverter
import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.ChannelName


class AdapterStateStreamHandler : EventChannel.StreamHandler {
    private var adapterStateSink: EventSink? = null
    override fun onListen(o: Any, eventSink: EventSink) {
        adapterStateSink = eventSink
    }

    override fun onCancel(o: Any) {
        adapterStateSink = null
    }

    fun onNewAdapterState(bluetoothAdapterState: String) {
        adapterStateSink?.success(bluetoothAdapterState)
    }
}