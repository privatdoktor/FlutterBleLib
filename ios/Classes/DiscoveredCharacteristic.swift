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
  private var descriptorsDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredDescriptor], DelegateError>) -> ())?
  private var _readCompleted: ((_ res: Result<Any?, DelegateError>) -> ())?
  private var _writeCompleted: ((_ res: Result<(), DelegateError>) -> ())?
  private var _setNorifyCompleted: ((_ res: Result<(), DelegateError>) -> ())?
  var discoveredDescriptors = [CBUUID : DiscoveredDescriptor]()
  
  init(_ characteristic: CBCharacteristic) {
    self.characteristic = characteristic
  }
}
// MARK: - For Consumers
extension DiscoveredCharacteristic {
  func onDescriptorsDiscovery(
    _ completion: @escaping (_ res: Result<[CBUUID : DiscoveredDescriptor], DelegateError>) -> ()
  ) {
    descriptorsDiscoveryCompleted = completion
  }
  func onReadCompleted (
    _ completion: @escaping (_ res: Result<(Any?), DelegateError>) -> ()
  ) {
    _readCompleted = completion
  }
  func onWriteCompleted (
    _ completion: @escaping (_ res: Result<(), DelegateError>) -> ()
  ) {
    _writeCompleted = completion
  }
  func onSetNorifyCompleted (
    _ completion: @escaping (_ res: Result<(), DelegateError>) -> ()
  ) {
    _setNorifyCompleted = completion
  }
}

// MARK: - For Publishers
extension DiscoveredCharacteristic {
  func descriptorsDiscovered(_ res: Result<[CBUUID : DiscoveredDescriptor], DelegateError>) {
    descriptorsDiscoveryCompleted?(res)
    descriptorsDiscoveryCompleted = nil
  }
  func readCompleted(_ res: Result<Any?, DelegateError>) {
    _readCompleted?(res)
    _readCompleted = nil
  }
  func writeCompleted(_ res: Result<(), DelegateError>) {
    _writeCompleted?(res)
    _writeCompleted = nil
  }
  func setNorifyCompleted(_ res: Result<(), DelegateError>) {
    _setNorifyCompleted?(res)
    _setNorifyCompleted = nil
  }
}
