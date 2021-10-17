package com.polidea.flutter_ble_lib.delegate;


import com.polidea.flutter_ble_lib.SafeMainThreadResolver;
import com.polidea.flutter_ble_lib.constant.ArgumentKey;
import com.polidea.flutter_ble_lib.constant.MethodName;
import com.polidea.flutter_ble_lib.converter.BleErrorJsonConverter;
import com.polidea.flutter_ble_lib.converter.DescriptorJsonConverter;
import com.polidea.multiplatformbleadapter.BleAdapter;
import com.polidea.multiplatformbleadapter.Descriptor;
import com.polidea.multiplatformbleadapter.OnErrorCallback;
import com.polidea.multiplatformbleadapter.OnSuccessCallback;
import com.polidea.multiplatformbleadapter.errors.BleError;
import com.polidea.multiplatformbleadapter.utils.Base64Converter;

import org.json.JSONException;

import java.util.Arrays;
import java.util.List;
import java.util.UUID;

import androidx.annotation.NonNull;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class DescriptorsDelegate extends CallDelegate {

    private static List<String> supportedMethods = Arrays.asList(
            MethodName.READ_DESCRIPTOR_FOR_DEVICE,
            MethodName.WRITE_DESCRIPTOR_FOR_DEVICE
    );

    private BleAdapter bleAdapter;
    private BleErrorJsonConverter errorConverter = new BleErrorJsonConverter();
    private DescriptorJsonConverter descriptorJsonConverter = new DescriptorJsonConverter();

    public DescriptorsDelegate(BleAdapter bleAdapter) {
        super(supportedMethods);
        this.bleAdapter = bleAdapter;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case MethodName.READ_DESCRIPTOR_FOR_DEVICE:
                readDescriptorForDevice(
                        call.<String>argument(ArgumentKey.DEVICE_IDENTIFIER),
                        call.<String>argument(ArgumentKey.SERVICE_UUID),
                        call.<String>argument(ArgumentKey.CHARACTERISTIC_UUID),
                        call.<String>argument(ArgumentKey.DESCRIPTOR_UUID),
                        UUID.randomUUID().toString(),
                        result
                );
                return;
            case MethodName.WRITE_DESCRIPTOR_FOR_DEVICE:
                writeDescriptorForDevice(
                        call.<String>argument(ArgumentKey.DEVICE_IDENTIFIER),
                        call.<String>argument(ArgumentKey.SERVICE_UUID),
                        call.<String>argument(ArgumentKey.CHARACTERISTIC_UUID),
                        call.<String>argument(ArgumentKey.DESCRIPTOR_UUID),
                        call.<byte[]>argument(ArgumentKey.VALUE),
                        UUID.randomUUID().toString(),
                        result
                );
                return;
            default:
                throw new IllegalArgumentException(call.method + " cannot be handled by this delegate");
        }
    }

    private SafeMainThreadResolver<Descriptor> createMainThreadResolverForResult(final MethodChannel.Result result, final String transactionId) {
        return new SafeMainThreadResolver<>(
                new OnSuccessCallback<Descriptor>() {
                    @Override
                    public void onSuccess(Descriptor descriptor) {
                        try {
                            result.success(descriptorJsonConverter.toJson(descriptor));
                        } catch (JSONException e) {
                            e.printStackTrace();
                            result.error(null, e.getMessage(), null);
                        }
                    }
                },
                new OnErrorCallback() {
                    @Override
                    public void onError(BleError error) {
                        result.error(
                                String.valueOf(error.errorCode.code),
                                error.reason,
                                errorConverter.toJson(error, transactionId)
                        );
                    }
                }
        );
    }

    private void readDescriptorForDevice(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid,
            final String descriptorUuid,
            final String transactionId,
            final MethodChannel.Result result) {
        final SafeMainThreadResolver<Descriptor> safeMainThreadResolver = createMainThreadResolverForResult(result, transactionId);

        bleAdapter.readDescriptorForDevice(
                deviceId,
                serviceUuid,
                characteristicUuid,
                descriptorUuid,
                transactionId,
                safeMainThreadResolver, //success
                safeMainThreadResolver //error
        );
    }

    private void writeDescriptorForDevice(
            final String deviceId,
            final String serviceUuid,
            final String characteristicUuid,
            final String descriptorUuid,
            final byte[] value,
            final String transactionId,
            final MethodChannel.Result result) {
        final SafeMainThreadResolver<Descriptor> safeMainThreadResolver = createMainThreadResolverForResult(result, transactionId);

        bleAdapter.writeDescriptorForDevice(
                deviceId,
                serviceUuid,
                characteristicUuid,
                descriptorUuid,
                Base64Converter.encode(value),
                transactionId,
                safeMainThreadResolver, //success
                safeMainThreadResolver //error
        );
    }
}
