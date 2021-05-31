import Foundation
import Flutter


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


public class Plugin: NSObject, FlutterPlugin {
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    
    Method.DefaultChannel.register(with: registrar)
//    let messenger: FlutterBinaryMessenger = registrar.messenger()
//    let methodChannel =
//      FlutterMethodChannel(
//        name: Method.DefaultChannel.name,
//        binaryMessenger: messenger
//      )
//
//    let plugin = Plugin(withClient: client)
    
    
  }
  
 
  
}

