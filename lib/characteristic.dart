part of flutter_ble_lib;

abstract class _CharacteristicMetadata {
  static const String uuid = 'characteristicUuid';
  static const String isReadable = 'isReadable';
  static const String isWritableWithResponse = 'isWritableWithResponse';
  static const String isWritableWithoutResponse = 'isWritableWithoutResponse';
  static const String isNotifiable = 'isNotifiable';
  static const String isIndicatable = 'isIndicatable';
  static const String value = 'value';
}

/// Representation of a single GATT Characteristic nested inside a [Service].
///
/// It contains a single value and any number of [Descriptor]s describing that
/// value. The properties of a characteristic determine how you can use
/// a characteristic’s value, and how you access the descriptors.
class Characteristic {
  /// The [Service] containing this characteristic.
  final Service service;

  /// The UUID of this characteristic.
  final String uuid;

  bool _isReadable;
  /// True if this characteristic can be read.
  bool get isReadable => _isReadable;

  bool _isWritableWithResponse;
  /// True if this characteristic can be written with resposne.
  bool get isWritableWithResponse => _isWritableWithResponse;

  bool _isWritableWithoutResponse;
  /// True if this characteristic can be written without resposne.
  bool get isWritableWithoutResponse => _isWritableWithoutResponse;

  bool _isNotifiable;
  /// True if this characteristic can be monitored via notifications.
  bool get isNotifiable => _isNotifiable;

  bool _isIndicatable;
  /// True if this characteristic can be monitored via indications.
  bool get isIndicatable => _isIndicatable;

  Uint8List? value;

  Characteristic.fromJson(
    Map<String, dynamic> jsonObject, 
    Service service
  ) : service = service,
      uuid = jsonObject[_CharacteristicMetadata.uuid],
      _isReadable = jsonObject[_CharacteristicMetadata.isReadable],
      _isWritableWithResponse =
        jsonObject[_CharacteristicMetadata.isWritableWithResponse],
      _isWritableWithoutResponse =
        jsonObject[_CharacteristicMetadata.isWritableWithoutResponse],
      _isNotifiable = jsonObject[_CharacteristicMetadata.isNotifiable],
      _isIndicatable = jsonObject[_CharacteristicMetadata.isIndicatable] {
    final valueStr = jsonObject[_CharacteristicMetadata.value];
    if (valueStr != null && valueStr is String) {
      value = base64Decode(valueStr);
    }
  }

  void _update({ required Map<String, dynamic> jsonObject }) {
    final isReadable = jsonObject[_CharacteristicMetadata.isReadable];
    if (isReadable != null && isReadable is bool) {
      _isReadable = isReadable;
    }

    final isWritableWithResponse = 
      jsonObject[_CharacteristicMetadata.isWritableWithResponse];
    if (isWritableWithResponse != null && isWritableWithResponse is bool) {
      _isWritableWithResponse = isWritableWithResponse;
    }

    final isWritableWithoutResponse =
      jsonObject[_CharacteristicMetadata.isWritableWithoutResponse];
    if (isWritableWithoutResponse != null && isWritableWithoutResponse is bool) {
      _isWritableWithoutResponse = isWritableWithoutResponse;
    }

    final isNotifiable = jsonObject[_CharacteristicMetadata.isNotifiable];
    if (isNotifiable != null && isNotifiable is bool) {
      _isNotifiable = isNotifiable;
    }

    final isIndicatable = jsonObject[_CharacteristicMetadata.isIndicatable];
    if (isIndicatable != null && isIndicatable is bool) {
      _isIndicatable = isIndicatable;
    }

    final valueStr = jsonObject[_CharacteristicMetadata.value];
    if (valueStr != null && valueStr is String) {
      value = base64Decode(valueStr);
    }
  }


