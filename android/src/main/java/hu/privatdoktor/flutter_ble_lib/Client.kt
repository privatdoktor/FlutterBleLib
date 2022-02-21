package hu.privatdoktor.flutter_ble_lib

import hu.privatdoktor.flutter_ble_lib.delegate.*
import hu.privatdoktor.multiplatformbleadapter.*
import hu.privatdoktor.multiplatformbleadapter.errors.BleError
import hu.privatdoktor.multiplatformbleadapter.utils.Base64Converter
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodChannel
import org.json.JSONException

class Client(val binding: FlutterPluginBinding) {

    fun isClientCreated(result: MethodChannel.Result) {
        result.success(false)
    }

    fun createClient(restoreStateIdentifier: String?, result: MethodChannel.Result) {
//        if (this.bleAdapter != null) {
//            Log.w(
//                FlutterBleLibPlugin.TAG,
//                "Overwriting existing native client. Use BleManager#isClientCreated to check whether a client already exists."
//            )
//        }
//        val bleAdapter = BleAdapter(context)
//        this.bleAdapter = bleAdapter
//        delegates.add(DeviceConnectionDelegate(bleAdapter, binaryMessenger))
//        delegates.add(LogLevelDelegate(bleAdapter))
//        delegates.add(DiscoveryDelegate(bleAdapter))
//        delegates.add(BluetoothStateDelegate(bleAdapter))
//        delegates.add(RssiDelegate(bleAdapter))
//        delegates.add(MtuDelegate(bleAdapter))
//        delegates.add(CharacteristicsDelegate(bleAdapter, binaryMessenger!!))
//        delegates.add(DevicesDelegate(bleAdapter))
//        delegates.add(DescriptorsDelegate(bleAdapter))
//        bleAdapter.createClient(call.argument(ArgumentKey.RESTORE_STATE_IDENTIFIER), {
//            adapterStateStreamHandler.onNewAdapterState(it)
//        }, {
//            restoreStateStreamHandler.onRestoreEvent(it)
//        })

        result.success(null)
    }

    fun destroyClient(result: MethodChannel.Result) {
//        if (bleAdapter != null) {
//            bleAdapter!!.destroyClient()
//        }
//        //        scanningStreamHandler.onComplete();
//        bleAdapter = null
//        delegates.clear()
        result.success(null)
    }



    fun startDeviceScan(
        scanMode: Int,
        callbackType: Int,
        filteredUUIDs: Array<String>,
        result: MethodChannel.Result
    ) {
//        val bleAdapter = this.bleAdapter
//        if (bleAdapter == null) {
//            result.success(null)
//            return
//        }
//        val uuids = call.argument<List<String>>(ArgumentKey.UUIDS)!!.toTypedArray()
//        bleAdapter.startDeviceScan(
//            uuids,
//            call.argument(ArgumentKey.SCAN_MODE)!!,
//            call.argument(ArgumentKey.CALLBACK_TYPE)!!, {
//                scanningStreamHandler.onScanResult(it)
//            }, { error ->
//                scanningStreamHandler.onError(error)
//            })
        result.success(null)
    }

    fun stopDeviceScan(result: MethodChannel.Result) {
//        bleAdapter?.stopDeviceScan()
//        //        scanningStreamHandler.onComplete();
        result.success(null)
    }

    fun enableRadio(result: MethodChannel.Result) {
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

}