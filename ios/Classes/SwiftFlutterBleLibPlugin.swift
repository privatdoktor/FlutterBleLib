import Foundation
import Flutter
import CoreBluetooth


//    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
//                                                               options:NSJSONReadingMutableContainers
//                                                                 error:nil];
//    return [FlutterError errorWithCode:[[dictionary objectForKey:@"errorCode"] stringValue]
//                               message:[dictionary objectForKey:@"reason"]
//                               details:jsonString];

extension FlutterError {
  convenience init(jsonString: String, transactionId: String?) {
    guard
      let data = jsonString.data(using: .utf8),
      let dict = try? JSONSerialization.jsonObject(with: data) as? Dictionary<String, AnyObject>,
      let code = dict["errorCode"] as? String,
      let reason = dict["reason"] as? String
    else {
      self.init(
        code: "666",
        message: "could not parse the jsonString see details for the original jsonString to parse",
        details: jsonString
      )
      return
    }
    self.init(
      code: code,
      message: reason,
      details: jsonString
    )
  }
}

enum PluginError : Error {
  case flutter(FlutterError)
  case invalidArgs(AnyObject?)
  case missingArgsKey(String, inDict: Dictionary<String, AnyObject>)
}

protocol SignatureEnum {
  init?(_ id: String, args: Dictionary<String, AnyObject>?) throws
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
        args: Dictionary<String, AnyObject>?,
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
        } catch PluginError.missingArgsKey(let key, let inDict) {
          result(FlutterError(code: "666", message: key, details: inDict))
          return nil
        } catch {
          result(error)
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
        
        init?(_ id: String, args: Dictionary<String, AnyObject>?) throws {
          switch id {
          case "isClientCreated":
            self = .isClientCreated
            return
          case "createClient":
            guard
              let args = args
            else {
              self = .createClient(nil)
              return
            }
        
            let restoreStateKey = "restoreStateIdentifier"

            guard
              let restoreId = args[restoreStateKey] as? String?
            else {
              throw PluginError.missingArgsKey(
                restoreStateKey,
                inDict: args
              )
            }
            self = .createClient(restoreId)
          default:
            return nil
          }
        }
        
        case isClientCreated
        case createClient(String?)
        case destroyClient
        
        case cancelTransaction
        
        case getState
        
        case enableRadio
        case disableRadio
        
        case startDeviceScan
        case stopDeviceScan
        
        case connectToDevice
        case isDeviceConnected
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

class Client : NSObject, CBCentralManagerDelegate, CallHandler {
  
  typealias SignatureEnumT = Descriptors.Method.DefaultChannel.Signature
  
  private var centralManager: CBCentralManager?
  
  
  func handle(call: Descriptors.Method.Call<SignatureEnumT>) {
    switch call.signature {
    case .isClientCreated:
      call.result(isCreated)
    case .createClient:
      create()
      call.result(nil)
    case .destroyClient:
      call.result(FlutterMethodNotImplemented)
    case .cancelTransaction:
      call.result(FlutterMethodNotImplemented)
    case .getState:
      
      call.result(FlutterMethodNotImplemented)
    case .enableRadio:
      call.result(FlutterMethodNotImplemented)
    case .disableRadio:
      call.result(FlutterMethodNotImplemented)
    case .startDeviceScan:
      call.result(FlutterMethodNotImplemented)
    case .stopDeviceScan:
      call.result(FlutterMethodNotImplemented)
    case .connectToDevice:
      call.result(FlutterMethodNotImplemented)
    case .isDeviceConnected:
      call.result(FlutterMethodNotImplemented)
    case .observeConnectionState:
      call.result(FlutterMethodNotImplemented)
    case .cancelConnection:
      call.result(FlutterMethodNotImplemented)
    case .discoverAllServicesAndCharacteristics:
      call.result(FlutterMethodNotImplemented)
    case .services:
      call.result(FlutterMethodNotImplemented)
    case .characteristics:
      call.result(FlutterMethodNotImplemented)
    case .characteristicsForService:
      call.result(FlutterMethodNotImplemented)
    case .descriptorsForDevice:
      call.result(FlutterMethodNotImplemented)
    case .descriptorsForService:
      call.result(FlutterMethodNotImplemented)
    case .descriptorsForCharacteristic:
      call.result(FlutterMethodNotImplemented)
    case .logLevel:
      call.result(FlutterMethodNotImplemented)
    case .setLogLevel:
      call.result(FlutterMethodNotImplemented)
    case .rssi:
      call.result(FlutterMethodNotImplemented)
    case .requestMtu:
      call.result(FlutterMethodNotImplemented)
    case .getConnectedDevices:
      call.result(FlutterMethodNotImplemented)
    case .getKnownDevices:
      call.result(FlutterMethodNotImplemented)
    case .readCharacteristicForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .readCharacteristicForDevice:
      call.result(FlutterMethodNotImplemented)
    case .readCharacteristicForService:
      call.result(FlutterMethodNotImplemented)
    case .writeCharacteristicForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .writeCharacteristicForDevice:
      call.result(FlutterMethodNotImplemented)
    case .writeCharacteristicForService:
      call.result(FlutterMethodNotImplemented)
    case .monitorCharacteristicForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .monitorCharacteristicForDevice:
      call.result(FlutterMethodNotImplemented)
    case .monitorCharacteristicForService:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForCharacteristic:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForService:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForDevice:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForCharacteristic:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForService:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForDevice:
      call.result(FlutterMethodNotImplemented)
    }

  }
  
  var isCreated: Bool {
    return centralManager != nil
  }
  
  func create() {
    centralManager = CBCentralManager(
      delegate: self,
      queue: nil,
      options: nil
    )
  }
  

  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    
  }
  
}


public class SwiftFlutterBleLibPlugin: NSObject, FlutterPlugin {
  private let client = Client()
  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = SwiftFlutterBleLibPlugin()
    let methodChannel =
      FlutterMethodChannel(
        name: Descriptors.Method.DefaultChannel.name,
        binaryMessenger: registrar.messenger()
      )
    registrar.addMethodCallDelegate(
      plugin,
      channel: methodChannel
    )


    
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    typealias Method = Descriptors.Method
    typealias DefaultChannel = Method.DefaultChannel
    guard
      let args = call.arguments as? Dictionary<String, AnyObject>?,
      let call = Method.Call<DefaultChannel.Signature>(call.method, args: args, onResult: result)
    else {
      return
    }
    client.handle(call: call)
  }
  
}

extension SwiftFlutterBleLibPlugin : CBCentralManagerDelegate {
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
  }
  
  public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    
  }
  
  
}
