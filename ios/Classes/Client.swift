//
//  Client.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 11/05/2021.
//

import Foundation
import CoreBluetooth

class PeripheralConnection : NSObject {
  let peripheral: CBPeripheral
  
  private var connectCompleted: ((_ res: Result<(), Client.Error>) -> ())?
  private var disconnectCompleted: ((_ res: Result<(), Client.Error>) -> ())?
  private var serviceDiscoveryCompleted: ((_ res: Result<(), Client.Error>) -> ())?
  
  init(_ peripheral: CBPeripheral) {
    self.peripheral = peripheral
    super.init()
    peripheral.delegate = self
  }
  
  func onConnected(_ completion: @escaping (_ res: Result<(), Client.Error>) -> ()) {
    connectCompleted = completion
  }
  func connected(_ res: Result<(), Client.Error>) {
    connectCompleted?(res)
    connectCompleted = nil
  }
  func onDisconnected(_ completion: @escaping (_ res: Result<(), Client.Error>) -> ()) {
    disconnectCompleted = completion
  }
  func disconnected(_ res: Result<(), Client.Error>) {
    disconnectCompleted?(res)
    disconnectCompleted = nil
  }
}

extension PeripheralConnection : CBPeripheralDelegate {
  func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
    
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didModifyServices invalidatedServices: [CBService]
  ) {
    
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didReadRSSI RSSI: NSNumber,
    error: Error?
  ) {
    
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverServices error: Error?
  ) {
    
  }


  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverIncludedServicesFor service: CBService,
    error: Error?
  ) {
    
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {}

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {}

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {}

  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {}

  func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {}

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {}

  func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {}


  func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {}

  @available(iOS 11.0, *)
  func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {}
}

class Client : NSObject {
  
  enum Error : LocalizedError {
    case notCreated
    case invalidUUIDString(String)
    case noPeripheralFoundFor(UUID)
    case peripheralConnection(internal: Swift.Error?)
    case peripheralDisconnection(internal: Swift.Error)

  }
    
  private class PeerConnectionEventHandler {
    let peerUUID: UUID
    
    private var connectionEventOccured: ((_ event: CBConnectionEvent) -> ())?
    
    init(_ uuid: UUID) {
      peerUUID = uuid
    }

    @available(iOS 13.0, *)
    func onConnectionEvent(
      _ handler: @escaping (_ event: CBConnectionEvent) -> ()
    ) {
      connectionEventOccured = handler
    }
    @available(iOS 13.0, *)
    func connectionEvent(_ event: CBConnectionEvent) {
      connectionEventOccured?(event)
    }
  }
  
  typealias SignatureEnumT = Method.DefaultChannel.Signature
  
  private let eventSink: EventSink
  private var centralManager: CBCentralManager?
  
  private var peripheralConnections = [UUID : PeripheralConnection]()
  private var peerConnectionEventHandlers = [UUID : PeerConnectionEventHandler]()
  
  init(eventSink: EventSink) {
    self.eventSink = eventSink
    super.init()
  }
  
  func noop() {}
  
  var isCreated: Bool {
    return centralManager != nil
  }
  
  func create(restoreId: String?, showPowerAlert: Bool?) {
    var options: [String : Any]?
    if restoreId != nil || showPowerAlert != nil {
      var opts = [String : Any]()
      if let restoreId = restoreId {
        opts[CBCentralManagerOptionShowPowerAlertKey] = restoreId
      }
      if let showPowerAlert = showPowerAlert {
        opts[CBCentralManagerOptionShowPowerAlertKey] = showPowerAlert
      }
      options = opts
    }
    centralManager = CBCentralManager(
      delegate: self,
      queue: nil,
      options: options
    )
  }
  
  func destroy() {
    centralManager?.stopScan()
    centralManager?.delegate = nil
    centralManager = nil
  }
  
  func cancelTransaction(transactionId: Any?) {}
  
  var state : String {
    let unknown = "Unknown"
    switch self.centralManager?.state {
    case .none, .some(.unknown): return unknown
    case .some(let state):
      switch state {
      case .unknown: return unknown
      case .resetting: return "Resetting"
      case .unsupported: return "Unsupported"
      case .unauthorized: return "Unauthorized"
      case .poweredOff: return "PoweredOff"
      case .poweredOn: return "PoweredOn"
      @unknown default: return unknown
      }
    }
  }
  
