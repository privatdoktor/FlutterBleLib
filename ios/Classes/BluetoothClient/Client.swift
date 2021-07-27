//
//  Client.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 11/05/2021.
//

import Foundation
import CoreBluetooth


class ConnectionStateResponse : Encodable {
  let peripheralIdentifier: String
  let connectionState: String
  
  init(state: CBPeripheralState, peripheralId: UUID) {
    switch state {
    case .connected:
      connectionState = "connected"
    case .connecting:
      connectionState = "connecting"
    case .disconnected:
      connectionState = "disconnected"
    case .disconnecting:
      connectionState = "disconnecting"
    @unknown default:
      connectionState = "disconnected"
    }
    
    peripheralIdentifier = peripheralId.uuidString.lowercased()
  }

  private enum CodingKeys: String, CodingKey {
    case peripheralIdentifier = "peripheralIdentifier"
    case connectionState = "connectionState"
  }
}

extension CBUUID {
  var fullUUIDString: String {
    let native = uuidString.lowercased()
    if (native.count == 4) {
      return "0000\(native)-0000-1000-8000-00805f9b34fb"
    }
    if (native.count == 8) {
      return "\(native)-0000-1000-8000-00805f9b34fb"
    }
    return native
  }
}


enum ClientError : LocalizedError {
  case notCreated
  case invalidState(CBManagerState?)
  case invalidUUIDString(String)
  case noPeripheralFoundFor(UUID, expectedState: CBPeripheralState? = nil)
  case peripheralConnection(internal: Swift.Error?)
  case peripheralDisconnection(internal: Swift.Error?)
  case peripheral(PeripheralError)
}

class Client : NSObject {
  
  class Stream<AnyT: Any> {
    enum Payload<AnyT: Any> {
      case data(AnyT)
      case endOfStream
    }
    let eventHandler: (_ payload: Payload<AnyT>) -> ()
    var afterCancelDo: (() -> ())?
    
    init(eventHandler: @escaping (_ payload: Payload<AnyT>) -> ()) {
      self.eventHandler = eventHandler
    }
  }
  
  private class PeerConnectionEventHandler {
    let peerUUID: UUID
    
    private var _connectionEventOccured: ((_ event: CBConnectionEvent) -> ())?
    
    init(_ uuid: UUID) {
      peerUUID = uuid
    }

    @available(iOS 13.0, *)
    func onConnectionEvent(
      _ handler: @escaping (_ event: CBConnectionEvent) -> ()
    ) {
      _connectionEventOccured = handler
    }
    @available(iOS 13.0, *)
    func connectionEvent(_ event: CBConnectionEvent) {
      _connectionEventOccured?(event)
    }
  }
  
  var centralManager: CBCentralManager?
  
  private var discoveredPeripherals = [UUID : DiscoveredPeripheral]()
  
  private var peerConnectionEventHandlers = [UUID : PeerConnectionEventHandler]()
  private var onPowerOnListeners = Queue<(_ cm: CBCentralManager) -> ()>()
  
  var stateChanges: Stream<Int>?
  var stateRestoreEvents: Stream<[PeripheralResponse]>?
  var scanningEvents: Stream<ScanResultEvent>?
}
// MARK: -- Helpers
extension Client {
  private func discoveredPeripheral(
    for uuid: UUID,
    centralManager: CBCentralManager
  ) -> DiscoveredPeripheral? {
    if let dp = discoveredPeripherals[uuid] {
      return dp
    }
    guard
      let peri = centralManager.retrievePeripherals(
        withIdentifiers: [uuid]
      ).last
    else {
      return nil
    }
    let dp = DiscoveredPeripheral(
      peri,
      centralManager: centralManager
    )
    discoveredPeripherals[uuid] = dp
    return dp
  }
  
  private func discoveredPeripheral(
    for deviceIdentifier: String,
    expectedState: CBPeripheralState? = nil
  ) -> Result<DiscoveredPeripheral, ClientError> {
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    guard
      let uuid = UUID(uuidString: deviceIdentifier)
    else {
      return .failure(ClientError.invalidUUIDString(deviceIdentifier))
    }
    guard
      let dp = discoveredPeripheral(
        for: uuid,
        centralManager: centralManager
      )
    else {
      return .failure(
        ClientError.noPeripheralFoundFor(uuid, expectedState: expectedState)
      )
    }
    if let state = expectedState,
       dp.peripheral.state != state {
      return .failure(
        ClientError.noPeripheralFoundFor(uuid, expectedState: state)
      )
    }
    
    return .success(dp)
  }
  
