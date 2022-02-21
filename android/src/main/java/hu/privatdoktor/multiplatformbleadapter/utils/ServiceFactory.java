package hu.privatdoktor.multiplatformbleadapter.utils;

import android.bluetooth.BluetoothGattService;

import hu.privatdoktor.multiplatformbleadapter.Service;

public class ServiceFactory {

    public Service create(String deviceId, BluetoothGattService btGattService) {
        return new Service(
                IdGenerator.getIdForKey(new IdGeneratorKey(deviceId, btGattService.getUuid(), btGattService.getInstanceId())),
                deviceId,
                btGattService
        );
    }
}
