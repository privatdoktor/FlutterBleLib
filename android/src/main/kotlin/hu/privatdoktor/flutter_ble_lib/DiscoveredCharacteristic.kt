package hu.privatdoktor.flutter_ble_lib

import android.bluetooth.BluetoothGattCharacteristic
import com.welie.blessed.BluetoothCentralManager
import com.welie.blessed.WriteType
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.cancel
import kotlinx.coroutines.withTimeout
import java.lang.ref.WeakReference
import kotlin.time.Duration

class DiscoveredCharacteristic(
    discoveredPeripheral: DiscoveredPeripheral,
    val characteristic: BluetoothGattCharacteristic
) {
    companion object {
        fun uniqueKeyFor(char: BluetoothGattCharacteristic) : String {
            return uniqueKeyFor(
                serviceUuidStr = char.service.uuid.toString(),
                characteristicUuidStr = char.uuid.toString()
            )
        }
        fun uniqueKeyFor(serviceUuidStr: String, characteristicUuidStr: String) : String {
            return "${serviceUuidStr.lowercase()}/${characteristicUuidStr.lowercase()}"
        }
    }
    private var _discoveredPeripheral: WeakReference<DiscoveredPeripheral?>
    private val discoveredPeripheral get() = _discoveredPeripheral.get()

    private var readCharacteristicCompleter: CompletableDeferred<BluetoothGattCharacteristic>? = null
    private var writeCharacteristicCompleter: CompletableDeferred<BluetoothGattCharacteristic>? = null

    private var setNotifyCompleter: CompletableDeferred<Unit>? = null


    init {
        _discoveredPeripheral = WeakReference(discoveredPeripheral)
    }

    //region API

    suspend fun read() : BluetoothGattCharacteristic {
        val dp = discoveredPeripheral
        if (dp == null) {
            throw BleError(
                errorCode = BleErrorCode.CharacteristicReadFailed,
                deviceID = discoveredPeripheral?.peripheral?.address ?: "",
                serviceUUID = characteristic.service.uuid.toString(),
                characteristicUUID = characteristic.uuid.toString(),
            )
        }

        val pending = readCharacteristicCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.CharacteristicReadFailed,
                    deviceID = discoveredPeripheral?.peripheral?.address ?: "",
                    serviceUUID = characteristic.service.uuid.toString(),
                    characteristicUUID = characteristic.uuid.toString(),
                )
            )
        }

        val completer = CompletableDeferred<BluetoothGattCharacteristic>()
        readCharacteristicCompleter = completer

        val succ = dp.peripheral.readCharacteristic(characteristic)
        if (succ == false) {
            readCharacteristicCompleter = null
            throw BleError(
                errorCode = BleErrorCode.CharacteristicReadFailed,
                serviceUUID = characteristic.service.uuid.toString(),
                characteristicUUID = characteristic.uuid.toString(),
                reason = "peripheral.readCharacteristic() failed, maybe device is not connected"
            )
        }
        return withTimeout(timeMillis = 2 * 2000) {
            completer.await()
        }
    }

    suspend fun writeCharacteristic(
        char: BluetoothGattCharacteristic,
        value: ByteArray,
        withResponse: Boolean,
    ) : BluetoothGattCharacteristic {
        val dp = discoveredPeripheral
        if (dp == null) {
            throw BleError(
                errorCode = BleErrorCode.CharacteristicReadFailed,
                deviceID = discoveredPeripheral?.peripheral?.address ?: "",
                serviceUUID = characteristic.service.uuid.toString(),
                characteristicUUID = characteristic.uuid.toString(),
            )
        }

        val pending = writeCharacteristicCompleter
        if (pending != null && pending.isActive) {
            pending.completeExceptionally(
                BleError(
                    errorCode = BleErrorCode.CharacteristicReadFailed,
                    deviceID = discoveredPeripheral?.peripheral?.address ?: "",
                    serviceUUID = characteristic.service.uuid.toString(),
                    characteristicUUID = characteristic.uuid.toString(),
                )
            )
        }
        val newChar = if (withResponse) {
            val completer = CompletableDeferred<BluetoothGattCharacteristic>()
            writeCharacteristicCompleter = completer

            val succ = dp.peripheral.writeCharacteristic(
                characteristic,
                value,
                WriteType.WITH_RESPONSE
            )
            if (succ == false) {
                writeCharacteristicCompleter = null
                throw BleError(
                    errorCode = BleErrorCode.CharacteristicWriteFailed,
                    serviceUUID = char.service.uuid.toString(),
                    characteristicUUID = char.uuid.toString(),
                    reason = "peripheral.writeCharacteristic() failed, maybe device is not connected"
                )
            }
            withTimeout(timeMillis = 2 * 1000) {
                completer.await()
            }
        } else {
            writeCharacteristicCompleter = null
            val succ = dp.peripheral.writeCharacteristic(
                characteristic,
                value,
                WriteType.WITHOUT_RESPONSE
            )
            if (succ == false) {
                throw BleError(
                    errorCode = BleErrorCode.CharacteristicWriteFailed,
                    serviceUUID = char.service.uuid.toString(),
                    characteristicUUID = char.uuid.toString(),
                    reason = "peripheral.writeCharacteristic() failed, maybe device is not connected"
                )
            }
            characteristic
        }
        return newChar
    }

    suspend fun setNotify(enable: Boolean) {
        val pending = setNotifyCompleter
        if (pending != null && pending.isActive) {
            val reason = "DiscoveredCharacteristic:: pending setNotify() cancelled"
            pending.cancel(
                message = reason,
                cause = BleError(
                    BleErrorCode.CharacteristicNotifyChangeFailed,
                    reason = reason
                )
            )
        }
        val completer = CompletableDeferred<Unit>()
        setNotifyCompleter = completer

        withTimeout(timeMillis = 2 * 1000) {
            completer.await()
        }

    }

    //endregion

    //region For Publishers

    fun onReadCompleted(newCharacteristic: Result<BluetoothGattCharacteristic>) {
        newCharacteristic.fold(
            onSuccess = {
                readCharacteristicCompleter?.complete(it)
            },
            onFailure = {
                readCharacteristicCompleter?.completeExceptionally(it)
            }
        )
    }

    fun onWriteCompleted(newCharacteristic: Result<BluetoothGattCharacteristic>) {
        newCharacteristic.fold(
            onSuccess = {
                writeCharacteristicCompleter?.complete(it)
            },
            onFailure = {
                writeCharacteristicCompleter?.completeExceptionally(it)
            }
        )
    }

    fun onSetNotifyChanged(enable: Result<Boolean>) {
        enable.fold(
            onSuccess = {
                setNotifyCompleter?.complete(Unit)
            },
            onFailure = {
                setNotifyCompleter?.completeExceptionally(it)
            }
        )


    }

    //endregion

}