  private func peripheralFor(
    uuid: UUID,
    centralManager: CBCentralManager
  ) -> CBPeripheral? {
    return discoveredPeripheral(
      for: uuid,
      centralManager: centralManager
    )?.peripheral
  }
  
}

// MARK: -- CallHandler API
extension Client {
  
  func noop() {}
  
  var isCreated: Bool {
    return centralManager != nil
  }
  
  func create(restoreId: String?, showPowerAlert: Bool?) {
    var options: [String : Any]?
    if restoreId != nil || showPowerAlert != nil {
      var opts = [String : Any]()
      if let restoreId = restoreId {
        opts[CBCentralManagerOptionRestoreIdentifierKey] = restoreId
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
    discoveredPeripherals.forEach { (_, dp) in
      dp.centralManager = centralManager
    }
  }
  
  func destroy() {
    centralManager?.stopScan()
    centralManager?.delegate = nil
    centralManager = nil
  }
    
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
  
  func startDeviceScan(
    withServices services: [String]?,
    allowDuplicates: Bool?
  ) -> Result<(), ClientError> {
    var options: [String : Any]?
    if let allowDuplicates = allowDuplicates {
      options = [CBCentralManagerScanOptionAllowDuplicatesKey : allowDuplicates]
    }
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    guard
      centralManager.state == .poweredOn
    else {
      onPowerOnListeners.enqueue { cm in
        cm.scanForPeripherals(
          withServices: services?.map(CBUUID.init(string:)),
          options: options
        )
      }
      return .success(())
    }
    centralManager.scanForPeripherals(
      withServices: services?.map(CBUUID.init(string:)),
      options: options
    )
    return .success(())
  }
  
  func stopDeviceScan() -> Result<(), ClientError> {
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    guard
      centralManager.state == .poweredOn
    else {
      onPowerOnListeners.enqueue { cm in
        cm.stopScan()
      }
      return .success(())
    }
    centralManager.stopScan()
    return .success(())
  }
  
  func connectToDevice(
    id: String,
    timoutMillis: Int?,
    completion: @escaping (_ completion: Result<(), ClientError>) -> ()
  ) {
    switch discoveredPeripheral(for: id) {
    case .failure(let error):
      completion(.failure(error))
    case .success(let dp):
      // FIXME: support connection option flags
      dp.connect(completion)
    }
  }

  func isDeviceConnected(id: String) -> Result<Bool, ClientError> {
    switch discoveredPeripheral(for: id) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      return .success(dp.peripheral.state == .connected)
    }
  }

  func observeConnectionState(
    deviceIdentifier: String,
    emitCurrentValue: Bool?,
    eventStream: Stream<ConnectionStateResponse>
  ) -> Result<(), ClientError> {
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    guard
      let uuid = UUID(uuidString: deviceIdentifier)
    else {
      return .failure(ClientError.invalidUUIDString(deviceIdentifier))
    }
    
    if emitCurrentValue == true {
      
      let state = peripheralFor(
        uuid: uuid,
        centralManager: centralManager
      )?.state ?? .disconnected
      
      eventStream.eventHandler(
        .data(
          ConnectionStateResponse(state: state, peripheralId: uuid)
        )
      )
    }
    if #available(iOS 13.0, *) {
      let handler = PeerConnectionEventHandler(uuid)
      peerConnectionEventHandlers[uuid] = handler
      
      eventStream.afterCancelDo = { [weak self] in
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
        eventStream.eventHandler(
          .data(ConnectionStateResponse(state: state, peripheralId: uuid))
        )
      }
      
      centralManager.registerForConnectionEvents(
        options: [.peripheralUUIDs : [uuid]]
      )
    } else {
      guard
        let dp = discoveredPeripherals[uuid]
      else {
        return.success(())
      }
      eventStream.afterCancelDo = {
        dp.onConnectionEvent(handler:nil)
      }
      
      dp.onConnectionEvent { event in
        let state: CBPeripheralState
        switch event {
        case .peerConnected:
          state = .connected
        case .peerDisconnected:
          state = .disconnected
        @unknown default:
          state = .disconnected
        }
        eventStream.eventHandler(
          .data(ConnectionStateResponse(state: state, peripheralId: uuid))
        )
      }
    }
    
    return .success(())
  }
  
