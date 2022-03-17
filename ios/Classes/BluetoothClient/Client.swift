//
//  Client.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 11/05/2021.
//

import Foundation
import CoreBluetooth

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
  case noPeripheralFoundFor(UUID?, expectedState: CBPeripheralState? = nil)
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
  func discoveredPeripheral(
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

  func discoveredPeripheral(
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

  func peripheralFor(
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
    guard
      let centralManager = self.centralManager
    else {
      return
    }
    
    if centralManager.state == .poweredOn &&
       centralManager.isScanning {
      centralManager.stopScan()
    }
    
    centralManager.delegate = nil
    self.centralManager = nil
  }
    
  var state : CBManagerState {
    switch self.centralManager?.state {
    case .none: return .unknown
    case .some(let state):
      return state
    }
  }
  
  @available(iOS 13.0, *)
  var authorization : CBManagerAuthorization {
    let authorization: CBManagerAuthorization
    if #available(iOS 13.1, *) {
      authorization = CBManager.authorization
    } else {
      authorization = CBCentralManager().authorization
    }

    return authorization
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

  func observeConnectionState(
    deviceIdentifier: String,
    emitCurrentValue: Bool?,
    eventStream: Stream<CBPeripheralState>
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
      
      eventStream.eventHandler(.data(state))
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
        eventStream.eventHandler(.data(state))
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
          .data(state)
        )
      }
    }
    
    return .success(())
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
