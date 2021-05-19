//
//  CallHandler.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 19/05/2021.
//

import Foundation

extension Client : CallHandler {
  func handle(call: Method.Call<SignatureEnumT>) {
    switch call.signature {
    case .isClientCreated:
      call.result(isCreated)
    case .createClient(let restoreId, let showPowerAlert):
      create(restoreId: restoreId, showPowerAlert: showPowerAlert)
      call.result()
    case .destroyClient:
      destroy()
      call.result()
    case .cancelTransaction(let transactionId):
      cancelTransaction(transactionId: transactionId)
      call.result()
    case .getState:
      call.result(state)
    case .enableRadio:
      noop()
      call.result()
    case .disableRadio:
      noop()
      call.result()
    case .startDeviceScan(let uuids, let allowDuplicates):
      startDeviceScan(withServices: uuids, allowDuplicates: allowDuplicates)
      call.result()
    case .stopDeviceScan:
      stopDeviceScan()
      call.result()
    case .connectToDevice(let id, let timoutMillis):
      connectToDevice(id: id, timoutMillis: timoutMillis) { res in
        call.result(res)
      }
    case .isDeviceConnected(let id):
      call.result(isDeviceConnected(id: id))
    case .observeConnectionState(let deviceIdentifier, let emitCurrentValue):
      let res = observeConnectionState(
        deviceIdentifier: deviceIdentifier,
        emitCurrentValue: emitCurrentValue
      )
      call.result(res)
    case .cancelConnection(let deviceIdentifier):
      cancelConnection(deviceIdentifier: deviceIdentifier) { res in
        call.result(res)
      }
    case .discoverAllServicesAndCharacteristics(let deviceIdentifier,
                                                let transactionId):
      discoverAllServicesAndCharacteristics(
        deviceIdentifier: deviceIdentifier,
        transactionId: transactionId
      ) { res in
        call.result(res)
      }
    case .services(let deviceIdentifier):
      let serResps = services(for: deviceIdentifier)
      call.result(encodable: serResps)
    case .characteristics(let deviceIdentifier,
                          let serviceUUID):
      let res = characteristics(
        for: deviceIdentifier,
        serviceUUID: serviceUUID
      )
      call.result(encodable: res)
    case .characteristicsForService(let serviceNumericId):
      let res = characteristics(for: Int(serviceNumericId))
      call.result(encodable: res)
    case .descriptorsForDevice(let deviceIdentifier,
                               let serviceUUID,
                               let characteristicUUID):
      let res =
        descriptorsForDevice(
          for: deviceIdentifier,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID
        )
      call.result(encodable: res)
    case .descriptorsForService(let serviceNumericId,
                                let characteristicUUID):
      let res =
        descriptorsForService(
          serviceNumericId: Int(serviceNumericId),
          characteristicUUID: characteristicUUID
        )
      call.result(encodable: res)
    case .descriptorsForCharacteristic(let characteristicNumericId):
      let res =
        descriptorsForCharacteristic(
          characteristicNumericId: Int(characteristicNumericId)
        )
      call.result(encodable: res)
    case .logLevel:
      call.result(logLevel)
    case .setLogLevel(let level):
      logLevel = level
      call.result()
    case .rssi(let deviceIdentifier,
               let transactionId):
      readRssi(for: deviceIdentifier,
               transactionId: transactionId) { res in
        call.result(res)
      }
    case .requestMtu(let deviceIdentifier, _, _):
      call.result(requestMtu(for: deviceIdentifier))
    case .getConnectedDevices(let serviceUUIDs):
      let res = connectedDevices(serviceUUIDs: serviceUUIDs)
      call.result(encodable: res)
    case .getKnownDevices(let deviceIdentifiers):
      let res = knownDevices(deviceIdentifiers: deviceIdentifiers)
      call.result(encodable: res)
    case .readCharacteristicForIdentifier(let characteristicNumericId,
                                          let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .readCharacteristicForDevice(let deviceIdentifier,
                                      let serviceUUID,
                                      let characteristicUUID,
                                      let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .readCharacteristicForService(let serviceNumericId,
                                       let characteristicUUID,
                                       let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .writeCharacteristicForIdentifier(let characteristicNumericId,
                                           let value,
                                           let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .writeCharacteristicForDevice(let deviceIdentifier,
                                       let serviceUUID,
                                       let characteristicUUID,
                                       let value,
                                       let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .writeCharacteristicForService(let serviceNumericId,
                                        let characteristicUUID,
                                        let value,
                                        let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .monitorCharacteristicForIdentifier(let characteristicNumericId,
                                             let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .monitorCharacteristicForDevice(let deviceIdentifier,
                                         let serviceUUID,
                                         let characteristicUUID,
                                         let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .monitorCharacteristicForService(let serviceNumericId,
                                          let characteristicUUID,
                                          let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .readDescriptorForIdentifier(let descriptorNumericId,
                                      let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .readDescriptorForCharacteristic(let characteristicNumericId,
                                          let descriptorUUID,
                                          let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .readDescriptorForService(let serviceNumericId,
                                   let characteristicUUID,
                                   let descriptorUUID,
                                   let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .readDescriptorForDevice(let deviceIdentifier,
                                  let serviceUUID,
                                  let characteristicUUID,
                                  let descriptorUUID,
                                  let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .writeDescriptorForIdentifier(let descriptorNumericId,
                                       let value,
                                       let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .writeDescriptorForCharacteristic(let characteristicNumericId,
                                           let descriptorUUID,
                                           let value,
                                           let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .writeDescriptorForService(let serviceNumericId,
                                    let characteristicUUID,
                                    let descriptorUUID,
                                    let value,
                                    let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    case .writeDescriptorForDevice(let deviceIdentifier,
                                   let serviceUUID,
                                   let characteristicUUID,
                                   let descriptorUUID,
                                   let value,
                                   let transactionId):
      call.result(any: FlutterMethodNotImplemented)
    }
  }
}
