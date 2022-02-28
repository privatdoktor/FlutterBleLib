package hu.privatdoktor.flutter_ble_lib

import org.json.JSONObject


private interface Metadata {

}

enum class BleErrorCode(val code: Int) {
    UnknownError(0),
    BluetoothManagerDestroyed(1),
    OperationCancelled(2),
    OperationTimedOut(3),
    OperationStartFailed(4),
    InvalidIdentifiers(5),
    BluetoothUnsupported(100),
    BluetoothUnauthorized(101),
    BluetoothPoweredOff(102),
    BluetoothInUnknownState(103),
    BluetoothResetting(104),
    BluetoothStateChangeFailed(105),
    DeviceConnectionFailed(200),
    DeviceDisconnected(201),
    DeviceRSSIReadFailed(202),
    DeviceAlreadyConnected(203),
    DeviceNotFound(204),
    DeviceNotConnected(205),
    DeviceMTUChangeFailed(206),
    ServicesDiscoveryFailed(300),
    IncludedServicesDiscoveryFailed(301),
    ServiceNotFound(302),
    ServicesNotDiscovered(303),
    CharacteristicsDiscoveryFailed(400),
    CharacteristicWriteFailed(401),
    CharacteristicReadFailed(402),
    CharacteristicNotifyChangeFailed(403),
    CharacteristicNotFound(404),
    CharacteristicsNotDiscovered(405),
    CharacteristicInvalidDataFormat(406),
    DescriptorsDiscoveryFailed(500),
    DescriptorWriteFailed(501),
    DescriptorReadFailed(502),
    DescriptorNotFound(503),
    DescriptorsNotDiscovered(504),
    DescriptorInvalidDataFormat(505),
    DescriptorWriteNotAllowed(506),
    ScanStartFailed(600),
    LocationServicesDisabled(601);
}

class BleError(
    val errorCode: BleErrorCode,
    val reason: String? = null,
    val androidCode: Int? = null,
    val deviceID: String? = null,
    val serviceUUID: String? = null,
    val characteristicUUID: String? = null,
    val descriptorUUID: String? = null,
    val internalMessage: String? = null,
) : Throwable() {

    override val message: String
        get() = (
            "Error code: " + errorCode +
            ", android code: " + androidCode +
            ", reason" + reason +
            ", deviceId" + deviceID +
            ", serviceUuid" + serviceUUID +
            ", characteristicUuid" + characteristicUUID +
            ", descriptorUuid" + descriptorUUID +
            ", internalMessage" + internalMessage
        )

    fun toJsonString(): String {
        val root = JSONObject()
        root.put(
            ERROR_CODE,
            errorCode.code
        )
        if (androidCode == null || androidCode > MAX_ATT_ERROR || androidCode < 0) {
            root.put(
                ATT_ERROR_CODE,
                JSONObject.NULL
            )
        } else {
            root.put(
                ATT_ERROR_CODE,
                androidCode
            )
        }
        if (androidCode == null || androidCode <= MAX_ATT_ERROR) {
            root.put(
                ANDROID_ERROR_CODE,
                JSONObject.NULL
            )
        } else {
            root.put(
                ANDROID_ERROR_CODE,
                androidCode
            )
        }
        root.put(
            REASON,
            reason
        )
        root.put(
            DEVICE_ID,
            deviceID
        )
        root.put(
            SERVICE_UUID,
            serviceUUID
        )
        root.put(
            CHARACTERISTIC_UUID,
            characteristicUUID
        )
        root.put(
            DESCRIPTOR_UUID,
            descriptorUUID
        )
        root.put(
            INTERNAL_MESSAGE,
            internalMessage
        )
        return root.toString()
    }

    companion object {
        const val ERROR_CODE = "errorCode"
        const val ATT_ERROR_CODE = "attErrorCode"
        const val ANDROID_ERROR_CODE = "androidErrorCode"
        const val REASON = "reason"
        const val DEVICE_ID = "deviceID"
        const val SERVICE_UUID = "serviceUUID"
        const val CHARACTERISTIC_UUID = "characteristicUUID"
        const val DESCRIPTOR_UUID = "descriptorUUID"
        const val INTERNAL_MESSAGE = "internalMessage"
        const val TRANSACTION_ID = "transactionId"

        const val MAX_ATT_ERROR = 0x80

        fun cancelled(): BleError {
            return BleError(errorCode = BleErrorCode.OperationCancelled)
        }

        fun invalidIdentifiers(vararg identifiers: String): BleError {
            val identifiersJoined = StringBuilder()
            for (identifier in identifiers) {
                identifiersJoined.append(identifier).append(", ")
            }
            val bleError = BleError(
                errorCode =BleErrorCode.InvalidIdentifiers,
                internalMessage = identifiersJoined.toString()
            )
            return bleError
        }

        fun deviceNotFound(uuid: String?): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.DeviceNotFound,
                deviceID = uuid
            )
            return bleError
        }

        fun deviceNotConnected(uuid: String?): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.DeviceNotConnected,
                deviceID = uuid
            )
            return bleError
        }

        fun characteristicNotFound(uuid: String?): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.CharacteristicNotFound,
                characteristicUUID = uuid
            )
            return bleError
        }

        fun invalidWriteDataForCharacteristic(data: String?, uuid: String?): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.CharacteristicInvalidDataFormat,
                characteristicUUID = uuid,
                internalMessage = data
            )
            return bleError
        }

        fun descriptorNotFound(uuid: String?): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.DescriptorNotFound,
                descriptorUUID = uuid
            )
            return bleError
        }

        fun invalidWriteDataForDescriptor(data: String?, uuid: String?): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.DescriptorInvalidDataFormat,
                descriptorUUID = uuid,
                internalMessage = data
            )
            return bleError
        }

        fun descriptorWriteNotAllowed(uuid: String?): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.DescriptorWriteNotAllowed,
                descriptorUUID = uuid
            )
            return bleError
        }

        fun serviceNotFound(uuid: String?): BleError {
            val bleError = BleError(errorCode = BleErrorCode.ServiceNotFound, serviceUUID = uuid)
            return bleError
        }

        fun cannotMonitorCharacteristic(
            reason: String?,
            deviceID: String?,
            serviceUUID: String?,
            characteristicUUID: String?
        ): BleError {
            val bleError = BleError(
                errorCode = BleErrorCode.CharacteristicNotifyChangeFailed,
                reason = reason,
                deviceID = deviceID,
                serviceUUID = serviceUUID,
                characteristicUUID = characteristicUUID
            )
            return bleError
        }

        fun deviceServicesNotDiscovered(deviceID: String?): BleError? {
            val bleError = BleError(
                errorCode = BleErrorCode.ServicesNotDiscovered,
                deviceID = deviceID
            )
            return bleError
        }

    }
}
