//
//  EventChannel.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 13/05/2021.
//

import Foundation
import CoreBluetooth

class EventChannelFactory {
  enum IdScheme {
    case userDefined(String)
    case generated
    case justBaseName
  }
  let messenger: FlutterBinaryMessenger
  private var eventChannels = [String : EventChannel]()
  
  func makeEventChannel<EventSinkerT : EventSinker>(
    _ type: EventSinkerT.Type,
    idScheme: IdScheme = .generated
  ) -> EventSinkerT {
    let name: String
    switch idScheme {
    case .userDefined(let id):
      name = "\(type.baseName)/\(id)"
    case .generated:
      name = "\(type.baseName)/\(UUID().uuidString)"
    case .justBaseName:
      name = type.baseName
    }
    let sinker = type.init(name: name, messenger: messenger)
    eventChannels[name] = sinker
    return sinker
  }
  
  func removeEventChannel(name: String) {
    eventChannels.removeValue(forKey: name)
  }
  
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }
}
