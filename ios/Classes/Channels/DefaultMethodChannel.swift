//
//  Method.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 13/05/2021.
//

import Foundation

final class DefaultMethodChannel : NSObject, MethodChannel {
  typealias CallHandlerT = Client
  typealias SignatureEnumT = Signature

  let handler: Client
  let eventChannelFactory: EventChannelFactory
  
  private func setupStaticEventChannels() {
    let stateChangesSink =
      eventChannelFactory.makeEventChannel(StateChanges.self)
    let stateRestoreSink =
      eventChannelFactory.makeEventChannel(StateRestoreEvents.self)
    let scanningSink =
      eventChannelFactory.makeEventChannel(ScanningEvents.self)
    handler.stateChanges = Client.Stream<Int>(eventHandler: { payload in
      switch payload {
      case .data(let state):
        stateChangesSink.sink(state)
      case .endOfStream:
        stateChangesSink.end()
      }
    })
    stateChangesSink.afterCancelDo { [weak handler] in
      handler?.stateChanges?.afterCancelDo?()
      handler?.stateChanges = nil
    }
    handler.stateRestoreEvents = Client.Stream(eventHandler: { payload in
      switch payload {
      case .data(let states):
        stateRestoreSink.sink(states)
      case .endOfStream:
        stateRestoreSink.end()
      }
    })
    stateRestoreSink.afterCancelDo { [weak handler] in
      handler?.stateRestoreEvents?.afterCancelDo?()
      handler?.stateRestoreEvents = nil
    }
    handler.scanningEvents = Client.Stream(eventHandler: { payload in
      switch payload {
      case .data(let scanResult):
        scanningSink.sink(scanResult)
      case .endOfStream:
        scanningSink.end()
      }
    })
    scanningSink.afterCancelDo { [weak handler] in
      handler?.scanningEvents?.afterCancelDo?()
      handler?.scanningEvents = nil
    }
  }
  
  init(handler: Client, messenger: FlutterBinaryMessenger) {
    self.handler = handler
    eventChannelFactory = EventChannelFactory(messenger: messenger)
    super.init()
    setupStaticEventChannels()
  }
  
  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger: FlutterBinaryMessenger = registrar.messenger()
    let flutterChannel =
      FlutterMethodChannel(
        name: self.name,
        binaryMessenger: messenger
      )
    let channel = self.init(handler: Client(), messenger: messenger)
    
