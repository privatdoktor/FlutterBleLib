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
  private let client: Client
  
  init(withClient: Client) {
    client = withClient
  }
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger: FlutterBinaryMessenger = registrar.messenger()
    let methodChannel =
      FlutterMethodChannel(
        name: Method.DefaultChannel.name,
        binaryMessenger: messenger
      )
    let eventSink = EventSink(messenger: messenger)
    let client = Client(eventSink: eventSink)
    let plugin = Plugin(withClient: client)
    
    registrar.addMethodCallDelegate(
      plugin,
      channel: methodChannel
    )
  }
  
  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let args = call.arguments as? Dictionary<String, Any>?,
      let call = Method.Call<Method.DefaultChannel.Signature>(
        call.method,
        args: args,
        onResult: result
      )
    else {
      return
    }
    client.handle(call: call)
  }
  
}