  func cancelConnection(
    deviceIdentifier: String,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
    case .success(let dp):
      dp.disconnect(completion)
    }
  }
  
  func discoverServices(
    deviceIdentifier: String,
    serviceUUIDStrs: [String]? = nil,
    completion: @escaping (Result<[ServiceResponse], ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    let serviceCBUUIDs = serviceUUIDStrs.map(
      { $0.map( { CBUUID(string: $0) } ) }
    )
    discoPeri.discoverServices(serviceUUIDs: serviceCBUUIDs) { res in
      switch res {
      case .success(let dss):
        let services = dss.values.map { ServiceResponse(with: $0.service) }
        completion(.success(services))
      case .failure(let error):
        completion(.failure(ClientError.peripheral(error)))
      }
    }
  }
  
  func discoverCharacteristics(
    deviceIdentifier: String,
    serviceUuid: String,
    characteristicUUIDStrs: [String]? = nil,
    completion: @escaping (Result<CharacteristicsResponse, ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    guard
      let ds = discoPeri.discoveredServices[CBUUID(string:serviceUuid)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(discoPeri.peripheral, id: serviceUuid))
        )
      )
      return
    }
    let characteristicCBUUIDs = characteristicUUIDStrs.map(
      { $0.map( { CBUUID(string: $0) } ) }
    )
    ds.discoverCharacteristics(characteristicUUIDs: characteristicCBUUIDs) { res in
      switch res {
      case .success(let dss):
        let chars = dss.map({ $0.value.characteristic })
        completion(
          .success(
            CharacteristicsResponse(
              with: chars,
              service: ds.service
            )
          )
        )
      case .failure(let error):
        completion(.failure(.peripheral(error)))
      }
    }
  }
  
