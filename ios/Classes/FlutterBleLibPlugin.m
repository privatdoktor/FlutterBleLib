#import "FlutterBleLibPlugin.h"

#if __has_include(<flutter_ble_lib/flutter_ble_lib-Swift.h>)
#import <flutter_ble_lib/flutter_ble_lib-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_ble_lib-Swift.h"
#endif

@implementation FlutterBleLibPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [Plugin registerWithRegistrar:registrar];
}
  
@end
