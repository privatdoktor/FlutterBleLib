package com.polidea.flutter_ble_lib.constant;

public interface MethodName {
    String IS_CLIENT_CREATED = "isClientCreated";
    String CREATE_CLIENT = "createClient";
    String DESTROY_CLIENT = "destroyClient";

    String GET_STATE = "getState";

    String ENABLE_RADIO = "enableRadio";
    String DISABLE_RADIO = "disableRadio";

    String START_DEVICE_SCAN = "startDeviceScan";
    String STOP_DEVICE_SCAN = "stopDeviceScan";

    String CONNECT_TO_DEVICE = "connectToDevice";
    String IS_DEVICE_CONNECTED = "isDeviceConnected";
    String OBSERVE_CONNECTION_STATE = "observeConnectionState";
    String CANCEL_CONNECTION = "cancelConnection";

    String DISCOVER_ALL_SERVICES_AND_CHARACTERISTICS = "discoverAllServicesAndCharacteristics";
    String DISCOVER_SERVICES = "discoverServices";
    String DISCOVER_CHARACTERISTICS = "discoverCharacteristics";
    String GET_SERVICES = "services";
    String GET_CHARACTERISTICS = "characteristics";
    String GET_DESCRIPTORS_FOR_DEVICE = "descriptorsForDevice";

    String LOG_LEVEL = "logLevel";
    String SET_LOG_LEVEL = "setLogLevel";

    String RSSI = "rssi";

    String REQUEST_MTU = "requestMtu";

    String GET_CONNECTED_DEVICES = "getConnectedDevices";
    String GET_KNOWN_DEVICES = "getKnownDevices";

    String READ_CHARACTERISTIC_FOR_DEVICE = "readCharacteristicForDevice";

    String WRITE_CHARACTERISTIC_FOR_DEVICE = "writeCharacteristicForDevice";

    String MONITOR_CHARACTERISTIC_FOR_DEVICE = "monitorCharacteristicForDevice";

    String READ_DESCRIPTOR_FOR_DEVICE = "readDescriptorForDevice";

    String WRITE_DESCRIPTOR_FOR_DEVICE = "writeDescriptorForDevice";
}
