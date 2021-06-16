//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

extension CBDescriptor {
  var valueAsData: Data? {
    guard
      let value = value
    else {
      return nil
    }
    switch uuid.uuidString {
    case CBUUIDCharacteristicExtendedPropertiesString,
         CBUUIDClientCharacteristicConfigurationString,
         CBUUIDServerCharacteristicConfigurationString:
      guard
        let numberValue = value as? NSNumber
      else {
        return nil
      }
      var data = numberValue.uint16Value.littleEndian
      return Data(bytes: &data, count: 2)
    case CBUUIDCharacteristicUserDescriptionString:
      guard
        let stringValue = value as? String
      else {
        return nil
      }
      return stringValue.data(using: .utf8)
    case CBUUIDCharacteristicFormatString,
         CBUUIDCharacteristicAggregateFormatString:
      fallthrough
    default:
      guard
        let dataValue = value as? Data
      else {
        return nil
      }
      return dataValue
    }
  }
}

struct DescriptorResponse : Encodable {
  let serviceUuid: String
  
  let characteristicUuid: String
  let isCharacteristicReadable: Bool
  let isCharacteristicWritableWithResponse: Bool
  let isCharacteristicWritableWithoutResponse: Bool
  let isCharacteristicNotifiable: Bool
  let isCharacteristicIndicatable: Bool
  
  
  let descriptorUuid: String
  let value: String? // base64encodedString from Data
    
  init(
    desc: CBDescriptor
  ) {
    let char = desc.characteristic
    let service = char.service
    serviceUuid = service.uuid.fullUUIDString
    characteristicUuid = desc.characteristic.uuid.fullUUIDString
    isCharacteristicReadable = char.properties.contains(.read)
    isCharacteristicWritableWithResponse = char.properties.contains(.write)
    isCharacteristicWritableWithoutResponse = char.properties.contains(.writeWithoutResponse)
    isCharacteristicNotifiable = char.properties.contains(.notify)
    isCharacteristicIndicatable = char.properties.contains(.indicate)
    
    descriptorUuid = desc.uuid.fullUUIDString
    value = desc.valueAsData?.base64EncodedString()
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceUuid = "serviceUuid"
    
    case characteristicUuid = "characteristicUuid"
    case isCharacteristicReadable = "isReadable"
    case isCharacteristicWritableWithResponse = "isWritableWithResponse"
    case isCharacteristicWritableWithoutResponse = "isWritableWithoutResponse"
    case isCharacteristicNotifiable = "isNotifiable"
    case isCharacteristicIndicatable = "isIndicatable"
    
    case descriptorUuid = "descriptorUuid"
    case value = "value"
  }
}

struct DescriptorsForPeripheralResponse : Encodable {
  let serviceUuid: String
  
  let characteristicUuid: String
  let isCharacteristicReadable: Bool
  let isCharacteristicWritableWithResponse: Bool
  let isCharacteristicWritableWithoutResponse: Bool
  let isCharacteristicNotifiable: Bool
  let isCharacteristicIndicatable: Bool
  
  let descriptors : [DescriptorResponse]
  
  init(
    with descs: [CBDescriptor],
    char: CBCharacteristic,
    service: CBService
  ) {
    serviceUuid = service.uuid.fullUUIDString
    characteristicUuid = char.uuid.fullUUIDString
    isCharacteristicReadable = char.properties.contains(.read)
    isCharacteristicWritableWithResponse = char.properties.contains(.write)
    isCharacteristicWritableWithoutResponse = char.properties.contains(.writeWithoutResponse)
    isCharacteristicNotifiable = char.properties.contains(.notify)
    isCharacteristicIndicatable = char.properties.contains(.indicate)
    descriptors = descs.map({ desc in
      return DescriptorResponse(
        desc: desc
      )
    })
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceUuid = "serviceUuid"
    
    case characteristicUuid = "characteristicUuid"
    case isCharacteristicReadable = "isReadable"
    case isCharacteristicWritableWithResponse = "isWritableWithResponse"
    case isCharacteristicWritableWithoutResponse = "isWritableWithoutResponse"
    case isCharacteristicNotifiable = "isNotifiable"
    case isCharacteristicIndicatable = "isIndicatable"
    
    case descriptors = "descriptors"
  }
}

