package hu.privatdoktor.flutter_ble_lib

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import com.welie.blessed.*
import hu.privatdoktor.flutter_ble_lib.event.ConnectionStateStreamHandler
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.lang.ref.WeakReference


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

    init {
        this.centralManager = WeakReference(centralManager)
    }

    fun updateInternalPeripheral(peripheral: BluetoothPeripheral) {
        _peripheral = peripheral
    }

    //region API
    fun connect(completion: (Result<Unit>) -> Unit) {
        val pending = _connectCompleted
        if (pending != null) {
            _connectCompleted = null
            pending(
                Result.failure(
                    BleError(errorCode = BleErrorCode.DeviceConnectionFailed)
                )
            )
        }
        _connectCompleted = completion
        centralManager.get()?.connectPeripheral(peripheral, this)
    }

    //region For Publishers

    fun connected(res: Result<Unit>) {
//        if case .success = res {
//            _connectionEventOccured?(.peerConnected)
//        }
        _connectCompleted?.invoke(res)
        _connectCompleted = null
    }

    fun connectionStateChange() {
        streamHandler.onNewConnectionState(peripheral.state)
    }

    //region Helpers

    //region Callbacks

    override fun onServicesDiscovered(peripheral: BluetoothPeripheral) {}

    override fun onNotificationStateUpdate(
        peripheral: BluetoothPeripheral,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {

    }

    override fun onCharacteristicUpdate(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
    }

    override fun onCharacteristicWrite(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        characteristic: BluetoothGattCharacteristic,
        status: GattStatus
    ) {
    }


    override fun onDescriptorRead(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        descriptor: BluetoothGattDescriptor,
        status: GattStatus
    ) {
    }

    override fun onDescriptorWrite(
        peripheral: BluetoothPeripheral,
        value: ByteArray,
        descriptor: BluetoothGattDescriptor,
        status: GattStatus
    ) {
    }

    override fun onBondingStarted(peripheral: BluetoothPeripheral) {}

    override fun onBondingSucceeded(peripheral: BluetoothPeripheral) {}

    override fun onBondingFailed(peripheral: BluetoothPeripheral) {}

    override fun onBondLost(peripheral: BluetoothPeripheral) {}

    override fun onReadRemoteRssi(peripheral: BluetoothPeripheral, rssi: Int, status: GattStatus) {}

    override fun onMtuChanged(peripheral: BluetoothPeripheral, mtu: Int, status: GattStatus) {}

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
}