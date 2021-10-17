package com.polidea.flutter_ble_lib.event;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.polidea.flutter_ble_lib.ConnectionStateChange;
import com.polidea.flutter_ble_lib.constant.ChannelName;
import com.polidea.flutter_ble_lib.converter.BleErrorJsonConverter;
import com.polidea.flutter_ble_lib.converter.ConnectionStateChangeJsonConverter;

import org.json.JSONException;

import java.util.UUID;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;

public class ConnectionStateStreamHandler implements EventChannel.StreamHandler {

    @NonNull private EventChannel eventChannel;
    @NonNull public String name;

    private EventChannel.EventSink eventSink;
    private ConnectionStateChangeJsonConverter connectionStateChangeJsonConverter =
            new ConnectionStateChangeJsonConverter();

    public ConnectionStateStreamHandler(BinaryMessenger binaryMessenger, String deviceId) {
        name = ChannelName.CONNECTION_STATE_CHANGE_EVENTS + "/" + deviceId.toUpperCase();
        eventChannel = new EventChannel(binaryMessenger, name);
        eventChannel.setStreamHandler(this);
    }

    @Override
    synchronized public void onListen(Object o, EventChannel.EventSink eventSink) {
        this.eventSink = eventSink;
    }

    @Override
    synchronized public void onCancel(Object o) {
        eventSink = null;
    }

    synchronized public void onNewConnectionState(final ConnectionStateChange connectionState) {
        if (eventSink != null) {
            final ConnectionStateStreamHandler that = this;
            new Handler(Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    synchronized (that) {
                        // Check again for null - by the time we get into this async runnable our eventSink
                        // may have been canceled
                        if (eventSink != null) {
                            try {
                                eventSink.success(connectionStateChangeJsonConverter.toJson(connectionState));
                            } catch (JSONException e) {
                                eventSink.error("-1", e.getMessage(), e.getStackTrace());
                            }
                        }
                    }
                }
            });
        }
    }

    public void end() {
        onComplete();
    }

    synchronized public void onComplete() {
        if (eventSink != null) {
            eventSink.endOfStream();
        }
    }
}
