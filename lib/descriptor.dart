part of flutter_ble_lib;

abstract class _DescriptorMetadata {
  static const String uuid = 'descriptorUuid';
  static const String value = 'value';
}

class Descriptor {
  final Characteristic characteristic;
  final String uuid;

  Uint8List? value;

  Descriptor.fromJson(
    Map<String, dynamic> jsonObject,
    this.characteristic,
  ) : uuid = jsonObject[_DescriptorMetadata.uuid] {
    final valueStr = jsonObject[_DescriptorMetadata.value];
    if (valueStr != null && valueStr is String) {
      value = base64Decode(valueStr);
    }
  }

  void _update({
    required Map<String, dynamic> jsonObject
  }) {
    final valueStr = jsonObject[_DescriptorMetadata.value];
    if (valueStr != null && valueStr is String) {
      value = base64Decode(valueStr);
    }
  }

  Future<Uint8List> read() async {
    String? jsonResponse;
    try {
      jsonResponse = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.readDescriptorForDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: characteristic.service.peripheral.identifier,
          ArgumentName.serviceUuid: characteristic.service.uuid,
          ArgumentName.characteristicUuid: characteristic.uuid,
          ArgumentName.descriptorUuid: uuid,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    Map<String, dynamic> jsonObject = jsonDecode(jsonResponse!);
    _update(jsonObject: jsonObject);

    return value!;
  }


  Future<void> write(Uint8List valueToWrite) async {
    String? jsonResponse;
    try {
      jsonResponse = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.writeDescriptorForDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: characteristic.service.peripheral.identifier,
          ArgumentName.serviceUuid: characteristic.service.uuid,
          ArgumentName.characteristicUuid: characteristic.uuid,
          ArgumentName.descriptorUuid: uuid,
          ArgumentName.value: valueToWrite,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    Map<String, dynamic> jsonObject = jsonDecode(jsonResponse!);
    _update(jsonObject: jsonObject);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Descriptor &&
          runtimeType == other.runtimeType &&
          characteristic == other.characteristic &&
          uuid == other.uuid;

  @override
  int get hashCode => characteristic.hashCode ^ uuid.hashCode;
}
