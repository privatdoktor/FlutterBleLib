//
//  PeripheralConnection.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 14/05/2021.
//

import Foundation
import CoreBluetooth

enum DelegateError : Error {
  case serviceDiscovery(internal: Error)
  case includedServicesDiscovery(CBService, internal: Error)
  case characteristicsDiscovery(CBService, internal: Error)
  case descriptorsDiscovery(CBCharacteristic, internal: Error)
  case characteristicRead(CBCharacteristic, internal: Error)
  case characteristicWrite(CBCharacteristic, internal: Error)
  case characteristicSetNotify(CBCharacteristic, internal: Error)
  case descriptorRead(CBDescriptor, internal: Error)
  case descriptorWrite(CBDescriptor, internal: Error)
}

class PeripheralConnection : NSObject {
  let peripheral: CBPeripheral
  
  private var connectCompleted: ((_ res: Result<(), Client.Error>) -> ())?
  private var disconnectCompleted: ((_ res: Result<(), Client.Error>) -> ())?
  
  private var servicesDiscoveryCompleted: ((_ res: Result<[CBUUID : DiscoveredService], DelegateError>) -> ())?
  
  private var discoveredServices = [CBUUID : DiscoveredService]()
 
  init(_ peripheral: CBPeripheral) {
    self.peripheral = peripheral
    super.init()
    peripheral.delegate = self
  }
}

// MARK: - For Consumers
extension PeripheralConnection {
  func onConnected(_ completion: @escaping (_ res: Result<(), Client.Error>) -> ()) {
    connectCompleted = completion
  }
  func onDisconnected(_ completion: @escaping (_ res: Result<(), Client.Error>) -> ()) {
    disconnectCompleted = completion
  }
  func onServicesDiscovery(_ completion: @escaping (_ res: Result<[CBUUID : DiscoveredService], DelegateError>) -> ()) {
    servicesDiscoveryCompleted = completion
  }
}
// MARK: - For Publishers
extension PeripheralConnection {
  func connected(_ res: Result<(), Client.Error>) {
    connectCompleted?(res)
    connectCompleted = nil
  }
  func disconnected(_ res: Result<(), Client.Error>) {
    disconnectCompleted?(res)
    disconnectCompleted = nil
  }
  private func servicesDiscovered(_ res: Result<[CBUUID : DiscoveredService], DelegateError>) {
    servicesDiscoveryCompleted?(res)
    servicesDiscoveryCompleted = nil
  }
}

// MARK: - Helpers
extension PeripheralConnection {
  var flattenedDiscoveredServices: [CBUUID : DiscoveredService] {
    var services = [CBUUID : DiscoveredService]()
    for (key, ds) in discoveredServices {
      services[key] = ds
      if let included = ds.includedDiscoveredServices {
        for (inclKey, inclDs) in included {
          services[inclKey] = inclDs
        }
      }
    }
    return services
  }
}

