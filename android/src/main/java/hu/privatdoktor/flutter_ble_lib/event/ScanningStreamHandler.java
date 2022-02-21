package hu.privatdoktor.flutter_ble_lib.event;

import hu.privatdoktor.flutter_ble_lib.converter.BleErrorJsonConverter;
import hu.privatdoktor.flutter_ble_lib.converter.ScanResultJsonConverter;
import hu.privatdoktor.multiplatformbleadapter.ScanResult;
import hu.privatdoktor.multiplatformbleadapter.errors.BleError;

import io.flutter.plugin.common.EventChannel;

public class ScanningStreamHandler implements EventChannel.StreamHandler {

    private EventChannel.EventSink scanResultsSink;
    private ScanResultJsonConverter scanResultJsonConverter = new ScanResultJsonConverter();
    private BleErrorJsonConverter bleErrorJsonConverter = new BleErrorJsonConverter();

    @Override
    synchronized public void onListen(Object o, EventChannel.EventSink eventSink) {
        scanResultsSink = eventSink;
    }

    @Override
    synchronized public void onCancel(Object o) {
        scanResultsSink = null;
    }

    synchronized public void onScanResult(ScanResult scanResult) {
        if (scanResultsSink != null) {
            scanResultsSink.success(scanResultJsonConverter.toJson(scanResult));
        }
    }

    synchronized public void onError(BleError error) {
        if (scanResultsSink != null) {
            scanResultsSink.error(
                    String.valueOf(error.errorCode.code),
                    error.reason,
                    bleErrorJsonConverter.toJson(error));
        }
    }
}
