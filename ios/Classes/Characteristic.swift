//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth


struct CharacteristicResponse : Encodable {
  let serviceUuid: String
  let serviceId: Int
  
  let characteristicUuid: String
  let id: Int
  let isIndicatable: Bool
  let isNotifiable: Bool
  let isNotifying: Bool
  let isReadable: Bool
  let isWritableWithResponse: Bool
  let isWritableWithoutResponse: Bool
  let value: String? // base64encodedString from Data
  
  init(
    char: CBCharacteristic,
    using uuidCache: HashableIdCache<CBUUID>,
    usingSevice serviceUuidCache: HashableIdCache<CBUUID>
  ) {
    serviceUuid = char.service.uuid.fullUUIDString
    serviceId = serviceUuidCache.numeric(from: char.service.uuid)
    characteristicUuid = char.uuid.fullUUIDString
    id = uuidCache.numeric(from: char.uuid)
    let properties = char.properties
    isIndicatable = properties.contains(.indicate)
    isReadable = properties.contains(.read)
    isWritableWithResponse = properties.contains(.write)
    isWritableWithoutResponse = properties.contains(.writeWithoutResponse)
    isNotifiable =  properties.contains(.notify)
    isNotifying = char.isNotifying
    value = char.value?.base64EncodedString()
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceUuid = "serviceUuid"
    case serviceId = "serviceId"
    
    case characteristicUuid = "characteristicUuid"
    case id = "id"
    case isIndicatable = "isIndicatable"
    case isNotifiable = "isNotifiable"
    case isNotifying = "isNotifying"
    case isReadable = "isReadable"
    case isWritableWithResponse = "isWritableWithResponse"
    case isWritableWithoutResponse = "isWritableWithoutResponse"
  }
}

struct CharacteristicsResponse : Encodable {
  let serviceUuid: String
  let serviceId: Int
  let characteristics: [CharacteristicResponse]
  
  init(
    with chars: [CBCharacteristic],
    using uuidCache: HashableIdCache<CBUUID>,
    with service: CBService,
    using serviceUuidCache: HashableIdCache<CBUUID>
  ) {
    serviceUuid = service.uuid.fullUUIDString
    serviceId = serviceUuidCache.numeric(from: service.uuid)
    characteristics = chars.map({ char in
      return CharacteristicResponse(
        char: char,
        using: uuidCache,
        usingSevice: serviceUuidCache
      )
    })
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceUuid = "serviceUuid"
    case serviceId = "serviceId"
    case characteristics = "characteristics"
  }
}

class DiscoveredCharacteristic {
  let characteristic: CBCharacteristic
  private var descriptorsDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredDescriptor], PeripheralError>) -> ())?
  private var _readCompleted: ((_ res: Result<CBCharacteristic, PeripheralError>) -> ())?
  private var _writeCompleted: ((_ res: Result<(), PeripheralError>) -> ())?
  private var _setNorifyCompleted: ((_ res: Result<(), PeripheralError>) -> ())?
  var discoveredDescriptors = [CBUUID : DiscoveredDescriptor]()
  
  init(_ characteristic: CBCharacteristic) {
    self.characteristic = characteristic
  }
}

// MARK: - API
extension DiscoveredCharacteristic {
  func discoverDescriptors(
    _ completion: @escaping (
      _ res: Result<[CBUUID : DiscoveredDescriptor], PeripheralError>
    ) -> ()
  ) {
    descriptorsDiscoveryCompleted = completion
    characteristic.service.peripheral.discoverDescriptors(
      for: characteristic
    )
  }
  func read(
    _ completion: @escaping (_ res: Result<CBCharacteristic, PeripheralError>) -> ()
  ) {
    _readCompleted = completion
    characteristic.service.peripheral.readValue(for: characteristic)
  }
  func write(
    _ data: Data,
    type: CBCharacteristicWriteType,
    completion: @escaping (_ res: Result<(), PeripheralError>) -> ()
  ) {
    _writeCompleted = completion
    characteristic.service.peripheral.writeValue(
      data,
      for: characteristic,
      type: type
    )
  }
  func setNorify(
    _ enabled: Bool,
    completion: @escaping (_ res: Result<(), PeripheralError>) -> ()
  ) {
    _setNorifyCompleted = completion
    characteristic.service.peripheral.setNotifyValue(
      enabled,
      for: characteristic
    )
  }
}

// MARK: - For Publishers
extension DiscoveredCharacteristic {
  func descriptorsDiscovered(_ res: Result<[CBUUID : DiscoveredDescriptor], PeripheralError>) {
    descriptorsDiscoveryCompleted?(res)
    descriptorsDiscoveryCompleted = nil
  }
  func readCompleted(_ res: Result<CBCharacteristic, PeripheralError>) {
    _readCompleted?(res)
    _readCompleted = nil
  }
  func writeCompleted(_ res: Result<(), PeripheralError>) {
    _writeCompleted?(res)
    _writeCompleted = nil
  }
  func setNorifyCompleted(_ res: Result<(), PeripheralError>) {
    _setNorifyCompleted?(res)
    _setNorifyCompleted = nil
  }
}
