part of flutter_ble_lib;

abstract class CharacteristicMetadata {
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

  /// True if this characteristic can be read.
  final bool isReadable;

  /// True if this characteristic can be written with resposne.
  final bool isWritableWithResponse;

  /// True if this characteristic can be written without resposne.
  final bool isWritableWithoutResponse;

  /// True if this characteristic can be monitored via notifications.
  final bool isNotifiable;

  /// True if this characteristic can be monitored via indications.
  final bool isIndicatable;

  Characteristic.fromJson(Map<String, dynamic> jsonObject, Service service,)
      : service = service,
        uuid = jsonObject[CharacteristicMetadata.uuid],
        isReadable = jsonObject[CharacteristicMetadata.isReadable],
        isWritableWithResponse =
            jsonObject[CharacteristicMetadata.isWritableWithResponse],
        isWritableWithoutResponse =
            jsonObject[CharacteristicMetadata.isWritableWithoutResponse],
        isNotifiable = jsonObject[CharacteristicMetadata.isNotifiable],
        isIndicatable = jsonObject[CharacteristicMetadata.isIndicatable];


  /// Reads the value of this characteristic.
  ///
  /// The value can be read only if [isReadable] is `true`.
  Future<Uint8List> read() async {
    final charWithVal =
      await service.peripheral.readCharacteristic(service.uuid, uuid);
    return charWithVal.value;
  }

  /// Writes to the value of this characteristic.
  ///
  /// The value can be written only if [isWritableWithResponse] or
  /// [isWritableWithoutResponse] is `true` and argument [withResponse] is
  /// set accordingly.
  Future<void> write(
    Uint8List value,
    bool withResponse,
  ) async {
    await service.peripheral.writeCharacteristic(
      service.uuid, 
      uuid, 
      value, 
      withResponse
    );
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
    final stream = 
      await service.peripheral.monitorCharacteristic(service.uuid, uuid);

    return stream.map((charWithValue) => charWithValue.value);
  }

  /// Returns a list of [Descriptor]s of this characteristic.
  Future<List<Descriptor>> descriptors() async {
    return await service.peripheral.descriptorsForCharacteristic(
      service.uuid,
      uuid
    );
  }

  /// Reads the value of a [Descriptor] identified by [descriptorUuid].
  Future<DescriptorWithValue> readDescriptor(
    String descriptorUuid, {
    String? transactionId,
  }) async {
    return service.peripheral.readDescriptor(
      service.uuid,
      uuid,
      descriptorUuid
    );
  }

  /// Writes the [value] of a [Descriptor] identified by [descriptorUuid].
  Future<Descriptor> writeDescriptor(
    String descriptorUuid,
    Uint8List value
  ) async {
    return service.peripheral.writeDescriptor(
      service.uuid, 
      uuid, 
      descriptorUuid, 
      value
    );
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
        ' isIndicatable: $isIndicatable}';
  }
}

/// [Characteristic] extended with [value] property.
///
/// This type is created to support chaining of operations on the characteristic
/// when it was first read from [Peripheral] or [Service].
class CharacteristicWithValue extends Characteristic {
  Uint8List value;

  CharacteristicWithValue.fromJson(
    Map<String, dynamic> jsonObject,
    Service service,
  ) : value = base64Decode(jsonObject[CharacteristicMetadata.value]),
      super.fromJson(jsonObject, service);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        super == other &&
            other is CharacteristicWithValue &&
            value.toString() == other.value.toString() &&
            runtimeType == other.runtimeType;
  }

  @override
  int get hashCode => super.hashCode;

  @override
  String toString() {
    return super.toString() +
        ' CharacteristicWithValue{value = ${value.toString()}';
  }
}
