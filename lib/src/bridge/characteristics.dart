part of flutter_ble_lib;

extension Characteristics on BleManager {  
  Stream<String> _characteristicsMonitoringEvents({ required String? name }) {
    if (name == null) {
      print("characteristicsMonitoringEvents name was null. using fallback");
    }
    name ??= ChannelName.monitorCharacteristic;
    return EventChannel(name)
          .receiveBroadcastStream()
          .cast();
  }

  Future<Uint8List> readCharacteristicForIdentifier(
    Peripheral peripheral,
    int characteristicIdentifier,
    String transactionId,
  ) =>
      BleManager._methodChannel
          .invokeMethod<String>(
            MethodName.readCharacteristicForIdentifier,
            <String, dynamic>{
              ArgumentName.characteristicIdentifier: characteristicIdentifier,
              ArgumentName.transactionId: transactionId
            },
          )
          .catchError((errorJson) => Future<String>.error(
              BleError.fromJson(jsonDecode(errorJson.details))))
          .then((rawValue) {
            return _parseCharacteristicWithValueWithTransactionIdResponse(
                    peripheral, rawValue)
                .value;
          });

  Future<CharacteristicWithValue> readCharacteristicForDevice(
    Peripheral peripheral,
    String serviceUuid,
    String characteristicUuid,
    String transactionId,
  ) =>
      BleManager._methodChannel
          .invokeMethod<String>(
            MethodName.readCharacteristicForDevice,
            <String, dynamic>{
              ArgumentName.deviceIdentifier: peripheral.identifier,
              ArgumentName.serviceUuid: serviceUuid,
              ArgumentName.characteristicUuid: characteristicUuid,
              ArgumentName.transactionId: transactionId
            },
          )
          .catchError((errorJson) => Future<String>.error(
              BleError.fromJson(jsonDecode(errorJson.details))))
          .then((rawValue) {
            return _parseCharacteristicWithValueWithTransactionIdResponse(
                peripheral, rawValue);
          });

  Future<CharacteristicWithValue> readCharacteristicForService(
    Peripheral peripheral,
    int serviceIdentifier,
    String characteristicUuid,
    String transactionId,
  ) =>
      BleManager._methodChannel
          .invokeMethod<String>(
            MethodName.readCharacteristicForService,
            <String, dynamic>{
              ArgumentName.serviceIdentifier: serviceIdentifier,
              ArgumentName.characteristicUuid: characteristicUuid,
              ArgumentName.transactionId: transactionId
            },
          )
          .catchError((errorJson) => Future<String>.error(
              BleError.fromJson(jsonDecode(errorJson.details))))
          .then((rawValue) {
            return _parseCharacteristicWithValueWithTransactionIdResponse(
                peripheral, rawValue);
          });

  Future<void> writeCharacteristicForIdentifier(
    Peripheral peripheral,
    int characteristicIdentifier,
    Uint8List value,
    bool withResponse,
    String transactionId,
  ) =>
      BleManager._methodChannel.invokeMethod<String>(
        MethodName.writeCharacteristicForIdentifier,
        <String, dynamic>{
          ArgumentName.characteristicIdentifier: characteristicIdentifier,
          ArgumentName.value: value,
          ArgumentName.withResponse: withResponse,
          ArgumentName.transactionId: transactionId,
        },
      ).catchError((errorJson) => Future<String>.error(
          BleError.fromJson(jsonDecode(errorJson.details))));

  Future<Characteristic> writeCharacteristicForDevice(
          Peripheral peripheral,
          String serviceUuid,
          String characteristicUuid,
          Uint8List value,
          bool withResponse,
          String transactionId) =>
      BleManager._methodChannel
          .invokeMethod<String>(
            MethodName.writeCharacteristicForDevice,
            <String, dynamic>{
              ArgumentName.deviceIdentifier: peripheral.identifier,
              ArgumentName.serviceUuid: serviceUuid,
              ArgumentName.characteristicUuid: characteristicUuid,
              ArgumentName.value: value,
              ArgumentName.withResponse: withResponse,
              ArgumentName.transactionId: transactionId,
            },
          )
          .catchError((errorJson) => Future<String>.error(
              BleError.fromJson(jsonDecode(errorJson.details))))
          .then(
            (rawJsonValue) =>
                _parseCharacteristicResponse(peripheral, rawJsonValue),
          );

