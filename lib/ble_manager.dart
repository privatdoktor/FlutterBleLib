part of flutter_ble_lib;

/// Callback used to inform about peripherals restored by the system.
///
/// iOS-specific.
typedef RestoreStateAction = Function(List<Peripheral> peripherals);


/// Level of details library is to output in logs.
enum LogLevel { none, verbose, debug, info, warning, error }

/// State of the Bluetooth Adapter.
enum BluetoothState {
  UNKNOWN,
  UNSUPPORTED,
  UNAUTHORIZED,
  POWERED_ON,
  POWERED_OFF,
  RESETTING,
}

/// Mode of scan for peripherals - Android only.
///
/// See [Android documentation](https://developer.android.com/reference/android/bluetooth/le/ScanSettings) for more information.
abstract class ScanMode {
  static const int opportunistic = -1;
  static const int lowPower = 0;
  static const int balanced = 1;
  static const int lowLatency = 2;
}

/// Type of scan for peripherals callback - Android only.
///
/// See [Android documentation](https://developer.android.com/reference/android/bluetooth/le/ScanSettings) for more information.
abstract class CallbackType {
  static const int allMatches = 1;
  static const int firstMatch = 2;
  static const int matchLost = 4;
}

/// Entry point for library operations, handling allocation and deallocation
/// of underlying native resources and obtaining [Peripheral] instances.
///
/// The class is a singleton, so there's no need to keep the reference to
/// the object in one's code.
///
/// Initialising/deinitialising native clients:
/// ```dart
/// BleManager bleManager = BleManager();
/// await bleManager.createClient(); //ready to go!
/// //your BLE logic
/// bleManager.destroyClient(); //remember to release native resources when they're no longer needed
/// ```
///
/// Obtaining [Peripheral]:
/// ```dart
/// bleManager.startPeripheralScan().listen((scanResult) {
///  //Scan one peripheral and stop scanning
///  print("Scanned Peripheral ${scanResult.peripheral.name}, RSSI ${scanResult.rssi}");
///  bleManager.stopPeripheralScan(); // stops the scan
///});
///```
class BleManager {
  static BleManager? _instance;

  BleManager._();

  factory BleManager() {
    var instance = _instance;
    if (instance == null) {
      instance = BleManager._();
      _instance = instance;
    }
    return instance;
  }

  static const MethodChannel _methodChannel =
    MethodChannel(ChannelName.flutterBleLib);

  static const EventChannel _restoreStateEventsEventChannel =
    EventChannel(ChannelName.stateRestoreEvents);
  static Stream<dynamic> get _restoreStateEvents =>
      _restoreStateEventsEventChannel
          .receiveBroadcastStream();

  static const EventChannel _scanningEventsEventChannel =
    EventChannel(ChannelName.scanningEvents);
  Stream<ScanResult>? _activeScanEvents;

  static const EventChannel _adapterStateChangesEventChannel = 
    EventChannel(ChannelName.adapterStateChanges);
  static Stream<String> get _adapterStateChanges =>
      _adapterStateChangesEventChannel
          .receiveBroadcastStream().cast();

  /// Cancels transaction's return, resulting in [BleError] with
  /// [BleError.errorCode] set to [BleErrorCode.operationCancelled] being returned
  /// from transaction's Future.
  ///
  /// The operation might be cancelled if it hadn't yet started or be run
  /// normally, eg. writing to
  /// characteristic, but you can dismiss awaiting for the result if,
  /// for example, the result is no longer useful due to user's actions.
  Future<void> cancelTransaction(String transactionId) async {
    await BleManager._methodChannel.invokeMethod(MethodName.cancelTransaction,
        <String, String>{ArgumentName.transactionId: transactionId});
  }

  Future<List<Peripheral>> restoredState() async { 
    final peripherals = await _restoreStateEvents
      .map(
        (jsonString) {
          if (jsonString == null || 
              jsonString is String == false) {
            return null;
          }
          final restoredPeripheralsJson =
              (jsonDecode(jsonString) as List<dynamic>)
              .cast<Map<String, dynamic>>();
          return restoredPeripheralsJson
              .map((peripheralJson) =>
                  Peripheral.fromJson(peripheralJson, this))
              .toList();
        },
      )
      .take(1)
      .single;
    return peripherals ?? <Peripheral>[];
  }


