part of flutter_ble_lib;

abstract class _ConnectionStateContainerMetadata {
  static const String peripheralIdentifier = 'peripheralIdentifier';
  static const String connectionState = 'connectionState';
}

class _ConnectionStateContainer {
  String peripheralIdentifier;
  String connectionState;

  _ConnectionStateContainer.fromJson(Map<String, dynamic> json)
      : peripheralIdentifier =
            json[_ConnectionStateContainerMetadata.peripheralIdentifier],
        connectionState =
            json[_ConnectionStateContainerMetadata.connectionState];
}

abstract class _PeripheralMetadata {
  static const name = 'name';
  static const identifier = 'id';
}

/// Representation of a unique peripheral
///
/// This class allows for managing the connection, discovery,
/// retrieving [Service]s, [Characteristic]s and [Descriptor]s and has
/// convenience methods for manipulation of the latter two.
///
/// Only [connect()], [observeConnectionState()], [isConnected()] and
/// [disconnectOrCancelConnection()] can be used if peripheral is not connected.
class Peripheral {
  static const int NO_MTU_NEGOTIATION = 0;

  final String? name;
  final String identifier;

  Peripheral.fromJson(Map<String, dynamic> json)
      : name = json[_PeripheralMetadata.name],
        identifier = json[_PeripheralMetadata.identifier];

// ++MH++
  /// Connects to the peripheral.
  ///
  /// Optional [isAutoConnect] controls whether to directly connect to the
  /// remote peripheral (`false`) or to automatically connect as soon as the
  /// remote peripheral becomes available (true). (Android only)
  ///
  /// Optional [requestMtu] size will be negotiated to this value. It is not
  /// guaranteed to get it after connection is successful. (Android only)
  /// iOS by default requests about 186 MTU size and there's nothing anyone can
  /// do about it.
  /// **NOTE**: if MTU has been requested on this step, then there's no way
  /// to retrieve its value later on.
  ///
  /// Passing `true` as [refreshGatt] will reset services cache. This option may
  /// be useful when a peripheral's firmware was updated and it's
  /// services/characteristics were added/removed/altered. (Android only)
  ///
  /// Optional [timeout] is used to define delay after which the connection is
  /// automatically cancelled. In case of race condition were connection
  /// is established right after timeout event, peripheral will be disconnected
  /// immediately. Timeout may happen earlier than specified due to OS
  /// specific behavior.
  Future<void> connect({
    bool isAutoConnect = false,
    int requestMtu = NO_MTU_NEGOTIATION,
    bool refreshGatt = false,
    Duration? timeout, // can ignore
  }) async {
    try {
      return await BleManager._methodChannel.invokeMethod<void>(
        MethodName.connectToDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.isAutoConnect: isAutoConnect,
          ArgumentName.requestMtu: requestMtu,
          ArgumentName.refreshGatt: refreshGatt,
          ArgumentName.timeoutMillis: timeout?.inMilliseconds
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
  }

  static Stream<dynamic> _peripheralConnectionStateChanges({
    required String name,
  }) {    
    return EventChannel(name).receiveBroadcastStream();
  }

// ++NTH++
  /// Returns a stream of [PeripheralConnectionState].
  ///
  Future<Stream<PeripheralConnectionState>> observeConnectionState({
    bool emitCurrentValue = false
  }) async {
    final String? channelName;
    try {
      channelName = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.observeConnectionState,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.emitCurrentValue: emitCurrentValue,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    } catch (e) {
      rethrow;
    }

    final stream = _peripheralConnectionStateChanges(name: channelName!)
        .map(
          (jsonString) => _ConnectionStateContainer.fromJson(
            jsonDecode(jsonString)
          ).connectionState
        )
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
    return stream;
  }

// ++MH++
  /// Returns whether this peripheral is connected.
  Future<bool> isConnected() async {
    try {
      final raw = await BleManager._methodChannel.invokeMethod<bool>(
        MethodName.isDeviceConnected, 
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
        });
      return raw!;
    } on MissingPluginException catch (_) {
      rethrow;
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
  } 

// ++MH++
  /// Disconnects from this peripheral if it's connected or cancels pending
  /// connection.
  Future<void> disconnectOrCancelConnection() async {
    try {
      await BleManager._methodChannel.invokeMethod<void>(
        MethodName.cancelConnection, 
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
      });
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;    }
  }

// ++MH++
  Future<List<Service>> discoverServices({List<String>? serviceUuids}) async {
    String? jsonString;
    try {
      jsonString = await BleManager._methodChannel.invokeMethod(
        MethodName.discoverServices,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.serviceUuids: serviceUuids,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
    final decodedJson =
        (jsonDecode(jsonString!) as List<dynamic>).cast<Map<String, dynamic>>();

    return decodedJson
        .map((serviceJson) =>
            Service.fromJson(serviceJson, this))
        .toList();
  }

// ++MH++
  Future<List<Characteristic>> discoverCharacteristics(
    String serviceUuid,
    {List<String>? characteristicUuids
  }) async {
    String? jsonString;
    try {
      jsonString = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.discoverCharacteristics,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.serviceUuid: serviceUuid,
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

    Map<String, dynamic> jsonObject = jsonDecode(jsonString!);
    final jsonCharacteristics = (jsonObject['characteristics'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    final service = Service.fromJson(jsonObject, this);

    return jsonCharacteristics.map((characteristicJson) {
      return Characteristic.fromJson(characteristicJson, service);
    }).toList();
  }


// ++MH++
  /// Returns a list of [Service]s of this peripheral.
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<List<Service>> services() async {
    String? jsonString;
    try {
      jsonString = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.services,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    final decodedJson =
        (jsonDecode(jsonString!) as List<dynamic>).cast<Map<String, dynamic>>();

    return decodedJson
        .map((serviceJson) =>
            Service.fromJson(serviceJson, this))
        .toList();
  }

// ++MH++
  /// Returns a list of discovered [Characteristic]s of a [Service] identified
  /// by [servicedUuid].
  ///
  /// [servicedUuid] must be specified as characteristics only for that
  /// service are returned.
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<List<Characteristic>> characteristics(String serviceUuid) async {
    String? jsonString;
    try {
      await BleManager._methodChannel.invokeMethod<String>(
        MethodName.characteristics,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.serviceUuid: serviceUuid,
        },
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    Map<String, dynamic> jsonObject = jsonDecode(jsonString!);
    final jsonCharacteristics = (jsonObject['characteristics'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final service = Service.fromJson(jsonObject, this);

    return jsonCharacteristics.map((characteristicJson) {
      return Characteristic.fromJson(characteristicJson, service);
    }).toList();
  }

// ++MH++
  /// Reads RSSI for the peripheral.
  ///
  Future<int> rssi() async {
    try {
      final raw = 
        await BleManager._methodChannel.invokeMethod<int>(
          MethodName.rssi, <String, dynamic>{
            ArgumentName.deviceIdentifier: identifier,
          }
        );
      return raw!;
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
  }

// ++NTH++
  /// Requests new MTU value for current connection and return the negotiation
  /// result on Android, reads MTU on iOS.
  ///
  /// This function currently is not doing anything on iOS platform as
  /// MTU is requested automatically around 186.
  ///
  ///
  /// If MTU has been requested in [connect()] this method will end with [BleError].
  Future<int> requestMtu(int mtu) async {
    try {
      final raw = await BleManager._methodChannel.invokeMethod<int>(
        MethodName.requestMtu, <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.mtu: mtu,
        }
      );
      return raw!;
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
  }

  Characteristic _parseCharacteristic(String rawJsonValue) {
    Map<String, dynamic> rootObject = jsonDecode(rawJsonValue);
    final service = Service.fromJson(rootObject, this);

    return Characteristic.fromJson(
      rootObject['characteristic'], 
      service
    );
  }

  CharacteristicWithValue _parseCharacteristicWithValue(String rawJsonValue) {
    Map<String, dynamic> rootObject = jsonDecode(rawJsonValue);
    final service = Service.fromJson(rootObject, this);
    final charWithValue = CharacteristicWithValue.fromJson(
      rootObject['characteristic'], 
      service
    );

    return charWithValue;
  }

// ++MH++
  /// Reads value of [Characteristic] matching specified UUIDs.
  ///
  /// Returns value of characteristic with [characteristicUuid] for service with
  /// [serviceUuid].
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<CharacteristicWithValue> readCharacteristic(
    String serviceUuid,
    String characteristicUuid
  ) async {
    String? rawValue;
    try {
      rawValue = await BleManager._methodChannel
          .invokeMethod<String>(
            MethodName.readCharacteristicForDevice,
            <String, dynamic>{
              ArgumentName.deviceIdentifier: identifier,
              ArgumentName.serviceUuid: serviceUuid,
              ArgumentName.characteristicUuid: characteristicUuid,
            },
          );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }
    return _parseCharacteristicWithValue(rawValue!);
  }

// ++MH++
  /// Writes value of [Characteristic] matching specified UUIDs.
  ///
  /// Writes [value] to characteristic with [characteristicUuid] for service with
  /// [serviceUuid].
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<Characteristic> writeCharacteristic(
    String serviceUuid,
    String characteristicUuid,
    Uint8List value,
    {required bool withResponse
  }) async {
    String? rawValue;
    try {
      rawValue = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.writeCharacteristicForDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.serviceUuid: serviceUuid,
          ArgumentName.characteristicUuid: characteristicUuid,
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

    return _parseCharacteristic(rawValue!);
  }

  static Stream<String> _characteristicsMonitoringEvents({ required String name }) {
    return EventChannel(name).receiveBroadcastStream().cast();
  }

// ++MH++
  /// Returns a stream of notifications/indications from [Characteristic]
  /// matching specified UUIDs.
  ///
  /// Emits [CharacteristicWithValue] for every observed change of the
  /// characteristic specified by [serviceUuid] and [characteristicUuid]
  /// If notifications are enabled they will be used in favour of indications.
  /// Unsubscribing from the stream cancels monitoring.
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<Stream<CharacteristicWithValue>> monitorCharacteristic(
    String serviceUuid,
    String characteristicUuid
  ) async {
      final channelName = await BleManager._methodChannel.invokeMethod<String>(
          MethodName.monitorCharacteristicForDevice,
          <String, dynamic>{
            ArgumentName.deviceIdentifier: identifier,
            ArgumentName.serviceUuid: serviceUuid,
            ArgumentName.characteristicUuid: characteristicUuid,
          },
        );

    final Stream<CharacteristicWithValue> characteristicStream;
    try {
      final channel = EventChannel(channelName!);
      final rawStream = channel.receiveBroadcastStream().cast<String>();
      characteristicStream = rawStream.map((rawValue) {
        CharacteristicWithValue charWithValue;
        try {
          charWithValue = _parseCharacteristicWithValue(rawValue);
        } catch (e) {
          rethrow;
        }
        return charWithValue;
      });
    } catch (e) {
      rethrow;
    }

    return characteristicStream;
  }

  @override
  String toString() {
    return 'Peripheral{\n\tname: $name, \n\tidentifier: $identifier\n}';
  }

// ++NTH++
  /// Returns a list of [Descriptor]s for [Characteristic] matching specified UUIDs.
  ///
  /// Returns list of discovered Descriptors for given [serviceUuid] in specified
  /// characteristic with [characteristicUuid]
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<List<Descriptor>> descriptorsForCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
    String? jsonString;
    try {
      jsonString = await BleManager._methodChannel.invokeMethod(
        MethodName.descriptorsForDevice, 
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.serviceUuid: serviceUuid,
          ArgumentName.characteristicUuid: characteristicUuid,
        }
      );
    } on PlatformException catch (pe) {
      final details = pe.details as Object?;
      if (details is String) {
        throw BleError.fromJson(jsonDecode(details));
      }
      rethrow;
    }

    Map<String, dynamic> jsonObject = jsonDecode(jsonString!);

    final service = Service.fromJson(jsonObject, this);
    final characteristic =
        Characteristic.fromJson(jsonObject, service);

    final jsonDescriptors = (jsonObject['descriptors'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    return jsonDescriptors
        .map((jsonDescriptor) {
          final uuid = jsonDescriptor[DescriptorMetadata.uuid] as String;
          return Descriptor(uuid, characteristic);
        })
        .toList();

  }

// ++NTH++
  /// Reads value of [Descriptor] matching specified UUIDs.
  ///
  /// Returns Descriptor object matching specified [serviceUuid],
  /// [characteristicUuid] and [descriptorUuid]. Latest value of the descriptor will
  /// be stored inside returned object.
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<DescriptorWithValue> readDescriptor(
    String serviceUuid,
    String characteristicUuid,
    String descriptorUuid, 
  ) async {
    String? jsonResponse;
    try {
      jsonResponse = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.readDescriptorForDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.serviceUuid: serviceUuid,
          ArgumentName.characteristicUuid: characteristicUuid,
          ArgumentName.descriptorUuid: descriptorUuid,
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
    final service =
        Service.fromJson(jsonObject, this);
    final characteristic =
        Characteristic.fromJson(jsonObject, service);
        
    final valueStr = jsonObject[DescriptorMetadata.value] as String;
    final descUuid = jsonObject[DescriptorMetadata.uuid] as String;
    return DescriptorWithValue(
      base64Decode(valueStr),
      descUuid, 
      characteristic
    );
  }

// ++NTH++
  /// Writes value of [Descriptor] matching specified UUIDs.
  ///
  /// Write [value] to Descriptor specified by [serviceUuid],
  /// [characteristicUuid] and [descriptorUuid]. Returns Descriptor which saved
  /// passed value.
  ///
  /// Will result in error if discovery was not done during this connection.
  Future<Descriptor> writeDescriptor(
    String serviceUuid,
    String characteristicUuid,
    String descriptorUuid,
    Uint8List value
  ) async {
    String? jsonResponse;
    try {
      jsonResponse = await BleManager._methodChannel.invokeMethod<String>(
        MethodName.writeDescriptorForDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
          ArgumentName.serviceUuid: serviceUuid,
          ArgumentName.characteristicUuid: characteristicUuid,
          ArgumentName.descriptorUuid: descriptorUuid,
          ArgumentName.value: value,
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
    final service =
        Service.fromJson(jsonObject, this);
    final characteristic =
        Characteristic.fromJson(jsonObject, service);
    
    final descUuid = jsonObject[DescriptorMetadata.uuid] as String;
    return Descriptor(descUuid, characteristic);
  }
}

/// Enum covers all possible connection state
enum PeripheralConnectionState {
  connecting,
  connected,
  disconnected,
  disconnecting
}
