package hu.privatdoktor.flutter_ble_lib;

import hu.privatdoktor.multiplatformbleadapter.errors.BleError;
import hu.privatdoktor.multiplatformbleadapter.errors.BleErrorCode;


public class BleErrorFactory {
    
    public static BleError fromThrowable(Throwable exception) {
        return new BleError(BleErrorCode.UnknownError, exception.toString(), null);
    }
}