    registrar.addMethodCallDelegate(
      channel,
      channel: flutterChannel
    )
  }
  
  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let args = call.arguments as? Dictionary<String, Any>?,
      let call = Call<CallHandlerT.SignatureEnumT>(
        call.method,
        args: args,
        onResult: result
      )
    else {
      return
    }
    handler.handle(call: call, eventChannelFactory: eventChannelFactory)
  }
  
  static let name = "flutter_ble_lib"
  
  enum ArgumentKey : String, ArgumentKeyEnum {
    case restoreStateIdentifier = "restoreStateIdentifier"
    case scanMode = "scanMode"
    case allowDuplicates = "allowDuplicates"
    case callbackType = "callbackType"
    case uuids = "uuids"
    case transactionId = "transactionId"
    case deviceUuid = "deviceIdentifier"
    case isAutoConnect = "isAutoConnect"
    case requestMtu = "requestMtu"
    case refreshGatt = "refreshGatt"
    case timeoutMillis = "timeout"
    case emitCurrentValue = "emitCurrentValue"
    case logLevel = "logLevel"
    case serviceUuid = "serviceUuid"
    case serviceNumericId = "serviceId"
    case showPowerAlertOnIOS = "showPowerAlertOnIOS"
    case characteristicUuid = "characteristicUuid"
    case characteristicNumericId = "characteristicIdentifier"
    case value = "value"
    case withResponse = "withResponse"
    case descriptorUuid = "descriptorUuid"
    case descriptorNumericId = "descriptorIdentifier"
    case mtu = "mtu"
    case deviceUuids = "deviceIdentifiers"
  }
  
  enum Signature : SignatureEnum {
    typealias ArgumentKeyEnumT = ArgumentKey
    
    struct ArgsHelper {
      let callId: String
      let args: [ArgumentKey : Any]?
      func requiredValueFor<ArgT>(
        _ key: ArgumentKey,
        type: ArgT.Type
      ) throws -> ArgT {
        guard
          let value = args?[key],
          let args = args
        else {
          throw SignatureError.missingArgsKey(
            key,
            inDict: args,
            id: callId
          )
        }
        guard
          let argument = value as? ArgT
        else {
          throw SignatureError.invalidValue(
            forKey: key,
            value: value,
            inDict: args,
            id: callId,
            expected: type
          )
          
        }
        return argument
      }
    }
    
    init?(_ id: String, args: [ArgumentKey : Any]?) throws {
      let argsHelper = ArgsHelper(callId: id, args: args)
      switch id {
      case "isClientCreated":
        self = .isClientCreated
      case "createClient":
        let restoreId = args?[.restoreStateIdentifier] as? String
        let showPowerAlert = args?[.showPowerAlertOnIOS] as? Bool
        self = .createClient(
          restoreId: restoreId,
          showPowerAlert: showPowerAlert
        )
      case "destroyClient":
        self = .destroyClient
      case "cancelTransaction":
        let transactionId = args?[.transactionId]
        self = .cancelTransaction(transactionId: transactionId)
      case "getState":
        self = .getState
      case "enableRadio":
        self = .enableRadio
      case "disableRadio":
        self = .disableRadio
      case "startDeviceScan":
        let uuids = args?[.uuids] as? [String]
        let allowDuplicates = args?[.allowDuplicates] as? Bool
        self = .startDeviceScan(
          uuids: uuids,
          allowDuplicates: allowDuplicates
        )
      case "stopDeviceScan":
        self = .stopDeviceScan
      case "connectToDevice":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let timoutMillis = args?[.timeoutMillis] as? Int
        self = .connectToDevice(
          deviceIdentifier: deviceId,
          timoutMillis: timoutMillis
        )
      case "isDeviceConnected":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        self = .isDeviceConnected(deviceIdentifier: deviceId)
      case "observeConnectionState":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let emitCurrentValue = args?[.emitCurrentValue] as? Bool ?? false
        self = .observeConnectionState(
          deviceIdentifier: deviceId,
          emitCurrentValue: emitCurrentValue
        )
      case "cancelConnection":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        self = .cancelConnection(deviceIdentifier: deviceId)
      case "discoverAllServicesAndCharacteristics":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .discoverAllServicesAndCharacteristics(
          deviceIdentifier: deviceId,
          transactionId: transactionId
        )
      case "services":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        self = .services(deviceIdentifier: deviceId)
      case "characteristics":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUID =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)

        self = .characteristics(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID
        )
      case "characteristicsForService":
        let serviceNumericId =
          try argsHelper.requiredValueFor(.serviceNumericId,
                                          type: Int.self)
        self = .characteristicsForService(serviceNumericId: serviceNumericId)
      case "descriptorsForDevice":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUID =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        self = .descriptorsForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID
        )
      case "descriptorsForService":
        let serviceNumericId =
          try argsHelper.requiredValueFor(.serviceNumericId,
                                          type: Int.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)

        self = .descriptorsForService(
          serviceNumericId: serviceNumericId,
          characteristicUUID: characteristicUUID
        )
      case "descriptorsForCharacteristic":
        let characteristicNumericId =
          try argsHelper.requiredValueFor(.characteristicNumericId,
                                          type: Int.self)
        self = .descriptorsForCharacteristic(
          characteristicNumericId: characteristicNumericId
        )
      case "logLevel":
        self = .logLevel
      case "setLogLevel":
        let logLevel =
          try argsHelper.requiredValueFor(.logLevel,
                                          type: String.self)
        self = .setLogLevel(logLevel)
      case "rssi":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .rssi(
          deviceIdentifier: deviceId,
          transactionId: transactionId
        )
      case "requestMtu":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let mtu =
          try argsHelper.requiredValueFor(.mtu,
                                          type: Int.self)
        let transactionId = args?[.transactionId] as? String
        self = .requestMtu(
          deviceIdentifier: deviceId,
          mtu: mtu,
          transactionId: transactionId
        )
      case "getConnectedDevices":
        let serviceUUIDs =
          try argsHelper.requiredValueFor(.uuids,
                                          type: [String].self)
        self = .getConnectedDevices(serviceUUIDs: serviceUUIDs)
      case "getKnownDevices":
        let deviceIdentifiers =
          try argsHelper.requiredValueFor(.deviceUuids,
                                          type: [String].self)
        self = .getKnownDevices(deviceIdentifiers: deviceIdentifiers)
      case "readCharacteristicForIdentifier":
        let characteristicNumericId =
          try argsHelper.requiredValueFor(.characteristicNumericId,
                                          type: Int.self)
          
        let transactionId = args?[.transactionId] as? String
        self = .readCharacteristicForIdentifier(
          characteristicNumericId: characteristicNumericId,
          transactionId: transactionId
        )
      case "readCharacteristicForDevice":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUID =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .readCharacteristicForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          transactionId: transactionId
        )
      case "readCharacteristicForService":
        let serviceNumericId =
          try argsHelper.requiredValueFor(.serviceNumericId,
                                          type: Int.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .readCharacteristicForService(
          serviceNumericId: serviceNumericId,
          characteristicUUID: characteristicUUID,
          transactionId: transactionId
        )
      case "writeCharacteristicForIdentifier":
        let characteristicNumericId =
          try argsHelper.requiredValueFor(.characteristicNumericId,
                                          type: Int.self)
        let value =
          try argsHelper.requiredValueFor(.value,
                                          type: FlutterStandardTypedData.self)
        let withResponse =
          try argsHelper.requiredValueFor(.withResponse,
                                          type: Bool.self)
        let transactionId = args?[.transactionId] as? String
        self = .writeCharacteristicForIdentifier(
          characteristicNumericId: characteristicNumericId,
          value: value,
          withResponse: withResponse,
          transactionId: transactionId
        )
      case "writeCharacteristicForDevice":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUID =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let value =
          try argsHelper.requiredValueFor(.value,
                                          type: FlutterStandardTypedData.self)
        let withResponse =
          try argsHelper.requiredValueFor(.withResponse,
                                          type: Bool.self)
        let transactionId = args?[.transactionId] as? String
        self = .writeCharacteristicForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          value: value,
          withResponse: withResponse,
          transactionId: transactionId
        )
      case "writeCharacteristicForService":
        let serviceNumericId =
          try argsHelper.requiredValueFor(.serviceNumericId,
                                          type: Int.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let value =
          try argsHelper.requiredValueFor(.value,
                                          type: FlutterStandardTypedData.self)
        let withResponse =
          try argsHelper.requiredValueFor(.withResponse,
                                          type: Bool.self)
        let transactionId = args?[.transactionId] as? String
        self = .writeCharacteristicForService(
          serviceNumericId: serviceNumericId,
          characteristicUUID: characteristicUUID,
          value: value,
          withResponse: withResponse,
          transactionId: transactionId
        )
      case "monitorCharacteristicForIdentifier":
        let characteristicNumericId =
          try argsHelper.requiredValueFor(.characteristicNumericId,
                                          type: Int.self)
          
        let transactionId = args?[.transactionId] as? String
        self = .monitorCharacteristicForIdentifier(
          characteristicNumericId: characteristicNumericId,
          transactionId: transactionId
        )
      case "monitorCharacteristicForDevice":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUID =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .monitorCharacteristicForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          transactionId: transactionId
        )
      case "monitorCharacteristicForService":
        let serviceNumericId =
          try argsHelper.requiredValueFor(.serviceNumericId,
                                          type: Int.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .monitorCharacteristicForService(
          serviceNumericId: serviceNumericId,
          characteristicUUID: characteristicUUID,
          transactionId: transactionId
        )
      case "readDescriptorForIdentifier":
        let descriptorNumericId =
          try argsHelper.requiredValueFor(.descriptorNumericId,
                                          type: Int.self)
        let transactionId = args?[.transactionId] as? String
        self = .readDescriptorForIdentifier(
          descriptorNumericId: descriptorNumericId,
          transactionId: transactionId
        )
      case "readDescriptorForCharacteristic":
        let characteristicNumericId =
          try argsHelper.requiredValueFor(.characteristicNumericId,
                                          type: Int.self)
        let descriptorUUID =
          try argsHelper.requiredValueFor(.descriptorUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .readDescriptorForCharacteristic(
          characteristicNumericId: characteristicNumericId,
          descriptorUUID: descriptorUUID,
          transactionId: transactionId
        )
      case "readDescriptorForService":
        let serviceNumericId =
          try argsHelper.requiredValueFor(.serviceNumericId,
                                      type: Int.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let descriptorUUID =
          try argsHelper.requiredValueFor(.descriptorUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .readDescriptorForService(
          serviceNumericId: serviceNumericId,
          characteristicUUID: characteristicUUID,
          descriptorUUID: descriptorUUID,
          transactionId: transactionId
        )
      case "readDescriptorForDevice":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUID =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let descriptorUUID =
          try argsHelper.requiredValueFor(.descriptorUuid,
                                          type: String.self)
        let transactionId = args?[.transactionId] as? String
        self = .readDescriptorForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          descriptorUUID: descriptorUUID,
          transactionId: transactionId
        )
      case "writeDescriptorForIdentifier":
        let descriptorNumericId =
          try argsHelper.requiredValueFor(.descriptorNumericId,
                                          type: Int.self)
        let value =
          try argsHelper.requiredValueFor(.value,
                                          type: FlutterStandardTypedData.self)
        let transactionId = args?[.transactionId] as? String
        self = .writeDescriptorForIdentifier(
          descriptorNumericId: descriptorNumericId,
          value: value,
          transactionId: transactionId
        )
      case "writeDescriptorForCharacteristic":
        let characteristicNumericId =
          try argsHelper.requiredValueFor(.characteristicNumericId,
                                          type: Int.self)
        let descriptorUUID =
          try argsHelper.requiredValueFor(.descriptorUuid,
                                          type: String.self)
        let value =
          try argsHelper.requiredValueFor(.value,
                                          type: FlutterStandardTypedData.self)
        let transactionId = args?[.transactionId] as? String
        self = .writeDescriptorForCharacteristic(
          characteristicNumericId: characteristicNumericId,
          descriptorUUID: descriptorUUID,
          value: value,
          transactionId: transactionId
        )
      case "writeDescriptorForService":
        let serviceNumericId =
          try argsHelper.requiredValueFor(.serviceNumericId,
                                      type: Int.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let descriptorUUID =
          try argsHelper.requiredValueFor(.descriptorUuid,
                                          type: String.self)
        let value =
          try argsHelper.requiredValueFor(.value,
                                          type: FlutterStandardTypedData.self)
        let transactionId = args?[.transactionId] as? String
        self = .writeDescriptorForService(
          serviceNumericId: serviceNumericId,
          characteristicUUID: characteristicUUID,
          descriptorUUID: descriptorUUID,
          value: value,
          transactionId: transactionId
        )
      case "writeDescriptorForDevice":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUID =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)
        let characteristicUUID =
          try argsHelper.requiredValueFor(.characteristicUuid,
                                          type: String.self)
        let descriptorUUID =
          try argsHelper.requiredValueFor(.descriptorUuid,
                                          type: String.self)
        let value =
          try argsHelper.requiredValueFor(.value,
                                          type: FlutterStandardTypedData.self)
        let transactionId = args?[.transactionId] as? String
        self = .writeDescriptorForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          descriptorUUID: descriptorUUID,
          value: value,
          transactionId: transactionId
        )
      default:
        return nil
      }
    }
    
    case isClientCreated
    case createClient(restoreId: String?, showPowerAlert: Bool?)
    case destroyClient
    
    case cancelTransaction(transactionId: Any?)
    
    case getState
    
    case enableRadio
    case disableRadio
    
    case startDeviceScan(uuids: [String]?, allowDuplicates: Bool?)
    case stopDeviceScan
    
    case connectToDevice(deviceIdentifier: String, timoutMillis: Int?)
    case isDeviceConnected(deviceIdentifier: String)
    case observeConnectionState(deviceIdentifier: String,
                                emitCurrentValue: Bool)
    case cancelConnection(deviceIdentifier: String)
    
    case discoverAllServicesAndCharacteristics(deviceIdentifier: String,
                                               transactionId: String?)
    case services(deviceIdentifier: String)
    case characteristics(deviceIdentifier: String, serviceUUID: String)
    case characteristicsForService(serviceNumericId: Int)
    case descriptorsForDevice(deviceIdentifier: String,
                              serviceUUID: String,
                              characteristicUUID: String)
    case descriptorsForService(serviceNumericId: Int,
                               characteristicUUID: String)
    case descriptorsForCharacteristic(characteristicNumericId: Int)
    
    case logLevel
    case setLogLevel(String)
    
    case rssi(deviceIdentifier: String,
              transactionId: String?)
    
    case requestMtu(deviceIdentifier: String,
                    mtu: Int,
                    transactionId: String?)
    
    case getConnectedDevices(serviceUUIDs: [String])
    case getKnownDevices(deviceIdentifiers: [String])
    
    case readCharacteristicForIdentifier(characteristicNumericId: Int,
                                         transactionId: String?)
    case readCharacteristicForDevice(deviceIdentifier: String,
                                     serviceUUID: String,
                                     characteristicUUID: String,
                                     transactionId: String?)
    case readCharacteristicForService(serviceNumericId: Int,
                                      characteristicUUID: String,
                                      transactionId: String?)
    
    case writeCharacteristicForIdentifier(characteristicNumericId: Int,
                                          value: FlutterStandardTypedData,
                                          withResponse: Bool,
                                          transactionId: String?)
    case writeCharacteristicForDevice(deviceIdentifier: String,
                                      serviceUUID: String,
                                      characteristicUUID: String,
                                      value: FlutterStandardTypedData,
                                      withResponse: Bool,
                                      transactionId: String?)
    case writeCharacteristicForService(serviceNumericId: Int,
                                       characteristicUUID: String,
                                       value: FlutterStandardTypedData,
                                       withResponse: Bool,
                                       transactionId: String?)
    
    case monitorCharacteristicForIdentifier(characteristicNumericId: Int,
                                            transactionId: String?)
    case monitorCharacteristicForDevice(deviceIdentifier: String,
                                        serviceUUID: String,
                                        characteristicUUID: String,
                                        transactionId: String?)
    case monitorCharacteristicForService(serviceNumericId: Int,
                                         characteristicUUID: String,
                                         transactionId: String?)
    
    case readDescriptorForIdentifier(descriptorNumericId: Int,
                                     transactionId: String?)
    case readDescriptorForCharacteristic(characteristicNumericId: Int,
                                         descriptorUUID: String,
                                         transactionId: String?)
    case readDescriptorForService(serviceNumericId: Int,
                                  characteristicUUID: String,
                                  descriptorUUID: String,
                                  transactionId: String?)
    case readDescriptorForDevice(deviceIdentifier: String,
                                 serviceUUID: String,
                                 characteristicUUID: String,
                                 descriptorUUID: String,
                                 transactionId: String?)
    
    case writeDescriptorForIdentifier(descriptorNumericId: Int,
                                      value: FlutterStandardTypedData,
                                      transactionId: String?)
    case writeDescriptorForCharacteristic(characteristicNumericId: Int,
                                          descriptorUUID: String,
                                          value: FlutterStandardTypedData,
                                          transactionId: String?)
    case writeDescriptorForService(serviceNumericId: Int,
                                   characteristicUUID: String,
                                   descriptorUUID: String,
                                   value: FlutterStandardTypedData,
                                   transactionId: String?)
    case writeDescriptorForDevice(deviceIdentifier: String,
                                  serviceUUID: String,
                                  characteristicUUID: String,
                                  descriptorUUID: String,
                                  value: FlutterStandardTypedData,
                                  transactionId: String?)
  }
}

