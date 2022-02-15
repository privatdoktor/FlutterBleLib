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
    let eventChannelFactory = eventChannelFactory
    let stateChangesSinker =
      eventChannelFactory.makeEventChannel(StateChanges.self, idScheme: .justBaseName)
    let stateRestoreSinker =
      eventChannelFactory.makeEventChannel(StateRestoreEvents.self, idScheme: .justBaseName)
    handler.stateChanges = Client.Stream<Int>(eventHandler: { payload in
      switch payload {
      case .data(let state):
        stateChangesSinker.sink(state)
      case .endOfStream:
        stateChangesSinker.end()
      }
    })
    handler.stateRestoreEvents = Client.Stream(eventHandler: { payload in
      switch payload {
      case .data(let states):
        stateRestoreSinker.sink(states)
      case .endOfStream:
        stateRestoreSinker.end()
      }
    })
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
    case serviceUuids = "serviceUuids"
    case showPowerAlertOnIOS = "showPowerAlertOnIOS"
    case characteristicUuid = "characteristicUuid"
    case characteristicUuids = "characteristicUuids"
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
      case "getAuthorization":
        self = .getAuthorization
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
      case "discoverServices":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUUIDStrs = args?[.serviceUuids] as? [String]
        self = .discoverServices(deviceIdentifier: deviceId,
                                 serviceUuidStrs: serviceUUIDStrs)
      case "discoverCharacteristics":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let serviceUuid =
          try argsHelper.requiredValueFor(.serviceUuid,
                                          type: String.self)
        let characteristicUuidStrs = args?[.characteristicUuids] as? [String]
        self = .discoverCharacteristics(
          deviceIdentifier: deviceId,
          serviceUuid: serviceUuid,
          characteristicsUuidStrs: characteristicUuidStrs
        )
      case "discoverAllServicesAndCharacteristics":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        self = .discoverAllServicesAndCharacteristics(
          deviceIdentifier: deviceId
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
        self = .rssi(
          deviceIdentifier: deviceId
        )
      case "requestMtu":
        let deviceId =
          try argsHelper.requiredValueFor(.deviceUuid,
                                          type: String.self)
        let mtu =
          try argsHelper.requiredValueFor(.mtu,
                                          type: Int.self)
        self = .requestMtu(
          deviceIdentifier: deviceId,
          mtu: mtu
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
        self = .readCharacteristicForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID
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
        self = .writeCharacteristicForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          value: value,
          withResponse: withResponse
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
        self = .monitorCharacteristicForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID
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
        self = .readDescriptorForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          descriptorUUID: descriptorUUID
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
        self = .writeDescriptorForDevice(
          deviceIdentifier: deviceId,
          serviceUUID: serviceUUID,
          characteristicUUID: characteristicUUID,
          descriptorUUID: descriptorUUID,
          value: value
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
    case getAuthorization
    
    case enableRadio
    case disableRadio
    
    case startDeviceScan(uuids: [String]?, allowDuplicates: Bool?)
    case stopDeviceScan
    
    case connectToDevice(deviceIdentifier: String, timoutMillis: Int?)
    case isDeviceConnected(deviceIdentifier: String)
    case observeConnectionState(deviceIdentifier: String,
                                emitCurrentValue: Bool)
    case cancelConnection(deviceIdentifier: String)
    
    case discoverServices(deviceIdentifier: String,
                          serviceUuidStrs: [String]?)
    case discoverCharacteristics(deviceIdentifier: String,
                                 serviceUuid: String,
                                 characteristicsUuidStrs: [String]?)
    case discoverAllServicesAndCharacteristics(deviceIdentifier: String)
    case services(deviceIdentifier: String)
    
    case characteristics(deviceIdentifier: String, serviceUUID: String)
    
    case descriptorsForDevice(deviceIdentifier: String,
                              serviceUUID: String,
                              characteristicUUID: String)
    
    case logLevel
    case setLogLevel(String)
    
    case rssi(deviceIdentifier: String)
    
    case requestMtu(deviceIdentifier: String,
                    mtu: Int)
    
    case getConnectedDevices(serviceUUIDs: [String])
    case getKnownDevices(deviceIdentifiers: [String])
    
    case readCharacteristicForDevice(deviceIdentifier: String,
                                     serviceUUID: String,
                                     characteristicUUID: String)

    case writeCharacteristicForDevice(deviceIdentifier: String,
                                      serviceUUID: String,
                                      characteristicUUID: String,
                                      value: FlutterStandardTypedData,
                                      withResponse: Bool)
    
    case monitorCharacteristicForDevice(deviceIdentifier: String,
                                        serviceUUID: String,
                                        characteristicUUID: String)

    case readDescriptorForDevice(deviceIdentifier: String,
                                 serviceUUID: String,
                                 characteristicUUID: String,
                                 descriptorUUID: String)
    
    case writeDescriptorForDevice(deviceIdentifier: String,
                                  serviceUUID: String,
                                  characteristicUUID: String,
                                  descriptorUUID: String,
                                  value: FlutterStandardTypedData)
  }
}

