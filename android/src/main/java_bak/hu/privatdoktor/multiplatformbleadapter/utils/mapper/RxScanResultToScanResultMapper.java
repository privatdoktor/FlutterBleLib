package hu.privatdoktor.multiplatformbleadapter.utils.mapper;

import hu.privatdoktor.multiplatformbleadapter.AdvertisementData;
import hu.privatdoktor.multiplatformbleadapter.ScanResult;
import hu.privatdoktor.multiplatformbleadapter.utils.Constants;

public class RxScanResultToScanResultMapper {

    public ScanResult map(com.polidea.rxandroidble2.scan.ScanResult rxScanResult) {
        return new ScanResult(
                rxScanResult.getBleDevice().getMacAddress(),
                rxScanResult.getBleDevice().getName(),
                rxScanResult.getRssi(),
                Constants.MINIMUM_MTU,
                false, //isConnectable flag is not available on Android
                null, //overflowServiceUUIDs are not available on Android
                AdvertisementData.parseScanResponseData(rxScanResult.getScanRecord().getBytes())
        );
    }
}