//  func discoverAllServicesAndCharacteristics(
//    deviceIdentifier: String,
//    completion: @escaping (Result<(), ClientError>) -> ()
//  ) {
//    let discoPeri: DiscoveredPeripheral
//    switch discoveredPeripheral(for: deviceIdentifier) {
//    case .failure(let error):
//      completion(.failure(error))
//      return
//    case .success(let dp):
//      discoPeri = dp
//    }
//
//    discoPeri.discoverServices() { res in
//      switch res {
//      case .success(let services):
//        var services = Array(services.values)
//        let ds = services.removeLast();
//        populateCharacteristics(for: ds, nextServices: services) {
//
//        }
//      case .failure(let error):
//        completion(.failure(ClientError.peripheral(error)))
//      }
//    }
//
//    func populateCharacteristics(
//      for ds: DiscoveredService,
//      nextServices: [DiscoveredService],
//      completion: () -> ()
//    ) {
//      ds.discoverCharacteristics { res in
//        switch res {
//        case .success(let chars):
//          var chars = Array(chars.values)
//          let dc = chars.removeLast()
//          populateDescriptors(
//            for: dc,
//            nextChars: chars
//          ) {
//
//
//          }
//        case .failure(let error):
//          break
//        }
//
//      }
//
//
////      var allDiscoveredChars =
////        [DiscoveredCharacteristic]()
////      var allErrors =
////        [PeripheralError]()
////
////      for ds in services {
////
////      }
////
////      populateDescriptors(
////        for: allDiscoveredChars,
////        allErrors: allErrors
////      )
//
//    }
//
//    func populateDescriptors(
//      for dc: DiscoveredCharacteristic,
//      nextChars: [DiscoveredCharacteristic],
//      completion: () -> ()
//    ) {
//      dc.discoverDescriptors { _ in
//        guard nextChars.isEmpty == false else {
//          completion()
//          return
//        }
//        var chars = nextChars
//        let dc = chars.removeLast()
//        populateDescriptors(for: dc, nextChars: chars, completion: completion)
//      }
//
//    }
//  }
  func services(
    for deviceIdentifier: String
  ) -> Result<[ServiceResponse], ClientError> {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      discoPeri = dp
    }
    let serResps = discoPeri.peripheral.services?.map({
      ServiceResponse(with: $0)
    }) ?? []
    return .success(serResps)
  }

  private func characteristics(
    for discoveredPeripheral: DiscoveredPeripheral,
    serviceCbuuid: CBUUID
  ) -> Result<CharacteristicsResponse, ClientError> {
    guard
      let ds = discoveredPeripheral.discoveredServices[serviceCbuuid]
    else {
      return .failure(
        .peripheral(
          .noServiceFound(discoveredPeripheral.peripheral, id: serviceCbuuid.uuidString)
        )
      )
    }
    return .success(
      CharacteristicsResponse(
        with: ds.service.characteristics ?? [],
        service: ds.service
      )
    )
  }
  
  func characteristics(
    for deviceIdentifier: String,
    serviceUUID: String
  ) -> Result<CharacteristicsResponse, ClientError> {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      discoPeri = dp
    }
    let cbuuid = CBUUID(string: serviceUUID)
    return characteristics(for: discoPeri, serviceCbuuid: cbuuid)
  }
  
  func descriptorsForDevice(
    for deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String
  ) -> Result<DescriptorsForPeripheralResponse, ClientError> {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      discoPeri = dp
    }
    guard
      let ds = discoPeri.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      return .failure(
        .peripheral(
          .noServiceFound(discoPeri.peripheral, id: serviceUUID)
        )
      )
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      return .failure(
        .peripheral(
          .noCharacteristicFound(ds.service, id: characteristicUUID)
        )
      )
    }
    let char = dc.characteristic
    return .success(
      DescriptorsForPeripheralResponse(
        with: char.descriptors ?? [],
        char: char,
        service: char.service
      )
    )
  }
  
  var logLevel: String {
    get {
      return "verbose"
    }
    set {
      // zero fax given now about loggin levels really
    }
  }
  
  func readRssi(
    for deviceIdentifier: String,
    completion: @escaping (Result<Int, ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    discoPeri.readRssi(completion)
  }
  
  func requestMtu(for deviceIdentifier: String) -> Int {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure:
      return CBPeripheral.defaultMtu
    case .success(let dp):
      discoPeri = dp
    }
    return discoPeri.peripheral.mtu
  }
  
  func connectedDevices(serviceUUIDs: [String]) -> Result<[PeripheralResponse], ClientError> {
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    return .success(
      centralManager.retrieveConnectedPeripherals(
        withServices: serviceUUIDs.map(CBUUID.init)
      ).map(
        PeripheralResponse.init
      )
    )
  }
  
  func knownDevices(deviceIdentifiers: [String]) -> Result<[PeripheralResponse], ClientError> {
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    return .success(
      centralManager.retrievePeripherals(
        withIdentifiers: deviceIdentifiers.compactMap(UUID.init)
      ).map(
        PeripheralResponse.init
      )
    )
  }
  
  private func readCharacteristic(
    for dc: DiscoveredCharacteristic,
    completion: @escaping (Result<SingleCharacteristicWithValueResponse, ClientError>) -> ()
  ) {
    dc.read { res in
      switch res {
      case .failure(let error):
        completion(.failure(.peripheral(error)))
      case .success(let char):
        let resp = SingleCharacteristicWithValueResponse(
          char: char
        )
        completion(.success(resp))
      }
    }
  }
  
  func readCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    completion: @escaping (Result<SingleCharacteristicWithValueResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    readCharacteristic(
      for: dc,
      completion: completion
    )
  }
  
  private func writeCharacteristic(
    for dc: DiscoveredCharacteristic,
    value: FlutterStandardTypedData,
    withResponse: Bool,
    completion: @escaping (Result<SingleCharacteristicResponse, ClientError>) -> ()
  ) {
    dc.write(
      value.data,
      type: withResponse ? .withResponse : .withoutResponse
    ) { res in
      completion(
        res.map({ char in
          return SingleCharacteristicResponse(
            char: char
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }
  
  func writeCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    value: FlutterStandardTypedData,
    withResponse: Bool,
    completion: @escaping (Result<SingleCharacteristicResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    writeCharacteristic(
      for: dc,
      value: value,
      withResponse: withResponse,
      completion: completion
    )
    
  }

  
  private func monitorCharacteristic(
    for dc: DiscoveredCharacteristic,
    eventSteam: Stream<SingleCharacteristicWithValueResponse>,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    let puuid = dc.characteristic.service.peripheral.identifier
    guard
      let dp =
        discoveredPeripherals[puuid]
    else {
      completion(
        .failure(.noPeripheralFoundFor(puuid, expectedState: nil))
      )
      return
    }
    eventSteam.afterCancelDo = {
      let char = dc.characteristic
      if char.isNotifying {
        char.service.peripheral.setNotifyValue(false, for: char)
      }
      dc.onValueUpdate(handler: nil)
    }
    dp.onDisconnected {
      eventSteam.eventHandler(.endOfStream)
    }
    dc.onValueUpdate { char in
      eventSteam.eventHandler(
        .data(
          SingleCharacteristicWithValueResponse(
            char: char
          )
        )
      )
    }
    guard
      dc.characteristic.isNotifying == false
    else {
      completion(.success(()))
      return
    }
    
    dc.setNotify(true) { res in
      switch res {
      case .failure(let error):
        completion(.failure(.peripheral(error)))
        return
      case .success(let char):
        if char.isNotifying {
          completion(.success(()))
        } else {
          completion(
            .failure(
              .peripheral(.characteristicSetNotify(char, internal: nil))
            )
          )
        }
        
      }
    }
  }
  
  func monitorCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    eventSteam: Stream<SingleCharacteristicWithValueResponse>,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    monitorCharacteristic(
      for: dc,
      eventSteam: eventSteam,
      completion: completion
    )
  }
  
  private func readDescriptor(
    for dd: DiscoveredDescriptor,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    dd.read { res in
      completion(
        res.map({ desc in
          return DescriptorResponse(
            desc: desc
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }
  
  func readDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    guard
      let dd = dc.discoveredDescriptors[CBUUID(string:descriptorUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noDescriptorFound(dc.characteristic, id: descriptorUUID))
        )
      )
      return
    }
    readDescriptor(
      for: dd,
      completion: completion
    )
  }
  
  private func writeDescriptor(
    for dd: DiscoveredDescriptor,
    value: FlutterStandardTypedData,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    dd.write(value.data) { res in
      completion(
        res.map({ desc in
          return DescriptorResponse(
            desc: desc
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }

  
  func writeDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    guard
      let dd = dc.discoveredDescriptors[CBUUID(string:descriptorUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noDescriptorFound(dc.characteristic, id: descriptorUUID))
        )
      )
      return
    }
    writeDescriptor(
      for: dd,
      value: value,
      completion: completion
    )
  }
}

extension Client : CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
      while onPowerOnListeners.isEmpty == false {
        onPowerOnListeners.dequeue()?(central)
      }
    }
    stateChanges?.eventHandler(.data(central.state.rawValue))
  }
  
  func centralManager(
    _ central: CBCentralManager,
    willRestoreState dict: [String : Any]
  ) {
    guard
      let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
    else {
      return
    }
    stateRestoreEvents?.eventHandler(
      .data(peripherals.map(PeripheralResponse.init))
    )
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String : Any],
    rssi RSSI: NSNumber
  ) {
    if let dp = discoveredPeripherals[peripheral.identifier] {
      dp.updateInternalPeripheral(peripheral)
    } else {
      discoveredPeripherals[peripheral.identifier] =
        DiscoveredPeripheral(peripheral, centralManager: central)
    }
    scanningEvents?.eventHandler(
      .data(
        ScanResultEvent(
          peripheral: peripheral,
          advertisementData: advertisementData,
          rssi: RSSI.intValue
        )
      )
    )
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didConnect peripheral: CBPeripheral
  ) {
    discoveredPeripherals[peripheral.identifier]?.connected(.success(()))
  }
  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Swift.Error?
  ) {
    
    discoveredPeripherals[peripheral.identifier]?.connected(
      .failure(ClientError.peripheralConnection(internal: error))
    )
  }
  
  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Swift.Error?
  ) {
    let dp = discoveredPeripherals[peripheral.identifier]
    if let error = error {
      dp?.disconnected(
        .failure(ClientError.peripheralDisconnection(internal: error))
      )
      return
    }
    dp?.disconnected(.success(()))
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
