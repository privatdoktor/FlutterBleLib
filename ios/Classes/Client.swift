//
//  Client.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 11/05/2021.
//

import Foundation
import CoreBluetooth

class HashableIdCache<HashableT: Hashable> {
  private var reverseCache = [Int : HashableT]()
  private var cache = [HashableT : Int]()
  func numeric(from hashable: HashableT) -> Int {
    let numeric: Int
    if let num = cache[hashable] {
      numeric = num
    } else {
      numeric = hashable.hashValue
      cache[hashable] = numeric
    }
    reverseCache[numeric] = hashable
    return numeric
  }
  func hashable(from numeric: Int) -> HashableT? {
    return reverseCache[numeric]
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
  
  private let eventSink: EventSink
  var centralManager: CBCentralManager?
  
  private var discoveredPeripherals = [UUID : DiscoveredPeripheral]()
  private var peripheralUuidCache = HashableIdCache<UUID>()
  private var serviceUuidCache = HashableIdCache<CBUUID>()
  private var characteristicUuidCache = HashableIdCache<CBUUID>()
  private var descriptorUuidCache =  HashableIdCache<CBUUID>()
  
  private var peerConnectionEventHandlers = [UUID : PeerConnectionEventHandler]()
  private var onPowerOnListeners = Queue<(_ cm: CBCentralManager) -> ()>()
  
  init(eventSink: EventSink) {
    self.eventSink = eventSink
    super.init()
  }
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
  
  private func discoveredCharacteristic(
    for characteristicNumericId: Int
  ) -> Result<DiscoveredCharacteristic, ClientError> {
    guard
      let characteristicCbuuid =
        characteristicUuidCache.hashable(from: characteristicNumericId)
    else {
      return .failure(
        .peripheral(
          .noCharacteristicFound(nil, id: "\(characteristicNumericId)")
        )
      )
    }
    var foundDiscoChar: DiscoveredCharacteristic?
    outer: for (_, dp) in discoveredPeripherals {
      for (_, ds) in dp.discoveredServices {
        if let dc = ds.discoveredCharacteristics[characteristicCbuuid] {
          foundDiscoChar = dc
          break outer
        }
      }
    }
    guard
      let dc = foundDiscoChar
    else {
      return .failure(
        .peripheral(
          .noCharacteristicFound(nil, id: characteristicCbuuid.fullUUIDString)
        )
      )
    }
    return .success(dc)
  }
  
  private func discoveredService(
    for serviceNumericId: Int
  ) -> Result<DiscoveredService, ClientError> {
    guard
      let serviceCbuuid =
        serviceUuidCache.hashable(from: serviceNumericId)
    else {
      return .failure(
        .peripheral(
          .noServiceFound(nil, id: "\(serviceNumericId)")
        )
      )
    }
    var foundDiscoSer: DiscoveredService?
    for (_, dp) in discoveredPeripherals {
      if let ds = dp.discoveredServices[serviceCbuuid] {
        foundDiscoSer = ds
        break
      }
    }
    guard
      let ds = foundDiscoSer
    else {
      return .failure(
        .peripheral(
          .noServiceFound(nil, id: serviceCbuuid.fullUUIDString)
        )
      )
    }
    return .success(ds)
  }
  private func discoveredDescriptor(
    for descriptorNumericId: Int
  ) -> Result<DiscoveredDescriptor, ClientError> {
    guard
      let descriptorCbuuid =
        descriptorUuidCache.hashable(from: descriptorNumericId)
    else {
      return .failure(
        .peripheral(
          .noDescriptorFound(nil, id: "\(descriptorNumericId)")
        )
      )
    }
    var foundDiscoDesc: DiscoveredDescriptor?
    outer: for (_, dp) in discoveredPeripherals {
      for (_, ds) in dp.discoveredServices {
        for (_, dc) in ds.discoveredCharacteristics {
          if let dc = dc.discoveredDescriptors[descriptorCbuuid] {
            foundDiscoDesc = dc
            break outer
          }
        }
      }
    }
    guard
      let dd = foundDiscoDesc
    else {
      return .failure(
        .peripheral(
          .noDescriptorFound(nil, id: descriptorCbuuid.fullUUIDString)
        )
      )
    }
    return .success(dd)
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
    emitCurrentValue: Bool?
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
    let connStateEvents = eventSink.connectionStateChangeEvents
    
    if emitCurrentValue == true {
      connStateEvents.sink(
        peripheralFor(
          uuid: uuid,
          centralManager: centralManager
        )?.state ?? .disconnected
      )
    }
    if #available(iOS 13.0, *) {
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
    } else {
      guard
        let dp = discoveredPeripherals[uuid]
      else {
        return.success(())
      }
      connStateEvents.afterCancelDo {
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
        connStateEvents.sink(state)
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
  
  func discoverAllServicesAndCharacteristics(
    deviceIdentifier: String,
    transactionId: String?,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    
    discoPeri.discoverServices() { res in
      switch res {
      case .success(let services):
        populateCharacteristics(for: Array(services.values))
      case .failure(let error):
        completion(.failure(ClientError.peripheral(error)))
      }
    }
    func populateCharacteristics(for services: [DiscoveredService]) {
      let group = DispatchGroup()
      var allDiscoveredChars =
        [DiscoveredCharacteristic]()
      var allErrors =
        [PeripheralError]()
      group.enter()
      for ds in services {
        group.enter()
        ds.discoverCharacteristics { res in
          switch res {
          case .success(let chars):
            allDiscoveredChars.append(contentsOf: chars.values)
          case .failure(let error):
            allErrors.append(error)
          }
          group.leave()
        }
      }
      group.leave()
      group.notify(queue: .main) {
        populateDescriptors(
          for: allDiscoveredChars,
          allErrors: allErrors
        )
      }
    }
    
    func populateDescriptors(
      for characteristics: [DiscoveredCharacteristic],
      allErrors: [PeripheralError]
    ) {
      var allErrors = allErrors
      let group = DispatchGroup()
      var allDiscoveredDescs =
        [DiscoveredDescriptor]()
      group.enter()
      for dc in characteristics {
        group.enter()
        dc.discoverDescriptors { res in
          switch res {
          case .success(let descs):
            allDiscoveredDescs.append(contentsOf: descs.values)
          case .failure(let error):
            allErrors.append(error)
          }
          group.leave()
        }
      }
      group.leave()
      group.notify(queue: .main) {
        completion(.success(()))
      }
    }
  }
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
      ServiceResponse(with: $0, using: serviceUuidCache)
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
        service: ds.service,
        charUuidCache: characteristicUuidCache,
        serviceUuidCache: serviceUuidCache
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
  
  
  func characteristics(
    for serviceNumericId: Int
  ) -> Result<[CharacteristicResponse], ClientError> {
    guard
      let cbuuid = serviceUuidCache.hashable(from: serviceNumericId)
    else {
      return .failure(
        .peripheral(.noServiceFound(nil, id: "\(serviceNumericId)"))
      )
    }
    guard
      let dp = discoveredPeripherals.values.first(
        where: { $0.discoveredServices.keys.contains(cbuuid) }
      )
    else {
      return .failure(
        .peripheral(.noServiceFound(nil, id: cbuuid.uuidString))
      )
    }
    return characteristics(
      for: dp,
      serviceCbuuid: cbuuid
    ).map { $0.characteristics }
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
        service: char.service,
        descUuidCache: descriptorUuidCache,
        charUuidChache: characteristicUuidCache,
        serviceUuidCache: serviceUuidCache
      )
    )
  }
  
  func descriptorsForService(
    serviceNumericId: Int,
    characteristicUUID: String
  ) -> Result<DescriptorsForServiceResponse, ClientError> {
    guard
      let serviceCbuuid = serviceUuidCache.hashable(from: serviceNumericId)
    else {
      return .failure(
        .peripheral(.noServiceFound(nil, id: "\(serviceNumericId)"))
      )
    }
    guard
      let dp = discoveredPeripherals.values.first(
        where: { $0.discoveredServices.keys.contains(serviceCbuuid) }
      )
    else {
      return .failure(
        .peripheral(.noServiceFound(nil, id: serviceCbuuid.uuidString))
      )
    }
    let ds = dp.discoveredServices[serviceCbuuid]!
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
      DescriptorsForServiceResponse(
        with: dc.characteristic.descriptors ?? [],
        char: char,
        descUuidCache: characteristicUuidCache,
        charUuidChache: characteristicUuidCache,
        serviceUuidCache: serviceUuidCache
      )
    )
  }
  
