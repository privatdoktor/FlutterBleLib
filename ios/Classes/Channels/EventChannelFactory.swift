//
//  EventChannel.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 13/05/2021.
//

import Foundation
import CoreBluetooth

class EventChannelFactory {
  let messenger: FlutterBinaryMessenger
  
//  let stateChanges: StateChanges
//  let stateRestoreEvents: StateRestoreEvents
//  let scanningEvents = ScanningEvents()
//  let connectionStateChangeEvents = ConnectionStateChangeEvents()
//  let monitorCharacteristic = MonitorCharacteristic()
//
  
  func makeEventChannel<EventSinkerT : EventSinker>(
    _ type: EventSinkerT.Type,
    id: String? = nil
  ) -> EventSinkerT {
    let name: String
    if let id = id {
      name = "\(type.baseName)/\(id)"
    } else {
      name = type.baseName
    }
    return type.init(name: name, messenger: messenger)
  }
  
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }
}
