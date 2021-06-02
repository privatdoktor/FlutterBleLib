import Foundation
import Flutter

public class Plugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    DefaultMethodChannel.register(with: registrar)
    
  }
}