  func descriptorsForCharacteristic(
    characteristicNumericId: Int
  ) -> Result<DescriptorsForCharacteristicResponse, ClientError> {
    let dc: DiscoveredCharacteristic
    switch discoveredCharacteristic(for: characteristicNumericId) {
    case .failure(let error):
      return .failure(error)
    case .success(let value):
      dc = value
    }
    return .success(
      DescriptorsForCharacteristicResponse(
        with: dc.characteristic.descriptors ?? [],
        descUuidCache: characteristicUuidCache,
        charUuidChache: characteristicUuidCache,
        serviceUuidCache: serviceUuidCache
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
    transactionId: String?,
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
    transactionId: String?,
    completion: @escaping (Result<SingleCharacteristicWithValueResponse, ClientError>) -> ()
  ) {
    dc.read { res in
      switch res {
      case .failure(let error):
        completion(.failure(.peripheral(error)))
      case .success(let char):
        let resp = SingleCharacteristicWithValueResponse(
          char: char,
          charUuidCache: self.characteristicUuidCache,
          serviceUuidCache: self.serviceUuidCache
        )
        completion(.success(resp))
      }
    }
  }
  
  func readCharacteristicForIdentifier(
    characteristicNumericId: Int,
    transactionId: String?,
    completion: @escaping (Result<SingleCharacteristicWithValueResponse, ClientError>) -> ()
  ) {
    let dc: DiscoveredCharacteristic
    switch discoveredCharacteristic(for: characteristicNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dc = value
    }
    readCharacteristic(
      for: dc,
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func readCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    transactionId: String?,
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
      transactionId: transactionId,
      completion: completion
    )
  }
  func readCharacteristicForService(
    serviceNumericId: Int,
    characteristicUUID: String,
    transactionId: String?,
    completion: @escaping (Result<SingleCharacteristicWithValueResponse, ClientError>) -> ()
  ) {
    let ds: DiscoveredService
    switch discoveredService(for: serviceNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      ds = value
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
      transactionId: transactionId,
      completion: completion
    )
  }
  private func writeCharacteristic(
    for dc: DiscoveredCharacteristic,
    value: FlutterStandardTypedData,
    withResponse: Bool,
    transactionId: String?,
    completion: @escaping (Result<SingleCharacteristicResponse, ClientError>) -> ()
  ) {
    dc.write(
      value.data,
      type: withResponse ? .withResponse : .withoutResponse
    ) { res in
      completion(
        res.map({ char in
          return SingleCharacteristicResponse(
            char: char,
            charUuidCache: self.characteristicUuidCache,
            serviceUuidCache: self.serviceUuidCache
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }
  
  func writeCharacteristicForIdentifier(
    characteristicNumericId: Int,
    value: FlutterStandardTypedData,
    withResponse: Bool,
    transactionId: String?,
    completion: @escaping (Result<SingleCharacteristicResponse, ClientError>) -> ()
  ) {
    let dc: DiscoveredCharacteristic
    switch discoveredCharacteristic(for: characteristicNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dc = value
    }
    writeCharacteristic(
      for: dc,
      value: value,
      withResponse: withResponse,
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func writeCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    value: FlutterStandardTypedData,
    withResponse: Bool,
    transactionId: String?,
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
      transactionId: transactionId,
      completion: completion
    )
    
  }
  
  func writeCharacteristicForService(
    serviceNumericId: Int,
    characteristicUUID: String,
    value: FlutterStandardTypedData,
    withResponse: Bool,
    transactionId: String?,
    completion: @escaping (Result<SingleCharacteristicResponse, ClientError>) -> ()
  ) {
    let ds: DiscoveredService
    switch discoveredService(for: serviceNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      ds = value
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  private func monitorCharacteristic(
    for dc: DiscoveredCharacteristic,
    transactionId: String?,
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
    let charEvents = eventSink.monitorCharacteristic
    charEvents.afterCancelDo {
      let char = dc.characteristic
      if char.isNotifying {
        char.service.peripheral.setNotifyValue(false, for: char)
      }
      dc.onValueUpdate(handler: nil)
    }
    dp.onDisconnected {
      charEvents.end()
    }
    dc.onValueUpdate { char in
      charEvents.sink(
        SingleCharacteristicWithValueResponse(
          char: char,
          charUuidCache: self.characteristicUuidCache,
          serviceUuidCache: self.serviceUuidCache,
          transactionId: transactionId
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
  
  func monitorCharacteristicForIdentifier(
    characteristicNumericId: Int,
    transactionId: String?,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    let dc: DiscoveredCharacteristic
    switch discoveredCharacteristic(for: characteristicNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dc = value
    }
    monitorCharacteristic(for: dc, transactionId: transactionId, completion: completion)
  }
  
  func monitorCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    transactionId: String?,
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func monitorCharacteristicForService(
    serviceNumericId: Int,
    characteristicUUID: String,
    transactionId: String?,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    let ds: DiscoveredService
    switch discoveredService(for: serviceNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      ds = value
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  private func readDescriptor(
    for dd: DiscoveredDescriptor,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    dd.read { res in
      completion(
        res.map({ desc in
          return DescriptorResponse(
            desc: desc,
            descUuidCache: self.descriptorUuidCache,
            charUuidChache: self.characteristicUuidCache,
            serviceUuidCache: self.serviceUuidCache
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }
  
  func readDescriptorForIdentifier(
    descriptorNumericId: Int,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dd: DiscoveredDescriptor
    switch discoveredDescriptor(for: descriptorNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dd = value
    }
    readDescriptor(
      for: dd,
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func readDescriptorForCharacteristic(
    characteristicNumericId: Int,
    descriptorUUID: String,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dc: DiscoveredCharacteristic
    switch discoveredCharacteristic(for: characteristicNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dc = value
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func readDescriptorForService(
    serviceNumericId: Int,
    characteristicUUID: String,
    descriptorUUID: String,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let ds: DiscoveredService
    switch discoveredService(for: serviceNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      ds = value
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func readDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    transactionId: String?,
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  private func writeDescriptor(
    for dd: DiscoveredDescriptor,
    value: FlutterStandardTypedData,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    dd.write(value.data) { res in
      completion(
        res.map({ desc in
          return DescriptorResponse(
            desc: desc,
            descUuidCache: self.descriptorUuidCache,
            charUuidChache: self.characteristicUuidCache,
            serviceUuidCache: self.serviceUuidCache
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }
  
  func writeDescriptorForIdentifier(
    descriptorNumericId: Int,
    value: FlutterStandardTypedData,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dd: DiscoveredDescriptor
    switch discoveredDescriptor(for: descriptorNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dd = value
    }
    writeDescriptor(
      for: dd,
      value: value,
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func writeDescriptorForCharacteristic(
    characteristicNumericId: Int,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dc: DiscoveredCharacteristic
    switch discoveredCharacteristic(for: characteristicNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dc = value
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func writeDescriptorForService(
    serviceNumericId: Int,
    characteristicUUID: String,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let ds: DiscoveredService
    switch discoveredService(for: serviceNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      ds = value
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
      transactionId: transactionId,
      completion: completion
    )
  }
  
  func writeDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?,
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
      transactionId: transactionId,
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
    eventSink.stateChanges.sink(central.state.rawValue)
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
    eventSink.stateRestoreEvents.sink(
      peripherals.map(PeripheralResponse.init)
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
    eventSink.scanningEvents.sink(
      ScanResultEvent(
        peripheral: peripheral,
        advertisementData: advertisementData,
        rssi: RSSI.intValue
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