  /// Checks whether the native client exists.
  Future<bool> isClientCreated() async {
    final raw = await BleManager._methodChannel.invokeMethod<bool>(
      MethodName.isClientCreated
    );
    return raw!;
  }

  /// Allocates native resources.
  ///
  /// [restoreStateIdentifier] and [restoreStateAction] are iOS-specific.
  ///
  /// Must return before any other operation can be called.
  ///
  /// ```dart
  /// await BleManager().createClient();
  /// ```
  Future<void> createClient({
    String? restoreStateIdentifier,
    RestoreStateAction? restoreStateAction,
  }) async {
    if (restoreStateAction != null) {
      final devices = await restoredState();
      restoreStateAction(devices);
    }
    await BleManager._methodChannel.invokeMethod(MethodName.createClient, <String, String?>{
      ArgumentName.restoreStateIdentifier: restoreStateIdentifier
    });
  }

  /// Frees native resources.
  ///
  /// After calling this method you must call again [createClient()] before
  /// any BLE operation.
  Future<void> destroyClient() async {
    await BleManager._methodChannel.invokeMethod(MethodName.destroyClient);
  }
  
  Stream<ScanResult> get _scanEvents {
    var scanEvents = _activeScanEvents;
    if (scanEvents == null) {
      scanEvents = 
        _scanningEventsEventChannel.receiveBroadcastStream().handleError(
          (errorJson) => throw BleError.fromJson(
            jsonDecode(errorJson.details)
          ),
          test: (error) => error is PlatformException,
        ).map(
          (scanResultJson) =>
              ScanResult.fromJson(jsonDecode(scanResultJson), this),
        );
      _activeScanEvents = scanEvents;
    }
    return scanEvents;
  }
  void _resetScanEvents() {
    _activeScanEvents = null;
  }

  /// Starts scanning for peripherals.
  ///
  /// Arguments [scanMode] and [callbackType] are Android-only,
  /// while [allowDuplicates] is iOS-only. Note that [allowDuplicates] set to
  /// false will only result in slower refresh rate for unique peripheral's
  /// advertisement data, not dismissal of it after receiving the initial one.
  /// Refer to each platform's own documentation for more detailed information.
  ///
  /// [uuids] is used to filter scan results to those whose advertised service
  /// match either of the specified UUIDs.
  ///
  /// ```dart
  /// bleManager.startPeripheralScan().listen((scanResult) {
  ///   //Scan one peripheral and stop scanning
  ///   print("Scanned Peripheral ${scanResult.peripheral.name}, RSSI ${scanResult.rssi}");
  ///   bleManager.stopPeripheralScan();
  /// });
  /// ```
  Future<Stream<ScanResult>> startPeripheralScan({
    int scanMode = ScanMode.lowPower,
    int callbackType = CallbackType.allMatches,
    List<String> uuids = const [],
    bool allowDuplicates = false,
  }) async {
    await BleManager._methodChannel.invokeMethod<void>(
      MethodName.startDeviceScan,
      <String, dynamic>{
        ArgumentName.scanMode: scanMode,
        ArgumentName.callbackType: callbackType,
        ArgumentName.uuids: uuids,
        ArgumentName.allowDuplicates: allowDuplicates,
      },
    );

    return _scanEvents;
  }

  /// Finishes the scan operation on the device.
  Future<void> stopPeripheralScan() async {
    await BleManager._methodChannel.invokeMethod<void>(MethodName.stopDeviceScan);
    // _resetScanEvents();  
  }

  /// Sets specified [LogLevel].
  ///
  /// This sets log level for both Dart and native platform.
  Future<void> setLogLevel(LogLevel logLevel) async {
    print('set log level to ${describeEnum(logLevel)}');
    return await BleManager._methodChannel.invokeMethod(
      MethodName.setLogLevel,
      <String, dynamic>{
        ArgumentName.logLevel: describeEnum(logLevel),
      },
    ).catchError((errorJson) =>
        Future.error(BleError.fromJson(jsonDecode(errorJson.details))));
  }

  LogLevel _logLevelFromString(String logLevelName) {
    print('try to get log level from: $logLevelName');
    return LogLevel.values.firstWhere(
        (e) => e.toString() == 'LogLevel.' + logLevelName.toLowerCase());
  }

