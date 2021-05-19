//
//  PeripheralConnection.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

enum PeripheralError : Error {
  case serviceDiscovery(internal: Error)
  case includedServicesDiscovery(CBService, internal: Error)
  case characteristicsDiscovery(CBService, internal: Error)
  case descriptorsDiscovery(CBCharacteristic, internal: Error)
  case characteristicRead(CBCharacteristic, internal: Error)
  case characteristicWrite(CBCharacteristic, internal: Error)
  case characteristicSetNotify(CBCharacteristic, internal: Error)
  case descriptorRead(CBDescriptor, internal: Error)
  case descriptorWrite(CBDescriptor, internal: Error)
  case noServiceFound(CBPeripheral?, id: String)
  case noCharacteristicFound(CBService?, id: String)
  case rssiUpdated(CBPeripheral, value: NSNumber, internal: Error)
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

struct ScanResultEvent : Encodable {
  let id: String
  let name: String?
  let rssi: Int
  let mtu: Int
  
  let manufacturerData: String? // base64EncodedString
  let serviceUUIDs: [String]?
  let overflowServiceUUIDs: [String]?
  let solicitedServiceUUIDs: [String]?
  let serviceData: [String : String]? // base64EncodedString value
  
  let localName: String?
  let txPowerLevel: Int?
  let isConnectable: Bool?
  
  init(
    peripheral: CBPeripheral,
    advertisementData: [String : Any],
    rssi: Int
  ) {
    id = peripheral.identifier.uuidString
    name = peripheral.name
    self.rssi = rssi
    mtu = peripheral.mtu
    
    do {
      let manData =
        advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
      let serUuids =
        advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
      let overFlSerUuids =
        advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
      let solicitedSerUuids =
        advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
      let serData =
        advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID : Data]
      let locName =
        advertisementData[CBAdvertisementDataLocalNameKey] as? String
      let txPowLvl =
        advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Int
      let isConnble =
        advertisementData[CBAdvertisementDataIsConnectable] as? Bool
      
      manufacturerData = manData?.base64EncodedString()
      serviceUUIDs = serUuids?.map { $0.fullUUIDString }
      overflowServiceUUIDs = overFlSerUuids?.map { $0.fullUUIDString }
      solicitedServiceUUIDs = solicitedSerUuids?.map { $0.fullUUIDString }
      if let serData = serData {
        serviceData = Dictionary(
          uniqueKeysWithValues: serData.map({
            ($0.key.fullUUIDString, $0.value.base64EncodedString())
          })
        )
      } else {
        serviceData = nil
      }
      localName = locName
      txPowerLevel = txPowLvl
      isConnectable = isConnble
    }
  }
  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case name = "name"
    case manufacturerData = "manufacturerData"
    case serviceData = "serviceData"
    case serviceUUIDs = "serviceUUIDs"
    case localName = "localName"
    case txPowerLevel = "txPowerLevel"
    case solicitedServiceUUIDs = "solicitedServiceUUIDs"
    case isConnectable = "isConnectable"
    case overflowServiceUUIDs = "overflowServiceUUIDs"
  }
}


struct PeripheralResponse : Encodable {
  let name: String?
  let id: String
  
  init(_ peripheral: CBPeripheral) {
    name = peripheral.name
    id = peripheral.identifier.uuidString
  }
  
  private enum CodingKeys: String, CodingKey {
    case name = "name"
    case id = "id"
  }
}

class DiscoveredPeripheral : NSObject {
  private var _peripheral: CBPeripheral
  var peripheral: CBPeripheral {
    return _peripheral
  }
  weak var centralManager: CBCentralManager?
  var discoveredServices = [CBUUID : DiscoveredService]()
  
  
  private var _connectCompleted: ((_ res: Result<(), ClientError>) -> ())?
  private var _disconnectCompleted: ((_ res: Result<(), ClientError>) -> ())?
  
  private var _connectionEventOccured: ((_ event: CBConnectionEvent) -> ())?

  
  private var _servicesDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) -> ())?
  
  private var _readRSSICompleted: ((_ res: Result<Int, ClientError>) -> ())?
  
 
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
  func discoverServices(
    serviceUUIDs: [CBUUID]? = nil,
    _ completion: @escaping (
      _ res: Result<[CBUUID : DiscoveredService], PeripheralError>
    ) -> ()
  ) {
    _servicesDiscoveryCompleted = completion
    peripheral.discoverServices(serviceUUIDs)
  }
  func connect(
    options: [String : Any]? = nil,
    _ completion: @escaping (_ res: Result<(), ClientError>) -> ()
  ) {
    _connectCompleted = completion
    centralManager?.connect(peripheral, options: options)
  }
  func disconnect(
    _ completion: @escaping (_ res: Result<(), ClientError>) -> ()
  ) {
    _disconnectCompleted = completion
    centralManager?.cancelPeripheralConnection(peripheral)
  }
  func onConnectionEvent(
    handler: ((_ event: CBConnectionEvent) -> ())?
  ) {
    _connectionEventOccured = handler
  }
  func readRssi(
    _ completion: @escaping (_ res: Result<Int, ClientError>
    ) -> ()) {
    _readRSSICompleted = completion
    peripheral.readRSSI()
  }
}
// MARK: - For Publishers
extension DiscoveredPeripheral {
  func connected(_ res: Result<(), ClientError>) {
    _connectionEventOccured?(.peerConnected)
    _connectCompleted?(res)
    _connectCompleted = nil
  }
  func disconnected(_ res: Result<(), ClientError>) {
    _connectionEventOccured?(.peerDisconnected)
    _disconnectCompleted?(res)
    _disconnectCompleted = nil
  }
  private func servicesDiscovered(_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) {
    _servicesDiscoveryCompleted?(res)
    _servicesDiscoveryCompleted = nil
  }
  private func rssiUpdated(_ res: Result<Int, ClientError>) {
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
    ds.discoveredCharacteristics.removeAll()
    for char in service.characteristics ?? [] {
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
      let ds = flattenedDiscoveredServices[characteristic.service.uuid],
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
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[characteristic.service.uuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      dc.writeCompleted(
        .failure(.characteristicWrite(characteristic, internal: error))
      )
      return
    }
    dc.writeCompleted(.success(()))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[characteristic.service.uuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      dc.setNorifyCompleted(
        .failure(.characteristicSetNotify(characteristic, internal: error))
      )
      return
    }
    dc.setNorifyCompleted(.success(()))
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
      let ser = discoveredServices[characteristic.service.uuid],
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
      let ser = discoveredServices[descriptor.characteristic.service.uuid],
      let char = ser.discoveredCharacteristics[descriptor.characteristic.uuid],
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
    discoveredDesc.readCompleted(.success(descriptor.value))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor descriptor: CBDescriptor,
    error: Error?
  ) {
    guard
      let ser = discoveredServices[descriptor.characteristic.service.uuid],
      let char = ser.discoveredCharacteristics[descriptor.characteristic.uuid],
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
    discoveredDesc.writeCompleted(.success(()))
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
