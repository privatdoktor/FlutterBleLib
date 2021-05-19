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

//const NSString *keyDescriptorResponseDescriptorId = @"descriptorId";
//const NSString *keyDescriptorResponseDescriptorUuid = @"descriptorUuid";
//const NSString *keyDescriptorResponseValue = @"value";
//const NSString *keyDescriptorResponseServiceId = @"serviceId";
//const NSString *keyDescriptorResponseServiceUuid = @"serviceUuid";
//const NSString *keyDescriptorResponseCharacteristicId = @"id";
//const NSString *keyDescriptorResponseCharacteristicUuid = @"characteristicUuid";
//const NSString *keyDescriptorResponseDescriptors = @"descriptors";

struct DescriptorResponse : Encodable {
  let descriptorId: Int
  let descriptorUuid: String
  let value: String? // base64encodedString from Data
  
  init(
    desc: CBDescriptor,
    using uuidCache: HashableIdCache<CBUUID>
  ) {
    descriptorUuid = desc.uuid.fullUUIDString
    descriptorId = uuidCache.numeric(from: desc.uuid)
    value = desc.valueAsData?.base64EncodedString()
  }
  
  private enum CodingKeys: String, CodingKey {
    case descriptorId = "descriptorId"
    case descriptorUuid = "descriptorUuid"
    case value = "value"
  }
}

struct DescriptorsForPeripheralResponse : Encodable {
  let serviceId: Int
  let serviceUuid: String
  
  let characteristicId: Int
  let characteristicUuid: String
  let isCharacteristicReadable: Bool
  let isCharacteristicWritableWithResponse: Bool
  let isCharacteristicWritableWithoutResponse: Bool
  let isCharacteristicNotifiable: Bool
  let isCharacteristicIndicatable: Bool
  
  let descriptors : [DescriptorResponse]
  
  init(
    with descs: [CBDescriptor],
    using uuidCache: HashableIdCache<CBUUID>,
    with char: CBCharacteristic,
    using charUuidChache: HashableIdCache<CBUUID>,
    with service: CBService,
    using serviceUuidCache: HashableIdCache<CBUUID>
  ) {
    serviceUuid = service.uuid.fullUUIDString
    serviceId = serviceUuidCache.numeric(from: service.uuid)
    characteristicUuid = char.uuid.fullUUIDString
    characteristicId = charUuidChache.numeric(from: char.uuid)
    isCharacteristicReadable = char.properties.contains(.read)
    isCharacteristicWritableWithResponse = char.properties.contains(.write)
    isCharacteristicWritableWithoutResponse = char.properties.contains(.writeWithoutResponse)
    isCharacteristicNotifiable = char.properties.contains(.notify)
    isCharacteristicIndicatable = char.properties.contains(.indicate)
    descriptors = descs.map({ desc in
      return DescriptorResponse(desc: desc, using: uuidCache)
    })
  }
  
  private enum CodingKeys: String, CodingKey {
    case serviceId = "serviceId"
    case serviceUuid = "serviceUuid"
    
    case characteristicId = "id"
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
  let characteristicId: Int
  let characteristicUuid: String
  let isCharacteristicReadable: Bool
  let isCharacteristicWritableWithResponse: Bool
  let isCharacteristicWritableWithoutResponse: Bool
  let isCharacteristicNotifiable: Bool
  let isCharacteristicIndicatable: Bool
  
  let descriptors : [DescriptorResponse]
  
  init(
    with descs: [CBDescriptor],
    using uuidCache: HashableIdCache<CBUUID>,
    with char: CBCharacteristic,
    using charUuidChache: HashableIdCache<CBUUID>
  ) {
    characteristicUuid = char.uuid.fullUUIDString
    characteristicId = charUuidChache.numeric(from: char.uuid)
    isCharacteristicReadable = char.properties.contains(.read)
    isCharacteristicWritableWithResponse = char.properties.contains(.write)
    isCharacteristicWritableWithoutResponse = char.properties.contains(.writeWithoutResponse)
    isCharacteristicNotifiable = char.properties.contains(.notify)
    isCharacteristicIndicatable = char.properties.contains(.indicate)
    descriptors = descs.map { desc in
      return DescriptorResponse(desc: desc, using: uuidCache)
    }
  }
  
  private enum CodingKeys: String, CodingKey {
    case characteristicId = "id"
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
    with descs: [CBDescriptor],
    using uuidCache: HashableIdCache<CBUUID>
  ) {
    descriptors = descs.map { desc in
      return DescriptorResponse(desc: desc, using: uuidCache)
    }
  }
  private enum CodingKeys: String, CodingKey {
    case descriptors = "descriptors"
  }
}

class DiscoveredDescriptor {
  let descriptor: CBDescriptor
  private var _readCompleted: ((_ res: Result<Any?, PeripheralError>) -> ())?
  private var _writeCompleted: ((_ res: Result<(), PeripheralError>) -> ())?
  
  init(_ descriptor: CBDescriptor) {
    self.descriptor = descriptor
  }
}
// MARK: - API
extension DiscoveredDescriptor {
  func read(
    _ completion: @escaping (_ res: Result<(Any?), PeripheralError>) -> ()
  ) {
    _readCompleted = completion
    descriptor.characteristic.service.peripheral.readValue(for: descriptor)
  }
  func onWriteCompleted (
    _ data: Data,
    completion: @escaping (_ res: Result<(), PeripheralError>) -> ()
  ) {
    _writeCompleted = completion
    descriptor.characteristic.service.peripheral.writeValue(
      data,
      for: descriptor
    )
  }
}
// MARK: - For Publishers
extension DiscoveredDescriptor {
  func readCompleted(_ res: Result<Any?, PeripheralError>) {
    _readCompleted?(res)
    _readCompleted = nil
  }
  func writeCompleted(_ res: Result<(), PeripheralError>) {
    _writeCompleted?(res)
    _writeCompleted = nil
  }
}
