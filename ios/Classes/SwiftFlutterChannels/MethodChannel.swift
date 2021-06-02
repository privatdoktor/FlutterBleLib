//
//  Method.swift
//  flutter_ble_lib
//
//  Created by Oliver Kocsis on 13/05/2021.
//

import Foundation

enum SignatureError<ArgumentKeyT : ArgumentKeyEnum> : LocalizedError {
  
  var failureReason: String? {
    switch self {
    case .missingArgsKey(let key, let dict, let id):
      return
        """
        Missing argument key: \(key)
        in dict: \(String(describing: dict)) for method \(id)
        """
    case .invalidValue(let key, let value,
                       let dict, let id,
                       let expected):
      return
        """
        Invalid value: \(value) for key: \(key)
        in dict: \(dict) for method: \(id).
        Expected value type: \(expected) and got \(type(of: value))
        """
    }
  }
  case missingArgsKey(ArgumentKeyT,
                      inDict: Dictionary<ArgumentKeyT, Any>?,
                      id: String)
  case invalidValue(forKey: ArgumentKeyT, value: Any,
                    inDict: Dictionary<ArgumentKeyT, Any>, id: String,
                    expected: Any.Type)
}

protocol ArgumentKeyEnum : Hashable, RawRepresentable where RawValue == String {}

protocol SignatureEnum {
  associatedtype ArgumentKeyEnumT: ArgumentKeyEnum
  static func validate(args: [String : Any]?) -> [ArgumentKeyEnumT : Any]?
  init?(_ id: String, args: [ArgumentKeyEnumT : Any]?) throws
}

extension SignatureEnum {
  static func validate(args: [String : Any]?) -> [ArgumentKeyEnumT : Any]? {
    guard let args = args else {
      return nil
    }
    return Dictionary(
      uniqueKeysWithValues: args.compactMap { (key: String, value: Any) in
        guard let argKey = ArgumentKeyEnumT(rawValue: key) else {
          return nil
        }
        return (argKey, value)
      }
    )
  }

}

protocol MethodChannel : NSObject, FlutterPlugin {
  associatedtype SignatureEnumT: SignatureEnum
  associatedtype CallHandlerT: CallHandler
  static var name: String { get }
  
  var handler: CallHandlerT { get }
  var eventChannelFactory: EventChannelFactory { get }
  init(handler: CallHandlerT, messenger: FlutterBinaryMessenger)
}


protocol CallHandler {
  associatedtype SignatureEnumT: SignatureEnum
  func handle(call: Call<SignatureEnumT>,
              eventChannelFactory: EventChannelFactory)
}

class Call<SignatureEnumT: SignatureEnum> {
  let signature: SignatureEnumT
  private var isResulted = false
  private let onResult: FlutterResult
  
  init?(
    _ id: String,
    args: Dictionary<String, Any>?,
    onResult result: @escaping FlutterResult
  ) {
    do {
      guard
        let sig = try SignatureEnumT(
          id,
          args: SignatureEnumT.validate(args: args)
        )
      else {
        result(FlutterMethodNotImplemented)
        return nil
      }
      signature = sig
      onResult = result
    } catch {
      result(FlutterError(withError: error as NSError))
      return nil
    }
  }
  
  private func _result(
    _ objectOrError: Result<Any?, Error>
  ) {
    guard
      isResulted == false
    else {
      return
    }
    switch objectOrError {
    case .success(let objectOrError):
      onResult(objectOrError)
    case .failure(let error as BleError):
      onResult(FlutterError(bleError: error))
    case .failure(let error):
      onResult(FlutterError(bleError: BleError(withError: error)))
    }
    isResulted = true
  }
  func result<AnyT: Any, ErrorT: Error>(
    any anyOrError: Result<AnyT, ErrorT>
  ) {
    switch anyOrError {
    case .success(let any):
      _result(.success(any))
    case .failure(let error):
      _result(.failure(error))
    }
  }
  func result<ResponseT : Any>(any: ResponseT) {
    result(any: Result<ResponseT,Error>.success(any))
  }
  
  
  func result<ResponseT: Encodable, ErrorT: Error>(
    encodable encodableOrError: Result<ResponseT, ErrorT>
  ) {
    switch encodableOrError {
    case .success(let encodable):
      do {
        let data = try JSONEncoder().encode(encodable)
        let jsonStr = String(data: data, encoding: .utf8)
        _result(.success(jsonStr))
      } catch {
        _result(.failure(error))
      }
    case .failure(let error):
      _result(.failure(error))
    }
  }
  func result<ErrorT: Error>(
    _ unitOrError: Result<(), ErrorT>
  ) {
    switch unitOrError {
    case .success:
      _result(.success(nil))
    case .failure(let error):
      _result(.failure(error))
    }
  }
  func result() {
    _result(.success(nil))
  }
  func result(error: Error) {
    _result(.failure(error))
  }
  func result<ResponseT : Encodable>(encodable: ResponseT) {
    result(encodable: Result<ResponseT,Error>.success(encodable))
  }
  func result<ErrorT: Error>(_ value: Result<Bool,ErrorT>)  {
    result(any: value)
  }
  func result(_ value: Bool)  {
    result(Result<Bool,Error>.success(value))
  }
  func result<ErrorT: Error>(_ value: Result<Int,ErrorT>)  {
    result(any: value)
  }
  func result(_ value: Int)  {
    result(Result<Int,Error>.success(value))
  }
  func result<ErrorT: Error>(_ value: Result<String, ErrorT>)  {
    result(any: value)
  }
  func result(_ value: String)  {
    result(Result<String,Error>.success(value))
  }
  
}
  