  /// Returns current [LogLevel].
  Future<LogLevel> logLevel() async {
    String logLevelName =
        await BleManager._methodChannel.invokeMethod(MethodName.logLevel);
    return _logLevelFromString(logLevelName);
  }

  /// Enables Bluetooth on Android; NOOP on iOS.
  ///
  /// Passing optional [transactionId] lets you discard the result of this
  /// operation before it is finished.
  Future<void> enableRadio({String? transactionId}) async {
    await BleManager._methodChannel.invokeMethod(
      MethodName.enableRadio,
      <String, dynamic>{
        ArgumentName.transactionId: transactionId,
      },
    ).catchError((errorJson) =>
        Future.error(BleError.fromJson(jsonDecode(errorJson.details))));
  }

  /// Disables Bluetooth on Android; NOOP on iOS.
  ///
  /// Passing optional [transactionId] lets you discard the result of this
  /// operation before it is finished.
  Future<void> disableRadio({String? transactionId}) async {
    await BleManager._methodChannel.invokeMethod(
      MethodName.disableRadio,
      <String, dynamic>{
        ArgumentName.transactionId: transactionId,
      },
    ).catchError((errorJson) =>
        Future.error(BleError.fromJson(jsonDecode(errorJson.details))));
  }

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

  /// Returns current state of the Bluetooth adapter.
  Future<BluetoothState> bluetoothState() async {
    final stateStr = await BleManager._methodChannel
      .invokeMethod<String>(MethodName.getState);
    return _mapToBluetoothState(stateStr);
  }

  /// Returns a stream of changes to the state of the Bluetooth adapter.
  ///
  /// By default starts the stream with the current state, but this can
  /// overridden by passing `false` as [emitCurrentValue].
  Stream<BluetoothState> observeBluetoothState({ bool emitCurrentValue = true }) async* {
    if (emitCurrentValue == true) {
      final currentState = await bluetoothState();
      yield currentState;
    }
    yield* _adapterStateChanges.map(_mapToBluetoothState);
  }

  List<Peripheral> _parsePeripheralsJson(String peripheralsJson) {
    List list = json
        .decode(peripheralsJson)
        .map((peripheral) => Peripheral.fromJson(peripheral, this))
        .toList();
    return list.cast<Peripheral>();
  }

  /// Returns a list of [Peripheral]: on iOS known to system, on Android
  /// known to the library.
  ///
  /// If [peripheralIdentifiers] is empty, this will return an empty list.
  Future<List<Peripheral>> knownPeripherals(List<String> peripheralIdentifiers) async {
    final peripheralsJson = await BleManager._methodChannel
        .invokeMethod(MethodName.knownDevices, <String, dynamic>{
      ArgumentName.deviceIdentifiers: peripheralIdentifiers,
    });
    print('known devices json: $peripheralsJson');
    return _parsePeripheralsJson(peripheralsJson!);
  }

  /// Returns a list of [Peripheral]: on iOS connected and known to system,
  /// on Android connected and known to the library.
  ///
  /// If [serviceUUIDs] is empty, this will return an empty list.
  Future<List<Peripheral>> connectedPeripherals(List<String> serviceUuids) async {
    final peripheralsJson = await BleManager._methodChannel
        .invokeMethod<String>(MethodName.connectedDevices, <String, dynamic>{
      ArgumentName.uuids: serviceUuids,
      });
    print('connected devices json: $peripheralsJson');
    return _parsePeripheralsJson(peripheralsJson!);
  }

  /// Creates a peripheral which may not exist or be available. Since the
  /// [peripheralId] might be a UUID or a MAC address,
  /// depending on the platform, its format is not validated.
  ///
  /// On iOS [peripheralId] is unique for a particular device
  /// and will not be recognized on any different device.
  /// On Android [peripheralId] scanned on one  device may or may not be
  /// recognized on a different Android device depending on peripheral’s
  /// implementation and changes in future OS releases.
  Peripheral createUnsafePeripheral(String peripheralId, {String? name}) {
    const nameField = 'name';
    const identifierField = 'id';
    return Peripheral.fromJson({
      nameField: name,
      identifierField: peripheralId,
    }, this);
  }
}
