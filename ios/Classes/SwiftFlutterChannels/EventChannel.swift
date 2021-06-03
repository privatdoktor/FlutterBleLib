//
//  EventChannel.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 13/05/2021.
//

import Foundation
import Flutter
import CoreBluetooth

protocol EventSinker : EventChannel {
  associatedtype SinkableT
  
  static var baseName: String { get }
  func sink(_ obj: SinkableT)
  func afterCancelDo(_ cleanUpClosure: @escaping () -> ())
  var name: String { get }
}

class EventChannel : NSObject {
  private var flutterEventSink: FlutterEventSink?
  private var cleanUpClosure: (() -> ())?
  private let flutterEventChannel: FlutterEventChannel
  let name: String
  
  required init(name: String, messenger: FlutterBinaryMessenger) {
    self.name = name
    flutterEventChannel =
      FlutterEventChannel(
        name: name,
        binaryMessenger: messenger
      )
    super.init()
    flutterEventChannel.setStreamHandler(self)
  }
  
  func afterCancelDo(_ cleanUpClosure: @escaping () -> ()) {
    self.cleanUpClosure = cleanUpClosure
  }
  
  func end() {
    flutterEventSink?(FlutterEndOfEventStream)
    flutterEventSink = nil
    cleanUpClosure?()
    cleanUpClosure = nil
  }
  
  func _sink(error: FlutterError) {
    flutterEventSink?(error)
  }
  func _sink(string: String) {
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
  
  deinit {
    end()
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
//    flutterEventChannel.setStreamHandler(nil)
    return nil
  }
}
