part of flutter_ble_lib;

extension LogLevel on BleManager {

  LogLevel _logLevelFromString(String logLevelName) {
    print('try to get log level from: $logLevelName');
    return LogLevel.values.firstWhere(
        (e) => e.toString() == 'LogLevel.' + logLevelName.toLowerCase());
  }
}
