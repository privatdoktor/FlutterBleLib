//
//  ClientAdapter.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 17/03/2022.
//

import Foundation
import CoreBluetooth

extension Client {
  
  func noop() {}
  
  func connectToDevice(
    id: String,
    timoutMillis: Int?,
    completion: @escaping (_ completion: Result<(), ClientError>) -> ()
  ) {
    switch discoveredPeripheral(for: id) {
    case .failure(let error):
      completion(.failure(error))
    case .success(let dp):
      // FIXME: support connection option flags
      dp.connect(completion)
    }
  }

  func isDeviceConnected(id: String) -> Result<Bool, ClientError> {
    switch discoveredPeripheral(for: id) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      return .success(dp.peripheral.state == .connected)
    }
  }
  
  func cancelConnection(
    deviceIdentifier: String,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
    case .success(let dp):
      dp.disconnect(completion)
    }
  }
  
  func discoverServices(
    deviceIdentifier: String,
    serviceUUIDStrs: [String]? = nil,
    completion: @escaping (Result<[ServiceResponse], ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    let serviceCBUUIDs = serviceUUIDStrs.map(
      { $0.map( { CBUUID(string: $0) } ) }
    )
    discoPeri.discoverServices(serviceUUIDs: serviceCBUUIDs) { res in
      switch res {
      case .success(let dss):
        let services = dss.values.map { ServiceResponse(with: $0.service) }
        completion(.success(services))
      case .failure(let error):
        completion(.failure(ClientError.peripheral(error)))
      }
    }
  }
  
  func discoverCharacteristics(
    deviceIdentifier: String,
    serviceUuid: String,
    characteristicUUIDStrs: [String]? = nil,
    completion: @escaping (Result<[CharacteristicResponse], ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    guard
      let ds = discoPeri.discoveredServices[CBUUID(string:serviceUuid)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(discoPeri.peripheral, id: serviceUuid))
        )
      )
      return
    }
    let characteristicCBUUIDs = characteristicUUIDStrs.map(
      { $0.map( { CBUUID(string: $0) } ) }
    )
    ds.discoverCharacteristics(characteristicUUIDs: characteristicCBUUIDs) { res in
      switch res {
      case .success(let dss):
        let chars = dss.map({
          CharacteristicResponse(char:$0.value.characteristic)
        })
        completion(.success(chars))
      case .failure(let error):
        completion(.failure(.peripheral(error)))
      }
    }
  }
  
  func discoverDescriptors(
    deviceIdentifier: String,
    serviceUuid: String,
    characteristicUUIDStr: String,
    completion: @escaping (Result<[DescriptorResponse], ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    guard
      let ds = discoPeri.discoveredServices[CBUUID(string:serviceUuid)],
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUIDStr)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(discoPeri.peripheral, id: serviceUuid))
        )
      )
      return
    }
    
    dc.discoverDescriptors { res in
      switch res {
      case .success(let dcs):
        let descs = dcs.map {
          return DescriptorResponse(desc: $0.value.descriptor)
        }
        completion(.success(descs))
      case .failure(let error):
        completion(.failure(.peripheral(error)))
      }
    }
  }
  
  func services(
    for deviceIdentifier: String
  ) -> Result<[ServiceResponse], ClientError> {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      discoPeri = dp
    }
    let serResps = discoPeri.peripheral.services?.map({
      ServiceResponse(with: $0)
    }) ?? []
    return .success(serResps)
  }

  
  func characteristics(
    for deviceIdentifier: String,
    serviceUUID: String
  ) -> Result<[CharacteristicResponse], ClientError> {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      discoPeri = dp
    }
    let cbuuid = CBUUID(string: serviceUUID)
    guard
      let ds = discoveredPeripheral.discoveredServices[serviceCbuuid]
    else {
      return .failure(
        .peripheral(
          .noServiceFound(discoveredPeripheral.peripheral, id: serviceCbuuid.uuidString)
        )
      )
    }
    let chars = (ds.service.characteristics ?? []).map {
      CharacteristicResponse(char: $0)
    }
    return .success(chars)
  }
  
  func descriptors(
    for deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String
  ) -> Result<[DescriptorResponse], ClientError> {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      return .failure(error)
    case .success(let dp):
      discoPeri = dp
    }
    guard
      let ds = discoPeri.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      return .failure(
        .peripheral(
          .noServiceFound(discoPeri.peripheral, id: serviceUUID)
        )
      )
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      return .failure(
        .peripheral(
          .noCharacteristicFound(ds.service, id: characteristicUUID)
        )
      )
    }
    let char = dc.characteristic
    let descs = char.descriptors ?? []
    return .success(
      descs.map { descriptor in
        return DescriptorResponse(desc: descriptor)
      }
    )
  }
  
  func readRssi(
    for deviceIdentifier: String,
    completion: @escaping (Result<Int, ClientError>) -> ()
  ) {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let dp):
      discoPeri = dp
    }
    discoPeri.readRssi(completion)
  }
  
  func requestMtu(for deviceIdentifier: String) -> Int {
    let discoPeri: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure:
      return CBPeripheral.defaultMtu
    case .success(let dp):
      discoPeri = dp
    }
    return discoPeri.peripheral.mtu
  }
  
  func connectedDevices(serviceUUIDs: [String]) -> Result<[PeripheralResponse], ClientError> {
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    return .success(
      centralManager.retrieveConnectedPeripherals(
        withServices: serviceUUIDs.map(CBUUID.init)
      ).map(
        PeripheralResponse.init
      )
    )
  }
  
  func knownDevices(deviceIdentifiers: [String]) -> Result<[PeripheralResponse], ClientError> {
    guard
      let centralManager = centralManager
    else {
      return .failure(.notCreated)
    }
    return .success(
      centralManager.retrievePeripherals(
        withIdentifiers: deviceIdentifiers.compactMap(UUID.init)
      ).map(
        PeripheralResponse.init
      )
    )
  }
  
  func readCharacteristic(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    completion: @escaping (Result<CharacteristicResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    dc.read { res in
      switch res {
      case .failure(let error):
        completion(.failure(.peripheral(error)))
      case .success(let char):
        let resp = CharacteristicResponse(
          char: char
        )
        completion(.success(resp))
      }
    }
  }
  
  func writeCharacteristic(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    value: FlutterStandardTypedData,
    withResponse: Bool,
    completion: @escaping (Result<CharacteristicResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    dc.write(
      value.data,
      type: withResponse ? .withResponse : .withoutResponse
    ) { res in
      completion(
        res.map({ char in
          return CharacteristicResponse(
            char: char
          )
        }).mapError(ClientError.peripheral)
      )
    }
    
  }
  
  func monitorCharacteristic(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    eventSteam: Stream<CharacteristicResponse>,
    completion: @escaping (Result<(), ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    guard
      let peripheral = dc.characteristic.service?.peripheral
    else {
      completion(
        .failure(.noPeripheralFoundFor(nil, expectedState: nil))
      )
      return
    }
    let puuid = peripheral.identifier
    
    guard
      let dp =
        discoveredPeripherals[puuid]
    else {
      completion(
        .failure(.noPeripheralFoundFor(puuid, expectedState: nil))
      )
      return
    }
    eventSteam.afterCancelDo = {
      let char = dc.characteristic
      if char.isNotifying {
        peripheral.setNotifyValue(false, for: char)
      }
      dc.onValueUpdate(handler: nil)
    }
    dp.onDisconnected {
      eventSteam.eventHandler(.endOfStream)
    }
    dc.onValueUpdate { char in
      eventSteam.eventHandler(
        .data(
          CharacteristicResponse(
            char: char
          )
        )
      )
    }
    guard
      dc.characteristic.isNotifying == false
    else {
      completion(.success(()))
      return
    }
    
    dc.setNotify(true) { res in
      switch res {
      case .failure(let error):
        completion(.failure(.peripheral(error)))
        return
      case .success(let char):
        if char.isNotifying {
          completion(.success(()))
        } else {
          completion(
            .failure(
              .peripheral(.characteristicSetNotify(char, internal: nil))
            )
          )
        }
        
      }
    }
  }
  
  func readDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    guard
      let dd = dc.discoveredDescriptors[CBUUID(string:descriptorUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noDescriptorFound(dc.characteristic, id: descriptorUUID))
        )
      )
      return
    }
    dd.read { res in
      completion(
        res.map({ desc in
          return DescriptorResponse(
            desc: desc
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }
  
  func writeDescriptorForDevice(
    deviceIdentifier: String,
    serviceUUID: String,
    characteristicUUID: String,
    descriptorUUID: String,
    value: FlutterStandardTypedData,
    completion: @escaping (Result<DescriptorResponse, ClientError>) -> ()
  ) {
    let dp: DiscoveredPeripheral
    switch discoveredPeripheral(for: deviceIdentifier) {
    case .failure(let error):
      completion(.failure(error))
      return
    case .success(let value):
      dp = value
    }
    guard
      let ds = dp.discoveredServices[CBUUID(string: serviceUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noServiceFound(dp.peripheral, id: serviceUUID))
        )
      )
      return
    }
    guard
      let dc = ds.discoveredCharacteristics[CBUUID(string: characteristicUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noCharacteristicFound(ds.service, id: characteristicUUID))
        )
      )
      return
    }
    guard
      let dd = dc.discoveredDescriptors[CBUUID(string:descriptorUUID)]
    else {
      completion(
        .failure(
          .peripheral(.noDescriptorFound(dc.characteristic, id: descriptorUUID))
        )
      )
      return
    }
    dd.write(value.data) { res in
      completion(
        res.map({ desc in
          return DescriptorResponse(
            desc: desc
          )
        }).mapError(ClientError.peripheral)
      )
    }
  }
}

