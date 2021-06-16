//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

struct CharacteristicResponse : Encodable {
  let characteristicUuid: String
  let isIndicatable: Bool
  let isNotifiable: Bool
  let isNotifying: Bool
  let isReadable: Bool
  let isWritableWithResponse: Bool
  let isWritableWithoutResponse: Bool
  
  init(
    char: CBCharacteristic
  ) {
    characteristicUuid = char.uuid.fullUUIDString
    let properties = char.properties
    isIndicatable = properties.contains(.indicate)
    isReadable = properties.contains(.read)
    isWritableWithResponse = properties.contains(.write)
    isWritableWithoutResponse = properties.contains(.writeWithoutResponse)
    isNotifiable =  properties.contains(.notify)
    isNotifying = char.isNotifying
  }
  
  private enum CodingKeys: String, CodingKey {
    case characteristicUuid = "characteristicUuid"
    case isIndicatable = "isIndicatable"
    case isNotifiable = "isNotifiable"
    case isNotifying = "isNotifying"
    case isReadable = "isReadable"
    case isWritableWithResponse = "isWritableWithResponse"
    case isWritableWithoutResponse = "isWritableWithoutResponse"
  }
}

struct SingleCharacteristicResponse : Encodable {
  let serviceUuid: String
    
  let characteristic: CharacteristicResponse
  
  init(
    char: CBCharacteristic
  ) {
    serviceUuid = char.service.uuid.fullUUIDString
        
    characteristic =
      CharacteristicResponse(char: char)
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceUuid = "serviceUuid"
        
    case characteristic = "characteristic"
  }
}

struct CharacteristicWithValueResponse : Encodable {
  let characteristicUuid: String
  let isIndicatable: Bool
  let isNotifiable: Bool
  let isNotifying: Bool
  let isReadable: Bool
  let isWritableWithResponse: Bool
  let isWritableWithoutResponse: Bool
  let value: String // base64encodedString from Data
  
  init(
    char: CBCharacteristic
  ) {
    characteristicUuid = char.uuid.fullUUIDString
    let properties = char.properties
    isIndicatable = properties.contains(.indicate)
    isReadable = properties.contains(.read)
    isWritableWithResponse = properties.contains(.write)
    isWritableWithoutResponse = properties.contains(.writeWithoutResponse)
    isNotifiable =  properties.contains(.notify)
    isNotifying = char.isNotifying
    value = char.value?.base64EncodedString() ?? ""
  }
  
  private enum CodingKeys: String, CodingKey {
    case characteristicUuid = "characteristicUuid"
    case isIndicatable = "isIndicatable"
    case isNotifiable = "isNotifiable"
    case isNotifying = "isNotifying"
    case isReadable = "isReadable"
    case isWritableWithResponse = "isWritableWithResponse"
    case isWritableWithoutResponse = "isWritableWithoutResponse"
    case value = "value"
  }
}

struct SingleCharacteristicWithValueResponse : Encodable {
  let serviceUuid: String
    
  let characteristic: CharacteristicWithValueResponse
  
  init(
    char: CBCharacteristic
  ) {
    serviceUuid = char.service.uuid.fullUUIDString
        
    characteristic =
      CharacteristicWithValueResponse(char: char)
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceUuid = "serviceUuid"
        
    case characteristic = "characteristic"
  }
}

struct CharacteristicsResponse : Encodable {
  let serviceUuid: String
  let characteristics: [CharacteristicResponse]
  
  init(
    with chars: [CBCharacteristic],
    service: CBService
  ) {
    serviceUuid = service.uuid.fullUUIDString
    characteristics = chars.map({ char in
      return CharacteristicResponse(
        char: char
      )
    })
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceUuid = "serviceUuid"
    case characteristics = "characteristics"
  }
}