  func startDeviceScan(withServices services: [String]?, allowDuplicates: Bool?) {
    var options: [String : Any]?
    if let allowDuplicates = allowDuplicates {
      options = [CBCentralManagerScanOptionAllowDuplicatesKey : allowDuplicates]
    }
    centralManager?.scanForPeripherals(
      withServices: services?.map(CBUUID.init(string:)),
      options: options
    )
  }
  
  func stopDeviceScan() {
    centralManager?.stopScan()
  }
  
  private func retrievePeripheralFor(uuid: UUID) -> CBPeripheral? {
    return centralManager?.retrievePeripherals(withIdentifiers: [uuid]).last
  }
  
  private func peripheralConnectionFor(uuid: UUID) -> PeripheralConnection? {
    if let periConn = peripheralConnections[uuid] {
      return periConn
    }
    guard let peri = retrievePeripheralFor(uuid:uuid) else {
      return nil
    }
    let periConn = PeripheralConnection(peri)
    peripheralConnections[uuid] = periConn
    return periConn
  }
  
  private func peripheralFor(uuid: UUID) -> CBPeripheral? {
    return peripheralConnectionFor(uuid: uuid)?.peripheral
  }
  
  func connectToDevice(
    id: String,
    timoutMillis: Int?,
    completion: @escaping (_ completion: Result<(), Error>) -> ()
  ) {
    guard
      let centralManager = centralManager
    else {
      completion(.failure(.notCreated))
      return
    }
    guard
      let uuid = UUID(uuidString: id)
    else {
      completion(.failure(Error.invalidUUIDString(id)))
      return
    }
    guard
      let conn = peripheralConnectionFor(uuid: uuid)
    else {
      completion(.failure(.noPeripheralFoundFor(uuid)))
      return
    }

    conn.onConnected { res in
      completion(res)
    }
    // FIXME: support connection option flags
    centralManager.connect(conn.peripheral)
  }

  func isDeviceConnected(id: String) -> Result<Bool, Error> {
    guard
      let uuid = UUID(uuidString: id)
    else {
      return .failure(Error.invalidUUIDString(id))
    }
    return .success(peripheralFor(uuid: uuid)?.state == .connected)
  }
  
  func observeConnectionState(
    deviceIdentifier: String,
    emitCurrentValue: Bool?
  ) -> Result<(), Error> {
    
    guard
      let uuid = UUID(uuidString: deviceIdentifier)
    else {
      return .failure(Error.invalidUUIDString(deviceIdentifier))
    }
    let connStateEvents = eventSink.connectionStateChangeEvents
    
    if emitCurrentValue == true {
      connStateEvents.sink(
        peripheralFor(uuid: uuid)?.state ?? .disconnected
      )
    }
    if #available(iOS 13.0, *), let centralManager = centralManager {
      let handler = PeerConnectionEventHandler(uuid)
      peerConnectionEventHandlers[uuid] = handler
      
      connStateEvents.afterCancelDo { [weak self] in
        self?.peerConnectionEventHandlers[uuid] = nil
      }
      
      handler.onConnectionEvent { event in
        let state: CBPeripheralState
        switch event {
        case .peerConnected:
          state = .connected
        case .peerDisconnected:
          state = .disconnected
        @unknown default:
          state = .disconnected
        }
        connStateEvents.sink(state)
      }
      
      centralManager.registerForConnectionEvents(
        options: [.peripheralUUIDs : [uuid]]
      )
    }
    
    return .success(())
  }
  
  func cancelConnection(deviceIdentifier: String) -> Result<(), Error> {
    guard
      let uuid = UUID(uuidString: deviceIdentifier)
    else {
      return .failure(Error.invalidUUIDString(deviceIdentifier))
    }
    if let peri = peripheralFor(uuid: uuid) {
      centralManager?.cancelPeripheralConnection(peri)
    }
    return .success(())
  }
  
  func discoverAllServicesAndCharacteristics(deviceIdentifier: String,
                                             transactionId: String?) -> Result<(), Error> {
    guard
      let uuid = UUID(uuidString: deviceIdentifier)
    else {
      return .failure(Error.invalidUUIDString(deviceIdentifier))
    }
    guard let peri = peripheralFor(uuid: uuid) else {
      return .failure(Error.noPeripheralFoundFor(uuid))
    }
    peri.discoverServices(nil)
    return .success(())
  }
}

