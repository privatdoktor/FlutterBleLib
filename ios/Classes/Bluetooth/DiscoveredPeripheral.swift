//
//  PeripheralConnection.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

enum PeripheralError : Error {
  case serviceDiscovery(internal: Error?)
  case includedServicesDiscovery(CBService, internal: Error?)
  case characteristicsDiscovery(CBService, internal: Error?)
  case descriptorsDiscovery(CBCharacteristic, internal: Error?)
  case characteristicRead(CBCharacteristic, internal: Error?)
  case characteristicWrite(CBCharacteristic, internal: Error?)
  case characteristicSetNotify(CBCharacteristic, internal: Error?)
  case descriptorRead(CBDescriptor, internal: Error?)
  case descriptorWrite(CBDescriptor, internal: Error?)
  case noServiceFound(CBPeripheral?, id: String)
  case noCharacteristicFound(CBService?, id: String)
  case noDescriptorFound(CBCharacteristic?, id: String)
  case rssiUpdated(CBPeripheral, value: NSNumber?, internal: Error?)
}

extension CBPeripheral {
  static let defaultMtu = 23
  var mtu: Int {
    if #available(iOS 9.0, *) {
      return maximumWriteValueLength(for: .withoutResponse) + 3
    } else {
      return CBPeripheral.defaultMtu
    }
  }
}

class DiscoveredPeripheral : NSObject {
  private var _peripheral: CBPeripheral
  var peripheral: CBPeripheral {
    return _peripheral
  }
  weak var centralManager: CBCentralManager?
  var discoveredServices = [CBUUID : DiscoveredService]()
  
  private var _connectCompleted: ((_ res: Result<(), BluetoothCentralManagerError>) -> ())?
  private var _disconnectCompleted: ((_ res: Result<(), BluetoothCentralManagerError>) -> ())?
  
  private var _connectionEventOccured: ((_ event: CBConnectionEvent) -> ())?
  private var _onDisconnectedListeners = Queue<() -> ()>()

  
  private var _servicesDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) -> ())?
  
  private var _readRSSICompleted: ((_ res: Result<Int, BluetoothCentralManagerError>) -> ())?
  
 
  init(_ peripheral: CBPeripheral,
       centralManager: CBCentralManager?
  ) {
    self._peripheral = peripheral
    self.centralManager = centralManager
    super.init()
    peripheral.delegate = self
  }
  
  func updateInternalPeripheral(_ peripheral: CBPeripheral) {
    _peripheral = peripheral
  }
}
// MARK: - API
extension DiscoveredPeripheral {
  
  func connect(
    options: [String : Any]? = nil,
    _ completion: @escaping (_ res: Result<(), BluetoothCentralManagerError>) -> ()
  ) {
    if let pending = _connectCompleted {
      _connectCompleted = nil
      pending(.failure(.peripheralConnection(internal: nil)))
    }
    _connectCompleted = completion
    centralManager?.connect(peripheral, options: options)
  }
  
  func disconnect(
    _ completion: @escaping (_ res: Result<(), BluetoothCentralManagerError>) -> ()
  ) {
    if let pending = _disconnectCompleted {
      _disconnectCompleted = nil
      pending(.failure(.peripheralDisconnection(internal: nil)))
    }
    _disconnectCompleted = completion
    centralManager?.cancelPeripheralConnection(peripheral)
  }
  
  func onConnectionEvent(
    handler: ((_ event: CBConnectionEvent) -> ())?
  ) {
    _connectionEventOccured = handler
  }
  
  func onDisconnected(listener: @escaping () -> ()) {
    _onDisconnectedListeners.enqueue(listener)
  }
  
  func discoverServices(
    serviceUUIDs: [CBUUID]? = nil,
    _ completion: @escaping (
      _ res: Result<[CBUUID : DiscoveredService], PeripheralError>
    ) -> ()
  ) {
    if let pending = _servicesDiscoveryCompleted {
      _servicesDiscoveryCompleted = nil
      pending(.failure(.serviceDiscovery(internal: nil)))
    }
    _servicesDiscoveryCompleted = completion
    peripheral.discoverServices(serviceUUIDs)
  }
  
