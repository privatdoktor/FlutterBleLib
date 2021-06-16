part of flutter_ble_lib;

abstract class DescriptorMetadata {
  static const String uuid = 'descriptorUuid';
  static const String value = 'value';
}

class Descriptor {
  final Characteristic characteristic;
  final String uuid;

  Descriptor(
    this.uuid,
    this.characteristic,
  );

  Future<Uint8List> read() async {
    final descWithVal = await characteristic.service.peripheral.readDescriptor(
      characteristic.service.uuid,
      characteristic.uuid,
      uuid
    );
    return descWithVal.value;
  }


  Future<void> write(Uint8List value) async {
    await characteristic.service.peripheral.writeDescriptor(
      characteristic.service.uuid,
      characteristic.uuid,
      uuid, 
      value
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Descriptor &&
          runtimeType == other.runtimeType &&
          characteristic == other.characteristic &&
          uuid == other.uuid;

  @override
  int get hashCode =>
      characteristic.hashCode ^ uuid.hashCode;
}

class DescriptorWithValue extends Descriptor {
  Uint8List value;

  DescriptorWithValue(
    this.value,
    String uuid,
    Characteristic characteristic,
  ) : super(uuid, characteristic);
}
