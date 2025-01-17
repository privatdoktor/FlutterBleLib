//
//  CallHandler.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 19/05/2021.
//

import Foundation
import CoreBluetooth

extension BluetoothCentralManager : CallHandler {
  typealias SignatureEnumT = DefaultMethodChannel.Signature
  
  private func validate(
    call: Call<SignatureEnumT>
  ) -> Result<(),BluetoothCentralManagerError> {
    switch call.signature {
    case .isClientCreated,
         .createClient,
         .destroyClient,
         .getState,
         .getAuthorization,
         .enableRadio,
         .disableRadio,
         .startDeviceScan,
         .stopDeviceScan:
      return .success(())
    default:
      guard centralManager?.state == .poweredOn else {
        return .failure(
          .invalidState(centralManager?.state)
        )
      }
      return .success(())
    }
  }
  
  func handle(
    call: Call<SignatureEnumT>,
    eventChannelFactory: EventChannelFactory
  ) {
    switch validate(call: call) {
    case .failure(let error):
      call.result(error: error)
      return
    case .success:
      break
    }
    
    switch call.signature {
    case .isClientCreated:
      call.result(isCreated)
    case .createClient(let restoreId, let showPowerAlert):
      create(restoreId: restoreId, showPowerAlert: showPowerAlert)
      call.result()
    case .destroyClient:
      destroy()
      call.result()
    case .getState:
      let stateStr: String
      let unknown = "Unknown"
      switch state {
      case .unknown: stateStr = unknown
      case .resetting: stateStr = "Resetting"
      case .unsupported: stateStr = "Unsupported"
      case .unauthorized: stateStr = "Unauthorized"
      case .poweredOff: stateStr = "PoweredOff"
      case .poweredOn: stateStr = "PoweredOn"
      @unknown default: stateStr = unknown
      }
      call.result(stateStr)
    case .getAuthorization:
      let authorizationStr: String
      if #available(iOS 13.0, *) {
        switch authorization {
        case .restricted:
          authorizationStr = "restricted"
        case .denied:
          authorizationStr = "denied"
        case .allowedAlways:
          authorizationStr = "allowedAlways"
        case .notDetermined:
          fallthrough
        @unknown default:
          authorizationStr = "notDetermined"
        }
      } else {
        authorizationStr = "allowedAlways"
      }
      
      call.result(authorizationStr)
    case .enableRadio:
      noop()
      call.result()
    case .disableRadio:
      noop()
      call.result()
    case .startDeviceScan(let uuids, let allowDuplicates):
      if scanningEvents == nil {
        let scanningSinker =
          eventChannelFactory.makeEventChannel(ScanningEvents.self, idScheme: .justBaseName)
        scanningEvents = BluetoothCentralManager.Stream(eventHandler: { payload in
          switch payload {
          case .data(let scanResult):
            scanningSinker.sink(scanResult)
          case .endOfStream:
            scanningSinker.end()
          }
        })
      }
      let res = startDeviceScan(withServices: uuids, allowDuplicates: allowDuplicates)
      call.result(res)
    case .stopDeviceScan:
      let res = stopDeviceScan()
      call.result(res)
    case .connectToDevice(let id, let timoutMillis):
      connectToDevice(id: id, timoutMillis: timoutMillis) { res in
        call.result(res)
      }
    case .isDeviceConnected(let id):
      call.result(isDeviceConnected(id: id))
    case .observeConnectionState(let deviceIdentifier, let emitCurrentValue):
      let sinker =
        eventChannelFactory.makeEventChannel(
          ConnectionStateChangeEvents.self
        )
      let sinkerName = sinker.name
      let stream = Stream<CBPeripheralState>(eventHandler: { payload in
        switch payload {
        case .data(let state):
          sinker.sink(state)
        case .endOfStream:
          sinker.end()
        }
      })
      
      let res = observeConnectionState(
        deviceIdentifier: deviceIdentifier,
        emitCurrentValue: emitCurrentValue,
        eventStream: stream
      )
      call.result(
        res.map({ sinkerName })
      )
    case .cancelConnection(let deviceIdentifier):
      cancelConnection(deviceIdentifier: deviceIdentifier) { res in
        call.result(res)
      }
    case .discoverServices(let deviceIdentifier,
                           let serviceUUIDStrs):
      discoverServices(
        deviceIdentifier: deviceIdentifier,
        serviceUUIDStrs: serviceUUIDStrs
      ) { res in
        call.result(encodable: res)
      }
    case .discoverCharacteristics(let deviceIdentifier,
                                  let serviceUuid,
                                  let characteristicUUIDStrs):
      discoverCharacteristics(
        deviceIdentifier: deviceIdentifier,
        serviceUuid: serviceUuid,
        characteristicUUIDStrs: characteristicUUIDStrs
      ) { res in
        call.result(encodable: res)
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
    case .descriptorsForDevice(let deviceIdentifier,
                               let serviceUUID,
                               let characteristicUUID):
      let res =
        descriptors(
          for: deviceIdentifier,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID
        )
      call.result(encodable: res)
    case .rssi(let deviceIdentifier):
      readRssi(for: deviceIdentifier) { res in
        call.result(res)
      }
    case .requestMtu(let deviceIdentifier, _):
      call.result(requestMtu(for: deviceIdentifier))
    case .getConnectedDevices(let serviceUUIDs):
      let res = connectedDevices(serviceUUIDs: serviceUUIDs)
      call.result(encodable: res)
    case .getKnownDevices(let deviceIdentifiers):
      let res = knownDevices(deviceIdentifiers: deviceIdentifiers)
      call.result(encodable: res)
    case .readCharacteristicForDevice(let deviceIdentifier,
                                      let serviceUUID,
                                      let characteristicUUID):
      readCharacteristic(
        deviceIdentifier: deviceIdentifier,
        serviceUUID: serviceUUID,
        characteristicUUID: characteristicUUID
      ) { res in
        call.result(encodable: res)
      }
    case .writeCharacteristicForDevice(let deviceIdentifier,
                                       let serviceUUID,
                                       let characteristicUUID,
                                       let value,
                                       let withResponse):
      writeCharacteristic(
        deviceIdentifier: deviceIdentifier,
        serviceUUID: serviceUUID,
        characteristicUUID: characteristicUUID,
        value: value, withResponse: withResponse
      ) { res in
        call.result(encodable: res)
      }
    case .monitorCharacteristicForDevice(let deviceIdentifier,
                                         let serviceUUID,
                                         let characteristicUUID):
      let sinker =
        eventChannelFactory.makeEventChannel(
          MonitorCharacteristic.self
        )
      let sinkerName = sinker.name
      let stream =
        BluetoothCentralManager.Stream<CharacteristicResponse>(
          eventHandler: { payload in
            switch payload {
            case .data(let charRes):
              sinker.sink(charRes)
            case .endOfStream:
              sinker.end()
            }
          }
        )
      sinker.afterCancelDo {
        eventChannelFactory.removeEventChannel(name: sinkerName)
        stream.afterCancelDo?()
      }
      monitorCharacteristic(
        deviceIdentifier: deviceIdentifier,
        serviceUUID: serviceUUID,
        characteristicUUID: characteristicUUID,
        eventSteam: stream
      ) { res in
        call.result(
          res.map({ sinkerName })
        )
      }
    case .readDescriptorForDevice(let deviceIdentifier,
                                  let serviceUUID,
                                  let characteristicUUID,
                                  let descriptorUUID):
      readDescriptorForDevice(
        deviceIdentifier: deviceIdentifier,
        serviceUUID: serviceUUID,
        characteristicUUID: characteristicUUID,
        descriptorUUID: descriptorUUID
      ) { res in
        call.result(encodable: res)
      }
    case .writeDescriptorForDevice(let deviceIdentifier,
                                   let serviceUUID,
                                   let characteristicUUID,
                                   let descriptorUUID,
                                   let value):
      writeDescriptorForDevice(
        deviceIdentifier: deviceIdentifier,
        serviceUUID: serviceUUID,
        characteristicUUID: characteristicUUID,
        descriptorUUID: descriptorUUID,
        value: value
      ) { res in
        call.result(encodable: res)
      }
    }
  }
}
