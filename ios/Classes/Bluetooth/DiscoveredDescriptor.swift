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
    guard
      let peripheral = descriptor.characteristic?.service?.peripheral
    else {
      completion(.failure(.descriptorRead(descriptor, internal: nil)))
      return
    }
    _readCompleted = completion
    peripheral.readValue(for: descriptor)
  }
  func write(
    _ data: Data,
    completion: @escaping (_ res: Result<CBDescriptor, PeripheralError>) -> ()
  ) {
    if let pending = _writeCompleted {
      _writeCompleted = nil
      pending(.failure(.descriptorWrite(descriptor, internal: nil)))
    }
    guard
      let peripheral = descriptor.characteristic?.service?.peripheral
    else {
      completion(.failure(.descriptorWrite(descriptor, internal: nil)))
      return
    }
    _writeCompleted = completion
    peripheral.writeValue(
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
