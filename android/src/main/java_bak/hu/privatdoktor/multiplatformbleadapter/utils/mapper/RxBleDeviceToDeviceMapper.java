package hu.privatdoktor.multiplatformbleadapter.utils.mapper;

import hu.privatdoktor.multiplatformbleadapter.Device;
import com.polidea.rxandroidble2.RxBleDevice;

public class RxBleDeviceToDeviceMapper {

    public Device map(RxBleDevice rxDevice) {
        return new Device(rxDevice.getMacAddress(), rxDevice.getName());
    }
}
