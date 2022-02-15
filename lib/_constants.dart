abstract class MethodName {
  static const String isClientCreated = 'isClientCreated';
  static const String createClient = 'createClient';
  static const String destroyClient = 'destroyClient';

  static const String cancelTransaction = 'cancelTransaction';

  static const String getState = 'getState';
  static const String getAuthorization = 'getAuthorization';

  static const String enableRadio = 'enableRadio';
  static const String disableRadio = 'disableRadio';

  static const String createScanningEventChannel = 'createScanningEventChannel';
  static const String startDeviceScan = 'startDeviceScan';
  static const String stopDeviceScan = 'stopDeviceScan';

  static const String connectToDevice = 'connectToDevice';
  static const String isDeviceConnected = 'isDeviceConnected';
  static const String observeConnectionState = 'observeConnectionState';
  static const String cancelConnection = 'cancelConnection';

  static const String discoverServices = 'discoverServices';
  static const String discoverCharacteristics = 'discoverCharacteristics';
  static const String discoverAllServicesAndCharacteristics =
      'discoverAllServicesAndCharacteristics';
  static const String services = 'services';
  static const String characteristics = 'characteristics';
  static const String descriptorsForDevice = 'descriptorsForDevice';

  static const String setLogLevel = 'setLogLevel';
  static const String logLevel = 'logLevel';

  static const String rssi = 'rssi';
  static const String requestMtu = 'requestMtu';

  static const String readCharacteristicForDevice =
      'readCharacteristicForDevice';

  static const String writeCharacteristicForDevice =
      'writeCharacteristicForDevice';


  static const String monitorCharacteristicForDevice =
      'monitorCharacteristicForDevice';

  static const String readDescriptorForDevice = 'readDescriptorForDevice';


  static const String writeDescriptorForDevice = 'writeDescriptorForDevice';

  static const String connectedDevices = 'getConnectedDevices';
  static const String knownDevices = 'getKnownDevices';
}

abstract class ChannelName {
  static const String flutterBleLib = 'flutter_ble_lib';
  static const String adapterStateChanges = flutterBleLib + '/stateChanges';
  static const String stateRestoreEvents =
      flutterBleLib + '/stateRestoreEvents';
  static const String scanningEvents = flutterBleLib + '/scanningEvents';
  static const String connectionStateChangeEvents =
      flutterBleLib + '/connectionStateChangeEvents';
  static const String monitorCharacteristic =
      flutterBleLib + '/monitorCharacteristic';
}

abstract class ArgumentName {
  static const String restoreStateIdentifier = 'restoreStateIdentifier';
  static const String showPowerAlertOnIOS = 'showPowerAlertOnIOS';
  static const String scanMode = 'scanMode';
  static const String callbackType = 'callbackType';
  static const String allowDuplicates = 'allowDuplicates';
  static const String uuids = 'uuids';

  static const String transactionId = 'transactionId';

  static const String deviceIdentifier = 'deviceIdentifier';
  static const String isAutoConnect = 'isAutoConnect';
  static const String requestMtu = 'requestMtu';
  static const String refreshGatt = 'refreshGatt';
  static const String timeoutMillis = 'timeout';
  static const String emitCurrentValue = 'emitCurrentValue';

  static const String serviceUuid = 'serviceUuid';
  static const String serviceUuids = 'serviceUuids';
  static const String characteristicUuid = 'characteristicUuid';
  static const String characteristicUuids = 'characteristicUuids';

  
  // static const String characteristicIdentifier = 'characteristicIdentifier';
  static const String descriptorUuid = 'descriptorUuid';
  // static const String descriptorIdentifier = 'descriptorIdentifier';

  static const String value = 'value';
  static const String withResponse = 'withResponse';

  static const String logLevel = 'logLevel';

  static const String mtu = 'mtu';

  static const String deviceIdentifiers = 'deviceIdentifiers';
}

abstract class NativeConnectionState {
  static const String connecting = 'connecting';
  static const String connected = 'connected';
  static const String disconnecting = 'disconnecting';
  static const String disconnected = 'disconnected';
}