  Future<Characteristic> writeCharacteristicForService(
    Peripheral peripheral,
    int serviceIdentifier,
    String characteristicUuid,
    Uint8List value,
    bool withResponse,
    String transactionId,
  ) =>
      BleManager._methodChannel
          .invokeMethod<String>(
            MethodName.writeCharacteristicForService,
            <String, dynamic>{
              ArgumentName.serviceIdentifier: serviceIdentifier,
              ArgumentName.characteristicUuid: characteristicUuid,
              ArgumentName.value: value,
              ArgumentName.withResponse: withResponse,
              ArgumentName.transactionId: transactionId,
            },
          )
          .catchError((errorJson) => Future<String>.error(
              BleError.fromJson(jsonDecode(errorJson.details))))
          .then(
            (rawJsonValue) =>
                _parseCharacteristicResponse(peripheral, rawJsonValue),
          );

  Future<Stream<Uint8List>> monitorCharacteristicForIdentifier(
    Peripheral peripheral,
    int characteristicIdentifier,
    String transactionId,
  ) async {
    final channelName = await BleManager._methodChannel.invokeMethod(
          MethodName.monitorCharacteristicForIdentifier,
          <String, dynamic>{
            ArgumentName.characteristicIdentifier: characteristicIdentifier,
            ArgumentName.transactionId: transactionId,
          },
        );

    bool characteristicFilter(
      CharacteristicWithValueAndTransactionId characteristic,
    ) {
      if (characteristic._id != characteristicIdentifier) {
        return false;
      }
      return equalsIgnoreAsciiCase(
        transactionId,
        characteristic._transactionId ?? '',
      );
    }

    ;

    return _createMonitoringStream(
      // startMonitoring,
      characteristicFilter,
      peripheral,
      transactionId,
      channelName,
    ).map((characteristicWithValue) => characteristicWithValue.value);
  }

  Future<Stream<CharacteristicWithValue>> monitorCharacteristicForDevice(
    Peripheral peripheral,
    String serviceUuid,
    String characteristicUuid,
    String transactionId,
  ) async {
    final channelName = await BleManager._methodChannel.invokeMethod(
          MethodName.monitorCharacteristicForDevice,
          <String, dynamic>{
            ArgumentName.deviceIdentifier: peripheral.identifier,
            ArgumentName.serviceUuid: serviceUuid,
            ArgumentName.characteristicUuid: characteristicUuid,
            ArgumentName.transactionId: transactionId,
          },
        );

    bool characteristicsFilter(
            CharacteristicWithValueAndTransactionId characteristic) =>
        equalsIgnoreAsciiCase(characteristicUuid, characteristic.uuid) &&
        equalsIgnoreAsciiCase(serviceUuid, characteristic.service.uuid) &&
        equalsIgnoreAsciiCase(
            transactionId, characteristic._transactionId ?? '');

    return _createMonitoringStream(
      // startMonitoring,
      characteristicsFilter,
      peripheral,
      transactionId,
      channelName,
    );
  }

