package hu.privatdoktor.flutter_ble_lib

import android.bluetooth.le.ScanResult
import android.os.Handler
import android.os.Looper
import com.welie.blessed.*
import hu.privatdoktor.flutter_ble_lib.event.AdapterStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.RestoreStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.ScanningStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.*

class Client(val binding: FlutterPluginBinding) : BluetoothCentralManagerCallback() {
    private val adapterStateStreamHandler = AdapterStateStreamHandler()
    private val restoreStateStreamHandler = RestoreStateStreamHandler()
    private val scanningStreamHandler = ScanningStreamHandler()

    private var centralManager: BluetoothCentralManager? = null

    init {
        val bluetoothStateChannel = EventChannel(binding.binaryMessenger, ChannelName.ADAPTER_STATE_CHANGES)
        bluetoothStateChannel.setStreamHandler(adapterStateStreamHandler)

        val restoreStateChannel = EventChannel(binding.binaryMessenger, ChannelName.STATE_RESTORE_EVENTS)
        restoreStateChannel.setStreamHandler(restoreStateStreamHandler)

        val scanningChannel = EventChannel(binding.binaryMessenger, ChannelName.SCANNING_EVENTS)
        scanningChannel.setStreamHandler(scanningStreamHandler)
    }

    fun isClientCreated(result: MethodChannel.Result) {
        result.success(centralManager != null)
    }

    fun createClient(result: MethodChannel.Result) {
        centralManager = BluetoothCentralManager(
            binding.applicationContext,
            this,
            Handler(Looper.getMainLooper())
        )
        restoreStateStreamHandler.sendDummyRestoreEvent()

        result.success(null)
    }

    fun destroyClient(result: MethodChannel.Result) {
        val centralManager = this.centralManager
        if (centralManager == null) {
            result.success(null)
            return
        }

        if (centralManager.isBluetoothEnabled && centralManager.isScanning) {
            centralManager.stopScan()
        }
        centralManager.close()
        this.centralManager = null

        result.success(null)
    }

    fun startDeviceScan(
        scanMode: Int,
        callbackType: Int,
        filteredUUIDStrings: List<String>,
        result: MethodChannel.Result
    ) {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }

        val filteredUUIDs = filteredUUIDStrings.map { UUID.fromString(it) }

        centralManager.scanForPeripheralsWithServices(filteredUUIDs.toTypedArray())

