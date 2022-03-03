package hu.privatdoktor.flutter_ble_lib

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Base64
import com.welie.blessed.*
import hu.privatdoktor.flutter_ble_lib.event.AdapterStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.RestoreStateStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.ScanningStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.bluetoothStateStrFrom
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.withTimeout
import org.json.JSONArray
import org.json.JSONObject
import java.io.Serializable
import java.util.*

class Client(private val binding: FlutterPluginBinding) : BluetoothCentralManagerCallback() {
    private val adapterStateStreamHandler = AdapterStateStreamHandler(binding.binaryMessenger)
    private val restoreStateStreamHandler = RestoreStateStreamHandler(binding.binaryMessenger)
    private val scanningStreamHandler = ScanningStreamHandler(binding.binaryMessenger)

    private var centralManager: BluetoothCentralManager? = null
    private val discoveredPeripherals = HashMap<String, DiscoveredPeripheral>()
    private val adapterStateListeners = HashMap<UUID, (Int) -> Unit>()

    //region Helpers
    companion object {
        fun serviceResponsesFor(
            deviceIdentifier: String,
            services: List<BluetoothGattService>
        ) : List<Map<String, Serializable>> {
            return services.map {
                mapOf(
                    "serviceUuid" to it.uuid.toString(),
                    "deviceID" to deviceIdentifier,
                    "isPrimary" to (it.type == BluetoothGattService.SERVICE_TYPE_PRIMARY)
                )
            }
        }

        fun characteristicResponseFor(
            peripheral: BluetoothPeripheral,
            characteristic: BluetoothGattCharacteristic
        ) : Map<String, Any> {
            val isIndicatbale =
                characteristic.properties.and(BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0

            val isNotifiable =
                characteristic.properties.and(BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
            val isReadable =
                characteristic.properties.and(BluetoothGattCharacteristic.PROPERTY_READ) != 0
            val isWritableWithResponse =
                characteristic.properties.and(BluetoothGattCharacteristic.PROPERTY_WRITE) != 0
            val isWritableWithoutResponse =
                characteristic.properties.and(BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
            return mapOf(
                "characteristicUuid" to characteristic.uuid.toString(),
                "isIndicatable" to isIndicatbale,
                "isNotifiable" to isNotifiable,
                "isNotifying" to peripheral.isNotifying(characteristic),
                "isReadable" to isReadable,
                "isWritableWithResponse" to isWritableWithResponse,
                "isWritableWithoutResponse" to isWritableWithoutResponse,
            )
        }

        fun characteristicsResponseFor(
            peripheral: BluetoothPeripheral,
            serviceUuidStr: String,
            characteristics: List<BluetoothGattCharacteristic>
        ) : Map<String, Any> {
            val characteristicResponses = characteristics.map {
                characteristicResponseFor(peripheral, it)
            }
            val characteristicsResponse = mapOf(
                "serviceUuid" to serviceUuidStr,
                "characteristics" to characteristicResponses
            )
            return characteristicsResponse
        }

        fun singleCharacteristicResponse(
            peripheral: BluetoothPeripheral,
            serviceUuidStr: String,
            characteristic: BluetoothGattCharacteristic
        ) : Map<String, Any> {
            val characteristicResponse = characteristicResponseFor(peripheral, characteristic)
            mapOf(
                "serviceUuid" to serviceUuidStr,
                "characteristic" to characteristicResponse
            )
            return characteristicResponse
        }

        fun singleCharacteristicWithValueResponse(
                peripheral: BluetoothPeripheral,
                serviceUuidStr: String,
                characteristic: BluetoothGattCharacteristic
        ): Map<String, Any> {
            val characteristicWithValueResponse =
                characteristicResponseFor(
                    peripheral,
                    characteristic
                ).toMutableMap()
            characteristicWithValueResponse["value"] =
                Base64.encodeToString(characteristic.value, Base64.NO_WRAP)
            return mapOf(
                "serviceUuid" to serviceUuidStr,
                "characteristic" to characteristicWithValueResponse
            )
        }

        fun descriptorsForPeripheralResponseFor(
            peripheral: BluetoothPeripheral,
            serviceUuidStr: String,
            characteristic: BluetoothGattCharacteristic
        ) : Map<String, Any> {
            val response = characteristicResponseFor(peripheral, characteristic).toMutableMap()
            response["serviceUuid"] = serviceUuidStr
            val descriptorResponses = characteristic.descriptors.map {
                mapOf("descriptorUuid" to it.uuid.toString())
            }
            response["descriptors"] = descriptorResponses
            return response
        }

        fun descriptorResponseFor(
            peripheral: BluetoothPeripheral,
            serviceUuidStr: String,
            characteristic: BluetoothGattCharacteristic,
            descriptor: BluetoothGattDescriptor
        ) : Map<String, Any> {
            val response = characteristicResponseFor(peripheral, characteristic).toMutableMap()
            response["serviceUuid"] = serviceUuidStr
            response["descriptorUuid"] = descriptor.uuid.toString()
            response["value"] = Base64.encodeToString(descriptor.value, Base64.NO_WRAP)
            return response
        }

        fun peripheralResponseFor(peripheral: BluetoothPeripheral) : Map<String, Any> {
            val peripheralResponse = mapOf("id" to peripheral.address).toMutableMap()
            peripheralResponse["name"] = peripheral.name ?: ""
            return peripheralResponse
        }
    }

    fun discoveredPeripheral(deviceIdentifier: String) : DiscoveredPeripheral {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }

        val chachedDp = discoveredPeripherals[deviceIdentifier]

        val dp = if (chachedDp != null) {
            chachedDp
        } else {
            val libCachedPeripheral = centralManager.getPeripheral(deviceIdentifier)
            val newDp = DiscoveredPeripheral(_peripheral =  libCachedPeripheral, centralManager = centralManager, binding = binding)
            discoveredPeripherals[deviceIdentifier] = newDp
            newDp
        }
        return dp
    }

    //endregion

    //region API

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
        filteredUUIDs: List<UUID>,
        result: MethodChannel.Result
    ) {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }
        val mode = when (scanMode) {
            -1 -> ScanMode.OPPORTUNISTIC
            0 -> ScanMode.LOW_POWER
            1 -> ScanMode.BALANCED
            2 -> ScanMode.LOW_LATENCY
            else -> ScanMode.LOW_POWER
        }
        centralManager.setScanMode(mode)
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

    @SuppressLint("MissingPermission")
    suspend fun enableRadio(result: MethodChannel.Result) : Unit {
        val context = binding.applicationContext
        val bluetoothService =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val bluetoothAdapter = bluetoothService?.adapter
        if (bluetoothAdapter == null) {
            result.success(null)
            return
        }
        if (bluetoothAdapter.state == BluetoothAdapter.STATE_ON) {
            result.success(null)
            return
        }

        val listenerUuid = UUID.randomUUID()
        val bluetoothOnNow = CompletableDeferred<Unit>()
        adapterStateListeners[listenerUuid] = {
            when (it) {
                BluetoothAdapter.STATE_ON -> {
                    bluetoothOnNow.complete(Unit)
                }
            }
        }
        val succ = bluetoothAdapter.enable()
        if (succ == false) {
            result.error(
                BleError(BleErrorCode.BluetoothStateChangeFailed)
            )
            return
        }
        withTimeout(timeMillis = 10 * 1000) {
            try {
                bluetoothOnNow.await()
            } catch (e: Throwable) {
               print(e)
            }
            adapterStateListeners.remove(listenerUuid)
            result.success(null)
        }
    }

    @SuppressLint("MissingPermission")
    suspend fun disableRadio(result: MethodChannel.Result) {
        val context = binding.applicationContext
        val bluetoothService =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val bluetoothAdapter = bluetoothService?.adapter
        if (bluetoothAdapter == null) {
            result.success(null)
            return
        }
        if (bluetoothAdapter.state == BluetoothAdapter.STATE_OFF) {
            result.success(null)
            return
        }

        val listenerUuid = UUID.randomUUID()
        val bluetoothOffNow = CompletableDeferred<Unit>()
        adapterStateListeners[listenerUuid] = {
            when (it) {
                BluetoothAdapter.STATE_OFF -> {
                    bluetoothOffNow.complete(Unit)
                }
            }
        }
        bluetoothAdapter.disable()
        withTimeout(timeMillis = 10 * 1000) {
            try {
                bluetoothOffNow.await()
            } catch (e: Throwable) {
                print(e)
            }
            adapterStateListeners.remove(listenerUuid)
            result.success(null)
        }
    }

    fun getState(result: MethodChannel.Result) {
        val context = binding.applicationContext
        val bluetoothService =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val state = bluetoothService?.adapter?.state
        if (state == null) {
            result.success("Unsupported")
            return
        }
        result.success(bluetoothStateStrFrom(state))
    }

    fun connectToDevice(
        deviceIdentifier: String,
        isAutoConnect: Boolean?,
        requestMtu: Int?,
        refreshGatt: Boolean,
        timeoutMillis: Long?,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        //FIXME: support configuration parameters

        dp.connect {
            it.fold(
                onSuccess = {
                    result.success(null)
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun isDeviceConnected(deviceIdentifier: String, result: MethodChannel.Result) {
        val dp = discoveredPeripheral(deviceIdentifier)

        result.success(dp.peripheral.state == ConnectionState.CONNECTED)
    }

    fun observeConnectionState(
        deviceIdentifier: String,
        emitCurrentValue: Boolean,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        if (emitCurrentValue) {
            Handler(Looper.getMainLooper()).post {
                dp.streamHandler.onNewConnectionState(dp.peripheral.state)
            }
        }
        result.success(dp.streamHandler.name)
    }

    fun cancelConnection(
        deviceIdentifier: String,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        dp.disconnect { it ->
            it.fold(
                onSuccess = {
                    result.success(null)
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun discoverServices(
        deviceIdentifier: String,
        serviceUUIDs: List<UUID>?,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        dp.discoverServices(serviceUUIDs = serviceUUIDs) {
            it.fold(
                onSuccess = {
                    val serviceResponses =
                        serviceResponsesFor(
                            deviceIdentifier = deviceIdentifier,
                            services = it.values.toList()
                        )

                    try {
                        val jsonStr = JSONArray(serviceResponses).toString()
                        result.success(jsonStr)
                    } catch (e: Throwable) {
                        result.error(e)
                    }
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun discoverCharacteristics(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicsUuids: List<UUID>?,
        result: MethodChannel.Result
    ) {
        characteristics(
            deviceIdentifier = deviceIdentifier,
            serviceUuid = serviceUuid,
            result = result
        )
    }

    fun services(
        deviceIdentifier: String,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        val serviceResponses =
            serviceResponsesFor(
                deviceIdentifier = deviceIdentifier,
                services = dp.peripheral.services
            )

        val jsonStr = JSONArray(serviceResponses).toString()
        result.success(jsonStr)
    }

    fun characteristics(
        deviceIdentifier: String,
        serviceUuid: UUID,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        val service = dp.peripheral.getService(serviceUuid)
        if (service == null) {
            throw BleError.serviceNotFound(serviceUuid.toString())
        }

        val characteristicsResponse = characteristicsResponseFor(
            peripheral = dp.peripheral,
            serviceUuidStr = serviceUuid.toString(),
            characteristics = service.characteristics
        )
        val characteristicsResponseJsonStr = JSONObject(characteristicsResponse).toString()
        result.success(characteristicsResponseJsonStr)
    }

    fun descriptorsForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        val characteristic = dp.peripheral.getService(
            serviceUuid
        )?.getCharacteristic(
            characteristicUuid
        )
        if (characteristic == null) {
            throw BleError.characteristicNotFound(characteristicUuid.toString())
        }

        val response = descriptorsForPeripheralResponseFor(
            peripheral = dp.peripheral,
            serviceUuidStr = serviceUuid.toString(),
            characteristic = characteristic
        )
        val jsonStr = JSONObject(response).toString()
        result.success(jsonStr)
    }

    fun rssi(
        deviceIdentifier: String,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)
        dp.readRemoteRssi {
            it.fold(
                onSuccess = {
                    result.success(it)
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun requestMtu(
        deviceIdentifier: String,
        mtu: Int,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        dp.requestMtu(mtu) {
            it.fold(
                onSuccess = {
                    result.success(it)
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun getConnectedDevices(
        serviceUUIDs: List<UUID>,
        result: MethodChannel.Result
    ) {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }
        val serviceUUIDset = serviceUUIDs.toSet()
        val connectedPeripherals = centralManager.connectedPeripherals

        val fileteredPeripherals =
            connectedPeripherals.filter {
                val connectedServiceUUIDs = it.services.map { it.uuid }.toSet()
                connectedServiceUUIDs.intersect(serviceUUIDset).isNotEmpty()
            }

        val peripheralResponses = fileteredPeripherals.map { peripheralResponseFor(it) }
        val jsonArray = JSONArray(peripheralResponses)

        result.success(jsonArray)
    }

    fun getKnownDevices(deviceIdentifiers: List<String>, result: MethodChannel.Result) {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }
        val deviceIds = deviceIdentifiers.map { it.lowercase() }.toSet()
        val connectedPeripherals = centralManager.connectedPeripherals

        val fileteredPeripherals =
            connectedPeripherals.filter {
                deviceIdentifiers.contains(it.address.lowercase())
            }

        val peripheralResponses = fileteredPeripherals.map { peripheralResponseFor(it) }
        val jsonArray = JSONArray(peripheralResponses)

        result.success(jsonArray)
    }


    fun readCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)
        val characteristic = dp.peripheral.getService(
            serviceUuid
        )?.getCharacteristic(
            characteristicUuid
        )
        if (characteristic == null) {
            throw BleError.characteristicNotFound(characteristicUuid.toString())
        }

        dp.readCharacteristic(char = characteristic) {
            it.fold(
                onSuccess = {
                    val payload = singleCharacteristicWithValueResponse(
                        peripheral = dp.peripheral,
                        serviceUuidStr = serviceUuid.toString(),
                        characteristic = it
                    )
                    try {
                        val jsonStr = JSONObject(payload).toString()
                        result.success(jsonStr)
                    } catch (e: Throwable) {
                        result.error(e)
                    }
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun writeCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID,
        bytesToWrite: ByteArray,
        withResponse: Boolean,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)
        val characteristic = dp.peripheral.getService(
            serviceUuid
        )?.getCharacteristic(
            characteristicUuid
        )
        if (characteristic == null) {
            throw BleError.characteristicNotFound(characteristicUuid.toString())
        }

        dp.writeCharacteristic(
            char = characteristic,
            value = bytesToWrite,
            withResponse = withResponse
        ) {
            it.fold(
                onSuccess = {
                    val payload = singleCharacteristicResponse(
                        peripheral = dp.peripheral,
                        serviceUuidStr = serviceUuid.toString(),
                        characteristic = it
                    )
                    try {
                        val jsonStr = JSONObject(payload).toString()
                        result.success(jsonStr)
                    } catch (e: Throwable) {
                        result.error(e)
                    }
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun monitorCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        dp.monitorCharacteristic(
            serviceUuid = serviceUuid.toString(),
            characteristicUuid = characteristicUuid.toString()
        ) {
            it.fold(
                onSuccess = {
                    result.success(it)
                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun readDescriptorForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID,
        descriptorUuid: UUID,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)
        val descriptor = dp.peripheral.getService(
            serviceUuid
        )?.getCharacteristic(
            characteristicUuid
        )?.getDescriptor(
            descriptorUuid
        )
        if (descriptor == null) {
            throw BleError.descriptorNotFound(descriptorUuid.toString())
        }

        dp.readDescriptor(desc = descriptor) {
            it.fold(
                onSuccess = {
                    val payload = descriptorResponseFor(
                        peripheral = dp.peripheral,
                        serviceUuidStr = serviceUuid.toString(),
                        characteristic = it.characteristic,
                        descriptor = it
                    )
                    try {
                        val jsonStr = JSONObject(payload).toString()
                        result.success(jsonStr)
                    } catch (e: Throwable) {
                        result.error(e)
                    }

                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }

    fun writeDescriptorForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID,
        descriptorUuid: UUID,
        value: ByteArray,
        result: MethodChannel.Result
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)
        val descriptor = dp.peripheral.getService(
            serviceUuid
        )?.getCharacteristic(
            characteristicUuid
        )?.getDescriptor(
            descriptorUuid
        )
        if (descriptor == null) {
            throw BleError.descriptorNotFound(descriptorUuid.toString())
        }

        dp.writeDescriptor(desc = descriptor, value = value) {
            it.fold(
                onSuccess = {
                    val payload = descriptorResponseFor(
                        peripheral = dp.peripheral,
                        serviceUuidStr = serviceUuid.toString(),
                        characteristic = it.characteristic,
                        descriptor = it
                    )
                    try {
                        val jsonStr = JSONObject(payload).toString()
                        result.success(jsonStr)
                    } catch (e: Throwable) {
                        result.error(e)
                    }

                },
                onFailure = {
                    result.error(it)
                }
            )
        }
    }
    //endregion

    //region Callbacks

    override fun onDiscoveredPeripheral(peripheral: BluetoothPeripheral, scanResult: ScanResult) {
        val discoveredPeripheral = discoveredPeripherals[peripheral.address]
        if (discoveredPeripheral != null) {
            discoveredPeripheral.updateInternalPeripheral(peripheral)
        } else {
            val centralManager = this.centralManager
            if (centralManager == null) {
                return
            }
            discoveredPeripherals[peripheral.address] =
                DiscoveredPeripheral(
                    _peripheral = peripheral,
                    centralManager = centralManager,
                    binding = binding
                )
        }
        scanningStreamHandler.onScanResult(
            peripheral = peripheral,
            scanResult = scanResult
        )
    }

    override fun onScanFailed(scanFailure: ScanFailure) {
        print("Client.kt::onScanFailed:  $scanFailure")
    }

    override fun onConnectingPeripheral(peripheral: BluetoothPeripheral) {
        discoveredPeripherals[peripheral.address]?.connectionStateChange()
    }

    override fun onConnectedPeripheral(peripheral: BluetoothPeripheral) {
        val discoveredPeripheral = discoveredPeripherals[peripheral.address]
        if (discoveredPeripheral == null) {
            return
        }
        discoveredPeripheral.connectionStateChange()
        discoveredPeripheral.connected(Result.success(Unit))
    }

    override fun onConnectionFailed(peripheral: BluetoothPeripheral, status: HciStatus) {
        val discoveredPeripheral = discoveredPeripherals[peripheral.address]
        if (discoveredPeripheral == null) {
            return
        }
        discoveredPeripheral.connectionStateChange()
        discoveredPeripheral.connected(
            Result.failure(
                BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
            )
        )

    }

    override fun onDisconnectingPeripheral(peripheral: BluetoothPeripheral) {
        val dp = discoveredPeripherals[peripheral.address]
        dp?.connectionStateChange()
    }

    override fun onDisconnectedPeripheral(peripheral: BluetoothPeripheral, status: HciStatus) {
        val dp = discoveredPeripherals[peripheral.address]
        dp?.connectionStateChange()
        dp?.disconnected(Result.success(Unit))
        discoveredPeripherals.remove(peripheral.address)
    }

    override fun onBluetoothAdapterStateChanged(state: Int) {
        adapterStateListeners.forEach {
            it.value(state)
        }
        adapterStateStreamHandler.onNewAdapterState(state = state)
    }

    //endregion


}
