import Foundation
import Flutter


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
  
  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    typealias Method = Descriptors.Method
    typealias DefaultChannel = Method.DefaultChannel
    guard
      let args = call.arguments as? Dictionary<String, Any>?,
      let call = Method.Call<DefaultChannel.Signature>(
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

