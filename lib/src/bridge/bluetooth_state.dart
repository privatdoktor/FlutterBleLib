part of flutter_ble_lib;

extension BluetoothState on BleManager {

  static const EventChannel _adapterStateChangesEventChannel = 
    EventChannel(ChannelName.adapterStateChanges);
  static Stream<String> get _adapterStateChanges =>
      _adapterStateChangesEventChannel
          .receiveBroadcastStream().cast();

  BluetoothState _mapToBluetoothState(String? rawValue) {
    switch (rawValue) {
      case 'Unknown':
        return BluetoothState.UNKNOWN;
      case 'Unsupported':
        return BluetoothState.UNSUPPORTED;
      case 'Unauthorized':
        return BluetoothState.UNAUTHORIZED;
      case 'Resetting':
        return BluetoothState.RESETTING;
      case 'PoweredOn':
        return BluetoothState.POWERED_ON;
      case 'PoweredOff':
        return BluetoothState.POWERED_OFF;
      default:
        throw 'Cannot map $rawValue to known bluetooth state';
    }
  }
}
