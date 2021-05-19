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
  case invalidUUIDString(String)
  case noPeripheralFoundFor(UUID, expectedState: CBPeripheralState? = nil)
  case peripheralConnection(internal: Swift.Error?)
  case peripheralDisconnection(internal: Swift.Error)
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
  
  typealias SignatureEnumT = Method.DefaultChannel.Signature
  
  private let eventSink: EventSink
  private var centralManager: CBCentralManager?
  
  private var discoveredPeripherals = [UUID : DiscoveredPeripheral]()
  private var peripheralUuidCache = HashableIdCache<UUID>()
  private var serviceUuidCache = HashableIdCache<CBUUID>()
  private var characteristicUuidCache = HashableIdCache<CBUUID>()
  private var descriptorUuidCache =  HashableIdCache<CBUUID>()
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
  
  private func peripheralConnectionFor(
    uuid: UUID,
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
  
  private func peripheralConnectionFor(
    deviceIdentifier: String,
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
      let dp = peripheralConnectionFor(
        uuid: uuid,
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
    return peripheralConnectionFor(
      uuid: uuid,
      centralManager: centralManager
    )?.peripheral
  }
  
  func connectToDevice(
    id: String,
    timoutMillis: Int?,
    completion: @escaping (_ completion: Result<(), ClientError>) -> ()
  ) {
    switch peripheralConnectionFor(deviceIdentifier: id) {
    case .failure(let error):
      completion(.failure(error))
    case .success(let dp):
      // FIXME: support connection option flags
      dp.connect(completion)
    }
  }

  func isDeviceConnected(id: String) -> Result<Bool, ClientError> {
    switch peripheralConnectionFor(deviceIdentifier: id) {
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
    switch peripheralConnectionFor(deviceIdentifier: deviceIdentifier) {
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
    switch peripheralConnectionFor(deviceIdentifier: deviceIdentifier) {
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
    switch peripheralConnectionFor(deviceIdentifier: deviceIdentifier) {
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
        using: characteristicUuidCache,
        with: ds.service,
        using: serviceUuidCache
      )
    )
  }
  
  func characteristics(
    for deviceIdentifier: String,
    serviceUUID: String
  ) -> Result<CharacteristicsResponse, ClientError> {
    let discoPeri: DiscoveredPeripheral
    switch peripheralConnectionFor(deviceIdentifier: deviceIdentifier) {
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
    switch peripheralConnectionFor(deviceIdentifier: deviceIdentifier) {
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
    return .success(
      DescriptorsForPeripheralResponse(
        with: dc.characteristic.descriptors ?? [],
        using: descriptorUuidCache,
        with: dc.characteristic,
        using: characteristicUuidCache,
        with: ds.service,
        using: serviceUuidCache
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
    
    return .success(
      DescriptorsForServiceResponse(
        with: dc.characteristic.descriptors ?? [],
        using: descriptorUuidCache,
        with: dc.characteristic,
        using: characteristicUuidCache
      )
    )
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
        using: characteristicUuidCache
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
    switch peripheralConnectionFor(deviceIdentifier: deviceIdentifier) {
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
    switch peripheralConnectionFor(deviceIdentifier: deviceIdentifier) {
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
  
  func readCharacteristicForIdentifier(
    characteristicNumericId: Int,
    transactionId: String?,
    completion: @escaping (Result<CharacteristicResponse, ClientError>) -> ()
  ) {
    let dc: DiscoveredCharacteristic
    switch discoveredCharacteristic(for: characteristicNumericId) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dc = value
    }
    
    dc.read { res in
      switch res {
      case .failure(let error):
        completion(.failure(.peripheral(error)))
      case .success(let char):
        let resp = CharacteristicResponse(
          char: char,
          using: self.characteristicUuidCache,
          usingSevice: self.serviceUuidCache
        )
        completion(.success(resp))
      }
    }
    
  }
  
  func readCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    transactionId: String?
  ) {
    
  }
  
  func readCharacteristicForService(
    serviceNumericId: Double,
    characteristicUUID: String,
    transactionId: String?
  ) {
    
  }
  func writeCharacteristicForIdentifier(
    characteristicNumericId: Double,
    value: FlutterStandardTypedData,
    transactionId: String?
  ) {
    
  }
  
  func writeCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?
  ) {
    
  }
  
  func writeCharacteristicForService(
    serviceNumericId: Double,
    characteristicUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?
  ) {
    
  }
  
  func monitorCharacteristicForIdentifier(
    characteristicNumericId: Double,
    transactionId: String?
  ) {
    
  }
  
  func monitorCharacteristicForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    transactionId: String?
  ) {
    
  }
  
  func monitorCharacteristicForService(
    serviceNumericId: Double,
    characteristicUUID: String,
    transactionId: String?
  ) {
    
  }
  
  func readDescriptorForIdentifier(
    descriptorNumericId: Double,
    transactionId: String?
  ) {
    
  }
  
  func readDescriptorForCharacteristic(
    characteristicNumericId: Double,
    descriptorUUID: String,
    transactionId: String?
  ) {
    
  }
  
  func readDescriptorForService(
    serviceNumericId: Double,
    characteristicUUID: String,
    descriptorUUID: String,
    transactionId: String?
  ) {
    
  }
  
  func readDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    transactionId: String?
  ) {
    
  }
  
  func writeDescriptorForIdentifier(
    descriptorNumericId: Double,
    value: FlutterStandardTypedData,
    transactionId: String?
  ) {
    
  }
  
  func writeDescriptorForCharacteristic(
    characteristicNumericId: Double,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?
  ) {
    
  }
  
  func writeDescriptorForService(
    serviceNumericId: Double,
    characteristicUUID: String,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?
  ) {
    
  }
  
  func writeDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    transactionId: String?
  ) {
    
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
