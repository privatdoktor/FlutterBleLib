part of flutter_ble_lib;

abstract class _ServiceMetadata {
  static const String uuid = 'serviceUuid';
}

/// A collection of [Characteristic]s and associated behaviors.
class Service {

  /// [Peripheral] containing this service.
  final Peripheral peripheral;


  /// The UUID of this service.
  final String uuid;

  Service.fromJson(
    Map<String, dynamic> jsonObject,
    Peripheral peripheral,
  ) : peripheral = peripheral,
      uuid = jsonObject[_ServiceMetadata.uuid];

  Future<List<Characteristic>> discoverCharacteristics() async {
    return await peripheral.discoverCharacteristics(uuid);
  }

  /// Returns a list of [Characteristic]s of this service.
  Future<List<Characteristic>> characteristics() async {
    return await peripheral.characteristics(uuid);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Service &&
          runtimeType == other.runtimeType &&
          peripheral.identifier == other.peripheral.identifier &&
          uuid == other.uuid;

  @override
  int get hashCode => peripheral.hashCode ^ uuid.hashCode;

  /// Returns a string representation of this service in a format that exposes
  /// [Peripheral.identifier] and [uuid].
  @override
  String toString() {
    return 'Service{peripheralId: ${peripheral.identifier}, uuid: $uuid}';
  }
}