struct ScanResultEvent : Encodable {
  let id: String
  let name: String?
  let rssi: Int
  let mtu: Int
  
  let localName: String?
  let txPowerLevel: Int?
  let isConnectable: Bool?
  
  let manufacturerData: String? // base64EncodedString
  
  let serviceUUIDs: [String]?
  let overflowServiceUUIDs: [String]?
  let solicitedServiceUUIDs: [String]?
  
  let serviceData: [String : String]? // base64EncodedString value
  
  init(
    peripheral: CBPeripheral,
    advertisementData: [String : Any],
    rssi: Int
  ) {
    id = peripheral.identifier.uuidString
    name = peripheral.name
    self.rssi = rssi
    mtu = peripheral.mtu
    
    do {
      let manData =
        advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
      let serUuids =
        advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
      let overFlSerUuids =
        advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
      let solicitedSerUuids =
        advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
      let serData =
        advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID : Data]
      let locName =
        advertisementData[CBAdvertisementDataLocalNameKey] as? String
      let txPowLvl =
        advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Int
      let isConnble =
        advertisementData[CBAdvertisementDataIsConnectable] as? Bool
      
      manufacturerData = manData?.base64EncodedString()
      serviceUUIDs = serUuids?.map { $0.fullUUIDString }
      overflowServiceUUIDs = overFlSerUuids?.map { $0.fullUUIDString }
      solicitedServiceUUIDs = solicitedSerUuids?.map { $0.fullUUIDString }
      if let serData = serData {
        serviceData = Dictionary(
          uniqueKeysWithValues: serData.map({
            ($0.key.fullUUIDString, $0.value.base64EncodedString())
          })
        )
      } else {
        serviceData = nil
      }
      localName = locName
      txPowerLevel = txPowLvl
      isConnectable = isConnble
    }
  }
  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case name = "name"
    case rssi = "rssi"
    case mtu = "mtu"
    
    case isConnectable = "isConnectable"
    case localName = "localName"
    case txPowerLevel = "txPowerLevel"
    
    case manufacturerData = "manufacturerData"
    
    case serviceUUIDs = "serviceUUIDs"
    case overflowServiceUUIDs = "overflowServiceUUIDs"
    case solicitedServiceUUIDs = "solicitedServiceUUIDs"
    
    case serviceData = "serviceData"


  }
}