struct DescriptorsForServiceResponse : Encodable {
  let characteristicUuid: String
  let isCharacteristicReadable: Bool
  let isCharacteristicWritableWithResponse: Bool
  let isCharacteristicWritableWithoutResponse: Bool
  let isCharacteristicNotifiable: Bool
  let isCharacteristicIndicatable: Bool
  
  let descriptors : [DescriptorResponse]
  
  init(
    with descs: [CBDescriptor],
    char: CBCharacteristic
  ) {
    characteristicUuid = char.uuid.fullUUIDString
    isCharacteristicReadable = char.properties.contains(.read)
    isCharacteristicWritableWithResponse = char.properties.contains(.write)
    isCharacteristicWritableWithoutResponse = char.properties.contains(.writeWithoutResponse)
    isCharacteristicNotifiable = char.properties.contains(.notify)
    isCharacteristicIndicatable = char.properties.contains(.indicate)
    descriptors = descs.map { desc in
      return DescriptorResponse(
        desc: desc
      )
    }
  }
  
  private enum CodingKeys: String, CodingKey {
    case characteristicUuid = "characteristicUuid"
    case isCharacteristicReadable = "isReadable"
    case isCharacteristicWritableWithResponse = "isWritableWithResponse"
    case isCharacteristicWritableWithoutResponse = "isWritableWithoutResponse"
    case isCharacteristicNotifiable = "isNotifiable"
    case isCharacteristicIndicatable = "isIndicatable"
    
    case descriptors = "descriptors"
  }
}

struct DescriptorsForCharacteristicResponse : Encodable {
  let descriptors : [DescriptorResponse]
  init(
    with descs: [CBDescriptor]
  ) {
    descriptors = descs.map { desc in
      return DescriptorResponse(
        desc: desc
      )
    }
  }
  private enum CodingKeys: String, CodingKey {
    case descriptors = "descriptors"
  }
}

class DiscoveredDescriptor {
  let descriptor: CBDescriptor
  private var _readCompleted: ((_ res: Result<CBDescriptor, PeripheralError>) -> ())?
  private var _writeCompleted: ((_ res: Result<CBDescriptor, PeripheralError>) -> ())?
  
  init(_ descriptor: CBDescriptor) {
    self.descriptor = descriptor
  }
}
// MARK: - API
extension DiscoveredDescriptor {
  func read(
    _ completion: @escaping (_ res: Result<CBDescriptor, PeripheralError>) -> ()
  ) {
    if let pending = _readCompleted {
      _readCompleted = nil
      pending(.failure(.descriptorRead(descriptor, internal: nil)))
    }
    _readCompleted = completion
    descriptor.characteristic.service.peripheral.readValue(for: descriptor)
  }
  func write(
    _ data: Data,
    completion: @escaping (_ res: Result<CBDescriptor, PeripheralError>) -> ()
  ) {
    if let pending = _writeCompleted {
      _writeCompleted = nil
      pending(.failure(.descriptorWrite(descriptor, internal: nil)))
    }
    _writeCompleted = completion
    descriptor.characteristic.service.peripheral.writeValue(
      data,
      for: descriptor
    )
  }
}
// MARK: - For Publishers
extension DiscoveredDescriptor {
  func readCompleted(_ res: Result<CBDescriptor, PeripheralError>) {
    _readCompleted?(res)
    _readCompleted = nil
  }
  func writeCompleted(_ res: Result<CBDescriptor, PeripheralError>) {
    _writeCompleted?(res)
    _writeCompleted = nil
  }
}
