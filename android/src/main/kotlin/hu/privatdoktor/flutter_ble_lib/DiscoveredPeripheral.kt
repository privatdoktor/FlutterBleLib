package hu.privatdoktor.flutter_ble_lib

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import com.welie.blessed.*
import hu.privatdoktor.flutter_ble_lib.event.CharacteristicsMonitorStreamHandler
import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeout
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
    private val discoveredCharacteristics = HashMap<String, DiscoveredCharacteristic>()

    private val monitorCharacteristicStreamHandlers = HashMap<String, CharacteristicsMonitorStreamHandler>()

    private var connectCompleter: CompletableDeferred<Unit>? = null
    private var serviceDiscoveryCompleter: CompletableDeferred<Map<UUID, BluetoothGattService>>? = null

    private var disconnectCompleter: CompletableDeferred<Unit>? = null
    private var _onDisconnectedListeners: Queue<() -> Unit> = LinkedList()

    private var onRemoteRssiReadCompleter: CompletableDeferred<Int>? = null
    private var onRequestMtuCompleter: CompletableDeferred<Int>? = null

    private var onBondingStartedCompleter: CompletableDeferred<Unit>? = null
    private var onBondedCompleter: CompletableDeferred<Result<Unit>>? = null
    private var onBondingLostCompleter: CompletableDeferred<Unit>? = null

    init {
        _centralManager = WeakReference(centralManager)
    }

    fun updateInternalPeripheral(peripheral: BluetoothPeripheral) {
        _peripheral = peripheral
    }

    //region API
    suspend fun connect(
        requestMtu: Int?,
        refreshGatt: Boolean,
        timeoutMillis: Long?
    ) {
        val connectionTimeout = timeoutMillis ?: 60 * 1000
        val pending = connectCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
            )
        }
        val pendingServiceDiscovery = serviceDiscoveryCompleter
        if (pendingServiceDiscovery != null && pendingServiceDiscovery.isActive) {
            pendingServiceDiscovery.completeExceptionally(
                BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
            )
        }
        val connectCompleter = CompletableDeferred<Unit>()
        val serviceDiscoveryCompleter = CompletableDeferred<Map<UUID, BluetoothGattService>>()
        this.connectCompleter = connectCompleter
        this.serviceDiscoveryCompleter = serviceDiscoveryCompleter

        centralManager?.connectPeripheral(peripheral, this)
        withTimeout(timeMillis = connectionTimeout) {
            awaitAll(connectCompleter, serviceDiscoveryCompleter)
        }

        peripheral.requestConnectionPriority(ConnectionPriority.HIGH)
        if (requestMtu != null) {
            requestMtu(requestMtu, timeoutMillis = connectionTimeout)
        }
    }

    suspend fun disconnect() {
        val pending = disconnectCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
            )
        }
        val completer = CompletableDeferred<Unit>()
        disconnectCompleter = completer
        centralManager?.cancelConnection(peripheral)
        completer.await()
    }

    fun onDisconnected(listener: () -> Unit) {
        _onDisconnectedListeners.add(listener)
    }

    fun discoverServices(
        serviceUUIDs: List<UUID>? = null,
    ) : Map<UUID, BluetoothGattService> {
        return peripheral.services.associateBy { it.uuid }
    }

    suspend fun readRemoteRssi() : Int {
        val pending = onRemoteRssiReadCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.DeviceRSSIReadFailed,
                    deviceID = peripheral.address
                )
            )
        }
        val completer = CompletableDeferred<Int>()
        onRemoteRssiReadCompleter = completer
        val succ = peripheral.readRemoteRssi()
        if (succ == false) {
            onRemoteRssiReadCompleter = null
            throw BleError(
                errorCode = BleErrorCode.DeviceRSSIReadFailed,
                deviceID = peripheral.address,
                reason = "peripheral.readRemoteRssi() failed, maybe device is not connected"
            )
        }
        return completer.await()
    }

    suspend fun requestMtu(mtu: Int, timeoutMillis: Long = 60 * 1000) : Int {
        val pending = onRequestMtuCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.DeviceMTUChangeFailed,
                    deviceID = peripheral.address
                )
            )
        }
        val completer = CompletableDeferred<Int>()
        onRequestMtuCompleter = completer
        val succ = peripheral.requestMtu(mtu)
        if (succ == false) {
            onRequestMtuCompleter = null
            throw BleError(
                errorCode = BleErrorCode.DeviceMTUChangeFailed,
                deviceID = peripheral.address,
                reason = "peripheral.requestMtu() failed, maybe device is not connected"
            )
        }
        return withTimeout(timeMillis = timeoutMillis) {
            completer.await()
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
    //endregion

    //region For Publishers

    fun connected(res: Result<Unit>) {
        connectCompleter?.complete(Unit)
    }

    fun disconnected() {
        disconnectCompleter?.complete(Unit)

        while (_onDisconnectedListeners.isNotEmpty()) {
            _onDisconnectedListeners.poll()?.invoke()
        }
    }

    //endregion

    //region Callbacks
    override fun onServicesDiscovered(peripheral: BluetoothPeripheral) {
        for (service in peripheral.services) {
            for (char in service.characteristics) {
                discoveredCharacteristics[DiscoveredCharacteristic.uniqueKeyFor(char)] =
                    DiscoveredCharacteristic(discoveredPeripheral = this, characteristic = char)
            }
        }

        serviceDiscoveryCompleter?.complete(peripheral.services.associateBy { it.uuid })
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

        dc?.onSetNotifyChanged(
            Result.success(peripheral.isNotifying(characteristic))
        )

        val streamHandler = dc?.monitorStreamHandler
        println("DiscoveredPeripheral::onNotificationStateUpdate: streamhandler exists: ${streamHandler != null}}")
    }

    override fun onCharacteristicUpdate(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
        val dc = discoveredCharacteristicFor(characteristic = characteristic)
        if (dc == null) {
            return
        }

        if (peripheral.isNotifying(characteristic)) {
            dc.monitorStreamHandler?.onCharacteristicsUpdate(
                peripheral = peripheral,
                characteristic = characteristic
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
        val dd = discoveredCharacteristics[
            descriptor.characteristic.uuid.toString().lowercase()
        ]?.discoveredDescriptors?.get(
            descriptor.uuid.toString().lowercase()
        )

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
        dd?.onReadCompleted(res)
    }

    override fun onDescriptorWrite(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        descriptor: BluetoothGattDescriptor,
        status: GattStatus
    ) {
        val dd = discoveredCharacteristics[
            descriptor.characteristic.uuid.toString().lowercase()
        ]?.discoveredDescriptors?.get(
            descriptor.uuid.toString().lowercase()
        )

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
        dd?.onWriteCompleted(res)
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
        if (status == GattStatus.SUCCESS) {
            onRemoteRssiReadCompleter?.complete(rssi)
        } else {
            onRemoteRssiReadCompleter?.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.DeviceRSSIReadFailed,
                    androidCode = status.value,
                    reason = status.toString()
                )
            )
        }
    }

    override fun onMtuChanged(
        peripheral: BluetoothPeripheral,
        mtu: Int,
        status: GattStatus
    ) {
        if (status == GattStatus.SUCCESS) {
            onRequestMtuCompleter?.complete(mtu)
        } else {
            onRequestMtuCompleter?.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.DeviceMTUChangeFailed,
                    androidCode = status.value,
                    reason = status.toString()
                )
            )
        }
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