//
//  EventChannel.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 13/05/2021.
//

import Foundation
import CoreBluetooth

private let base = "flutter_ble_lib"

class StateChanges : EventChannel, EventSinker {
  typealias SinkableT = Int
  static let baseName = "\(base)/stateChanges"
  func sink(_ rawState: Int) {
    let stateStr: String
    if #available(iOS 10, *) {
      switch CBManagerState(rawValue: rawState) {
      case .resetting?:
        stateStr = "Resetting"
      case .unsupported:
        stateStr = "Unsupported"
      case .unauthorized:
        stateStr = "Unauthorized"
      case .poweredOff:
        stateStr = "PoweredOff"
      case .poweredOn:
        stateStr = "PoweredOn"
      case .unknown, .none:
        fallthrough
      @unknown default:
        stateStr = "Unknown"
      }
    } else {
      switch CBCentralManagerState(rawValue: rawState) {
      case .resetting:
        stateStr = "Resetting"
      case .unsupported:
        stateStr = "Unsupported"
      case .unauthorized:
        stateStr = "Unauthorized"
      case .poweredOff:
        stateStr = "PoweredOff"
      case .poweredOn:
        stateStr = "PoweredOn"
      case .unknown, .none:
        fallthrough
      @unknown default:
        stateStr = "Unknown"
      }
    }
    _sink(string: stateStr)
  }
}

class StateRestoreEvents : EventChannel, EventSinker {
  typealias SinkableT = [PeripheralResponse]
  static let baseName = "\(base)/stateRestoreEvents"
  func sink(_ obj: [PeripheralResponse]) {
    _sink(encodable: obj)
  }
}

class ScanningEvents : EventChannel, EventSinker {
  typealias SinkableT = ScanResultEvent
  static let baseName = "\(base)/scanningEvents"
  func sink(_ obj: ScanResultEvent) {
    _sink(encodable: obj)
  }
}

class ConnectionStateChangeEvents : EventChannel, EventSinker {
  typealias SinkableT = CBPeripheralState
  static let baseName = "\(base)/connectionStateChangeEvents"
  func sink(_ state: CBPeripheralState) {
    let stateStr: String
    switch state {
    case .connected:
      stateStr = "connected"
    case .connecting:
      stateStr = "connecting"
    case .disconnected:
      stateStr = "disconnected"
    case .disconnecting:
      stateStr = "disconnecting"
    @unknown default:
      stateStr = "disconnected"
    }
    _sink(string: stateStr)
  }
}

class MonitorCharacteristic : EventChannel, EventSinker {
  typealias SinkableT = SingleCharacteristicWithValueResponse
  static let baseName = "\(base)/monitorCharacteristic"
  func sink(_ obj: SingleCharacteristicWithValueResponse) {
    _sink(encodable: obj)
  }
}