  func readRssi(
    _ completion: @escaping (_ res: Result<Int, BluetoothCentralManagerError>
    ) -> ()) {
    if let pending = _readRSSICompleted {
      _readRSSICompleted = nil
      pending(.failure(.peripheral(.rssiUpdated(peripheral, value: nil, internal: nil))))
    }
    _readRSSICompleted = completion
    peripheral.readRSSI()
  }
  
}
// MARK: - For Publishers
extension DiscoveredPeripheral {
  func connected(_ res: Result<(), BluetoothCentralManagerError>) {
    if case .success = res {
      _connectionEventOccured?(.peerConnected)
    }
    _connectCompleted?(res)
    _connectCompleted = nil
  }
  func disconnected(_ res: Result<(), BluetoothCentralManagerError>) {
    if case .success = res {
      _connectionEventOccured?(.peerDisconnected)
    }
    _disconnectCompleted?(res)
    _disconnectCompleted = nil
    if case .success = res {
      while _onDisconnectedListeners.isEmpty == false {
        _onDisconnectedListeners.dequeue()?()
      }
    }
  }
  private func servicesDiscovered(_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) {
    _servicesDiscoveryCompleted?(res)
    _servicesDiscoveryCompleted = nil
  }
  private func rssiUpdated(_ res: Result<Int, BluetoothCentralManagerError>) {
    _readRSSICompleted?(res)
    _readRSSICompleted = nil
  }
}

// MARK: - Helpers
extension DiscoveredPeripheral {
  var flattenedDiscoveredServices: [CBUUID : DiscoveredService] {
    var services = [CBUUID : DiscoveredService]()
    for (key, ds) in discoveredServices {
      services[key] = ds
      if let included = ds.includedDiscoveredServices {
        for (inclKey, inclDs) in included {
          services[inclKey] = inclDs
        }
      }
    }
    return services
  }
}