struct PeripheralResponse : Encodable {
  let name: String?
  let id: String
  
  init(_ peripheral: CBPeripheral) {
    name = peripheral.name
    id = peripheral.identifier.uuidString
  }
  
  private enum CodingKeys: String, CodingKey {
    case name = "name"
    case id = "id"
  }
}

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

struct CharacteristicResponse : Encodable {
  let characteristicUuid: String
  let isIndicatable: Bool
  let isNotifiable: Bool
  let isNotifying: Bool
  let isReadable: Bool
  let isWritableWithResponse: Bool
  let isWritableWithoutResponse: Bool
  let value: String?
  
  init(
    char: CBCharacteristic
  ) {
    characteristicUuid = char.uuid.fullUUIDString
    let properties = char.properties
    isIndicatable = properties.contains(.indicate)
    isReadable = properties.contains(.read)
    isWritableWithResponse = properties.contains(.write)
    isWritableWithoutResponse = properties.contains(.writeWithoutResponse)
    isNotifiable =  properties.contains(.notify)
    isNotifying = char.isNotifying
    value = char.value?.base64EncodedString()
  }
  
  private enum CodingKeys: String, CodingKey {
    case characteristicUuid = "characteristicUuid"
    case isIndicatable = "isIndicatable"
    case isNotifiable = "isNotifiable"
    case isNotifying = "isNotifying"
    case isReadable = "isReadable"
    case isWritableWithResponse = "isWritableWithResponse"
    case isWritableWithoutResponse = "isWritableWithoutResponse"
    case value = "value"
  }
}

struct DescriptorResponse : Encodable {
  let descriptorUuid: String
  let value: String? // base64encodedString from Data
    
  init(
    desc: CBDescriptor
  ) {
    descriptorUuid = desc.uuid.fullUUIDString
    value = desc.valueAsData?.base64EncodedString()
  }
  
  private enum CodingKeys: String, CodingKey {
    case descriptorUuid = "descriptorUuid"
    case value = "value"
  }
}
