//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

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
      let periheral = characteristic.service?.peripheral,
      characteristic.properties.contains(.writeWithoutResponse)
    else {
      return .failure(.characteristicWrite(characteristic, internal: nil))
    }
    periheral.writeValue(
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
      
    guard
      let peripheral = characteristic.service?.peripheral
    else {
      completion(
        .failure(.characteristicWrite(characteristic, internal: nil))
      )
      return
    }
    _writeCompleted = completion
      peripheral.writeValue(
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
    
    guard
      let peripheral = characteristic.service?.peripheral
    else {
      completion(
        .failure(.characteristicWrite(characteristic, internal: nil))
      )
      return
    }
    _descriptorsDiscoveryCompleted = completion
    peripheral.discoverDescriptors(
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
    guard
      let peripheral = characteristic.service?.peripheral
    else {
      completion(
        .failure(.characteristicRead(characteristic, internal: nil))
      )
      return
    }
    _readCompleted = completion
    peripheral.readValue(for: characteristic)
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
    guard
      let peripheral = characteristic.service?.peripheral
    else {
      completion(.failure(.characteristicSetNotify(characteristic, internal: nil)))
      return
    }
    _setNorifyCompleted = completion
    peripheral.setNotifyValue(
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
