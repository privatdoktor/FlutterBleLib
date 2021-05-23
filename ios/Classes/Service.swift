//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

struct ServiceResponse : Encodable {
  let id: Int
  let uuid: String
  let deviceID: String
  let isPrimary: Bool
  
  init(
    with service: CBService,
    using uuidCache: HashableIdCache<CBUUID>
  ) {
    uuid = service.uuid.fullUUIDString
    deviceID = service.peripheral.identifier.uuidString
    isPrimary = service.isPrimary
    id = uuidCache.numeric(from: service.uuid)
  }
  
  private enum CodingKeys: String, CodingKey {
    case id = "serviceId"
    case uuid = "serviceUuid"
    case deviceID = "deviceID"
    case isPrimary = "isPrimary"
  }
}

class DiscoveredService {
  let service: CBService
  
  private var includedServicesDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) -> ())?
  private var characteristicsDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredCharacteristic], PeripheralError>) -> ())?
  
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
    characteristicsDiscoveryCompleted = completion
    service.peripheral.discoverCharacteristics(
      characteristicUUIDs,
      for: service
    )
  }
  func discoverIncludedServices(
    includedServiceUUIDs: [CBUUID]?,
    _ completion:
      @escaping (_ res: Result<[CBUUID : DiscoveredService],PeripheralError>) -> ()
  ) {
    includedServicesDiscoveryCompleted = completion
    service.peripheral.discoverIncludedServices(
      includedServiceUUIDs,
      for: service
    )
  }
}
// MARK: - For Publishers
extension DiscoveredService {
  func includedServicesDiscovered(_ res: Result<[CBUUID : DiscoveredService], PeripheralError>) {
    includedServicesDiscoveryCompleted?(res)
    includedServicesDiscoveryCompleted = nil
  }
  func characteristicsDiscovered(_ res: Result<[CBUUID : DiscoveredCharacteristic], PeripheralError>) {
    characteristicsDiscoveryCompleted?(res)
    characteristicsDiscoveryCompleted = nil
  }
}