  Future<Stream<CharacteristicWithValue>> monitorCharacteristicForService(
    Peripheral peripheral,
    int serviceIdentifier,
    String characteristicUuid,
    String transactionId,
  ) async {
    final channelName = await BleManager._methodChannel.invokeMethod(
          MethodName.monitorCharacteristicForService,
          <String, dynamic>{
            ArgumentName.serviceIdentifier: serviceIdentifier,
            ArgumentName.characteristicUuid: characteristicUuid,
            ArgumentName.transactionId: transactionId,
          },
        );

    bool characteristicFilter(
            CharacteristicWithValueAndTransactionId characteristic) =>
        equalsIgnoreAsciiCase(characteristicUuid, characteristic.uuid) &&
        serviceIdentifier == characteristic.service._id &&
        equalsIgnoreAsciiCase(
            transactionId, characteristic._transactionId ?? '');

    return _createMonitoringStream(
      // startMonitoring,
      characteristicFilter,
      peripheral,
      transactionId,
      channelName
    );
  }

  Stream<CharacteristicWithValueAndTransactionId> _createMonitoringStream(
    // void Function() onListen,
    bool Function(CharacteristicWithValueAndTransactionId) filter,
    Peripheral peripheral,
    String transactionId,
    String? channelName,
  ) {
    final stream =
        _characteristicsMonitoringEvents(name: channelName)
            .map((rawValue) {
              return _parseCharacteristicWithValueWithTransactionIdResponse(
                  peripheral, rawValue);
            })
            .where(filter)
            .handleError((errorJson) =>
                _throwErrorIfMatchesWithTransactionId(errorJson, transactionId))
            .transform<CharacteristicWithValueAndTransactionId>(
                CancelOnErrorStreamTransformer());
    final streamController =
        StreamController<CharacteristicWithValueAndTransactionId>.broadcast(
      onListen: null,
      onCancel: () => cancelTransaction(transactionId),
    );

    streamController
        .addStream(stream, cancelOnError: true)
        .then((_) => streamController.close());

    return streamController.stream;
  }

  CharacteristicWithValueAndTransactionId
      _parseCharacteristicWithValueWithTransactionIdResponse(
          Peripheral peripheral, String? rawJsonValue) {
    if (rawJsonValue == null) {
      throw FormatException(
          'Characteristic deserialization received unexpected null value');
    }
    Map<String, dynamic> rootObject = jsonDecode(rawJsonValue);
    final service = Service.fromJson(rootObject, peripheral, _manager);

    var transactionId = rootObject['transactionId'];
    return CharacteristicWithValueAndTransactionId.fromJson(
            rootObject['characteristic'], service, _manager)
        .setTransactionId(transactionId);
  }

  Characteristic _parseCharacteristicResponse(
      Peripheral peripheral, String? rawJsonValue) {
    if (rawJsonValue == null) {
      throw FormatException(
          'Characteristic deserialization received unexpected null value');
    }
    Map<String, dynamic> rootObject = jsonDecode(rawJsonValue);
    final service = Service.fromJson(rootObject, peripheral, _manager);

    return Characteristic.fromJson(
        rootObject['characteristic'], service, _manager);
  }

  void _throwErrorIfMatchesWithTransactionId(
      PlatformException errorJson, String transactionId) {
    if (errorJson is PlatformException == false) {
      return;
    }
    final errorDetails = jsonDecode(errorJson.details);
    if (transactionId != errorDetails['transactionId']) {
      return;
    }
    throw BleError.fromJson(errorDetails);
  }
}

class CharacteristicWithValueAndTransactionId extends CharacteristicWithValue {
  String? _transactionId;

  CharacteristicWithValueAndTransactionId.fromJson(
    Map<String, dynamic> jsonObject,
    Service service,
    BleManager manager,
  ) : super.fromJson(jsonObject, service, manager);

  CharacteristicWithValueAndTransactionId setTransactionId(
      String? transactionId) {
    _transactionId = transactionId;
    return this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is CharacteristicWithValueAndTransactionId &&
          runtimeType == other.runtimeType &&
          _transactionId == other._transactionId;

  @override
  int get hashCode => super.hashCode ^ _transactionId.hashCode;

  @override
  String toString() =>
      super.toString() +
      ' CharacteristicWithValueAndTransactionId{transactionId: $_transactionId}';
}
