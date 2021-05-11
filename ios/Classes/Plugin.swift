//
//  Plugin.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 11/05/2021.
//

import Foundation

enum PluginError : LocalizedError {
  var failureReason: String? {
    switch self {
    case .signature(let sigErr):
      return sigErr.failureReason
    default:
      return nil
    }
  }
  case signature(SignatureError)
  case coreBluetooth(Error)
}

enum SignatureError : LocalizedError {
  
  var failureReason: String? {
    switch self {
    case .missingArgsKey(let key, let dict, let id):
      return
        """
        Missing argument key: \(key)
        in dict: \(String(describing: dict)) for method \(id)
        """
    case .invalidValue(let key, let value,
                       let dict, let id,
                       let expected):
      return
        """
        Invalid value: \(value) for key: \(key)
        in dict: \(dict) for method: \(id).
        Expected value type: \(expected) and got \(type(of: value))
        """
    }
  }
  
  case missingArgsKey(String, inDict: Dictionary<String, Any>?, id: String)
  case invalidValue(forKey: String, value: Any,
                    inDict: Dictionary<String, Any>, id: String,
                    expected: Any.Type)
}

protocol SignatureEnum {
  init?(_ id: String, args: Dictionary<String, Any>?) throws
}

protocol Channel {
  associatedtype SignatureEnumT: SignatureEnum
  static var name: String { get }
}

protocol CallHandler {
  associatedtype SignatureEnumT: SignatureEnum
  func handle(call: Descriptors.Method.Call<SignatureEnumT>)
}

enum Descriptors {
  static private let base = "flutter_ble_lib"
  struct Method {
    class Call<SignatureEnumT> where SignatureEnumT : SignatureEnum {
      let signature: SignatureEnumT
      private var isResulted = false
      private let onResult: FlutterResult
      
      init?(
        _ id: String,
        args: Dictionary<String, Any>?,
        onResult result: @escaping FlutterResult
      ) {
        do {
          guard
            let sig = try SignatureEnumT(id, args: args)
          else {
            result(FlutterMethodNotImplemented)
            return nil
          }
          signature = sig
          onResult = result
        } catch {
          result(FlutterError(bleError: BleError(withError: error)))
          return nil
        }
      }
      
      func result(_ object: Any?)  {
        guard
          isResulted == false
        else {
          return
        }
        onResult(object)
        isResulted = true
      }
    }
    
    struct DefaultChannel : Channel {
      static let name = base
      typealias SignatureEnumT = Signature
      
      enum Signature : SignatureEnum {
        
        init?(_ id: String, args: Dictionary<String, Any>?) throws {
          switch id {
          case "isClientCreated":
            self = .isClientCreated
            return
          case "createClient":
            let restoreId = args?["restoreStateIdentifier"] as? String
            let showPowerAlert = args?["showPowerAlertOnIOS"] as? Bool

            self = .createClient(
              restoreId: restoreId,
              showPowerAlert: showPowerAlert
            )
          case "destroyClient":
            self = .destroyClient
          case "cancelTransaction":
            let transactionId = args?["transactionId"]
            self = .cancelTransaction(transactionId: transactionId)
          case "getState":
            self = .getState
          case "enableRadio":
            self = .enableRadio
          case "disableRadio":
            self = .disableRadio
          case "startDeviceScan":
            let uuids = args?["uuids"] as? [String]
            let allowDuplicates = args?["allowDuplicates"] as? Bool
            self = .startDeviceScan(
              uuids: uuids,
              allowDuplicates: allowDuplicates
            )
          case "stopDeviceScan":
            self = .stopDeviceScan
          case "connectToDevice":
            let deviceIdentifierKey = "deviceIdentifier"
            guard
              let value = args?[deviceIdentifierKey],
              let args = args
            else {
              throw PluginError.signature(
                .missingArgsKey(
                  deviceIdentifierKey,
                  inDict: args,
                  id: id
                )
              )
            }
            guard
              let deviceId = value as? String
            else {
              throw PluginError.signature(
                .invalidValue(
                  forKey: deviceIdentifierKey,
                  value: value,
                  inDict: args,
                  id: id,
                  expected: String.self
                )
              )
            }
            let timoutMillis = args["timeout"] as? Int
            self = .connectToDevice(
              deviceIdentifier: deviceId,
              timoutMillis: timoutMillis
            )
          default:
            return nil
          }
        }
        
        case isClientCreated
        case createClient(restoreId: String?, showPowerAlert: Bool?)
        case destroyClient
        
        case cancelTransaction(transactionId: Any?)
        
        case getState
        
        case enableRadio
        case disableRadio
        
        case startDeviceScan(uuids: [String]?, allowDuplicates: Bool?)
        case stopDeviceScan
        
        case connectToDevice(deviceIdentifier: String, timoutMillis: Int?)
        case isDeviceConnected(deviceIdentifier: String)
        case observeConnectionState
        case cancelConnection
        
        case discoverAllServicesAndCharacteristics
        case services
        case characteristics
        case characteristicsForService
        case descriptorsForDevice
        case descriptorsForService
        case descriptorsForCharacteristic
        
        case logLevel
        case setLogLevel
        
        case rssi
        
        case requestMtu
        
        case getConnectedDevices
        case getKnownDevices
        
        case readCharacteristicForIdentifier
        case readCharacteristicForDevice
        case readCharacteristicForService
        
        case writeCharacteristicForIdentifier
        case writeCharacteristicForDevice
        case writeCharacteristicForService
        
        case monitorCharacteristicForIdentifier
        case monitorCharacteristicForDevice
        case monitorCharacteristicForService
        
        case readDescriptorForIdentifier
        case readDescriptorForCharacteristic
        case readDescriptorForService
        case readDescriptorForDevice
        
        case writeDescriptorForIdentifier
        case writeDescriptorForCharacteristic
        case writeDescriptorForService
        case writeDescriptorForDevice
      }
      
    }
  }
  
  struct Event {
    enum Channel {
      case stateChanges
      case stateRestoreEvents
      case scanningEvents
      case connectionStateChangeEvents
      case monitorCharacteristic
      var name: String {
        switch self {
        case .stateChanges: return "\(base)/stateChanges"
        case .stateRestoreEvents: return "\(base)/stateChanges"
        case .scanningEvents: return "\(base)/stateChanges"
        case .connectionStateChangeEvents: return "\(base)/stateChanges"
        case .monitorCharacteristic: return "\(base)/stateChanges"
        }
      }
    }
  }
}
