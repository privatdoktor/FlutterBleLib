part of flutter_ble_lib;

extension Scanning on BleManager {
  static const EventChannel _scanningEventsEventChannel =
    EventChannel(ChannelName.scanningEvents);
  Stream<ScanResult>? _activeScanEvents;
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
              ScanResult.fromJson(jsonDecode(scanResultJson), _manager),
        );
      _activeScanEvents = scanEvents;
    }
    return scanEvents;
  }
  void _resetScanEvents() {
    _activeScanEvents = null;
  }

  Future<Stream<ScanResult>> startDeviceScan(
    int scanMode,
    int callbackType,
    List<String> uuids,
    bool allowDuplicates,
  ) async {
    await BleManager._methodChannel.invokeMethod(
      MethodName.createScanningEventChannel
    );
    final streamController = StreamController<ScanResult>.broadcast(
      onListen: () => 
      BleManager._methodChannel.invokeMethod(
        MethodName.startDeviceScan,
        <String, dynamic>{
          ArgumentName.scanMode: scanMode,
          ArgumentName.callbackType: callbackType,
          ArgumentName.uuids: uuids,
          ArgumentName.allowDuplicates: allowDuplicates,
        },
      ),
      onCancel: () => stopDeviceScan(),
    );

    streamController
        .addStream(_scanEvents, cancelOnError: true)
        .then((_) => streamController.close());

    return streamController.stream;
  }

  Future<void> stopDeviceScan() async {
    await BleManager._methodChannel.invokeMethod(MethodName.stopDeviceScan);
    _resetScanEvents();
    return;
  }
}
