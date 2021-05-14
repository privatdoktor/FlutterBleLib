//
//  DiscoveredService.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

class DiscoveredDescriptor {
  let descriptor: CBDescriptor
  private var _readCompleted: ((_ res: Result<Any?, DelegateError>) -> ())?
  private var _writeCompleted: ((_ res: Result<(), DelegateError>) -> ())?
  
  init(_ descriptor: CBDescriptor) {
    self.descriptor = descriptor
  }
}
// MARK: - For Consumers
extension DiscoveredDescriptor {
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
}

// MARK: - For Publishers
extension DiscoveredDescriptor {
  func readCompleted(_ res: Result<Any?, DelegateError>) {
    _readCompleted?(res)
    _readCompleted = nil
  }
  func writeCompleted(_ res: Result<(), DelegateError>) {
    _writeCompleted?(res)
    _writeCompleted = nil
  }
}
