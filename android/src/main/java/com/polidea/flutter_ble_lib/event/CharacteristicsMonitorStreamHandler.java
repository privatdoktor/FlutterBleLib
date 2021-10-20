package com.polidea.flutter_ble_lib.event;

import androidx.annotation.NonNull;

import com.polidea.flutter_ble_lib.SingleCharacteristicResponse;
import com.polidea.flutter_ble_lib.constant.ChannelName;
import com.polidea.flutter_ble_lib.converter.BleErrorJsonConverter;
import com.polidea.flutter_ble_lib.converter.SingleCharacteristicResponseJsonConverter;
import com.polidea.multiplatformbleadapter.errors.BleError;

import org.json.JSONException;

import java.util.UUID;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;

public class CharacteristicsMonitorStreamHandler implements EventChannel.StreamHandler {

    @NonNull private EventChannel eventChannel;
    @NonNull public String name;
    @NonNull public String deviceId;

    private EventChannel.EventSink eventSink;
    private SingleCharacteristicResponseJsonConverter characteristicResponseJsonConverter
            = new SingleCharacteristicResponseJsonConverter();
    private BleErrorJsonConverter bleErrorJsonConverter = new BleErrorJsonConverter();

    public CharacteristicsMonitorStreamHandler(BinaryMessenger binaryMessenger, String deviceIdentifier) {
        name = ChannelName.MONITOR_CHARACTERISTIC + "/" + UUID.randomUUID().toString().toUpperCase();
        deviceId = deviceIdentifier;
        eventChannel = new EventChannel(binaryMessenger, name);
        eventChannel.setStreamHandler(this);
    }

    @Override
    synchronized public void onListen(Object o, EventChannel.EventSink eventSink) {
        this.eventSink = eventSink;
    }

    @Override
    synchronized public void onCancel(Object o) {
        eventSink = null;
    }

    synchronized public void onCharacteristicsUpdate(SingleCharacteristicResponse characteristic) throws JSONException {
        if (eventSink != null) {
            eventSink.success(characteristicResponseJsonConverter.toJson(characteristic));
        }
    }

    synchronized public void end() {
        if (eventSink != null) {
            eventSink.endOfStream();
        }
    }

    synchronized public void onError(BleError error, String transactionId) {
        if (eventSink != null) {
            eventSink.error(String.valueOf(error.errorCode.code), error.reason, bleErrorJsonConverter.toJson(error, transactionId));
        }
    }
}
