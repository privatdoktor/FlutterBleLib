package hu.privatdoktor.flutter_ble_lib.event

import android.bluetooth.le.ScanResult
import android.os.Build
import android.util.Base64
import com.welie.blessed.BluetoothPeripheral
import hu.privatdoktor.flutter_ble_lib.ChannelName
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import org.json.JSONObject

class ScanningStreamHandler(
    binaryMessenger: BinaryMessenger
) : EventChannel.StreamHandler {
    private var scanResultsSink: EventSink? = null
    private val eventChannel = EventChannel(binaryMessenger, ChannelName.SCANNING_EVENTS)
    private var eventSink: EventSink? = null

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(o: Any?, eventSink: EventSink) {
        scanResultsSink = eventSink
    }

    override fun onCancel(o: Any?) {
        scanResultsSink = null
    }

    fun onScanResult(peripheral: BluetoothPeripheral, scanResult: ScanResult) {
        val scanResultsSink = this.scanResultsSink
        if (scanResultsSink == null) {
            return
        }
        val id = scanResult.device.address
        val name = peripheral.name
        val rssi = scanResult.rssi
        val mtu = peripheral.currentMtu

        val scanRecord = scanResult.scanRecord

        val localName = scanRecord?.deviceName
        val txPowerLevel: Int?
        val isConnectable: Boolean?
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            txPowerLevel = scanResult.txPower
            isConnectable = scanResult.isConnectable
        } else {
            txPowerLevel = null
            isConnectable = null
        }

        val manufacturerSpecificData = scanRecord?.manufacturerSpecificData
        val manufacturerData =
            if (manufacturerSpecificData != null && manufacturerSpecificData.size() > 0) {
                val manufacturerId = manufacturerSpecificData.keyAt(0)
                val manufacturerIdData = manufacturerSpecificData[manufacturerId]
                if (manufacturerIdData != null) {
                    val data = ByteArray(
                        size = manufacturerIdData.size + 2,
                        init = {
                            if (it == 0) {
                                (manufacturerId shr 0).toByte()
                            } else if (it == 1) {
                                (manufacturerId shr 8).toByte()
                            } else {
                                manufacturerIdData[it-2]
                            }
                        }
                    )
                    Base64.encodeToString(data, Base64.NO_WRAP)
                } else {
                    null
                }
            } else {
                null
            }

        val serviceUUIDs = scanRecord?.serviceUuids?.map { it.toString().lowercase() }
        val overflowServiceUUIDs = null
        val solicitedServiceUUIDs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            scanRecord?.serviceSolicitationUuids?.map { it.uuid.toString().lowercase() }
        } else {
            null
        }

        val serviceData = try { scanRecord?.serviceData?.mapKeys {
            it.key.toString()
        }?.mapValues {
            Base64.encodeToString(it.value, Base64.NO_WRAP)
        } } catch (e: Throwable) {
            print("ScanningStreamHandler::onScanResult: ${e.localizedMessage}")
            null
        }

        val payload = mapOf(
            "id" to id,
            "name" to name,
            "rssi" to rssi,
            "mtu" to mtu,

            "localName" to localName,
            "txPowerLevel" to txPowerLevel,
            "isConnectable" to isConnectable,

            "manufacturerData" to manufacturerData,

            "serviceUUIDs" to serviceUUIDs,
            "overflowServiceUUIDs" to overflowServiceUUIDs,
            "solicitedServiceUUIDs" to solicitedServiceUUIDs,

            "serviceData" to serviceData
        ).toMutableMap()

        try {
            val jsonStr = JSONObject(payload).toString()
            scanResultsSink.success(jsonStr)
        } catch (e: Throwable) {
            print("ScanningStreamHandler::onScanResult: ${e.localizedMessage}")
        }
    }
}