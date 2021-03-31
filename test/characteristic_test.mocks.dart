// Mocks generated by Mockito 5.0.3 from annotations
// in flutter_ble_lib/test/characteristic_test.dart.
// Do not manually edit this file.

import 'dart:async' as _i4;
import 'dart:typed_data' as _i3;

import 'package:flutter_ble_lib/flutter_ble_lib.dart' as _i2;
import 'package:flutter_ble_lib/src/_internal.dart' as _i6;
import 'package:flutter_ble_lib/src/_managers_for_classes.dart' as _i5;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: comment_references
// ignore_for_file: unnecessary_parenthesis

class _FakeCharacteristicWithValue extends _i1.Fake
    implements _i2.CharacteristicWithValue {}

class _FakeCharacteristic extends _i1.Fake implements _i2.Characteristic {}

class _FakeDescriptorWithValue extends _i1.Fake
    implements _i2.DescriptorWithValue {}

class _FakeDescriptor extends _i1.Fake implements _i2.Descriptor {}

class _FakeUint8List extends _i1.Fake implements _i3.Uint8List {}

class _FakePeripheral extends _i1.Fake implements _i2.Peripheral {}

/// A class which mocks [Peripheral].
///
/// See the documentation for Mockito's code generation for more information.
class MockPeripheral extends _i1.Mock implements _i2.Peripheral {
  MockPeripheral() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get name =>
      (super.noSuchMethod(Invocation.getter(#name), returnValue: '') as String);
  @override
  set name(String? _name) => super.noSuchMethod(Invocation.setter(#name, _name),
      returnValueForMissingStub: null);
  @override
  String get identifier =>
      (super.noSuchMethod(Invocation.getter(#identifier), returnValue: '')
          as String);
  @override
  set identifier(String? _identifier) =>
      super.noSuchMethod(Invocation.setter(#identifier, _identifier),
          returnValueForMissingStub: null);
  @override
  _i4.Future<void> connect(
          {bool? isAutoConnect = false,
          int? requestMtu = 0,
          bool? refreshGatt = false,
          Duration? timeout}) =>
      (super.noSuchMethod(
          Invocation.method(#connect, [], {
            #isAutoConnect: isAutoConnect,
            #requestMtu: requestMtu,
            #refreshGatt: refreshGatt,
            #timeout: timeout
          }),
          returnValue: Future.value(null),
          returnValueForMissingStub: Future.value()) as _i4.Future<void>);
  @override
  _i4.Stream<_i2.PeripheralConnectionState> observeConnectionState(
          {bool? emitCurrentValue = false,
          bool? completeOnDisconnect = false}) =>
      (super.noSuchMethod(
              Invocation.method(#observeConnectionState, [], {
                #emitCurrentValue: emitCurrentValue,
                #completeOnDisconnect: completeOnDisconnect
              }),
              returnValue: Stream<_i2.PeripheralConnectionState>.empty())
          as _i4.Stream<_i2.PeripheralConnectionState>);
  @override
  _i4.Future<bool> isConnected() =>
      (super.noSuchMethod(Invocation.method(#isConnected, []),
          returnValue: Future.value(false)) as _i4.Future<bool>);
  @override
  _i4.Future<void> disconnectOrCancelConnection() =>
      (super.noSuchMethod(Invocation.method(#disconnectOrCancelConnection, []),
          returnValue: Future.value(null),
          returnValueForMissingStub: Future.value()) as _i4.Future<void>);
  @override
  _i4.Future<void> discoverAllServicesAndCharacteristics(
          {String? transactionId}) =>
      (super.noSuchMethod(
          Invocation.method(#discoverAllServicesAndCharacteristics, [],
              {#transactionId: transactionId}),
          returnValue: Future.value(null),
          returnValueForMissingStub: Future.value()) as _i4.Future<void>);
  @override
  _i4.Future<List<_i2.Service>> services() =>
      (super.noSuchMethod(Invocation.method(#services, []),
              returnValue: Future.value(<_i2.Service>[]))
          as _i4.Future<List<_i2.Service>>);
  @override
  _i4.Future<List<_i2.Characteristic>> characteristics(String? servicedUuid) =>
      (super.noSuchMethod(Invocation.method(#characteristics, [servicedUuid]),
              returnValue: Future.value(<_i2.Characteristic>[]))
          as _i4.Future<List<_i2.Characteristic>>);
  @override
  _i4.Future<int> rssi({String? transactionId}) => (super.noSuchMethod(
      Invocation.method(#rssi, [], {#transactionId: transactionId}),
      returnValue: Future.value(0)) as _i4.Future<int>);
  @override
  _i4.Future<int> requestMtu(int? mtu, {String? transactionId}) =>
      (super.noSuchMethod(
          Invocation.method(
              #requestMtu, [mtu], {#transactionId: transactionId}),
          returnValue: Future.value(0)) as _i4.Future<int>);
  @override
  _i4.Future<_i2.CharacteristicWithValue> readCharacteristic(
          String? serviceUuid, String? characteristicUuid,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #readCharacteristic,
                  [serviceUuid, characteristicUuid],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeCharacteristicWithValue()))
          as _i4.Future<_i2.CharacteristicWithValue>);
  @override
  _i4.Future<_i2.Characteristic> writeCharacteristic(String? serviceUuid,
          String? characteristicUuid, _i3.Uint8List? value, bool? withResponse,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #writeCharacteristic,
                  [serviceUuid, characteristicUuid, value, withResponse],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeCharacteristic()))
          as _i4.Future<_i2.Characteristic>);
  @override
  _i4.Future<List<_i2.Descriptor>> descriptorsForCharacteristic(
          String? serviceUuid, String? characteristicUuid) =>
      (super.noSuchMethod(
              Invocation.method(#descriptorsForCharacteristic,
                  [serviceUuid, characteristicUuid]),
              returnValue: Future.value(<_i2.Descriptor>[]))
          as _i4.Future<List<_i2.Descriptor>>);
  @override
  _i4.Future<_i2.DescriptorWithValue> readDescriptor(String? serviceUuid,
          String? characteristicUuid, String? descriptorUuid,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #readDescriptor,
                  [serviceUuid, characteristicUuid, descriptorUuid],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeDescriptorWithValue()))
          as _i4.Future<_i2.DescriptorWithValue>);
  @override
  _i4.Future<_i2.Descriptor> writeDescriptor(
          String? serviceUuid,
          String? characteristicUuid,
          String? descriptorUuid,
          _i3.Uint8List? value,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #writeDescriptor,
                  [serviceUuid, characteristicUuid, descriptorUuid, value],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeDescriptor()))
          as _i4.Future<_i2.Descriptor>);
  @override
  _i4.Stream<_i2.CharacteristicWithValue> monitorCharacteristic(
          String? serviceUuid, String? characteristicUuid,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #monitorCharacteristic,
                  [serviceUuid, characteristicUuid],
                  {#transactionId: transactionId}),
              returnValue: Stream<_i2.CharacteristicWithValue>.empty())
          as _i4.Stream<_i2.CharacteristicWithValue>);
  @override
  String toString() =>
      (super.noSuchMethod(Invocation.method(#toString, []), returnValue: '')
          as String);
}

/// A class which mocks [ManagerForCharacteristic].
///
/// See the documentation for Mockito's code generation for more information.
class MockManagerForCharacteristic extends _i1.Mock
    implements _i5.ManagerForCharacteristic {
  MockManagerForCharacteristic() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Future<_i3.Uint8List> readCharacteristicForIdentifier(
          _i2.Peripheral? peripheral,
          _i6.InternalCharacteristic? characteristic,
          String? transactionId) =>
      (super.noSuchMethod(
              Invocation.method(#readCharacteristicForIdentifier,
                  [peripheral, characteristic, transactionId]),
              returnValue: Future.value(_FakeUint8List()))
          as _i4.Future<_i3.Uint8List>);
  @override
  _i4.Future<void> writeCharacteristicForIdentifier(
          _i2.Peripheral? peripheral,
          _i6.InternalCharacteristic? characteristic,
          _i3.Uint8List? value,
          bool? withResponse,
          String? transactionId) =>
      (super.noSuchMethod(
          Invocation.method(#writeCharacteristicForIdentifier,
              [peripheral, characteristic, value, withResponse, transactionId]),
          returnValue: Future.value(null),
          returnValueForMissingStub: Future.value()) as _i4.Future<void>);
  @override
  _i4.Stream<_i3.Uint8List> monitorCharacteristicForIdentifier(
          _i2.Peripheral? peripheral,
          _i6.InternalCharacteristic? characteristic,
          String? transactionId) =>
      (super.noSuchMethod(
              Invocation.method(#monitorCharacteristicForIdentifier,
                  [peripheral, characteristic, transactionId]),
              returnValue: Stream<_i3.Uint8List>.empty())
          as _i4.Stream<_i3.Uint8List>);
  @override
  _i4.Future<List<_i2.Descriptor>> descriptorsForCharacteristic(
          _i2.Characteristic? characteristic) =>
      (super.noSuchMethod(
          Invocation.method(#descriptorsForCharacteristic, [characteristic]),
          returnValue:
              Future.value(<_i2.Descriptor>[])) as _i4
          .Future<List<_i2.Descriptor>>);
  @override
  _i4.Future<_i2.DescriptorWithValue> readDescriptorForCharacteristic(
          _i2.Characteristic? characteristic,
          String? descriptorUuid,
          String? transactionId) =>
      (super.noSuchMethod(
              Invocation.method(#readDescriptorForCharacteristic,
                  [characteristic, descriptorUuid, transactionId]),
              returnValue: Future.value(_FakeDescriptorWithValue()))
          as _i4.Future<_i2.DescriptorWithValue>);
  @override
  _i4.Future<_i2.Descriptor> writeDescriptorForCharacteristic(
          _i2.Characteristic? characteristic,
          String? descriptorUuid,
          _i3.Uint8List? value,
          String? transactionId) =>
      (super.noSuchMethod(
              Invocation.method(#writeDescriptorForCharacteristic,
                  [characteristic, descriptorUuid, value, transactionId]),
              returnValue: Future.value(_FakeDescriptor()))
          as _i4.Future<_i2.Descriptor>);
}

/// A class which mocks [ManagerForDescriptor].
///
/// See the documentation for Mockito's code generation for more information.
class MockManagerForDescriptor extends _i1.Mock
    implements _i5.ManagerForDescriptor {
  MockManagerForDescriptor() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Future<_i3.Uint8List> readDescriptorForIdentifier(
          _i2.Descriptor? descriptor, String? transactionId) =>
      (super.noSuchMethod(
              Invocation.method(
                  #readDescriptorForIdentifier, [descriptor, transactionId]),
              returnValue: Future.value(_FakeUint8List()))
          as _i4.Future<_i3.Uint8List>);
  @override
  _i4.Future<void> writeDescriptorForIdentifier(_i2.Descriptor? descriptor,
          _i3.Uint8List? value, String? transactionId) =>
      (super.noSuchMethod(
          Invocation.method(#writeDescriptorForIdentifier,
              [descriptor, value, transactionId]),
          returnValue: Future.value(null),
          returnValueForMissingStub: Future.value()) as _i4.Future<void>);
}

/// A class which mocks [Service].
///
/// See the documentation for Mockito's code generation for more information.
class MockService extends _i1.Mock implements _i2.Service {
  MockService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.Peripheral get peripheral =>
      (super.noSuchMethod(Invocation.getter(#peripheral),
          returnValue: _FakePeripheral()) as _i2.Peripheral);
  @override
  set peripheral(_i2.Peripheral? _peripheral) =>
      super.noSuchMethod(Invocation.setter(#peripheral, _peripheral),
          returnValueForMissingStub: null);
  @override
  String get uuid =>
      (super.noSuchMethod(Invocation.getter(#uuid), returnValue: '') as String);
  @override
  set uuid(String? _uuid) => super.noSuchMethod(Invocation.setter(#uuid, _uuid),
      returnValueForMissingStub: null);
  @override
  int get hashCode =>
      (super.noSuchMethod(Invocation.getter(#hashCode), returnValue: 0) as int);
  @override
  _i4.Future<List<_i2.Characteristic>> characteristics() =>
      (super.noSuchMethod(Invocation.method(#characteristics, []),
              returnValue: Future.value(<_i2.Characteristic>[]))
          as _i4.Future<List<_i2.Characteristic>>);
  @override
  _i4.Future<_i2.Characteristic> writeCharacteristic(
          String? characteristicUuid, _i3.Uint8List? value, bool? withResponse,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #writeCharacteristic,
                  [characteristicUuid, value, withResponse],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeCharacteristic()))
          as _i4.Future<_i2.Characteristic>);
  @override
  _i4.Future<_i2.CharacteristicWithValue> readCharacteristic(
          String? characteristicUuid,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(#readCharacteristic, [characteristicUuid],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeCharacteristicWithValue()))
          as _i4.Future<_i2.CharacteristicWithValue>);
  @override
  _i4.Stream<_i2.CharacteristicWithValue> monitorCharacteristic(
          String? characteristicUuid,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(#monitorCharacteristic, [characteristicUuid],
                  {#transactionId: transactionId}),
              returnValue: Stream<_i2.CharacteristicWithValue>.empty())
          as _i4.Stream<_i2.CharacteristicWithValue>);
  @override
  _i4.Future<List<_i2.Descriptor>> descriptorsForCharacteristic(
          String? characteristicUuid) =>
      (super.noSuchMethod(
              Invocation.method(
                  #descriptorsForCharacteristic, [characteristicUuid]),
              returnValue: Future.value(<_i2.Descriptor>[]))
          as _i4.Future<List<_i2.Descriptor>>);
  @override
  _i4.Future<_i2.DescriptorWithValue> readDescriptor(
          String? characteristicUuid, String? descriptorUuid,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #readDescriptor,
                  [characteristicUuid, descriptorUuid],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeDescriptorWithValue()))
          as _i4.Future<_i2.DescriptorWithValue>);
  @override
  _i4.Future<_i2.Descriptor> writeDescriptor(String? characteristicUuid,
          String? descriptorUuid, _i3.Uint8List? value,
          {String? transactionId}) =>
      (super.noSuchMethod(
              Invocation.method(
                  #writeDescriptor,
                  [characteristicUuid, descriptorUuid, value],
                  {#transactionId: transactionId}),
              returnValue: Future.value(_FakeDescriptor()))
          as _i4.Future<_i2.Descriptor>);
  @override
  bool operator ==(Object? other) =>
      (super.noSuchMethod(Invocation.method(#==, [other]), returnValue: false)
          as bool);
  @override
  String toString() =>
      (super.noSuchMethod(Invocation.method(#toString, []), returnValue: '')
          as String);
}
