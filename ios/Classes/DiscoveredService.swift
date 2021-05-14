//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

class DiscoveredService {
  let service: CBService
  
  private var includedServicesDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredService], DelegateError>) -> ())?
  private var characteristicsDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredCharacteristic], DelegateError>) -> ())?
  
  var includedDiscoveredServices: [CBUUID : DiscoveredService]?
  var discoveredCharacteristics = [CBUUID : DiscoveredCharacteristic]()
  
  init(_ service: CBService) {
    self.service = service
  }
}
// MARK: - For Consumers
extension DiscoveredService {
  func onIncludedServicesDiscovery(
    _ completion:
      @escaping (_ res: Result<[CBUUID : DiscoveredService],DelegateError>) -> ()
  ) {
    includedServicesDiscoveryCompleted = completion
  }
  func onCharacteristicsDiscovery(
    _ completion:
      @escaping (_ res: Result<[CBUUID : DiscoveredCharacteristic], DelegateError>) -> ()
  ) {
    characteristicsDiscoveryCompleted = completion
  }
}
// MARK: - For Publishers
extension DiscoveredService {
  func includedServicesDiscovered(_ res: Result<[CBUUID : DiscoveredService], DelegateError>) {
    includedServicesDiscoveryCompleted?(res)
    includedServicesDiscoveryCompleted = nil
  }
  func characteristicsDiscovered(_ res: Result<[CBUUID : DiscoveredCharacteristic], DelegateError>) {
    characteristicsDiscoveryCompleted?(res)
    characteristicsDiscoveryCompleted = nil
  }
}
