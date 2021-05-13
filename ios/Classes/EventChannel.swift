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
    
  func sink(_ obj: SinkableT)
  func afterCancelDo(_ cleanUpClosure: @escaping () -> ())
}

class EventChannel : NSObject {
  fileprivate var flutterEventSink: FlutterEventSink?
  fileprivate var cleanUpClosure: (() -> ())?
  
  func afterCancelDo(_ cleanUpClosure: @escaping () -> ()) {
    self.cleanUpClosure = cleanUpClosure
  }
}
extension EventChannel : FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
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
    typealias SinkableT = String
    func sink(_ obj: SinkableT) {
      flutterEventSink?(obj)
    }
  }
  
  class StateRestoreEvents : EventChannel, EventSinker {
    typealias SinkableT = String
    func sink(_ obj: SinkableT) {
      flutterEventSink?(obj)
    }
  }
  
  class ScanningEvents : EventChannel, EventSinker {
    typealias SinkableT = String
    func sink(_ obj: SinkableT) {
      flutterEventSink?(obj)
    }
  }
  
  class ConnectionStateChangeEvents : EventChannel, EventSinker {
    typealias SinkableT = CBPeripheralState
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
      flutterEventSink?(stateStr)
    }
  }
  
  class MonitorCharacteristic : EventChannel, EventSinker {
    typealias SinkableT = String
    func sink(_ obj: SinkableT) {
      flutterEventSink?(obj)
    }
  }
  
  let stateChanges = StateChanges()
  let stateRestoreEvents = StateRestoreEvents()
  let scanningEvents = ScanningEvents()
  let connectionStateChangeEvents = ConnectionStateChangeEvents()
  let monitorCharacteristic = MonitorCharacteristic()
  
  static private let base = "flutter_ble_lib"
  
  init(messenger: FlutterBinaryMessenger) {
    FlutterEventChannel(
      name: "\(EventSink.base)/stateChanges",
      binaryMessenger: messenger
    ).setStreamHandler(stateChanges)
    FlutterEventChannel(
      name: "\(EventSink.base)/stateRestoreEvents",
      binaryMessenger: messenger
    ).setStreamHandler(stateRestoreEvents)
    FlutterEventChannel(
      name: "\(EventSink.base)/scanningEvents",
      binaryMessenger: messenger
    ).setStreamHandler(scanningEvents)
    FlutterEventChannel(
      name: "\(EventSink.base)/connectionStateChangeEvents",
      binaryMessenger: messenger
    ).setStreamHandler(connectionStateChangeEvents)
    FlutterEventChannel(
      name: "\(EventSink.base)/monitorCharacteristic",
      binaryMessenger: messenger
    ).setStreamHandler(monitorCharacteristic)
  }
}
