//
//  CallHandler.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 19/05/2021.
//

import Foundation
import CoreBluetooth

extension Client : CallHandler {
  typealias SignatureEnumT = DefaultMethodChannel.Signature
  
  private func validate(
    call: Call<SignatureEnumT>
  ) -> Result<(),ClientError> {
    switch call.signature {
    case .isClientCreated,
         .createClient,
         .destroyClient,
         .cancelTransaction,
         .getState,
         .getAuthorization,
         .enableRadio,
         .disableRadio,
         .startDeviceScan,
         .stopDeviceScan,
         .setLogLevel,
         .logLevel:
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
    case .cancelTransaction(let transactionId):
      noop()
      call.result()
    case .getState:
      call.result(state)
    case .getAuthorization:
      call.result(authorization)
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
        scanningEvents = Client.Stream(eventHandler: { payload in
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
      let stream = Stream<ConnectionStateResponse>(eventHandler: { payload in
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
    case .discoverAllServicesAndCharacteristics(let deviceIdentifier):
      noop()
      call.result()
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
        descriptorsForDevice(
          for: deviceIdentifier,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID
        )
      call.result(encodable: res)
    case .logLevel:
      call.result(logLevel)
    case .setLogLevel(let level):
      logLevel = level
      call.result()
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
      readCharacteristicForDevice(
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
      writeCharacteristicForDevice(
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
        Client.Stream<SingleCharacteristicWithValueResponse>(
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
      }
      monitorCharacteristicForDevice(
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
