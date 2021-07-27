//
//  BleError.swift
//
//  Created by Przemysław Lenart on 25/07/16.
//

import Foundation

enum BleErrorCode : Int {
    case unknownError = 0
    case bluetoothManagerDestroyed = 1
    case operationCancelled = 2
    case operationTimedOut = 3
    case operationStartFailed = 4
    case invalidIdentifiers = 5

    case bluetoothUnsupported = 100
    case bluetoothUnauthorized = 101
    case bluetoothPoweredOff = 102
    case bluetoothInUnknownState = 103
    case bluetoothResetting = 104
    case bluetoothStateChangeFailed = 105

    case deviceConnectionFailed = 200
    case deviceDisconnected = 201
    case deviceRSSIReadFailed = 202
    case deviceAlreadyConnected = 203
    case deviceNotFound = 204
    case deviceNotConnected = 205
    case deviceMTUChangeFailed = 206

    case servicesDiscoveryFailed = 300
    case includedServicesDiscoveryFailed = 301
    case serviceNotFound = 302
    case servicesNotDiscovered = 303

    case characteristicsDiscoveryFailed = 400
    case characteristicWriteFailed = 401
    case characteristicReadFailed = 402
    case characteristicNotifyChangeFailed = 403
    case characteristicNotFound = 404
    case characteristicsNotDiscovered = 405
    case characteristicInvalidDataFormat = 406

    case descriptorsDiscoveryFailed = 500
    case descriptorWriteFailed = 501
    case descriptorReadFailed = 502
    case descriptorNotFound = 503
    case descriptorsNotDiscovered = 504
    case descriptorInvalidDataFormat = 505
    case descriptorWriteNotAllowed = 506

    case scanStartFailed = 600
    case locationServicesDisabled = 601
}

struct BleError: Error, Encodable {
    let errorCode: BleErrorCode
    let reason: String?
    let attErrorCode: Int?
    let iosErrorCode: Int?
    

    let deviceID: String?
    let serviceUUID: String?
    let characteristicUUID: String?
    let descriptorUUID: String?
    let internalMessage: String?
  
  func encode(to encoder: Encoder) throws {
    var encCont = encoder.container(keyedBy: CodingKeys.self)
    try encCont.encode(errorCode.rawValue, forKey: .errorCode)
    try encCont.encode(reason, forKey: .reason)
    try encCont.encode(attErrorCode, forKey: .attErrorCode)
    try encCont.encode(iosErrorCode, forKey: .iosErrorCode)
    
    let androidErrorCode: Int? = nil
    try encCont.encode(androidErrorCode, forKey: .androidErrorCode)
    
    try encCont.encode(deviceID, forKey: .deviceID)
    try encCont.encode(serviceUUID, forKey: .serviceUUID)
    try encCont.encode(characteristicUUID, forKey: .characteristicUUID)
    try encCont.encode(descriptorUUID, forKey: .descriptorUUID)
    try encCont.encode(internalMessage, forKey: .internalMessage)
  }
  
  enum CodingKeys: String, CodingKey {
    case errorCode
    case reason
    case attErrorCode
    case iosErrorCode
    
    case androidErrorCode
    
    case deviceID
    case serviceUUID
    case characteristicUUID
    case descriptorUUID
    case internalMessage
  }
}

extension BleErrorCode {
//  init(pluginErr: PluginError) {
//    switch pluginErr {
//    case .signature(.invalidValue),
//         .signature(.missingArgsKey):
//      self = .invalidIdentifiers
//    case .coreBluetooth:
//      self = .unknownError
//    }
//
//  }
}

extension BleError {
  init(withError error: Error) {
    switch error {
//    case let error as PluginError:
//      self.init(pluginErr: error)
//    case let nsError
    default:
      self.init(
        errorCode: .unknownError,
        reason: error.localizedDescription,
        attErrorCode: nil,
        iosErrorCode: nil,
        deviceID: nil,
        serviceUUID: nil,
        characteristicUUID: nil,
        descriptorUUID: nil,
        internalMessage: nil
      )
    }
  }
  
//  init(pluginErr: PluginError) {
//    let code = BleErrorCode(pluginErr: pluginErr)
//    self.init(
//      errorCode: code,
//      reason: pluginErr.failureReason,
//      attErrorCode: nil,
//      iosErrorCode: nil,
//      deviceID: nil,
//      serviceUUID: nil,
//      characteristicUUID: nil,
//      descriptorUUID: nil,
//      internalMessage: nil
//    )
//  }
}

extension FlutterError {
  convenience init(bleError: BleError) {
    let jsonData = try? JSONEncoder().encode(bleError)
    let details: String
    if let data = jsonData {
      details = String(data: data, encoding: .utf8) ?? ""
    } else {
      details = ""
    }
    self.init(
      code: "\(bleError.errorCode.rawValue)",
      message: bleError.reason,
      details: details
    )
  }
  convenience init(withError error: Error) {
    switch error {
    case let error as NSError:
      self.init(
        code: "\(error.code)",
        message: error.localizedDescription,
        details: error.localizedFailureReason
      )
    default:
      self.init(
        code: "666",
        message: error.localizedDescription,
        details: ""
      )
    }
  }
}
