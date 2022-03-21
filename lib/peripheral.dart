part of flutter_ble_lib;

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
  final String? name;
  final String identifier;

  Peripheral.fromJson(Map<String, dynamic> json)
      : name = json[_PeripheralMetadata.name],
        identifier = json[_PeripheralMetadata.identifier];

  /// Connects to the peripheral.
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
    int? requestMtu,
    bool refreshGatt = false,
    Duration? timeout,
  }) async {
    try {
      return await BleManager._methodChannel.invokeMethod<void>(
        MethodName.connectToDevice,
        <String, dynamic>{
          ArgumentName.deviceIdentifier: identifier,
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

  /// Android Only, on iOS it's noop
  Future<void> ensureBonded() async {
    if (Platform.isAndroid == false) {
      return;
    }
    try {
      await BleManager._methodChannel.invokeMethod<void>(
        MethodName.ensureBondedWithDevice,
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
    } catch (e) {
      rethrow;
    }
  }

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

    final stream = EventChannel(
      channelName!
    ).receiveBroadcastStream().map((str) {
      switch (str.toLowerCase()) {
        case 'connected':
          return PeripheralConnectionState.connected;
        case 'connecting':
          return PeripheralConnectionState.connecting;
        case 'disconnected':
          return PeripheralConnectionState.disconnected;
        case 'disconnecting':
          return PeripheralConnectionState.disconnecting;
        default:
          throw FormatException(
            'Unrecognized value of device connection state. Value: $str',
          );
      }
    });
    return stream;
  }


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
    final servicesJson =
        (jsonDecode(jsonString!) as List<dynamic>).cast<Map<String, dynamic>>();

    return servicesJson.map((serviceJson) {
      return Service.fromJson(serviceJson, this);
    }).toList();
  }

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

    final servicesJson =
        (jsonDecode(jsonString!) as List<dynamic>).cast<Map<String, dynamic>>();

    return servicesJson.map((serviceJson) {
      return Service.fromJson(serviceJson, this);
    }).toList();
  }


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

  @override
  String toString() {
    return 'Peripheral{\n\tname: $name, \n\tidentifier: $identifier\n}';
  }
}

/// Enum covers all possible connection state
enum PeripheralConnectionState {
  connecting,
  connected,
  disconnected,
  disconnecting
}