extension Client : CallHandler {
  func handle(call: Method.Call<SignatureEnumT>) {
    switch call.signature {
    case .isClientCreated:
      call.result(isCreated)
    case .createClient(let restoreId, let showPowerAlert):
      create(restoreId: restoreId, showPowerAlert: showPowerAlert)
      call.result()
    case .destroyClient:
      destroy()
      call.result()
    case .cancelTransaction(let transactionId):
      cancelTransaction(transactionId: transactionId)
      call.result()
    case .getState:
      call.result(state)
    case .enableRadio:
      noop()
      call.result()
    case .disableRadio:
      noop()
      call.result()
    case .startDeviceScan(let uuids, let allowDuplicates):
      startDeviceScan(withServices: uuids, allowDuplicates: allowDuplicates)
      call.result()
    case .stopDeviceScan:
      stopDeviceScan()
      call.result()
    case .connectToDevice(let id, let timoutMillis):
      connectToDevice(id: id, timoutMillis: timoutMillis) { res in
        call.result(res)
      }
    case .isDeviceConnected(let id):
      call.result(isDeviceConnected(id: id))
    case .observeConnectionState(let deviceIdentifier, let emitCurrentValue):
      let res = observeConnectionState(
        deviceIdentifier: deviceIdentifier,
        emitCurrentValue: emitCurrentValue
      )
      call.result(res)
    case .cancelConnection(let deviceIdentifier):
      call.result(cancelConnection(deviceIdentifier: deviceIdentifier))
    case .discoverAllServicesAndCharacteristics(let deviceIdentifier,
                                                let transactionId):
      discoverAllServicesAndCharacteristics(
        deviceIdentifier: deviceIdentifier,
        transactionId: transactionId
      )
      call.result(FlutterMethodNotImplemented)
    case .services:
      call.result(FlutterMethodNotImplemented)
    case .characteristics:
      call.result(FlutterMethodNotImplemented)
    case .characteristicsForService:
      call.result(FlutterMethodNotImplemented)
    case .descriptorsForDevice:
      call.result(FlutterMethodNotImplemented)
    case .descriptorsForService:
      call.result(FlutterMethodNotImplemented)
    case .descriptorsForCharacteristic:
      call.result(FlutterMethodNotImplemented)
    case .logLevel:
      call.result(FlutterMethodNotImplemented)
    case .setLogLevel:
      call.result(FlutterMethodNotImplemented)
    case .rssi:
      call.result(FlutterMethodNotImplemented)
    case .requestMtu:
      call.result(FlutterMethodNotImplemented)
    case .getConnectedDevices:
      call.result(FlutterMethodNotImplemented)
    case .getKnownDevices:
      call.result(FlutterMethodNotImplemented)
    case .readCharacteristicForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .readCharacteristicForDevice:
      call.result(FlutterMethodNotImplemented)
    case .readCharacteristicForService:
      call.result(FlutterMethodNotImplemented)
    case .writeCharacteristicForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .writeCharacteristicForDevice:
      call.result(FlutterMethodNotImplemented)
    case .writeCharacteristicForService:
      call.result(FlutterMethodNotImplemented)
    case .monitorCharacteristicForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .monitorCharacteristicForDevice:
      call.result(FlutterMethodNotImplemented)
    case .monitorCharacteristicForService:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForCharacteristic:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForService:
      call.result(FlutterMethodNotImplemented)
    case .readDescriptorForDevice:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForIdentifier:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForCharacteristic:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForService:
      call.result(FlutterMethodNotImplemented)
    case .writeDescriptorForDevice:
      call.result(FlutterMethodNotImplemented)
    }
  }
}


extension Client : CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    
  }
  
  func centralManager(
    _ central: CBCentralManager,
    willRestoreState dict: [String : Any]
  ) {
    
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String : Any],
    rssi RSSI: NSNumber
  ) {
    
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didConnect peripheral: CBPeripheral
  ) {
    peripheralConnections[peripheral.identifier]?.connected(.success(()))
  }
  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Swift.Error?
  ) {
    let conn = peripheralConnections[peripheral.identifier]
    conn?.connected(.success(()))
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Swift.Error?
  ) {
    let conn = peripheralConnections[peripheral.identifier]
    if let error = error {
      conn?.connected(
        .failure(Error.peripheralDisconnection(internal: error))
      )
      return
    }
    conn?.disconnected(.success(()))
  }
  
  @available(iOS 13.0, *)
  func centralManager(
    _ central: CBCentralManager,
    connectionEventDidOccur event: CBConnectionEvent,
    for peripheral: CBPeripheral
  ) {
    peerConnectionEventHandlers[peripheral.identifier]?.connectionEvent(event)
    
  }

  func centralManager(
    _ central: CBCentralManager,
    didUpdateANCSAuthorizationFor peripheral: CBPeripheral
  ) {
    
  }
}
