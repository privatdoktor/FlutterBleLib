package hu.privatdoktor.flutter_ble_lib

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import kotlinx.coroutines.CompletableDeferred
import java.lang.ref.WeakReference

class DiscoveredDescriptor(
    discoveredCharacteristic : DiscoveredCharacteristic,
    val descriptor: BluetoothGattDescriptor
) {
    private var _discoveredCharacteristic: WeakReference<DiscoveredCharacteristic?>
    private val discoveredCharacteristic get() = _discoveredCharacteristic.get()

    private var onDescriptorReadCompleter: CompletableDeferred<BluetoothGattDescriptor>? = null
    private var onDescriptorWriteCompleter: CompletableDeferred<BluetoothGattDescriptor>? = null

    init {
        _discoveredCharacteristic = WeakReference(discoveredCharacteristic)
    }

    //region API

    suspend fun read() : BluetoothGattDescriptor {
        val peripheral = discoveredCharacteristic?.discoveredPeripheral?.peripheral
        if (peripheral == null) {
            throw BleError(
                errorCode = BleErrorCode.CharacteristicReadFailed,
                deviceID = peripheral?.address,
                serviceUUID = descriptor.characteristic.service.uuid.toString(),
                characteristicUUID = descriptor.characteristic.uuid.toString(),
                descriptorUUID = descriptor.uuid.toString()
            )
        }

        val pending = onDescriptorReadCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.CharacteristicReadFailed,
                    deviceID = discoveredCharacteristic?.discoveredPeripheral?.peripheral?.address,
                    serviceUUID = descriptor.characteristic.service.uuid.toString(),
                    characteristicUUID = descriptor.characteristic.uuid.toString(),
                    descriptorUUID = descriptor.uuid.toString()
                )
            )
        }
        val completer = CompletableDeferred<BluetoothGattDescriptor>()
        onDescriptorReadCompleter = completer
        val succ = peripheral.readDescriptor(descriptor)
        if (succ == false) {
            throw BleError(
                errorCode = BleErrorCode.CharacteristicReadFailed,
                serviceUUID = descriptor.characteristic.service.uuid.toString(),
                characteristicUUID = descriptor.characteristic.uuid.toString(),
                descriptorUUID = descriptor.uuid.toString(),
                reason = "peripheral.readDescriptor() failed, maybe device is not connected"
            )
        }
        return completer.await()
    }

    suspend fun write(value: ByteArray) : BluetoothGattDescriptor {
        val peripheral = discoveredCharacteristic?.discoveredPeripheral?.peripheral
        if (peripheral == null) {
            throw BleError(
                errorCode = BleErrorCode.CharacteristicReadFailed,
                deviceID = peripheral?.address,
                serviceUUID = descriptor.characteristic.service.uuid.toString(),
                characteristicUUID = descriptor.characteristic.uuid.toString(),
                descriptorUUID = descriptor.uuid.toString()
            )
        }

        val pending = onDescriptorWriteCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.DescriptorWriteFailed,
                    deviceID = peripheral.address,
                    serviceUUID = descriptor.characteristic.service.uuid.toString(),
                    characteristicUUID = descriptor.characteristic.uuid.toString(),
                    descriptorUUID = descriptor.uuid.toString()
                )
            )
        }

        val completer = CompletableDeferred<BluetoothGattDescriptor>()
        onDescriptorWriteCompleter = completer

        val succ = peripheral.writeDescriptor(descriptor, value)
        if (succ == false) {
            onDescriptorWriteCompleter = null
            throw BleError(
                errorCode = BleErrorCode.DescriptorWriteFailed,
                deviceID = peripheral.address,
                serviceUUID = descriptor.characteristic.service.uuid.toString(),
                characteristicUUID = descriptor.characteristic.uuid.toString(),
                descriptorUUID = descriptor.uuid.toString(),
                reason = "peripheral.writeDescriptor() failed, maybe device is not connected"
            )
        }
        return completer.await()
    }

    //endregion

    //region For Publishers

    fun onReadCompleted(newDescriptor: Result<BluetoothGattDescriptor>) {
        newDescriptor.fold(
            onSuccess = {
                onDescriptorReadCompleter?.complete(it)
            },
            onFailure = {
                onDescriptorReadCompleter?.completeExceptionally(it)
            }
        )
    }

    fun onWriteCompleted(newDescriptor: Result<BluetoothGattDescriptor>) {
        newDescriptor.fold(
            onSuccess = {
                onDescriptorWriteCompleter?.complete(it)
            },
            onFailure = {
                onDescriptorWriteCompleter?.completeExceptionally(it)
            }
        )
    }
    //endregion
}