extension DiscoveredPeripheral : CBPeripheralDelegate {
  // MARK: - Service related delegate methods
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverServices error: Error?
  ) {
    if let error = error {
      servicesDiscovered(.failure(.serviceDiscovery(internal: error)))
      return
    }
    guard
      let services = peripheral.services
    else {
      servicesDiscovered(.success([:]))
      return
    }
    discoveredServices.removeAll()
    for service in services {
      discoveredServices[service.uuid] = DiscoveredService(service)
    }
    servicesDiscovered(.success(discoveredServices))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverIncludedServicesFor service: CBService,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[service.uuid]
    else {
      return
    }
    if let error = error {
      ds.includedServicesDiscovered(
        .failure(.includedServicesDiscovery(service, internal: error))
      )
      return
    }
    guard let included = service.includedServices  else {
      ds.includedServicesDiscovered(.success([:]))
      return
    }
    let ids =
      Dictionary(
        uniqueKeysWithValues: zip(
          included.map({ $0.uuid }),
          included.map(DiscoveredService.init)
        )
      )
    ds.includedDiscoveredServices = ids
    ds.includedServicesDiscovered(.success(ids))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didModifyServices invalidatedServices: [CBService]
  ) {
    for invalid in invalidatedServices {
      discoveredServices.removeValue(forKey: invalid.uuid)
      for (_, ds) in discoveredServices {
        ds.includedDiscoveredServices?.removeValue(forKey: invalid.uuid)
      }
    }
  }
  // MARK: - Characteristic related delegate methods
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[service.uuid]
    else {
      return
    }
    if let error = error {
      ds.characteristicsDiscovered(
        .failure(.characteristicsDiscovery(service, internal: error))
      )
      return
    }
    guard
      let chars = service.characteristics
    else {
      ds.characteristicsDiscovered(.success([:]))
      return
    }
    ds.discoveredCharacteristics.removeAll()
    for char in chars {
      ds.discoveredCharacteristics[char.uuid] = DiscoveredCharacteristic(char)
    }
    ds.characteristicsDiscovered(.success(ds.discoveredCharacteristics))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let serviceUuid = characteristic.service?.uuid,
      let ds = flattenedDiscoveredServices[serviceUuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      dc.readCompleted(
        .failure(.characteristicRead(characteristic, internal: error))
      )
      return
    }
    dc.readCompleted(.success(characteristic))
    dc.valueUpdated(characteristic)
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let serviceUuid = characteristic.service?.uuid,
      let ds = flattenedDiscoveredServices[serviceUuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      print("GRRRRRRRRRRRRRRRGGGGGWWWWW \(error.localizedDescription)")
      dc.writeCompleted(
        .failure(.characteristicWrite(characteristic, internal: error))
      )
      return
    }
    dc.writeCompleted(.success(characteristic))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let serviceUuid = characteristic.service?.uuid,
      let ds = flattenedDiscoveredServices[serviceUuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      dc.setNotifyCompleted(
        .failure(.characteristicSetNotify(characteristic, internal: error))
      )
      return
    }
    dc.setNotifyCompleted(.success(characteristic))
  }
    
  func peripheralIsReady(toSendWriteWithoutResponse
    peripheral: CBPeripheral
  ) {
      //TODO: figure out what to do here exactly
  }
  
  // MARK: - Descriptor related delegate methods
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverDescriptorsFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let serviceUuid = characteristic.service?.uuid,
      let ser = discoveredServices[serviceUuid],
      let discoveredChar = ser.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      discoveredChar.descriptorsDiscovered(
        .failure(.descriptorsDiscovery(characteristic, internal: error))
      )
      return
    }
    discoveredChar.discoveredDescriptors.removeAll()
    for desc in characteristic.descriptors ?? [] {
      discoveredChar.discoveredDescriptors[desc.uuid] =
        DiscoveredDescriptor(desc)
    }
    discoveredChar.descriptorsDiscovered(
      .success(discoveredChar.discoveredDescriptors)
    )
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor descriptor: CBDescriptor,
    error: Error?
  ) {
    guard
      let serviceUuid = descriptor.characteristic?.service?.uuid,
      let ser = discoveredServices[serviceUuid],
      let charUuid = descriptor.characteristic?.uuid,
      let char = ser.discoveredCharacteristics[charUuid],
      let discoveredDesc = char.discoveredDescriptors[descriptor.uuid]
    else {
      return
    }
    if let error = error {
      discoveredDesc.readCompleted(
        .failure(.descriptorRead(descriptor, internal: error))
      )
      return
    }
    discoveredDesc.readCompleted(.success(descriptor))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor descriptor: CBDescriptor,
    error: Error?
  ) {
    guard
      let serviceUuid = descriptor.characteristic?.service?.uuid,
      let ser = discoveredServices[serviceUuid],
      let charUuid = descriptor.characteristic?.uuid,
      let char = ser.discoveredCharacteristics[charUuid],
      let discoveredDesc = char.discoveredDescriptors[descriptor.uuid]
    else {
      return
    }
    if let error = error {
      discoveredDesc.writeCompleted(
        .failure(.descriptorWrite(descriptor, internal: error))
      )
      return
    }
    discoveredDesc.writeCompleted(.success(descriptor))
  }
  // MARK: - Other delegate methods
  func peripheralDidUpdateName(
    _ peripheral: CBPeripheral
  ) {
    
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didReadRSSI RSSI: NSNumber,
    error: Error?
  ) {
    if let error = error {
      rssiUpdated(
        .failure(
          .peripheral(.rssiUpdated(peripheral, value: RSSI, internal: error))
        )
      )
      return
    }
    rssiUpdated(.success(RSSI.intValue))
  }
  
  @available(iOS 11.0, *)
  func peripheral(
    _ peripheral: CBPeripheral,
    didOpen channel: CBL2CAPChannel?,
    error: Error?
  ) {
    
  }
}
