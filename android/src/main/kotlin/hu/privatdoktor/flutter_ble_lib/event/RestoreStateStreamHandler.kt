package hu.privatdoktor.flutter_ble_lib.event

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger

import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.ChannelName

class RestoreStateStreamHandler(
    binaryMessenger: BinaryMessenger
) : EventChannel.StreamHandler {
    private var restoreStateSink: EventSink? = null

    private val eventChannel = EventChannel(binaryMessenger, ChannelName.STATE_RESTORE_EVENTS)
    private var eventSink: EventSink? = null

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(o: Any?, eventSink: EventSink) {
        restoreStateSink = eventSink
    }

    override fun onCancel(o: Any?) {
        restoreStateSink = null
    }

    fun sendDummyRestoreEvent() {
        restoreStateSink?.success(null)
    }
}