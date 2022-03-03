package hu.privatdoktor.flutter_ble_lib

import android.util.Log
import hu.privatdoktor.flutter_ble_lib.event.AdapterStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.RestoreStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.ScanningStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.*
import java.util.*
import kotlin.coroutines.suspendCoroutine


private fun UUIDfrom(bluetoothUUIDStr: String) : UUID {
    val baseUUIDPrefix = "0000"
    val baseUUIDSuffix = "-0000-1000-8000-00805F9B34FB"

    val outUUUID =
        if (bluetoothUUIDStr.length == 4) {
            baseUUIDPrefix + bluetoothUUIDStr + baseUUIDSuffix
        } else if (bluetoothUUIDStr.length == 8) {
            bluetoothUUIDStr + baseUUIDSuffix
        } else {
            bluetoothUUIDStr
        }

    return UUID.fromString(outUUUID)
}

class FlutterBleLibPlugin : FlutterPlugin, MethodCallHandler {

    private var client: Client? = null
    private var methodChannel: MethodChannel? = null

    companion object {
        const val TAG = "FlutterBleLibPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        client = Client(binding)

        val methodChannel = MethodChannel(binding.binaryMessenger, ChannelName.FLUTTER_BLE_LIB)
        methodChannel.setMethodCallHandler(this)
        this.methodChannel = methodChannel
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        client = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "on native side observed method: " + call.method)
        val client = this.client
        if (client == null) {
            Log.d(TAG, "on native side onMethodCall:: client was null ")
            return
        }
        try {
            when (call.method) {
                MethodName.IS_CLIENT_CREATED -> {
                    client.isClientCreated(result = result)
                }
                MethodName.CREATE_CLIENT -> {
                    client.createClient(result = result)
                }
                MethodName.DESTROY_CLIENT -> {
                    client.destroyClient(result = result)
                }
                MethodName.START_DEVICE_SCAN -> {
                    val filteredUUIDs =
                        call.argument<List<String>>(ArgumentKey.UUIDS)!!.map {
                            UUIDfrom(bluetoothUUIDStr = it)
                        }

                    client.startDeviceScan(
                        scanMode = call.argument<Int>(ArgumentKey.SCAN_MODE)!!,
                        callbackType = call.argument<Int>(ArgumentKey.CALLBACK_TYPE)!!,
                        filteredUUIDs = filteredUUIDs,
                        result = result
                    )
                }
                MethodName.STOP_DEVICE_SCAN -> {
                    client.stopDeviceScan(result = result)
                }
                MethodName.ENABLE_RADIO -> {
                    GlobalScope.launch(Dispatchers.Main.immediate) {
                        client.enableRadio(result = result)
                    }
                }
                MethodName.DISABLE_RADIO -> {
                    GlobalScope.launch(Dispatchers.Main.immediate) {
                        client.disableRadio(result = result)
                    }
                }
                MethodName.GET_STATE -> {
                    client.getState(result = result)
                }
                MethodName.GET_AUTHORIZATION -> {
                    result.success("allowedAlways")
                }
                MethodName.CONNECT_TO_DEVICE -> {
                    val timeoutMillis =
                        try {
                            val unwrappedValue = call.argument<Int>(ArgumentKey.TIMEOUT_MILLIS)
                            unwrappedValue?.toLong()
                        } catch (exception: ClassCastException) {
                            call.argument<Long>(ArgumentKey.TIMEOUT_MILLIS)
                        }
                    client.connectToDevice(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        isAutoConnect = call.argument<Boolean>(ArgumentKey.IS_AUTO_CONNECT),
                        requestMtu = call.argument<Int>(ArgumentKey.REQUEST_MTU),
                        refreshGatt = call.argument<Boolean>(ArgumentKey.REFRESH_GATT)!!,
                        timeoutMillis = timeoutMillis,
                        result = result
                    )
                }
                MethodName.IS_DEVICE_CONNECTED -> {
                    client.isDeviceConnected(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        result = result
                    )
                }
                MethodName.OBSERVE_CONNECTION_STATE -> {
                    client.observeConnectionState(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        emitCurrentValue = call.argument<Boolean>(ArgumentKey.EMIT_CURRENT_VALUE)!!,
                        result = result
                    )
                }
                MethodName.CANCEL_CONNECTION -> {
                    client.cancelConnection(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        result = result
                    )
                }
                MethodName.DISCOVER_SERVICES -> {
                    val serviceUuids =
                        call.argument<List<String>>(ArgumentKey.SERVICE_UUIDS)?.map {
                            UUIDfrom(bluetoothUUIDStr = it)
                        }
                    client.discoverServices(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUUIDs = serviceUuids,
                        result = result
                    )
                }
                MethodName.DISCOVER_CHARACTERISTICS -> {
                    val characteristicsUuids =
                        call.argument<List<String>>(ArgumentKey.CHARACTERISTIC_UUIDS)?.map {
                            UUIDfrom(bluetoothUUIDStr = it)
                        }
                    client.discoverCharacteristics(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        characteristicsUuids = characteristicsUuids,
                        result = result
                    )
                }
                MethodName.GET_CHARACTERISTICS -> {
                    client.characteristics(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        result = result
                    )
                }
                MethodName.GET_SERVICES -> {
                    client.services(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        result = result
                    )
                }
                MethodName.GET_DESCRIPTORS_FOR_DEVICE -> {
                    client.descriptorsForDevice(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        characteristicUuid = UUIDfrom(call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!),
                        result = result
                    )
                }
                MethodName.RSSI -> {
                    client.rssi(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        result = result
                    )
                }
                MethodName.REQUEST_MTU -> {
                    client.requestMtu(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        mtu = call.argument<Int>(ArgumentKey.MTU)!!,
                        result = result
                    )
                }
                MethodName.GET_CONNECTED_DEVICES -> {
                    val serviceUUIDs = call.argument<List<String>>(ArgumentKey.UUIDS)!!.map {
                        UUIDfrom(bluetoothUUIDStr = it)
                    }
                    client.getConnectedDevices(
                        serviceUUIDs = serviceUUIDs,
                        result = result
                    )
                }
                MethodName.GET_KNOWN_DEVICES -> {
                    client.getKnownDevices(
                        deviceIdentifiers = call.argument<List<String>>(ArgumentKey.DEVICE_IDENTIFIERS)!!,
                        result = result
                    )
                }
                MethodName.READ_CHARACTERISTIC_FOR_DEVICE -> {
                    client.readCharacteristicForDevice(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        characteristicUuid = UUIDfrom(call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!),
                        result = result
                    )
                }
                MethodName.WRITE_CHARACTERISTIC_FOR_DEVICE -> {
                    val withResponse = call.argument<Boolean>(ArgumentKey.WITH_RESPONSE) ?: false;
                    client.writeCharacteristicForDevice(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        characteristicUuid = UUIDfrom(call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!),
                        bytesToWrite = call.argument<ByteArray>(ArgumentKey.VALUE)!!,
                        withResponse = withResponse,
                        result = result
                    )
                }
                MethodName.MONITOR_CHARACTERISTIC_FOR_DEVICE -> {
                    client.monitorCharacteristicForDevice(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        characteristicUuid = UUIDfrom(call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!),
                        result = result
                    )
                }
                MethodName.READ_DESCRIPTOR_FOR_DEVICE -> {
                    client.readDescriptorForDevice(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        characteristicUuid = UUIDfrom(call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!),
                        descriptorUuid = UUIDfrom(call.argument(ArgumentKey.DESCRIPTOR_UUID)!!),
                        result = result
                    )
                }
                MethodName.WRITE_DESCRIPTOR_FOR_DEVICE -> {
                    client.writeDescriptorForDevice(
                        deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                        serviceUuid = UUIDfrom(call.argument<String>(ArgumentKey.SERVICE_UUID)!!),
                        characteristicUuid = UUIDfrom(call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!),
                        descriptorUuid = call.argument(ArgumentKey.DESCRIPTOR_UUID)!!,
                        value = call.argument<ByteArray>(ArgumentKey.VALUE)!!,
                        result = result
                    )
                }
                else -> throw NotImplementedError()
            }
        } catch (e: NotImplementedError) {
            result.notImplemented()
        } catch (e: Throwable) {
            result.error(throwable = e)
        }
    }
}

fun MethodChannel.Result.error(throwable: Throwable) {
    if (throwable is BleError) {
        error(bleError = throwable)
        return
    }
    error(BleErrorCode.UnknownError.code.toString(), throwable.localizedMessage, throwable.cause)
}

fun MethodChannel.Result.error(bleError: BleError) {
    error(bleError.errorCode.code.toString(), bleError.message, bleError.cause)
}