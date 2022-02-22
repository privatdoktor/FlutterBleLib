package hu.privatdoktor.multiplatformbleadapter;

import hu.privatdoktor.multiplatformbleadapter.errors.BleError;

public interface OnErrorCallback {

    void onError(BleError error);
}
