part of flutter_ble_lib;

extension DeviceConnection on BleManager {
  static Stream<dynamic> _peripheralConnectionStateChanges({ 
    required String? name }) {
    if (name == null) {
      print("connectionStateChangeEvents name was null. using fallback");
    }
    name ??= ChannelName.connectionStateChangeEvents;
    
    return EventChannel(name)
        .receiveBroadcastStream();
  }

  Future<void> connectToPeripheral(
    String deviceIdentifier, 
    bool isAutoConnect,
    int requestMtu, 
    bool refreshGatt,
    Duration? timeout
  ) async {
    return await BleManager._methodChannel.invokeMethod(
      MethodName.connectToDevice,
      <String, dynamic>{
        ArgumentName.deviceIdentifier: deviceIdentifier,
        ArgumentName.isAutoConnect: isAutoConnect,
        ArgumentName.requestMtu: requestMtu,
        ArgumentName.refreshGatt: refreshGatt,
        ArgumentName.timeoutMillis: timeout?.inMilliseconds
      },
    ).catchError(
      (errorJson) => Future.error(
        BleError.fromJson(jsonDecode(errorJson.details)),
      ),
    );
  }

  Future<Stream<PeripheralConnectionState>> observePeripheralConnectionState(
      String identifier, bool emitCurrentValue) async {
    final channelName = await BleManager._methodChannel.invokeMethod<String>(
      MethodName.observeConnectionState,
      <String, dynamic>{
        ArgumentName.deviceIdentifier: identifier,
        ArgumentName.emitCurrentValue: emitCurrentValue,
      },
    ).catchError(
      (errorJson) => throw BleError.fromJson(jsonDecode(errorJson.details)),
    );

    final controller = StreamController<PeripheralConnectionState>(
      onListen: () {},
    );

    final sourceStream = _peripheralConnectionStateChanges(name: channelName)
        .map((jsonString) =>
            ConnectionStateContainer.fromJson(jsonDecode(jsonString)))
        .where((connectionStateContainer) =>
            connectionStateContainer.peripheralIdentifier == identifier)
        .map((connectionStateContainer) =>
            connectionStateContainer.connectionState)
        .map((connectionStateString) {
      switch (connectionStateString.toLowerCase()) {
        case NativeConnectionState.connected:
          return PeripheralConnectionState.connected;
        case NativeConnectionState.connecting:
          return PeripheralConnectionState.connecting;
        case NativeConnectionState.disconnected:
          return PeripheralConnectionState.disconnected;
        case NativeConnectionState.disconnecting:
          return PeripheralConnectionState.disconnecting;
        default:
          throw FormatException(
            'Unrecognized value of device connection state. Value: $connectionStateString',
          );
      }
    });

    controller
        .addStream(
          sourceStream,
          cancelOnError: true,
        )
        .then((value) => controller.close());

    return controller.stream;
  }

  Future<bool> isPeripheralConnected(String peripheralIdentifier) async {
    return await _methodChannel
        .invokeMethod(MethodName.isDeviceConnected, <String, dynamic>{
      ArgumentName.deviceIdentifier: peripheralIdentifier,
    }).catchError(
      (errorJson) {
        if (errorJson is MissingPluginException) {
          return Future.error(errorJson);
        }
        return Future.error(
          BleError.fromJson(jsonDecode(errorJson.details))
        );
      }
    );
  }

  Future<void> disconnectOrCancelPeripheralConnection(
      String peripheralIdentifier) async {
    return await _methodChannel
        .invokeMethod(MethodName.cancelConnection, <String, dynamic>{
      ArgumentName.deviceIdentifier: peripheralIdentifier,
    }).catchError(
      (errorJson) => Future.error(
        BleError.fromJson(jsonDecode(errorJson.details)),
      ),
    );
  }
}