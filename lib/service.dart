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

  Future<List<Characteristic>> discoverCharacteristics({
    List<String>? characteristicUuids
  }) async {
    String? jsonString;
    try {
      jsonString = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.discoverCharacteristics,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: peripheral.identifier,
          ArgumentName.serviceUuid: uuid,
          ArgumentName.characteristicUuids: characteristicUuids,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    } catch (ex) {
      rethrow;
    }

    final jsonObject = jsonDecode(jsonString!);
    final jsonCharacteristics = 
      (jsonObject as List<dynamic>).cast<Map<String, dynamic>>();

    return jsonCharacteristics.map((characteristicJson) {
      return Characteristic.fromJson(characteristicJson, this);
    }).toList();
  }

  /// Returns a list of [Characteristic]s of this service.
  Future<List<Characteristic>> characteristics() async {
    String? jsonString;
    try {
      await BleManager._methodChannel.invokeMethod<String>(
        MethodName.characteristics,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: peripheral.identifier,
          ArgumentName.serviceUuid: uuid,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    final jsonObject = jsonDecode(jsonString!);
    final jsonCharacteristics = 
      (jsonObject as List<dynamic>).cast<Map<String, dynamic>>();

    return jsonCharacteristics.map((characteristicJson) {
      return Characteristic.fromJson(characteristicJson, this);
    }).toList();
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
