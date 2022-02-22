package hu.privatdoktor.flutter_ble_lib

import android.util.Log
import hu.privatdoktor.flutter_ble_lib.constant.ArgumentKey
import hu.privatdoktor.flutter_ble_lib.constant.ChannelName
import hu.privatdoktor.flutter_ble_lib.constant.MethodName
import hu.privatdoktor.flutter_ble_lib.delegate.CallDelegate
import hu.privatdoktor.flutter_ble_lib.event.AdapterStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.RestoreStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.ScanningStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.util.*

class FlutterBleLibPlugin : FlutterPlugin, MethodCallHandler {
    private val adapterStateStreamHandler = AdapterStateStreamHandler()
    private val restoreStateStreamHandler = RestoreStateStreamHandler()
    private val scanningStreamHandler = ScanningStreamHandler()
    private val delegates: MutableList<CallDelegate> = LinkedList()


    private var client: Client? = null
    private var methodChannel: MethodChannel? = null

//    private var context: Context? = null
//    private var binaryMessenger: BinaryMessenger? = null

    companion object {
        const val TAG = "FlutterBleLibPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        val messenger = binding.binaryMessenger

        client = Client(binding)

        val methodChannel = MethodChannel(messenger, ChannelName.FLUTTER_BLE_LIB)
        methodChannel.setMethodCallHandler(this)
        this.methodChannel = methodChannel

        val bluetoothStateChannel = EventChannel(messenger, ChannelName.ADAPTER_STATE_CHANGES)
        bluetoothStateChannel.setStreamHandler(adapterStateStreamHandler)

        val restoreStateChannel = EventChannel(messenger, ChannelName.STATE_RESTORE_EVENTS)
        restoreStateChannel.setStreamHandler(restoreStateStreamHandler)

        val scanningChannel = EventChannel(messenger, ChannelName.SCANNING_EVENTS)
        scanningChannel.setStreamHandler(scanningStreamHandler)
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

        when (call.method) {
            MethodName.IS_CLIENT_CREATED -> {
                client.isClientCreated(result)
            }
            MethodName.CREATE_CLIENT -> {
                val restoreStateIdentifier =
                    call.argument<String>(ArgumentKey.RESTORE_STATE_IDENTIFIER)
                client.createClient(
                    restoreStateIdentifier = restoreStateIdentifier,
                    result = result
                )
            }
            MethodName.DESTROY_CLIENT -> {
                client.destroyClient(result)
            }
            MethodName.START_DEVICE_SCAN -> {
                val scanMode = call.argument<Int>(ArgumentKey.SCAN_MODE)!!
                val callbackType = call.argument<Int>(ArgumentKey.CALLBACK_TYPE)!!
                val filteredUUIDs = call.argument<List<String>>(ArgumentKey.UUIDS)!!.toTypedArray()

                client.startDeviceScan(
                    scanMode = scanMode,
                    callbackType = callbackType,
                    filteredUUIDs =filteredUUIDs,
                    result = result
                )
            }
            MethodName.STOP_DEVICE_SCAN -> {
                client.stopDeviceScan(result = result)
            }
            MethodName.ENABLE_RADIO -> {
                client.enableRadio(result = result)
            }
            MethodName.DISABLE_RADIO -> {
                client.disableRadio(result = result)
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
                client.discoverServices(
                    deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                    serviceUuids = call.argument<List<String>>(ArgumentKey.SERVICE_UUIDS),
                    result = result
                )
            }
            MethodName.DISCOVER_CHARACTERISTICS -> {
                client.discoverCharacteristics(
                    deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                    serviceUuid = call.argument<String>(ArgumentKey.SERVICE_UUID)!!,
                    characteristicsUuids = call.argument<List<String>>(ArgumentKey.CHARACTERISTIC_UUIDS),
                    result = result
                )
            }
            MethodName.GET_CHARACTERISTICS -> {
                client.characteristics(
                    deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
                    serviceUuid = call.argument<String>(ArgumentKey.SERVICE_UUID)!!,
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
                    serviceUuid = call.argument<String>(ArgumentKey.SERVICE_UUID)!!,
                    characteristicUuid = call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!,
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
                client.getConnectedDevices(
                    serviceUUIDs = call.argument<List<String>>(ArgumentKey.UUIDS)!!,
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
                    serviceUuid = call.argument<String>(ArgumentKey.SERVICE_UUID)!!,
                    characteristicUuid = call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!,
                    result = result
                )
            }
            MethodName.WRITE_CHARACTERISTIC_FOR_DEVICE -> {
//                client.writeCharacteristicForDevice(
//                    deviceIdentifier = call.argument<String>(ArgumentKey.DEVICE_IDENTIFIER)!!,
//                    serviceUuid = call.argument<String>(ArgumentKey.SERVICE_UUID)!!,
//                    characteristicUuid = call.argument<String>(ArgumentKey.CHARACTERISTIC_UUID)!!,
//                )

            }
            MethodName.MONITOR_CHARACTERISTIC_FOR_DEVICE -> {

            }
            MethodName.READ_DESCRIPTOR_FOR_DEVICE -> {

            }
            MethodName.WRITE_DESCRIPTOR_FOR_DEVICE -> {

            }
            else -> result.notImplemented()
        }
    }





}