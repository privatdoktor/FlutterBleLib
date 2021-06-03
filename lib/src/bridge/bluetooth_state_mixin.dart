part of _internal;

mixin BluetoothStateMixin on FlutterBLE {

  static const EventChannel _adapterStateChangesEventChannel = 
    EventChannel(ChannelName.adapterStateChanges);
  static Stream<String> get _adapterStateChanges =>
      _adapterStateChangesEventChannel
          .receiveBroadcastStream().cast();

  Future<void> enableRadio(String transactionId) async {
    await _methodChannel.invokeMethod(
      MethodName.enableRadio,
      <String, dynamic>{
        ArgumentName.transactionId: transactionId,
      },
    ).catchError((errorJson) =>
        Future.error(BleError.fromJson(jsonDecode(errorJson.details))));
  }

  Future<void> disableRadio(String transactionId) async {
    await _methodChannel.invokeMethod(
      MethodName.disableRadio,
      <String, dynamic>{
        ArgumentName.transactionId: transactionId,
      },
    ).catchError((errorJson) =>
        Future.error(BleError.fromJson(jsonDecode(errorJson.details))));
  }

  Future<BluetoothState> state() => _methodChannel
      .invokeMethod<String>(MethodName.getState)
      .then(_mapToBluetoothState);

  Stream<BluetoothState> observeBluetoothState(bool emitCurrentValue) async* {
    if (emitCurrentValue == true) {
      final currentState = await state();
      yield currentState;
    }
    yield* _adapterStateChanges.map(_mapToBluetoothState);
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
}
