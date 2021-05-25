//
//  EventChannel.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 13/05/2021.
//

import Foundation
import Flutter
import CoreBluetooth

protocol EventSinker : NSObject {
  associatedtype SinkableT
  var messenger: FlutterBinaryMessenger { get }
  init(messenger: FlutterBinaryMessenger)
  func begin()
  func end()
  func sink(_ obj: SinkableT)
  func afterCancelDo(_ cleanUpClosure: @escaping () -> ())
}

class EventChannel : NSObject {
  private var flutterEventSink: FlutterEventSink?
  private var cleanUpClosure: (() -> ())?
  fileprivate var _ended = true
  
  let messenger: FlutterBinaryMessenger
  
  required init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
    begin()
  }
  
  func afterCancelDo(_ cleanUpClosure: @escaping () -> ()) {
    self.cleanUpClosure = cleanUpClosure
  }
  
  func begin() {}
  
  func end() {
    flutterEventSink?(FlutterEndOfEventStream)
    _ended = true
  }
  
  func _sink(error: FlutterError) {
    begin()
    flutterEventSink?(error)
  }
  func _sink(string: String) {
    begin()
    flutterEventSink?(string)
  }
  
  func _sink<EncodableT: Encodable>(encodable: EncodableT) {
    do {
      let data = try JSONEncoder().encode(encodable)
      guard let jsonStr = String(data: data, encoding: .utf8) else {
        _sink(error:
          FlutterError(
            code: "666",
            message: "String(data:encoding:) failed",
            details: data
          )
        )
        return
      }
      _sink(string: jsonStr)
    } catch {
      _sink(error: FlutterError(bleError: BleError(withError: error)))
    }
  }
}
extension EventChannel : FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    flutterEventSink = events
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    flutterEventSink = nil
    cleanUpClosure?()
    cleanUpClosure = nil
    return nil
  }
}

class EventSink {
  
  class StateChanges : EventChannel, EventSinker {
    typealias SinkableT = Int
    
    override func begin() {
      guard _ended else {
        return
      }
      FlutterEventChannel(
        name: "\(EventSink.base)/stateChanges",
        binaryMessenger: messenger
      ).setStreamHandler(self)
      _ended = false
    }
    
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
    
    override func begin() {
      guard _ended else {
        return
      }
      FlutterEventChannel(
        name: "\(EventSink.base)/stateRestoreEvents",
        binaryMessenger: messenger
      ).setStreamHandler(self)
      _ended = false
    }
    
    func sink(_ obj: [PeripheralResponse]) {
      _sink(encodable: obj)
    }
  }
  
  class ScanningEvents : EventChannel, EventSinker {
    typealias SinkableT = ScanResultEvent
    
    override func begin() {
      guard _ended else {
        return
      }
      FlutterEventChannel(
        name: "\(EventSink.base)/scanningEvents",
        binaryMessenger: messenger
      ).setStreamHandler(self)
      _ended = false
    }
    
    func sink(_ obj: ScanResultEvent) {
      _sink(encodable: obj)
    }
  }
  
  class ConnectionStateChangeEvents : EventChannel, EventSinker {
    typealias SinkableT = CBPeripheralState
    
    override func begin() {
      guard _ended else {
        return
      }
      FlutterEventChannel(
        name: "\(EventSink.base)/connectionStateChangeEvents",
        binaryMessenger: messenger
      ).setStreamHandler(self)
      _ended = false
    }
    
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
    
    override func begin() {
      guard _ended else {
        return
      }
//      FlutterEventChannel(
//        name: "\(EventSink.base)/monitorCharacteristic",
//        binaryMessenger: messenger
//      ).setStreamHandler(self)
      _ended = false
    }
    
    func sink(_ obj: SingleCharacteristicWithValueResponse) {
      _sink(encodable: obj)
    }
  }
  
  let stateChanges: StateChanges
  let stateRestoreEvents: StateRestoreEvents
  let scanningEvents: ScanningEvents
  let connectionStateChangeEvents: ConnectionStateChangeEvents
  let monitorCharacteristic: MonitorCharacteristic
  
  static private let base = "flutter_ble_lib"
  
  init(messenger: FlutterBinaryMessenger) {
    stateChanges = StateChanges(messenger: messenger)
    stateChanges.begin()
    stateRestoreEvents = StateRestoreEvents(messenger: messenger)
    stateRestoreEvents.begin()
    scanningEvents = ScanningEvents(messenger: messenger)
    scanningEvents.begin()
    connectionStateChangeEvents =
      ConnectionStateChangeEvents(messenger: messenger)
    connectionStateChangeEvents.begin()
    monitorCharacteristic =
      MonitorCharacteristic(messenger: messenger)
    monitorCharacteristic.begin()
  }
}
