//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

struct ServiceResponse : Encodable {
  let uuid: String
  let deviceID: String
  let isPrimary: Bool
  
  init(
    with service: CBService
  ) {
    uuid = service.uuid.fullUUIDString
    deviceID = service.peripheral?.identifier.uuidString ?? ""
    isPrimary = service.isPrimary
  }
  
  private enum CodingKeys: String, CodingKey {
    case uuid = "serviceUuid"
    case deviceID = "deviceID"
    case isPrimary = "isPrimary"
  }
}

class DiscoveredService {
  let service: CBService
  
  private var _includedServicesDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) -> ())?
  private var _characteristicsDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredCharacteristic], PeripheralError>) -> ())?
  
  var includedDiscoveredServices: [CBUUID : DiscoveredService]?
  var discoveredCharacteristics = [CBUUID : DiscoveredCharacteristic]()
  
  init(_ service: CBService) {
    self.service = service
  }
}
// MARK: - API
extension DiscoveredService {
  func discoverCharacteristics(
    characteristicUUIDs: [CBUUID]? = nil,
    _ completion: @escaping (
      _ res: Result<[CBUUID : DiscoveredCharacteristic], PeripheralError>
    ) -> ()
  ) {
    if let pending = _characteristicsDiscoveryCompleted {
      _characteristicsDiscoveryCompleted = nil
      pending(.failure(.characteristicsDiscovery(service, internal: nil)))
    }
    guard
      let peripheral = service.peripheral
    else {
      completion(
        .failure(.characteristicsDiscovery(service, internal: nil))
      )
      return
    }
    _characteristicsDiscoveryCompleted = completion
    peripheral.discoverCharacteristics(
      characteristicUUIDs,
      for: service
    )
  }
  func discoverIncludedServices(
    includedServiceUUIDs: [CBUUID]?,
    _ completion:
      @escaping (_ res: Result<[CBUUID : DiscoveredService],PeripheralError>) -> ()
  ) {
    if let pending = _includedServicesDiscoveryCompleted {
      _includedServicesDiscoveryCompleted = nil
      pending(.failure(.includedServicesDiscovery(service, internal: nil)))
    }
    guard
      let peripheral = service.peripheral
    else {
      completion(
        .failure(.includedServicesDiscovery(service, internal: nil))
      )
      return
    }
    _includedServicesDiscoveryCompleted = completion
    peripheral.discoverIncludedServices(
      includedServiceUUIDs,
      for: service
    )
  }
}
// MARK: - For Publishers
extension DiscoveredService {
  func includedServicesDiscovered(_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) {
    _includedServicesDiscoveryCompleted?(res)
    _includedServicesDiscoveryCompleted = nil
  }
  func characteristicsDiscovered(_ res: Result<[CBUUID : DiscoveredCharacteristic], PeripheralError>) {
    _characteristicsDiscoveryCompleted?(res)
    _characteristicsDiscoveryCompleted = nil
  }
}
