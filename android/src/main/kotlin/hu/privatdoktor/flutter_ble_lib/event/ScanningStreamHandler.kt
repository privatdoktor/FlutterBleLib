package hu.privatdoktor.flutter_ble_lib.event

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

import io.flutter.plugin.common.BinaryMessenger

import hu.privatdoktor.flutter_ble_lib.ChannelName


class ScanningStreamHandler : EventChannel.StreamHandler {
    private var scanResultsSink: EventSink? = null
//    private val scanResultJsonConverter = ScanResultJsonConverter()
//    private val bleErrorJsonConverter = BleErrorJsonConverter()

    override fun onListen(o: Any, eventSink: EventSink) {
        scanResultsSink = eventSink
    }

    override fun onCancel(o: Any) {
        scanResultsSink = null
    }

//    fun onError(error: BleError) {
//        scanResultsSink?.error(
//            error.errorCode.code.toString(),
//            error.reason,
//            bleErrorJsonConverter.toJson(error)
//        )
//    }
//
//    fun onScanResult(scanResult: ScanResult?) {
//        scanResultsSink?.success(scanResultJsonConverter.toJson(scanResult))
//    }
}