  /// Reads the value of this characteristic.
  ///
  /// The value can be read only if [isReadable] is `true`.
  Future<Uint8List> read() async {
    String? rawValue;
    try {
      rawValue = await BleManager._methodChannel
          .invokeMethod<String>(
            MethodName.readCharacteristicForDevice,
            <String, dynamic>{
              ArgumentName.deviceIdentifier: service.peripheral.identifier,
              ArgumentName.serviceUuid: service.uuid,
              ArgumentName.characteristicUuid: uuid,
            },
          );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    Map<String, dynamic> charObject = jsonDecode(rawValue!);
    _update(jsonObject: charObject);

    return value!;
  }

  /// Writes to the value of this characteristic.
  ///
  /// The value can be written only if [isWritableWithResponse] or
  /// [isWritableWithoutResponse] is `true` and argument [withResponse] is
  /// set accordingly.
  Future<void> write(
    Uint8List value,
    {required bool withResponse,
  }) async {
    String? rawValue;
    try {
      rawValue = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.writeCharacteristicForDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: service.peripheral.identifier,
          ArgumentName.serviceUuid: service.uuid,
          ArgumentName.characteristicUuid: uuid,
          ArgumentName.value: value,
          ArgumentName.withResponse: withResponse,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
    if (rawValue is String == false) {
      print('$rawValue');
    }

    Map<String, dynamic> charObject = jsonDecode(rawValue!);
    _update(jsonObject: charObject);
  }

  /// Returns a [Stream] of notifications/indications emitted by this
  /// characteristic.
  ///
  /// Library chooses notifications over indications, if both are supported.
  ///
  /// Subscribing to the returned object enables the notifications/indications
  /// on the peripheral. Cancelling the last subscription disables the
  /// notifications/indications on this characteristic.
  Future<Stream<Uint8List>> monitor() async {
    String? channelName; 
    try {
      channelName = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.monitorCharacteristicForDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: service.peripheral.identifier,
          ArgumentName.serviceUuid: service.uuid,
          ArgumentName.characteristicUuid: uuid,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
    final channel = EventChannel(channelName!);
    final rawStream = channel.receiveBroadcastStream().cast<String>();
    final stream = rawStream.map((rawValue) {
      Map<String, dynamic> charObject = jsonDecode(rawValue);
      _update(jsonObject: charObject);
      return value!;
    });

    return stream;
  } 

  /// Returns a list of [Descriptor]s of this characteristic.
  Future<List<Descriptor>> descriptors() async {
    String? jsonString;
    try {
      jsonString = await BleManager._methodChannel.invokeMethod(
        MethodName.descriptorsForDevice, 
        <String, dynamic>{
          ArgumentName.deviceIdentifier: service.peripheral.identifier,
          ArgumentName.serviceUuid: service.uuid,
          ArgumentName.characteristicUuid: uuid,
        }
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    final jsonObject = jsonDecode(jsonString!);
    final jsonDescriptors =
      (jsonObject as List<dynamic>).cast<Map<String, dynamic>>();

    return jsonDescriptors.map((jsonDescriptor) {
      return Descriptor.fromJson(jsonDescriptor, this);
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Characteristic &&
          runtimeType == other.runtimeType &&
          service == other.service &&
          uuid == other.uuid &&
          isReadable == other.isReadable &&
          isWritableWithResponse == other.isWritableWithResponse &&
          isWritableWithoutResponse == other.isWritableWithoutResponse &&
          isNotifiable == other.isNotifiable &&
          isIndicatable == other.isIndicatable;

  @override
  int get hashCode =>
      service.hashCode ^
      uuid.hashCode ^
      isReadable.hashCode ^
      isWritableWithResponse.hashCode ^
      isWritableWithoutResponse.hashCode ^
      isNotifiable.hashCode ^
      isIndicatable.hashCode;

  /// Returns a string representation of this characteristic in a format that
  /// contains all its properties and [Service].
  @override
  String toString() {
    return 'Characteristic{service: $service,'
        ' uuid: $uuid,'
        ' isReadable: $isReadable,'
        ' isWritableWithResponse: $isWritableWithResponse,'
        ' isWritableWithoutResponse: $isWritableWithoutResponse,'
        ' isNotifiable: $isNotifiable,'
        ' isIndicatable: $isIndicatable}'
        ' CharacteristicWithValue{value = ${value.toString()}';
  }
}
