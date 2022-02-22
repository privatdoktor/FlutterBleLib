package hu.privatdoktor.multiplatformbleadapter.utils;

import androidx.annotation.Nullable;

import hu.privatdoktor.multiplatformbleadapter.OnErrorCallback;
import hu.privatdoktor.multiplatformbleadapter.OnSuccessCallback;
import hu.privatdoktor.multiplatformbleadapter.errors.BleError;

import java.util.concurrent.atomic.AtomicBoolean;

public class SafeExecutor<T> {

    private OnSuccessCallback<T> successCallback;
    private OnErrorCallback errorCallback;
    private AtomicBoolean wasExecuted = new AtomicBoolean(false);

    public SafeExecutor(@Nullable OnSuccessCallback<T> successCallback, @Nullable OnErrorCallback errorCallback) {
        this.successCallback = successCallback;
        this.errorCallback = errorCallback;
    }

    public void success(T data) {
        if (wasExecuted.compareAndSet(false, true)) {
            successCallback.onSuccess(data);
        }
    }

    public void error(BleError error) {
        if (wasExecuted.compareAndSet(false, true)) {
            errorCallback.onError(error);
        }
    }
}
