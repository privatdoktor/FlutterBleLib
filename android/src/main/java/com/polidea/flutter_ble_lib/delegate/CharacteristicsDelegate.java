package com.polidea.flutter_ble_lib.delegate;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.polidea.flutter_ble_lib.BleErrorFactory;
import com.polidea.flutter_ble_lib.SafeMainThreadResolver;
import com.polidea.flutter_ble_lib.SingleCharacteristicResponse;
import com.polidea.flutter_ble_lib.constant.ArgumentKey;
import com.polidea.flutter_ble_lib.constant.MethodName;
import com.polidea.flutter_ble_lib.converter.BleErrorJsonConverter;
import com.polidea.flutter_ble_lib.converter.SingleCharacteristicResponseJsonConverter;
import com.polidea.flutter_ble_lib.event.CharacteristicsMonitorStreamHandler;
import com.polidea.multiplatformbleadapter.Characteristic;
import com.polidea.multiplatformbleadapter.utils.Base64Converter;

import org.json.JSONException;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class CharacteristicsDelegate extends CallDelegate {

    private static final List<String> supportedMethods = Arrays.asList(
            MethodName.READ_CHARACTERISTIC_FOR_DEVICE,
            MethodName.WRITE_CHARACTERISTIC_FOR_DEVICE,
            MethodName.MONITOR_CHARACTERISTIC_FOR_DEVICE
    );

    private final BleAdapter bleAdapter;
    private final SingleCharacteristicResponseJsonConverter characteristicsResponseJsonConverter =
            new SingleCharacteristicResponseJsonConverter();
    @SuppressWarnings("MismatchedQueryAndUpdateOfCollection")
    static public final Map<String, CharacteristicsMonitorStreamHandler> characteristicsMonitorStreamHandlers = new HashMap<>();
    private final BleErrorJsonConverter bleErrorJsonConverter = new BleErrorJsonConverter();
    private final Handler mainThreadHandler = new Handler(Looper.getMainLooper());
    @NonNull private final BinaryMessenger binaryMessenger;

    public CharacteristicsDelegate(BleAdapter bleAdapter, @NonNull BinaryMessenger binaryMessenger) {
        super(supportedMethods);
        this.bleAdapter = bleAdapter;
        this.binaryMessenger = binaryMessenger;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case MethodName.READ_CHARACTERISTIC_FOR_DEVICE:
                readCharacteristicForDevice(
                        call.argument(ArgumentKey.DEVICE_IDENTIFIER),
                        call.argument(ArgumentKey.SERVICE_UUID),
                        call.argument(ArgumentKey.CHARACTERISTIC_UUID),
                        UUID.randomUUID().toString(),
                        result);
                return;
            case MethodName.WRITE_CHARACTERISTIC_FOR_DEVICE:
                final Boolean withResponseObj = call.<Boolean>argument(ArgumentKey.WITH_RESPONSE);
                final boolean withResponse = withResponseObj != null && withResponseObj;
                writeCharacteristicForDevice(
                        call.argument(ArgumentKey.DEVICE_IDENTIFIER),
                        call.argument(ArgumentKey.SERVICE_UUID),
                        call.argument(ArgumentKey.CHARACTERISTIC_UUID),
                        call.argument(ArgumentKey.VALUE),
                        withResponse,
                        UUID.randomUUID().toString(),
                        result);
                return;
            case MethodName.MONITOR_CHARACTERISTIC_FOR_DEVICE:
                monitorCharacteristicForDevice(
                        call.argument(ArgumentKey.DEVICE_IDENTIFIER),
                        call.argument(ArgumentKey.SERVICE_UUID),
                        call.argument(ArgumentKey.CHARACTERISTIC_UUID),
                        UUID.randomUUID().toString(),
                        result);
                return;
            default:
                throw new IllegalArgumentException(call.method + " cannot be handled by this delegate");
        }
    }

    private void readCharacteristicForDevice(
            String deviceIdentifier,
            String serviceUuid,
            String characteristicUuid,
            final String transactionId,
            final MethodChannel.Result result) {

        final SafeMainThreadResolver<Characteristic> safeMainThreadResolver = new SafeMainThreadResolver<>(
                data -> {
                    try {
                        result.success(characteristicsResponseJsonConverter.toJson(createCharacteristicResponse(data)));
                    } catch (JSONException e) {
                        e.printStackTrace();
                        result.error(null, e.getMessage(), null);
                    }
                },
                error -> result.error(String.valueOf(error.errorCode.code), error.reason, bleErrorJsonConverter.toJson(error))
        );
        bleAdapter.readCharacteristicForDevice(deviceIdentifier, serviceUuid, characteristicUuid, transactionId,
                safeMainThreadResolver, safeMainThreadResolver);
    }

    private void writeCharacteristicForDevice(String deviceIdentifier,
                                              String serviceUuid,
                                              String characteristicUuid,
                                              byte[] bytesToWrite,
                                              boolean withResponse,
                                              final String transactionId,
                                              final MethodChannel.Result result) {
        final SafeMainThreadResolver<Characteristic> safeMainThreadResolver = new SafeMainThreadResolver<>(
                data -> {
                    try {
                        result.success(characteristicsResponseJsonConverter.toJson(createCharacteristicResponse(data, transactionId)));
                    } catch (JSONException e) {
                        e.printStackTrace();
                        result.error(null, e.getMessage(), null);
                    }
                },
                error -> result.error(String.valueOf(error.errorCode.code), error.reason, bleErrorJsonConverter.toJson(error))
        );

        bleAdapter.writeCharacteristicForDevice(
                deviceIdentifier,
                serviceUuid, characteristicUuid,
                Base64Converter.encode(bytesToWrite),
                withResponse,
                transactionId,
                safeMainThreadResolver, safeMainThreadResolver);
    }

    private void monitorCharacteristicForDevice(String deviceIdentifier,
                                                String serviceUuid,
                                                String characteristicUuid,
                                                final String transactionId,
                                                final MethodChannel.Result result) {
        final CharacteristicsMonitorStreamHandler streamHandler =
                new CharacteristicsMonitorStreamHandler(binaryMessenger, deviceIdentifier);
        characteristicsMonitorStreamHandlers.put(streamHandler.name, streamHandler);
        bleAdapter.monitorCharacteristicForDevice(
                deviceIdentifier,
                serviceUuid,
                characteristicUuid,
                transactionId,
                data -> mainThreadHandler.post(() -> {
                    try {
                        streamHandler.onCharacteristicsUpdate(
                                createCharacteristicResponse(data, transactionId)
                        );
                    } catch (JSONException e) {
                        e.printStackTrace();
                        streamHandler.onError(BleErrorFactory.fromThrowable(e), transactionId);
                        streamHandler.end();
                    }
                }), error -> mainThreadHandler.post(() -> {
                    streamHandler.onError(error, transactionId);
                    streamHandler.end();
                }));
        result.success(streamHandler.name);
    }

    private SingleCharacteristicResponse createCharacteristicResponse(Characteristic characteristic) {
        return createCharacteristicResponse(characteristic, null);
    }

    private SingleCharacteristicResponse createCharacteristicResponse(Characteristic characteristic, String transactionId) {
        return new SingleCharacteristicResponse(
                characteristic,
                characteristic.getServiceID(),
                characteristic.getServiceUUID(),
                transactionId);
    }
}
