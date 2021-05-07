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
    struct Call<SignatureEnumT> where SignatureEnumT : SignatureEnum {
      let signature: SignatureEnumT
      let onResult: FlutterResult
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
              return
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
      call.onResult(isCreated)
    case .createClient:
      create()
      call.onResult(nil)
    case .destroyClient:
      call.onResult(FlutterMethodNotImplemented)
    case .cancelTransaction:
      call.onResult(FlutterMethodNotImplemented)
    case .getState:
      
      call.onResult(FlutterMethodNotImplemented)
    case .enableRadio:
      call.onResult(FlutterMethodNotImplemented)
    case .disableRadio:
      call.onResult(FlutterMethodNotImplemented)
    case .startDeviceScan:
      call.onResult(FlutterMethodNotImplemented)
    case .stopDeviceScan:
      call.onResult(FlutterMethodNotImplemented)
    case .connectToDevice:
      call.onResult(FlutterMethodNotImplemented)
    case .isDeviceConnected:
      call.onResult(FlutterMethodNotImplemented)
    case .observeConnectionState:
      call.onResult(FlutterMethodNotImplemented)
    case .cancelConnection:
      call.onResult(FlutterMethodNotImplemented)
    case .discoverAllServicesAndCharacteristics:
      call.onResult(FlutterMethodNotImplemented)
    case .services:
      call.onResult(FlutterMethodNotImplemented)
    case .characteristics:
      call.onResult(FlutterMethodNotImplemented)
    case .characteristicsForService:
      call.onResult(FlutterMethodNotImplemented)
    case .descriptorsForDevice:
      call.onResult(FlutterMethodNotImplemented)
    case .descriptorsForService:
      call.onResult(FlutterMethodNotImplemented)
    case .descriptorsForCharacteristic:
      call.onResult(FlutterMethodNotImplemented)
    case .logLevel:
      call.onResult(FlutterMethodNotImplemented)
    case .setLogLevel:
      call.onResult(FlutterMethodNotImplemented)
    case .rssi:
      call.onResult(FlutterMethodNotImplemented)
    case .requestMtu:
      call.onResult(FlutterMethodNotImplemented)
    case .getConnectedDevices:
      call.onResult(FlutterMethodNotImplemented)
    case .getKnownDevices:
      call.onResult(FlutterMethodNotImplemented)
    case .readCharacteristicForIdentifier:
      call.onResult(FlutterMethodNotImplemented)
    case .readCharacteristicForDevice:
      call.onResult(FlutterMethodNotImplemented)
    case .readCharacteristicForService:
      call.onResult(FlutterMethodNotImplemented)
    case .writeCharacteristicForIdentifier:
      call.onResult(FlutterMethodNotImplemented)
    case .writeCharacteristicForDevice:
      call.onResult(FlutterMethodNotImplemented)
    case .writeCharacteristicForService:
      call.onResult(FlutterMethodNotImplemented)
    case .monitorCharacteristicForIdentifier:
      call.onResult(FlutterMethodNotImplemented)
    case .monitorCharacteristicForDevice:
      call.onResult(FlutterMethodNotImplemented)
    case .monitorCharacteristicForService:
      call.onResult(FlutterMethodNotImplemented)
    case .readDescriptorForIdentifier:
      call.onResult(FlutterMethodNotImplemented)
    case .readDescriptorForCharacteristic:
      call.onResult(FlutterMethodNotImplemented)
    case .readDescriptorForService:
      call.onResult(FlutterMethodNotImplemented)
    case .readDescriptorForDevice:
      call.onResult(FlutterMethodNotImplemented)
    case .writeDescriptorForIdentifier:
      call.onResult(FlutterMethodNotImplemented)
    case .writeDescriptorForCharacteristic:
      call.onResult(FlutterMethodNotImplemented)
    case .writeDescriptorForService:
      call.onResult(FlutterMethodNotImplemented)
    case .writeDescriptorForDevice:
      call.onResult(FlutterMethodNotImplemented)
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
      let args = call.arguments as? Dictionary<String, Any>?,
      let signature = DefaultChannel.Signature(call.method, args: args)
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    
    let call = Method.Call(signature: signature, onResult: result)
    client.handle(call: call)
  }
  
}

extension SwiftFlutterBleLibPlugin : CBCentralManagerDelegate {
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
  }
  
  public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    
  }
  
  
}
