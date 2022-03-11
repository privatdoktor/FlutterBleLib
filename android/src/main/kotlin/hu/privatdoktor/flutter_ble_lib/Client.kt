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
import kotlinx.coroutines.*
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
            return mapOf(
                "serviceUuid" to serviceUuidStr,
                "characteristic" to characteristicResponse
            )
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

    fun isClientCreated() : Boolean {
        return centralManager != null
    }

    fun createClient() {
        centralManager = BluetoothCentralManager(
            binding.applicationContext,
            this,
            Handler(Looper.getMainLooper())
        )
        restoreStateStreamHandler.sendDummyRestoreEvent()
    }

    fun destroyClient() {
        val centralManager = this.centralManager
        if (centralManager == null) {
            return
        }

        if (centralManager.isBluetoothEnabled && centralManager.isScanning) {
            centralManager.stopScan()
        }
        centralManager.close()
        this.centralManager = null
    }

    fun startDeviceScan(
        scanMode: Int,
        callbackType: Int,
        filteredUUIDs: List<UUID>
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
    }

    fun stopDeviceScan() {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }

        centralManager.stopScan()
    }

    @SuppressLint("MissingPermission")
    suspend fun enableRadio() : Unit {
        val context = binding.applicationContext
        val bluetoothService =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val bluetoothAdapter = bluetoothService?.adapter
        if (bluetoothAdapter == null) {
            return
        }
        if (bluetoothAdapter.state == BluetoothAdapter.STATE_ON) {
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
            throw BleError(BleErrorCode.BluetoothStateChangeFailed)
        }
        withTimeout(timeMillis = 10 * 1000) {
            bluetoothOnNow.await()
            adapterStateListeners.remove(listenerUuid)
        }
    }

    @SuppressLint("MissingPermission")
    suspend fun disableRadio() {
        val context = binding.applicationContext
        val bluetoothService =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val bluetoothAdapter = bluetoothService?.adapter
        if (bluetoothAdapter == null) {
            return
        }
        if (bluetoothAdapter.state == BluetoothAdapter.STATE_OFF) {
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
            bluetoothOffNow.await()
            adapterStateListeners.remove(listenerUuid)
        }
    }

    fun getState() : String {
        val context = binding.applicationContext
        val bluetoothService =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val state = bluetoothService?.adapter?.state
        if (state == null) {
            return "Unsupported"
        }
        return bluetoothStateStrFrom(state)
    }

    suspend fun connectToDevice(
        deviceIdentifier: String,
        isAutoConnect: Boolean?,
        requestMtu: Int?,
        refreshGatt: Boolean,
        timeoutMillis: Long?
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        //FIXME: support configuration parameters

        dp.connect()
    }

    fun isDeviceConnected(deviceIdentifier: String) : Boolean {
        val dp = discoveredPeripheral(deviceIdentifier)

        return dp.peripheral.state == ConnectionState.CONNECTED
    }

    fun observeConnectionState(
        deviceIdentifier: String,
        emitCurrentValue: Boolean
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)

        if (emitCurrentValue) {
            Handler(Looper.getMainLooper()).post {
                dp.connectionStateStreamHandler.onNewConnectionState(dp.peripheral.state)
            }
        }
        return dp.connectionStateStreamHandler.name
    }

    suspend fun cancelConnection(
        deviceIdentifier: String
    ) {
        val dp = discoveredPeripheral(deviceIdentifier)

        dp.disconnect()
    }

    suspend fun discoverServices(
        deviceIdentifier: String,
        serviceUUIDs: List<UUID>?
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)

        val it = dp.discoverServices(serviceUUIDs = serviceUUIDs)
        val serviceResponses =
            serviceResponsesFor(
                deviceIdentifier = deviceIdentifier,
                services = it.values.toList()
            )

        val jsonStr = JSONArray(serviceResponses).toString()
        return jsonStr
    }

    fun discoverCharacteristics(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicsUuids: List<UUID>?
    ) : String {
        return characteristics(
            deviceIdentifier = deviceIdentifier,
            serviceUuid = serviceUuid
        )
    }

    fun services(
        deviceIdentifier: String
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)

        val serviceResponses =
            serviceResponsesFor(
                deviceIdentifier = deviceIdentifier,
                services = dp.peripheral.services
            )

        val jsonStr = JSONArray(serviceResponses).toString()
        return jsonStr
    }

    fun characteristics(
        deviceIdentifier: String,
        serviceUuid: UUID
    ) : String {
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
        return characteristicsResponseJsonStr
    }

    fun descriptorsForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID
    ) : String {
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
        return jsonStr
    }

    suspend fun rssi(
        deviceIdentifier: String
    ) : Int {
        val dp = discoveredPeripheral(deviceIdentifier)
        return dp.readRemoteRssi()
    }

    suspend fun requestMtu(
        deviceIdentifier: String,
        mtu: Int
    ) : Int {
        val dp = discoveredPeripheral(deviceIdentifier)

        return dp.requestMtu(mtu)
    }

    fun getConnectedDevices(
        serviceUUIDs: List<UUID>
    ) : String {
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
        val jsonArrayStr = JSONArray(peripheralResponses).toString()
        return jsonArrayStr
    }

    fun getKnownDevices(
        deviceIdentifiers: List<String>
    ) : String {
        val centralManager = this.centralManager
        if (centralManager == null) {
            throw BleError(errorCode = BleErrorCode.BluetoothManagerDestroyed)
        }
        val deviceIds = deviceIdentifiers.map { it.lowercase() }.toSet()
        val connectedPeripherals = centralManager.connectedPeripherals

        val fileteredPeripherals =
            connectedPeripherals.filter {
                deviceIds.contains(it.address.lowercase())
            }

        val peripheralResponses = fileteredPeripherals.map { peripheralResponseFor(it) }
        val jsonArrayStr = JSONArray(peripheralResponses).toString()
        return jsonArrayStr
    }


    suspend fun readCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuidStr: String,
        characteristicUuidStr: String
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)
        val dc = dp.discoveredCharacteristicFor(
            serviceUuidStr = serviceUuidStr,
            characteristicUuidStr = characteristicUuidStr
        )
        if (dc == null) {
            throw BleError.characteristicNotFound(characteristicUuidStr)
        }

        val newChar = dc.read()
        val payload = singleCharacteristicWithValueResponse(
            peripheral = dp.peripheral,
            serviceUuidStr = serviceUuidStr,
            characteristic = newChar
        )
        val jsonStr = JSONObject(payload).toString()
        return jsonStr
    }

    suspend fun writeCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuidStr: String,
        characteristicUuidStr: String,
        bytesToWrite: ByteArray,
        withResponse: Boolean
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)
        val dc = dp.discoveredCharacteristicFor(
            serviceUuidStr = serviceUuidStr,
            characteristicUuidStr = characteristicUuidStr
        )
        if (dc == null) {
            throw BleError.characteristicNotFound(characteristicUuidStr)
        }

        val newChar = dc.write(
            value = bytesToWrite,
            withResponse = withResponse
        )

        val payload = singleCharacteristicResponse(
            peripheral = dp.peripheral,
            serviceUuidStr = serviceUuidStr,
            characteristic = newChar
        )
        val jsonStr = JSONObject(payload).toString()
        return jsonStr
    }

    suspend fun monitorCharacteristicForDevice(
        deviceIdentifier: String,
        serviceUuid: UUID,
        characteristicUuid: UUID
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)

        val key = dp.monitorCharacteristic(
            serviceUuid = serviceUuid.toString(),
            characteristicUuid = characteristicUuid.toString()
        )
        return key
    }

    suspend fun readDescriptorForDevice(
        deviceIdentifier: String,
        serviceUuidStr: String,
        characteristicUuidStr: String,
        descriptorUuidStr: String
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)
        val dd = dp.discoveredCharacteristicFor(
            serviceUuidStr = serviceUuidStr,
            characteristicUuidStr = characteristicUuidStr
        )?.discoveredDescriptors?.get(
            descriptorUuidStr
        )
        if (dd == null) {
            throw BleError.descriptorNotFound(descriptorUuidStr)
        }

        val it = dd.read()

        val payload = descriptorResponseFor(
            peripheral = dp.peripheral,
            serviceUuidStr = serviceUuidStr,
            characteristic = it.characteristic,
            descriptor = it
        )

        val jsonStr = JSONObject(payload).toString()
        return jsonStr
    }

    suspend fun writeDescriptorForDevice(
        deviceIdentifier: String,
        serviceUuidStr: String,
        characteristicUuidStr: String,
        descriptorUuidStr: String,
        value: ByteArray
    ) : String {
        val dp = discoveredPeripheral(deviceIdentifier)
        val dd = dp.discoveredCharacteristicFor(
            serviceUuidStr = serviceUuidStr,
            characteristicUuidStr = characteristicUuidStr
        )?.discoveredDescriptors?.get(
            descriptorUuidStr
        )
        if (dd == null) {
            throw BleError.descriptorNotFound(descriptorUuidStr)
        }

        val it = dd.write(value)

        val payload = descriptorResponseFor(
            peripheral = dp.peripheral,
            serviceUuidStr = serviceUuidStr,
            characteristic = it.characteristic,
            descriptor = it
        )

        val jsonStr = JSONObject(payload).toString()
        return jsonStr
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
        discoveredPeripherals[peripheral.address]?.connectionStateStreamHandler?.onNewConnectionState(
            ConnectionState.CONNECTING
        )
    }

    override fun onConnectedPeripheral(peripheral: BluetoothPeripheral) {
        val dp = discoveredPeripherals[peripheral.address]
        if (dp == null) {
            return
        }
        dp.connectionStateStreamHandler.onNewConnectionState(
            ConnectionState.CONNECTED
        )
        dp.connected(Result.success(Unit))
    }

    override fun onConnectionFailed(peripheral: BluetoothPeripheral, status: HciStatus) {
        val discoveredPeripheral = discoveredPeripherals[peripheral.address]
        if (discoveredPeripheral == null) {
            return
        }

        discoveredPeripheral.connected(
            Result.failure(
                BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
            )
        )

    }

    override fun onDisconnectingPeripheral(peripheral: BluetoothPeripheral) {
        val dp = discoveredPeripherals[peripheral.address]
        dp?.connectionStateStreamHandler?.onNewConnectionState(
            ConnectionState.DISCONNECTING
        )
    }

    override fun onDisconnectedPeripheral(peripheral: BluetoothPeripheral, status: HciStatus) {
        val dp = discoveredPeripherals[peripheral.address]
        dp?.connectionStateStreamHandler?.onNewConnectionState(
            ConnectionState.DISCONNECTED
        )
        dp?.disconnected()
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