        result.success(null)
    }

    fun stopDeviceScan(result: MethodChannel.Result) {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }

        centralManager.stopScan()
        result.success(null)
    }

    fun enableRadio(result: MethodChannel.Result) {
         centralManager
//        bleAdapter.enable(transactionId,
//            object : OnSuccessCallback<Void?> {
//                fun onSuccess(data: Void) {
//                    result.success(null)
//                }
//            },
//            OnErrorCallback { error ->
//                result.error(
//                    error.errorCode.code.toString(),
//                    error.reason,
//                    bleErrorJsonConverter.toJson(error)
//                )
//            })
        result.success(null)
    }

    fun disableRadio(result: MethodChannel.Result) {
//        bleAdapter.disable(transactionId,
//            object : OnSuccessCallback<Void?> {
//                fun onSuccess(data: Void) {
//                    result.success(null)
//                }
//            },
//            OnErrorCallback { error ->
//                result.error(
//                    error.errorCode.code.toString(),
//                    error.reason,
//                    bleErrorJsonConverter.toJson(error)
//                )
//            })
        result.success(null)
    }

    fun getState(result: MethodChannel.Result) {
        result.success(true)
    }

    fun connectToDevice(
        deviceIdentifier: String,
        isAutoConnect: Boolean?,
        requestMtu: Int?,
        refreshGatt: Boolean,
        timeoutMillis: Long?,
        result: MethodChannel.Result
    ) {
//        val refreshGattMoment =
//            if (refreshGatt) {
//                RefreshGattMoment.ON_CONNECTED
//            } else {
//                null
//            }
//
//        val streamHandler = ConnectionStateStreamHandler(binaryMessenger, deviceId)
//        streamHandlers.put(deviceId, streamHandler)
//        val safeMainThreadResolver: SafeMainThreadResolver<*> = SafeMainThreadResolver(
//            object : OnSuccessCallback<Any?> {
//                fun onSuccess(data: Any) {
//                    result.success(null)
//                }
//            }
//        ) { error ->
//            result.error(
//                error.errorCode.code.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//            streamHandler.end()
//        }
//        val connectionPriorityBalanced = 0 //BluetoothGatt.CONNECTION_PRIORITY_BALANCED
//        bleAdapter.connectToDevice(
//            deviceId,
//            ConnectionOptions(
//                isAutoConnect,
//                requestMtu!!, refreshGattMoment, timeoutMillis, connectionPriorityBalanced
//            ),
//            object : OnSuccessCallback<Device?> {
//                fun onSuccess(data: Device) {
//                    safeMainThreadResolver.onSuccess(null)
//                }
//            },
//            object : OnEventCallback<ConnectionState?> {
//                fun onEvent(data: ConnectionState) {
//                    if (data == ConnectionState.DISCONNECTED) {
//                        for (cmsh in CharacteristicsDelegate.characteristicsMonitorStreamHandlers.values) {
//                            if (cmsh.deviceId === deviceId) {
//                                cmsh.end()
//                            }
//                        }
//                    }
//                    streamHandler.onNewConnectionState(ConnectionStateChange(deviceId, data))
//                }
//            },
//            OnErrorCallback { error -> safeMainThreadResolver.onError(error) }
//        )
        result.success(null)
    }

    fun isDeviceConnected(deviceIdentifier: String, result: MethodChannel.Result) {
//        val safeMainThreadResolver: SafeMainThreadResolver<*> = SafeMainThreadResolver(
//            object : OnSuccessCallback<Boolean?> {
//                fun onSuccess(data: Boolean) {
//                    result.success(data)
//                }
//            }
//        ) { error ->
//            result.error(
//                error.errorCode.code.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//        }
//        bleAdapter.isDeviceConnected(deviceIdentifier,
//            object : OnSuccessCallback<Boolean?> {
//                fun onSuccess(data: Boolean) {
//                    safeMainThreadResolver.onSuccess(data)
//                }
//            },
//            OnErrorCallback { error -> safeMainThreadResolver.onError(error) })
    }

    fun observeConnectionState(
        deviceIdentifier: String,
        emitCurrentValue: Boolean,
        result: MethodChannel.Result
    ) {
//        //emit current value if needed; rest is published automatically through connectToDevice()
//        val streamHandler: ConnectionStateStreamHandler = streamHandlers.get(deviceId)
//        val safeMainThreadResolver: SafeMainThreadResolver<*> = SafeMainThreadResolver(
//            object : OnSuccessCallback<Boolean?> {
//                fun onSuccess(isConnected: Boolean) {
//                    val state: ConnectionState
//                    state =
//                        if (isConnected) ConnectionState.CONNECTED else ConnectionState.DISCONNECTED
//                    streamHandler.onNewConnectionState(ConnectionStateChange(deviceId, state))
//                    result.success(streamHandler.name)
//                }
//            }
//        ) { error ->
//            result.error(
//                error.errorCode.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//        }
//        if (emitCurrentValue) {
//            bleAdapter.isDeviceConnected(deviceId,
//                object : OnSuccessCallback<Boolean?> {
//                    fun onSuccess(data: Boolean) {
//                        safeMainThreadResolver.onSuccess(data)
//                    }
//                },
//                OnErrorCallback { error -> safeMainThreadResolver.onError(error) })
//        } else {
//            result.success(streamHandler.name)
//        }
    }

    fun cancelConnection(
        deviceIdentifier: String,
        result: MethodChannel.Result
    ) {

//        val safeMainThreadResolver: SafeMainThreadResolver<*> = SafeMainThreadResolver(
//            object : OnSuccessCallback<Any?> {
//                fun onSuccess(data: Any) {
//                    result.success(null)
//                }
//            }
//        ) { error ->
//            result.error(
//                error.errorCode.code.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//        }
//        bleAdapter.cancelDeviceConnection(deviceId,
//            object : OnSuccessCallback<Device?> {
//                fun onSuccess(data: Device) {
//                    safeMainThreadResolver.onSuccess(null)
//                }
//            },
//            OnErrorCallback { error -> safeMainThreadResolver.onError(error) })
    }

    fun discoverServices(
        deviceIdentifier: String,
        serviceUuids: List<String>?,
        result: MethodChannel.Result
    ) {
//        _discoverAllServicesAndCharacteristics(
//            deviceId,
//            object : OnSuccessCallback<Any?> {
//                fun onSuccess(data: Any) {
//                    getServices(deviceId, result)
//                }
//            },
//            OnErrorCallback { error -> failWithError(result, error) })
    }

    fun discoverCharacteristics(
        deviceIdentifier: String,
        serviceUuid: String,
        characteristicsUuids: List<String>?,
        result: MethodChannel.Result
    ) {
//        _discoverAllServicesAndCharacteristics(
//            deviceId,
//            object : OnSuccessCallback<Any?> {
//                fun onSuccess(data: Any) {
//                    getCharacteristics(deviceId, serviceUuid, result)
//                }
//            },
//            OnErrorCallback { error -> failWithError(result, error) })
    }

    fun services(
        deviceIdentifier: String,
        result: MethodChannel.Result
    ) {
//        try {
//            val services: List<Service> = adapter.getServicesForDevice(deviceId)
//            result.success(serviceJsonConverter.toJson(services))
//        } catch (error: BleError) {
//            error.printStackTrace()
//            failWithError(result, error)
//        } catch (e: JSONException) {
//            e.printStackTrace()
//            result.error(null, e.message, null)
//        }
    }

    fun characteristics(
        deviceIdentifier: String,
        serviceUuid: String,
        result: MethodChannel.Result
    ) {
//        try {
//            val characteristics: List<Characteristic> =
//                adapter.getCharacteristicsForDevice(deviceId, serviceUuid)
//            val characteristicsResponse: MultiCharacteristicsResponse
//            characteristicsResponse = if (characteristics.size == 0) {
//                MultiCharacteristicsResponse(
//                    characteristics,
//                    -1,
//                    null
//                )
//            } else {
//                MultiCharacteristicsResponse(
//                    characteristics,
//                    characteristics[0].serviceID,
//                    characteristics[0].serviceUUID
//                )
//            }
//            val json: String =
//                multiCharacteristicsResponseJsonConverter.toJson(characteristicsResponse)
//            result.success(json)
//        } catch (error: BleError) {
//            error.printStackTrace()
//            failWithError(result, error)
//        } catch (e: JSONException) {
//            e.printStackTrace()
//            result.error(null, e.message, null)
//        }
    }

    fun descriptorsForDevice(
        deviceIdentifier: String,
        serviceUuid: String,
        characteristicUuid: String,
        result: MethodChannel.Result
    ) {
//        try {
//            val descriptors: List<Descriptor> =
//                adapter.descriptorsForDevice(deviceId, serviceUuid, characteristicUuid)
//            result.success(multiDescriptorsResponseJsonConverter.toJson(descriptors))
//        } catch (error: BleError) {
//            failWithError(result, error)
//        } catch (e: JSONException) {
//            e.printStackTrace()
//            result.error(null, e.message, null)
//        }
    }

    fun rssi(
        deviceIdentifier: String,
        result: MethodChannel.Result
    ) {
//        Log.d(
//            RssiDelegate.TAG,
//            "Read rssi for device $deviceIdentifier transactionId: $transactionId"
//        )
//        val resolver: SafeMainThreadResolver<*> = SafeMainThreadResolver(
//            object : OnSuccessCallback<Int?> {
//                fun onSuccess(rssi: Int) {
//                    result.success(rssi)
//                }
//            }
//        ) { error ->
//            Log.e(
//                RssiDelegate.TAG,
//                "RSSI error " + error.reason + "  " + error.internalMessage
//            )
//            result.error(
//                error.errorCode.code.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//        }
//        bleAdapter.readRSSIForDevice(
//            deviceIdentifier,
//            transactionId,
//            object : OnSuccessCallback<Device?> {
//                fun onSuccess(device: Device) {
//                    Log.d(RssiDelegate.TAG, "rssi ready on native side: " + device.rssi)
//                    resolver.onSuccess(device.rssi)
//                }
//            },
//            OnErrorCallback { error -> resolver.onError(error) })
    }

    fun requestMtu(
        deviceIdentifier: String?,
        mtu: Int,
        result: MethodChannel.Result
    ) {
//        Log.d(MtuDelegate.TAG, "Request MTU $mtu")
//        val resolver: SafeMainThreadResolver<*> = SafeMainThreadResolver(
//            object : OnSuccessCallback<Int?> {
//                fun onSuccess(mtu: Int) {
//                    result.success(mtu)
//                }
//            }
//        ) { error ->
//            Log.e(
//                MtuDelegate.TAG,
//                "MTU request error " + error.reason + "  " + error.internalMessage
//            )
//            result.error(
//                error.errorCode.code.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//        }
//        bleAdapter.requestMTUForDevice(
//            deviceIdentifier,
//            mtu,
//            transactionId,
//            object : OnSuccessCallback<Device?> {
//                fun onSuccess(device: Device) {
//                    resolver.onSuccess(device.mtu)
//                }
//            },
//            OnErrorCallback { error -> resolver.onError(error) })
    }

    fun getConnectedDevices(serviceUUIDs: List<String>, result: MethodChannel.Result) {
//        Log.d(DevicesDelegate.TAG, "Get known devices")
//        val resolver: SafeMainThreadResolver<*> = SafeMainThreadResolver<Array<Device>>(
//            object : OnSuccessCallback<Array<Device?>?> {
//                fun onSuccess(devices: Array<Device?>) {
//                    try {
//                        result.success(devicesResultJsonConverter.toJson(devices))
//                    } catch (e: JSONException) {
//                        e.printStackTrace()
//                        result.error(null, e.message, null)
//                    }
//                }
//            },
//            OnErrorCallback { error ->
//                Log.e(
//                    DevicesDelegate.TAG,
//                    "Get known devices error " + error.reason + "  " + error.internalMessage
//                )
//                result.error(
//                    error.errorCode.code.toString(),
//                    error.reason,
//                    bleErrorJsonConverter.toJson(error)
//                )
//            })
//        bleAdapter.getConnectedDevices(
//            serviceUUIDs.toTypedArray(),
//            object : OnSuccessCallback<Array<Device?>?> {
//                fun onSuccess(devices: Array<Device?>) {
//                    Log.d(DevicesDelegate.TAG, "Found known devices: " + devices.size)
//                    resolver.onSuccess(devices)
//                }
//            },
//            OnErrorCallback { error -> resolver.onError(error) })
    }

    fun getKnownDevices(deviceIdentifiers: List<String>, result: MethodChannel.Result) {
//        Log.d(DevicesDelegate.TAG, "Get known devices")
//        val resolver: SafeMainThreadResolver<*> = SafeMainThreadResolver<Array<Device>>(
//            object : OnSuccessCallback<Array<Device?>?> {
//                fun onSuccess(devices: Array<Device?>) {
//                    try {
//                        result.success(devicesResultJsonConverter.toJson(devices))
//                    } catch (e: JSONException) {
//                        e.printStackTrace()
//                        result.error(null, e.message, null)
//                    }
//                }
//            },
//            OnErrorCallback { error ->
//                Log.e(
//                    DevicesDelegate.TAG,
//                    "Get known devices error " + error.reason + "  " + error.internalMessage
//                )
//                result.error(
//                    error.errorCode.code.toString(),
//                    error.reason,
//                    bleErrorJsonConverter.toJson(error)
//                )
//            })
//        bleAdapter.getKnownDevices(
//            deviceIdentifiers.toTypedArray(),
//            object : OnSuccessCallback<Array<Device?>?> {
//                fun onSuccess(devices: Array<Device?>) {
//                    Log.d(DevicesDelegate.TAG, "Found known devices" + devices.size)
//                    resolver.onSuccess(devices)
//                }
//            },
//            OnErrorCallback { error -> resolver.onError(error) })
    }


    fun readCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuid: String,
        characteristicUuid: String,
        result: MethodChannel.Result
    ) {
//        val safeMainThreadResolver = SafeMainThreadResolver(
//            { data: Characteristic? ->
//                try {
//                    result.success(
//                        characteristicsResponseJsonConverter.toJson(
//                            createCharacteristicResponse(data)
//                        )
//                    )
//                } catch (e: JSONException) {
//                    e.printStackTrace()
//                    result.error(null, e.message, null)
//                }
//            }
//        ) { error: BleError ->
//            result.error(
//                error.errorCode.code.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//        }
//        bleAdapter.readCharacteristicForDevice(
//            deviceIdentifier, serviceUuid, characteristicUuid, transactionId,
//            safeMainThreadResolver, safeMainThreadResolver
//        )
    }

    fun writeCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuid: String,
        characteristicUuid: String,
        bytesToWrite: ByteArray,
        withResponse: Boolean,
        result: MethodChannel.Result
    ) {
//        val safeMainThreadResolver = SafeMainThreadResolver(
//            { data: Characteristic? ->
//                try {
//                    result.success(
//                        characteristicsResponseJsonConverter.toJson(
//                            createCharacteristicResponse(data, transactionId)
//                        )
//                    )
//                } catch (e: JSONException) {
//                    e.printStackTrace()
//                    result.error(null, e.message, null)
//                }
//            }
//        ) { error: BleError ->
//            result.error(
//                error.errorCode.code.toString(),
//                error.reason,
//                bleErrorJsonConverter.toJson(error)
//            )
//        }
//        bleAdapter.writeCharacteristicForDevice(
//            deviceIdentifier,
//            serviceUuid, characteristicUuid,
//            Base64Converter.encode(bytesToWrite),
//            withResponse,
//            transactionId,
//            safeMainThreadResolver, safeMainThreadResolver
//        )
    }

    fun monitorCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuid: String,
        characteristicUuid: String,
        result: MethodChannel.Result
    ) {
//        val streamHandler = CharacteristicsMonitorStreamHandler(binaryMessenger, deviceIdentifier)
//        CharacteristicsDelegate.characteristicsMonitorStreamHandlers[streamHandler.name] =
//            streamHandler
//        bleAdapter.monitorCharacteristicForDevice(
//            deviceIdentifier,
//            serviceUuid,
//            characteristicUuid,
//            transactionId,
//            OnEventCallback { data: Characteristic? ->
//                mainThreadHandler.post(Runnable {
//                    try {
//                        streamHandler.onCharacteristicsUpdate(
//                            createCharacteristicResponse(data, transactionId)
//                        )
//                    } catch (e: JSONException) {
//                        e.printStackTrace()
//                        streamHandler.onError(BleErrorFactory.fromThrowable(e), transactionId)
//                        streamHandler.end()
//                    }
//                })
//            }, OnErrorCallback { error: BleError? ->
//                mainThreadHandler.post(Runnable {
//                    streamHandler.onError(error, transactionId)
//                    streamHandler.end()
//                })
//            })
//        result.success(streamHandler.name)
    }

    fun readDescriptorForDevice(
        deviceIdentifier: String,
        serviceUuid: String,
        characteristicUuid: String,
        descriptorUuid: String,
        result: MethodChannel.Result
    ) {
//        val safeMainThreadResolver: SafeMainThreadResolver<Descriptor> =
//            createMainThreadResolverForResult(result, transactionId)
//        bleAdapter.readDescriptorForDevice(
//            deviceId,
//            serviceUuid,
//            characteristicUuid,
//            descriptorUuid,
//            transactionId,
//            safeMainThreadResolver,  //success
//            safeMainThreadResolver //error
//        )
    }

    fun writeDescriptorForDevice(
        deviceIdentifier: String,
        serviceUuid: String,
        characteristicUuid: String,
        descriptorUuid: String,
        value: ByteArray,
        result: MethodChannel.Result
    ) {
//        val safeMainThreadResolver: SafeMainThreadResolver<Descriptor> =
//            createMainThreadResolverForResult(result, transactionId)
//        bleAdapter.writeDescriptorForDevice(
//            deviceId,
//            serviceUuid,
//            characteristicUuid,
//            descriptorUuid,
//            Base64Converter.encode(value),
//            transactionId,
//            safeMainThreadResolver,  //success
//            safeMainThreadResolver //error
//        )
    }

    override fun onConnectingPeripheral(peripheral: BluetoothPeripheral) {

    }

    override fun onConnectedPeripheral(peripheral: BluetoothPeripheral) {

    }

    override fun onConnectionFailed(peripheral: BluetoothPeripheral, status: HciStatus) {

    }

    override fun onDisconnectingPeripheral(peripheral: BluetoothPeripheral) {

    }

    override fun onDisconnectedPeripheral(peripheral: BluetoothPeripheral, status: HciStatus) {

    }

    override fun onDiscoveredPeripheral(peripheral: BluetoothPeripheral, scanResult: ScanResult) {

    }

    override fun onScanFailed(scanFailure: ScanFailure) {

    }

    override fun onBluetoothAdapterStateChanged(state: Int) {

    }
}
