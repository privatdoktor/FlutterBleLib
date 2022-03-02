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
    private var centralManager: WeakReference<BluetoothCentralManager?>
    val streamHandler = ConnectionStateStreamHandler(binding.binaryMessenger, peripheral.address)

    private var _connectCompleted: ((Result<Unit>) -> Unit)? = null
    private var _disconnectCompleted: ((Result<Unit>) -> Unit)? = null
    private var _onDisconnectedListeners: Queue<() -> Unit> = LinkedList()
    private var _servicesDiscoveryCompleted:((Result<Map<UUID, BluetoothGattService>>) -> Unit)? = null
    private var _onRemoteRssiReadCompleted: ((Result<Int>) -> Unit)? = null
    private var _onRequestMtuCompleted: ((Result<Int>) -> Unit)? = null

    private var _onCharacteristicReadCompleted: ((Result<BluetoothGattCharacteristic>) -> Unit)? = null
    private var _onCharacteristicWriteCompleted: ((Result<BluetoothGattCharacteristic>) -> Unit)? = null

    private val monitorCharacteristicStreamHandlers = HashMap<String, CharacteristicsMonitorStreamHandler>()

    private var _onDescriptorReadCompleted: ((Result<BluetoothGattDescriptor>) -> Unit)? = null
    private var _onDescriptorWriteCompleted: ((Result<BluetoothGattDescriptor>) -> Unit)? = null


    init {
        this.centralManager = WeakReference(centralManager)
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

        centralManager.get()?.connectPeripheral(peripheral, this)
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
        centralManager.get()?.cancelConnection(peripheral)
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

    fun readCharacteristic(
        char: BluetoothGattCharacteristic,
        completion: (Result<BluetoothGattCharacteristic>) -> Unit
    ) {
        val pending = _onCharacteristicReadCompleted
        if (pending != null) {
            _onCharacteristicReadCompleted = null
            pending(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicReadFailed,
                        deviceID = peripheral.address,
                        serviceUUID = char.service.uuid.toString(),
                        characteristicUUID = char.uuid.toString(),
                    )
                )
            )
        }
        _onCharacteristicReadCompleted = completion
        val succ = peripheral.readCharacteristic(char)
        if (succ == false) {
            _onCharacteristicReadCompleted = null
            completion(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicReadFailed,
                        serviceUUID = char.service.uuid.toString(),
                        characteristicUUID = char.uuid.toString(),
                        reason = "peripheral.readCharacteristic() failed, maybe device is not connected"
                    )
                )
            )
        }

    }

    fun writeCharacteristic(
        char: BluetoothGattCharacteristic,
        value: ByteArray,
        withResponse: Boolean,
        completion: (Result<BluetoothGattCharacteristic>) -> Unit
    ) {
        val pending = _onCharacteristicWriteCompleted
        if (pending != null) {
            _onCharacteristicWriteCompleted = null
            pending(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicWriteFailed,
                        deviceID = peripheral.address,
                        serviceUUID = char.service.uuid.toString(),
                        characteristicUUID = char.uuid.toString(),
                    )
                )
            )
        }
        _onCharacteristicWriteCompleted = completion
        val type = if (withResponse) {
            WriteType.WITH_RESPONSE
        } else {
            WriteType.WITHOUT_RESPONSE
        }
        val succ = peripheral.writeCharacteristic(char, value, type)
        if (succ == false) {
            _onCharacteristicWriteCompleted = null
            completion(
                Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicWriteFailed,
                        serviceUUID = char.service.uuid.toString(),
                        characteristicUUID = char.uuid.toString(),
                        reason = "peripheral.writeCharacteristic() failed, maybe device is not connected"
                    )
                )
            )
        }

    }

    fun monitorCharacteristic(
        serviceUuid: String,
        characteristicUuid: String,
        completion: (Result<String>) -> Unit
    ) {
        val characteristic = peripheral.getService(
            UUID.fromString(serviceUuid)
        )?.getCharacteristic(
            UUID.fromString(characteristicUuid)
        )
        if (characteristic == null) {
            completion(
                Result.failure(BleError.characteristicNotFound(characteristicUuid))
            )
            return
        }


        val streamHandler =
            CharacteristicsMonitorStreamHandler(
                binaryMessenger = binding.binaryMessenger,
                deviceIdentifier = peripheral.address,
                serviceUuid = serviceUuid,
                characteristicUuid = characteristicUuid,
            )
        val key = streamHandler.name
        monitorCharacteristicStreamHandlers[key] = streamHandler
        streamHandler.afterCancelDo {
            monitorCharacteristicStreamHandlers.remove(key)
            if (peripheral.isNotifying(characteristic)) {
                peripheral.setNotify(characteristic, false)
            }
        }
        onDisconnected {
            streamHandler.end()
            monitorCharacteristicStreamHandlers.remove(key)
        }
        if (peripheral.isNotifying(characteristic) == false) {
            val succ = peripheral.setNotify(characteristic, true)
            if (succ == false) {
                completion(Result.failure(
                    BleError(
                        errorCode = BleErrorCode.CharacteristicNotifyChangeFailed,
                        serviceUUID = characteristic.service.uuid.toString(),
                        characteristicUUID = characteristic.uuid.toString(),
                        reason = "peripheral.monitorCharacteristic() failed, maybe device is not connected"
                    )
                ))
                return
            }
        }
        completion(Result.success(key))
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

    fun connectionStateChange() {
        streamHandler.onNewConnectionState(peripheral.state)
    }

    private fun remoteRssiReadComleted(res: Result<Int>) {
        _onRemoteRssiReadCompleted?.invoke(res)
        _onRemoteRssiReadCompleted = null
    }

    private fun requestMtuCompleted(res: Result<Int>) {
        _onRequestMtuCompleted?.invoke(res)
        _onRequestMtuCompleted = null
    }

    private fun characteristicReadCompleted(res: Result<BluetoothGattCharacteristic>) {
        _onCharacteristicReadCompleted?.invoke(res)
        _onCharacteristicReadCompleted = null
    }

    private fun characteristicWriteCompleted(res: Result<BluetoothGattCharacteristic>) {
        _onCharacteristicWriteCompleted?.invoke(res)
        _onCharacteristicWriteCompleted = null
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
        servicesDiscoveredCompleted(peripheral = peripheral)
    }

    override fun onNotificationStateUpdate(
        peripheral: BluetoothPeripheral,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
        val key =
            "${ChannelName.MONITOR_CHARACTERISTIC}/${characteristic.service.uuid.toString()}/${characteristic.uuid.toString()}"
        val streamHandler = monitorCharacteristicStreamHandlers[key]
        print("DiscoveredPeripheral::onNotificationStateUpdate: streamhandler exists: ${streamHandler != null}}")

        if (peripheral.isNotifying(characteristic)) {
            print("DiscoveredPeripheral::onNotificationStateUpdate: isNotifying: true for char: ${characteristic.uuid.toString()}")
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
                "${ChannelName.MONITOR_CHARACTERISTIC}/${characteristic.service.uuid.toString()}/${characteristic.uuid.toString()}"
            val streamHandler = monitorCharacteristicStreamHandlers[key]
            streamHandler?.onCharacteristicsUpdate(
                peripheral,
                characteristic.service.uuid.toString(),
                characteristic
            )
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
        characteristicReadCompleted(res)
    }

    override fun onCharacteristicWrite(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
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
        characteristicWriteCompleted(res)
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