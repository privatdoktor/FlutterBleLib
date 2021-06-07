part of flutter_ble_lib;

extension Rssi on BleManager {
  Future<int> rssi(Peripheral peripheral, String transactionId) async {
    return await BleManager._methodChannel.invokeMethod(MethodName.rssi, <String, dynamic>{
      ArgumentName.deviceIdentifier: peripheral.identifier,
      ArgumentName.transactionId: transactionId
    }).catchError((errorJson) =>
        Future.error(BleError.fromJson(jsonDecode(errorJson.details))));
  }
}