extension PeripheralConnection : CBPeripheralDelegate {
  // MARK: - Service related delegate methods
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverServices error: Error?
  ) {
    if let error = error {
      servicesDiscovered(.failure(.serviceDiscovery(internal: error)))
      return
    }
    guard
      let services = peripheral.services
    else {
      servicesDiscovered(.success([:]))
      return
    }
    discoveredServices.removeAll()
    for service in services {
      discoveredServices[service.uuid] = DiscoveredService(service)
    }
    servicesDiscovered(.success(discoveredServices))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverIncludedServicesFor service: CBService,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[service.uuid]
    else {
      return
    }
    if let error = error {
      ds.includedServicesDiscovered(
        .failure(.includedServicesDiscovery(service, internal: error))
      )
      return
    }
    guard let included = service.includedServices  else {
      ds.includedServicesDiscovered(.success([:]))
      return
    }
    let ids =
      Dictionary(
        uniqueKeysWithValues: zip(
          included.map({ $0.uuid }),
          included.map(DiscoveredService.init)
        )
      )
    ds.includedDiscoveredServices = ids
    ds.includedServicesDiscovered(.success(ids))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didModifyServices invalidatedServices: [CBService]
  ) {
    for invalid in invalidatedServices {
      discoveredServices.removeValue(forKey: invalid.uuid)
      for (_, ds) in discoveredServices {
        ds.includedDiscoveredServices?.removeValue(forKey: invalid.uuid)
      }
    }
  }
  // MARK: - Characteristic related delegate methods
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[service.uuid]
    else {
      return
    }
    if let error = error {
      ds.characteristicsDiscovered(
        .failure(.characteristicsDiscovery(service, internal: error))
      )
      return
    }
    ds.discoveredCharacteristics.removeAll()
    for char in service.characteristics ?? [] {
      ds.discoveredCharacteristics[char.uuid] = DiscoveredCharacteristic(char)
    }
    ds.characteristicsDiscovered(.success(ds.discoveredCharacteristics))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[characteristic.service.uuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      dc.readCompleted(
        .failure(.characteristicRead(characteristic, internal: error))
      )
      return
    }
    dc.readCompleted(.success(characteristic.value))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[characteristic.service.uuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      dc.writeCompleted(
        .failure(.characteristicWrite(characteristic, internal: error))
      )
      return
    }
    dc.writeCompleted(.success(()))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let ds = flattenedDiscoveredServices[characteristic.service.uuid],
      let dc = ds.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      dc.setNorifyCompleted(
        .failure(.characteristicSetNotify(characteristic, internal: error))
      )
      return
    }
    dc.setNorifyCompleted(.success(()))
  }
    
  func peripheralIsReady(toSendWriteWithoutResponse
    peripheral: CBPeripheral
  ) {
      //TODO: figure out what to do here exactly
  }
  
  // MARK: - Descriptor related delegate methods
  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverDescriptorsFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard
      let ser = discoveredServices[characteristic.service.uuid],
      let discoveredChar = ser.discoveredCharacteristics[characteristic.uuid]
    else {
      return
    }
    if let error = error {
      discoveredChar.descriptorsDiscovered(
        .failure(.descriptorsDiscovery(characteristic, internal: error))
      )
      return
    }
    discoveredChar.discoveredDescriptors.removeAll()
    for desc in characteristic.descriptors ?? [] {
      discoveredChar.discoveredDescriptors[desc.uuid] =
        DiscoveredDescriptor(desc)
    }
    discoveredChar.descriptorsDiscovered(
      .success(discoveredChar.discoveredDescriptors)
    )
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor descriptor: CBDescriptor,
    error: Error?
  ) {
    guard
      let ser = discoveredServices[descriptor.characteristic.service.uuid],
      let char = ser.discoveredCharacteristics[descriptor.characteristic.uuid],
      let discoveredDesc = char.discoveredDescriptors[descriptor.uuid]
    else {
      return
    }
    if let error = error {
      discoveredDesc.readCompleted(
        .failure(.descriptorRead(descriptor, internal: error))
      )
      return
    }
    discoveredDesc.readCompleted(.success(descriptor.value))
  }
  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor descriptor: CBDescriptor,
    error: Error?
  ) {
    guard
      let ser = discoveredServices[descriptor.characteristic.service.uuid],
      let char = ser.discoveredCharacteristics[descriptor.characteristic.uuid],
      let discoveredDesc = char.discoveredDescriptors[descriptor.uuid]
    else {
      return
    }
    if let error = error {
      discoveredDesc.writeCompleted(
        .failure(.descriptorWrite(descriptor, internal: error))
      )
      return
    }
    discoveredDesc.writeCompleted(.success(()))
  }
  // MARK: - Other delegate methods
  func peripheralDidUpdateName(
    _ peripheral: CBPeripheral
  ) {
    
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didReadRSSI RSSI: NSNumber,
    error: Error?
  ) {
    
  }
  
  @available(iOS 11.0, *)
  func peripheral(
    _ peripheral: CBPeripheral,
    didOpen channel: CBL2CAPChannel?,
    error: Error?
  ) {
    
  }
}