class DiscoveredCharacteristic {
  let characteristic: CBCharacteristic
  private var _descriptorsDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredDescriptor], PeripheralError>) -> ())?
  private var _readCompleted: ((_ res: Result<CBCharacteristic, PeripheralError>) -> ())?
  private var _writeCompleted: ((_ res: Result<CBCharacteristic, PeripheralError>) -> ())?
  private var _setNorifyCompleted: ((_ res: Result<CBCharacteristic, PeripheralError>) -> ())?
  private var _valueUpdated: ((_ char: CBCharacteristic) -> ())?
  var discoveredDescriptors = [CBUUID : DiscoveredDescriptor]()
  
  init(_ characteristic: CBCharacteristic) {
    self.characteristic = characteristic
  }
}
extension DiscoveredCharacteristic {
  private func writeWithoutResponse(
    _ data: Data
  ) -> Result<CBCharacteristic, PeripheralError> {
    guard
      characteristic.properties.contains(.writeWithoutResponse)
    else {
      return .failure(.characteristicWrite(characteristic, internal: nil))
    }
    characteristic.service.peripheral.writeValue(
      data,
      for: characteristic,
      type: .withoutResponse
    )
    return .success(characteristic)
  }
  private func writeWithResponse(
    _ data: Data,
    completion: @escaping (_ res: Result<CBCharacteristic, PeripheralError>) -> ()
  ) {
    guard
      characteristic.properties.contains(.write)
    else {
      completion(
        .failure(.characteristicWrite(characteristic, internal: nil))
      )
      return
    }
    if let pending = _writeCompleted {
      _writeCompleted = nil
      pending(.failure(.characteristicWrite(characteristic, internal: nil)))
    }
    _writeCompleted = completion
    characteristic.service.peripheral.writeValue(
      data,
      for: characteristic,
      type: .withResponse
    )
  }
}


// MARK: - API
extension DiscoveredCharacteristic {
  func discoverDescriptors(
    _ completion: @escaping (
      _ res: Result<[CBUUID : DiscoveredDescriptor], PeripheralError>
    ) -> ()
  ) {
    if let pending = _descriptorsDiscoveryCompleted {
      _descriptorsDiscoveryCompleted = nil
      pending(.failure(.descriptorsDiscovery(characteristic, internal: nil)))
    }
    _descriptorsDiscoveryCompleted = completion
    characteristic.service.peripheral.discoverDescriptors(
      for: characteristic
    )
  }
  func read(
    _ completion: @escaping (_ res: Result<CBCharacteristic, PeripheralError>) -> ()
  ) {
    if let pending = _readCompleted {
      _readCompleted = nil
      pending(.failure(.characteristicRead(characteristic, internal: nil)))
    }
    _readCompleted = completion
    characteristic.service.peripheral.readValue(for: characteristic)
  }
  func write(
    _ data: Data,
    type: CBCharacteristicWriteType,
    completion: @escaping (_ res: Result<CBCharacteristic, PeripheralError>) -> ()
  ) {
    switch type {
    case .withoutResponse:
      completion(writeWithoutResponse(data))
    case .withResponse:
      writeWithResponse(data, completion: completion)
    @unknown default:
      completion(
        .failure(
          .characteristicWrite(characteristic, internal: nil)
        )
      )
    }
  }
  func setNotify(
    _ enabled: Bool,
    completion: @escaping (_ res: Result<CBCharacteristic, PeripheralError>) -> ()
  ) {
    if let pending = _setNorifyCompleted {
      _setNorifyCompleted = nil
      pending(.failure(.characteristicSetNotify(characteristic, internal: nil)))
    }
    _setNorifyCompleted = completion
    characteristic.service.peripheral.setNotifyValue(
      enabled,
      for: characteristic
    )
  }
  func onValueUpdate(
    handler: ((_ char: CBCharacteristic) -> ())?
  ) {
    _valueUpdated = handler
  }
}

// MARK: - For Publishers
extension DiscoveredCharacteristic {
  func descriptorsDiscovered(_ res: Result<[CBUUID : DiscoveredDescriptor], PeripheralError>) {
    _descriptorsDiscoveryCompleted?(res)
    _descriptorsDiscoveryCompleted = nil
  }
  func readCompleted(_ res: Result<CBCharacteristic, PeripheralError>) {
    _readCompleted?(res)
    _readCompleted = nil
  }
  func writeCompleted(_ res: Result<CBCharacteristic, PeripheralError>) {
    _writeCompleted?(res)
    _writeCompleted = nil
  }
  func setNotifyCompleted(_ res: Result<CBCharacteristic, PeripheralError>) {
    _setNorifyCompleted?(res)
    _setNorifyCompleted = nil
  }
  func valueUpdated(_ char: CBCharacteristic) {
    _valueUpdated?(char)
  }
}
