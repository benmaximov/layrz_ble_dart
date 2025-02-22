package com.layrz.layrz_ble

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService

class BleService(var service: BluetoothGattService, var uuid: String, var characteristics: List<BleCharacteristic>) {}

class BleCharacteristic(var characteristic: BluetoothGattCharacteristic, var uuid: String, var properties: List<String>) {}