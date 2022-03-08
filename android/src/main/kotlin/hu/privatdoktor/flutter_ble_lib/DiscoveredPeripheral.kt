package hu.privatdoktor.flutter_ble_lib

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import com.welie.blessed.*
import hu.privatdoktor.flutter_ble_lib.event.CharacteristicsMonitorStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.lang.ref.WeakReference
import java.util.*


class DiscoveredPeripheral(
    private var _peripheral: BluetoothPeripheral,
    centralManager: BluetoothCentralManager,
    val binding: FlutterPlugin.FlutterPluginBinding
) : BluetoothPeripheralCallback() {
    val peripheral get() = _peripheral
    private var _centralManager: WeakReference<BluetoothCentralManager?>
    private val centralManager get() = _centralManager.get()

    val connectionStateStreamHandler = ConnectionStateStreamHandler(binding.binaryMessenger, peripheral.address)

    private var _connectCompleted: ((Result<Unit>) -> Unit)? = null
    private var _disconnectCompleted: ((Result<Unit>) -> Unit)? = null
    private var _onDisconnectedListeners: Queue<() -> Unit> = LinkedList()
    private var _servicesDiscoveryCompleted:((Result<Map<UUID, BluetoothGattService>>) -> Unit)? = null
    private var _onRemoteRssiReadCompleted: ((Result<Int>) -> Unit)? = null
    private var _onRequestMtuCompleted: ((Result<Int>) -> Unit)? = null

//    private var _onSetNotifyCompleted: ((Result<Unit>) -> Unit)? = null
    private val discoveredCharacteristics = HashMap<String, DiscoveredCharacteristic>()


//    private var _onCharacteristicWriteCompleted: ((Result<BluetoothGattCharacteristic>) -> Unit)? = null

    private val monitorCharacteristicStreamHandlers = HashMap<String, CharacteristicsMonitorStreamHandler>()

    private var _onDescriptorReadCompleted: ((Result<BluetoothGattDescriptor>) -> Unit)? = null
    private var _onDescriptorWriteCompleted: ((Result<BluetoothGattDescriptor>) -> Unit)? = null


    init {
        _centralManager = WeakReference(centralManager)
    }

    fun updateInternalPeripheral(peripheral: BluetoothPeripheral) {
        _peripheral = peripheral
    }

    //region API
    fun connect(completion: (Result<Unit>) -> Unit) {
        val pending = _servicesDiscoveryCompleted
        if (pending != null) {
            _servicesDiscoveryCompleted = null
            pending(
                Result.failure(
                    BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
                )
            )
        }

        _servicesDiscoveryCompleted = {
            completion(it.map { Unit })
        }

        centralManager?.connectPeripheral(peripheral, this)
        peripheral.requestConnectionPriority(ConnectionPriority.HIGH)
    }

    fun disconnect(completion: (Result<Unit>) -> Unit) {
        val pending = _disconnectCompleted
        if (pending != null) {
            _disconnectCompleted = null
            pending(
                Result.failure(
                    BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
                )
            )
        }
        _disconnectCompleted = completion
        centralManager?.cancelConnection(peripheral)
    }

    fun onDisconnected(listener: () -> Unit) {
        _onDisconnectedListeners.add(listener)
    }

    fun discoverServices(
        serviceUUIDs: List<UUID>? = null,
        completion: (
            res: Result<Map<UUID, BluetoothGattService>>
        ) -> Unit
    ) {

        completion(
            Result.success(
                peripheral.services.associateBy { it.uuid }
            )
        )
    }

    fun readRemoteRssi(
        completion: (
            res: Result<Int>
        ) -> Unit
    ) {
        val pending = _onRemoteRssiReadCompleted
        if (pending != null) {
            _onRemoteRssiReadCompleted = null
            pending(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.DeviceRSSIReadFailed,
                        deviceID = peripheral.address
                    )
                )
            )
        }
        _onRemoteRssiReadCompleted = completion
        val succ = peripheral.readRemoteRssi()
        if (succ == false) {
            _onRemoteRssiReadCompleted = null
            completion(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.DeviceRSSIReadFailed,
                        deviceID = peripheral.address,
                        reason = "peripheral.readRemoteRssi() failed, maybe device is not connected"
                    )
                )
            )
        }
    }

    fun requestMtu(
        mtu: Int,
        completion: (
            res: Result<Int>
        ) -> Unit
    ) {
        val pending = _onRequestMtuCompleted
        if (pending != null) {
            _onRequestMtuCompleted = null
            pending(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.DeviceMTUChangeFailed,
                        deviceID = peripheral.address
                    )
                )
            )
        }
        _onRequestMtuCompleted = completion
        val succ = peripheral.requestMtu(mtu)
        if (succ == false) {
            _onRequestMtuCompleted = null
            completion(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.DeviceMTUChangeFailed,
                        deviceID = peripheral.address,
                        reason = "peripheral.requestMtu() failed, maybe device is not connected"
                    )
                )
            )
        }
    }

    fun discoveredCharacteristicFor(
        serviceUuidStr: String,
        characteristicUuidStr: String
    ) : DiscoveredCharacteristic? {
        return discoveredCharacteristics[
            DiscoveredCharacteristic.uniqueKeyFor(
                serviceUuidStr = serviceUuidStr,
                characteristicUuidStr = characteristicUuidStr
            )
        ]
    }

    fun discoveredCharacteristicFor(
        characteristic: BluetoothGattCharacteristic
    ) : DiscoveredCharacteristic? {
        return discoveredCharacteristics[
            DiscoveredCharacteristic.uniqueKeyFor(
                char = characteristic
            )
        ]
    }





    suspend fun monitorCharacteristic(
        serviceUuid: String,
        characteristicUuid: String
    ) : String {

        val characteristic = peripheral.getService(
            UUID.fromString(serviceUuid)
        )?.getCharacteristic(
            UUID.fromString(characteristicUuid)
        )
        if (characteristic == null) {
            throw BleError.characteristicNotFound(characteristicUuid)
        }
        val uniqueKey = CharacteristicsMonitorStreamHandler.uniqueKeyFor(
            deviceIdentifier = peripheral.address,
            char = characteristic
        )
        val streamHandler =
            CharacteristicsMonitorStreamHandler(
                binaryMessenger = binding.binaryMessenger,
                uniqueKey = uniqueKey
            )
        monitorCharacteristicStreamHandlers[uniqueKey] = streamHandler
        streamHandler.afterCancelDo {
            monitorCharacteristicStreamHandlers.remove(uniqueKey)
            if (peripheral.isNotifying(characteristic)) {
//                peripheral.setNotify(characteristic, false)
            }
        }
        onDisconnected {
            streamHandler.end()
            monitorCharacteristicStreamHandlers.remove(uniqueKey)
        }

        return uniqueKey

//        val pending = _onSetNotifyCompleted
//        if (pending != null) {
//            _onSetNotifyCompleted = null
//            pending.invoke(Result.failure(BleError(BleErrorCode.CharacteristicNotifyChangeFailed)))
//        }
//
//        if (peripheral.isNotifying(characteristic)) {
//            completion(Result.success(key))
//            return
//        }
//
//        _onSetNotifyCompleted = {
//            completion(it.map { key })
//        }
//        val succ = peripheral.setNotify(characteristic, true)
//        if (succ == false) {
//            _onSetNotifyCompleted = null
//            completion(Result.failure(
//                BleError(
//                    errorCode = BleErrorCode.CharacteristicNotifyChangeFailed,
//                    serviceUUID = characteristic.service.uuid.toString(),
//                    characteristicUUID = characteristic.uuid.toString(),
//                    reason = "peripheral.monitorCharacteristic() failed, maybe device is not connected"
//                )
//            ))
//            return
//        }
//
    }

    fun readDescriptor(
        desc: BluetoothGattDescriptor,
        completion: (Result<BluetoothGattDescriptor>) -> Unit
    ) {
        val pending = _onDescriptorReadCompleted
        if (pending != null) {
            _onDescriptorReadCompleted = null
            pending(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicReadFailed,
                        deviceID = peripheral.address,
                        serviceUUID = desc.characteristic.service.uuid.toString(),
                        characteristicUUID = desc.characteristic.uuid.toString(),
                        descriptorUUID = desc.uuid.toString()
                    )
                )
            )
        }
        _onDescriptorReadCompleted = completion
        val succ = peripheral.readDescriptor(desc)
        if (succ == false) {
            _onDescriptorReadCompleted = null
            completion(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicReadFailed,
                        serviceUUID = desc.characteristic.service.uuid.toString(),
                        characteristicUUID = desc.characteristic.uuid.toString(),
                        descriptorUUID = desc.uuid.toString(),
                        reason = "peripheral.readDescriptor() failed, maybe device is not connected"
                    )
                )
            )
        }

    }

    fun writeDescriptor(
        desc: BluetoothGattDescriptor,
        value: ByteArray,
        completion: (Result<BluetoothGattDescriptor>) -> Unit
    ) {
        val pending = _onDescriptorWriteCompleted
        if (pending != null) {
            _onDescriptorWriteCompleted = null
            pending(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.DescriptorWriteFailed,
                        deviceID = peripheral.address,
                        serviceUUID = desc.characteristic.service.uuid.toString(),
                        characteristicUUID = desc.characteristic.uuid.toString(),
                        descriptorUUID = desc.uuid.toString()
                    )
                )
            )
        }
        _onDescriptorWriteCompleted = completion

        val succ = peripheral.writeDescriptor(desc, value)
        if (succ == false) {
            _onDescriptorWriteCompleted = null
            completion(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.DescriptorWriteFailed,
                        deviceID = peripheral.address,
                        serviceUUID = desc.characteristic.service.uuid.toString(),
                        characteristicUUID = desc.characteristic.uuid.toString(),
                        descriptorUUID = desc.uuid.toString(),
                        reason = "peripheral.writeDescriptor() failed, maybe device is not connected"
                    )
                )
            )
        }
    }

    //endregion

    //region For Publishers

    fun connected(res: Result<Unit>) {
        _connectCompleted?.invoke(res)
        _connectCompleted = null
    }

    fun disconnected(res: Result<Unit>) {
        _disconnectCompleted?.invoke(res)
        _disconnectCompleted = null

        if (res.isSuccess) {
            while (_onDisconnectedListeners.isNotEmpty()) {
                _onDisconnectedListeners.poll()?.invoke()
            }
        }
    }

    fun servicesDiscoveredCompleted(peripheral: BluetoothPeripheral) {
        _servicesDiscoveryCompleted?.invoke(
            Result.success(
                value = peripheral.services.associateBy { it.uuid }
            )
        )
        _servicesDiscoveryCompleted = null
    }

    private fun remoteRssiReadComleted(res: Result<Int>) {
        _onRemoteRssiReadCompleted?.invoke(res)
        _onRemoteRssiReadCompleted = null
    }

    private fun requestMtuCompleted(res: Result<Int>) {
        _onRequestMtuCompleted?.invoke(res)
        _onRequestMtuCompleted = null
    }


    private fun descriptorReadCompleted(res: Result<BluetoothGattDescriptor>) {
        _onDescriptorReadCompleted?.invoke(res)
        _onDescriptorReadCompleted = null
    }

    private fun descriptorWriteCompleted(res: Result<BluetoothGattDescriptor>) {
        _onDescriptorWriteCompleted?.invoke(res)
        _onDescriptorWriteCompleted = null
    }
    //endregion

    //region Helpers



    //endregion

    //region Callbacks
    override fun onServicesDiscovered(peripheral: BluetoothPeripheral) {
        for (service in peripheral.services) {
            for (char in service.characteristics) {
                discoveredCharacteristics[DiscoveredCharacteristic.uniqueKeyFor(char)] =
                    DiscoveredCharacteristic(discoveredPeripheral = this, characteristic = char)
            }
        }
        servicesDiscoveredCompleted(peripheral = peripheral)
    }

    override fun onNotificationStateUpdate(
        peripheral: BluetoothPeripheral,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
        val dc = discoveredCharacteristics[
            DiscoveredCharacteristic.uniqueKeyFor(characteristic)
        ]

        if (status != GattStatus.SUCCESS) {
            dc?.onSetNotifyChanged(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicNotifyChangeFailed,
                        reason = "DiscoveredPeripheral::onNotificationStateUpdate: status: $status",
                        androidCode = status.value,
                        deviceID = peripheral.address,
                        serviceUUID = characteristic.service.uuid.toString(),
                        characteristicUUID = characteristic.uuid.toString()
                    )
                )
            )
            return
        }

        val key =
            CharacteristicsMonitorStreamHandler.uniqueKeyFor(
                deviceIdentifier = peripheral.address,
                char = characteristic
            )
        val streamHandler = monitorCharacteristicStreamHandlers[key]
        print("DiscoveredPeripheral::onNotificationStateUpdate: streamhandler exists: ${streamHandler != null}}")

        if (peripheral.isNotifying(characteristic)) {
            print("DiscoveredPeripheral::onNotificationStateUpdate: isNotifying: true for char: ${characteristic.uuid.toString()}")
//            _onSetNotifyCompleted?.invoke(Result.success(Unit))
//            _onSetNotifyCompleted = null
        } else {
            print("DiscoveredPeripheral::onNotificationStateUpdate: isNotifying: false for char: ${characteristic.uuid.toString()}")
            print("DiscoveredPeripheral::onNotificationStateUpdate: ending flutter notify stream for char: ${characteristic.uuid.toString()}")
            streamHandler?.end()
        }

    }

    override fun onCharacteristicUpdate(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
        if (peripheral.isNotifying(characteristic)) {
            val key =
                CharacteristicsMonitorStreamHandler.uniqueKeyFor(
                    deviceIdentifier = peripheral.address,
                    char = characteristic
                )
            val streamHandler = monitorCharacteristicStreamHandlers[key]
            streamHandler?.onCharacteristicsUpdate(
                peripheral,
                characteristic.service.uuid.toString(),
                characteristic
            )
            return
        }

        val dc = discoveredCharacteristicFor(characteristic = characteristic)
        if (dc == null) {
            return
        }

        val res = if (status == GattStatus.SUCCESS) {
            Result.success(characteristic)
        } else {
            Result.failure(
                BleError(
                    errorCode = BleErrorCode.CharacteristicReadFailed,
                    androidCode = status.value,
                    reason = status.toString(),
                    deviceID = peripheral.address,
                    serviceUUID = characteristic.service.uuid.toString(),
                    characteristicUUID = characteristic.uuid.toString()
                )
            )
        }
        dc.onReadCompleted(res)
    }

    override fun onCharacteristicWrite(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
        val dc = discoveredCharacteristicFor(characteristic = characteristic)
        if (dc == null) {
            return
        }

        val res = if (status == GattStatus.SUCCESS) {
            Result.success(characteristic)
        } else {
            Result.failure(
                BleError(
                    errorCode = BleErrorCode.CharacteristicReadFailed,
                    androidCode = status.value,
                    reason = status.toString(),
                    deviceID = peripheral.address,
                    serviceUUID = characteristic.service.uuid.toString(),
                    characteristicUUID = characteristic.uuid.toString()
                )
            )
        }
        dc.onWriteCompleted(res)
    }

    override fun onDescriptorRead(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        descriptor: BluetoothGattDescriptor,
        status: GattStatus
    ) {
        val res = if (status == GattStatus.SUCCESS) {
            Result.success(descriptor)
        } else {
            Result.failure(
                BleError(
                    errorCode = BleErrorCode.DescriptorWriteFailed,
                    androidCode = status.value,
                    reason = status.toString(),
                    deviceID = peripheral.address,
                    serviceUUID = descriptor.characteristic.service.uuid.toString(),
                    characteristicUUID = descriptor.characteristic.uuid.toString(),
                    descriptorUUID = descriptor.uuid.toString()
                )
            )
        }
        descriptorReadCompleted(res)
    }

    override fun onDescriptorWrite(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        descriptor: BluetoothGattDescriptor,
        status: GattStatus
    ) {
        val res = if (status == GattStatus.SUCCESS) {
            Result.success(descriptor)
        } else {
            Result.failure(
                BleError(
                    errorCode = BleErrorCode.DescriptorReadFailed,
                    androidCode = status.value,
                    reason = status.toString(),
                    deviceID = peripheral.address,
                    serviceUUID = descriptor.characteristic.service.uuid.toString(),
                    characteristicUUID = descriptor.characteristic.uuid.toString(),
                    descriptorUUID = descriptor.uuid.toString()
                )
            )
        }
        descriptorWriteCompleted(res)
    }

    override fun onBondingStarted(peripheral: BluetoothPeripheral) {

    }

    override fun onBondingSucceeded(peripheral: BluetoothPeripheral) {

    }

    override fun onBondingFailed(peripheral: BluetoothPeripheral) {

    }

    override fun onBondLost(peripheral: BluetoothPeripheral) {

    }

    override fun onReadRemoteRssi(peripheral: BluetoothPeripheral, rssi: Int, status: GattStatus) {
        val res = if (status == GattStatus.SUCCESS) {
            Result.success(rssi)
        } else {
            Result.failure(
                BleError(
                    errorCode = BleErrorCode.DeviceRSSIReadFailed,
                    androidCode = status.value,
                    reason = status.toString()
                )
            )
        }
        remoteRssiReadComleted(res)
    }

    override fun onMtuChanged(
        peripheral: BluetoothPeripheral,
        mtu: Int,
        status: GattStatus
    ) {
        val res = if (status == GattStatus.SUCCESS) {
            Result.success(mtu)
        } else {
            Result.failure(
                BleError(
                    errorCode = BleErrorCode.DeviceMTUChangeFailed,
                    androidCode = status.value,
                    reason = status.toString()
                )
            )
        }
        requestMtuCompleted(res)
    }

    override fun onPhyUpdate(
        peripheral: BluetoothPeripheral,
        txPhy: PhyType,
        rxPhy: PhyType,
        status: GattStatus
    ) {

    }

    override fun onConnectionUpdated(
        peripheral: BluetoothPeripheral,
        interval: Int,
        latency: Int,
        timeout: Int,
        status: GattStatus
    ) {

    }
    //endregion
}