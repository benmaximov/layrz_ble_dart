import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:layrz_ble/src/types.dart';
import 'package:layrz_models/layrz_models.dart';

import 'platform_interface.dart';

/// An implementation of [LayrzBlePlatform] that uses method channels.
class LayrzBleNative extends LayrzBlePlatform {
  void log(String message) {
    debugPrint('LayrzBlePlugin/Dart: $message');
  }

  LayrzBleNative() {
    eventsChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onScan':
          try {
            final args = Map<String, dynamic>.from(call.arguments);
            if (args['serviceData'] == null) {
              args['serviceData'] = [];
            }

            final serviceData = args['serviceData'].map((e) {
              return Map<String, dynamic>.from(e);
            }).toList();

            args['serviceData'] = serviceData;

            if (args['manufacturerData'] == null) {
              args['manufacturerData'] = [];
            }

            final manufacturerData = args['manufacturerData'].map((e) {
              return Map<String, dynamic>.from(e);
            }).toList();

            args['manufacturerData'] = manufacturerData;

            final device = BleDevice.fromJson(args);
            _scanController.add(device);
          } catch (e) {
            log('Error parsing BleDevice: $e - ${call.arguments}');
          }
          break;

        case 'onEvent':
          try {
            final event = BleEvent.fromPlatform(call.arguments);
            _eventController.add(event);
          } catch (e) {
            log('Error parsing BleEvent: $e');
          }
          break;

        case 'onNotify':
          try {
            final notification = BleCharacteristicNotification.fromMap(Map<String, dynamic>.from(call.arguments));
            _notifyController.add(notification);
          } catch (e) {
            log('Error parsing BleCharacteristicNotification: $e');
          }
          break;

        default:
          log('Unknown method: ${call.method}');
          break;
      }
    });
  }

  final checkCapabilitiesChannel = const MethodChannel('com.layrz.ble.checkCapabilities');
  final startScanChannel = const MethodChannel('com.layrz.ble.startScan');
  final stopScanChannel = const MethodChannel('com.layrz.ble.stopScan');
  final connectChannel = const MethodChannel('com.layrz.ble.connect');
  final disconnectChannel = const MethodChannel('com.layrz.ble.disconnect');
  final discoverServicesChannel = const MethodChannel('com.layrz.ble.discoverServices');
  final setMtuChannel = const MethodChannel('com.layrz.ble.setMtu');
  final writeCharacteristicChannel = const MethodChannel('com.layrz.ble.writeCharacteristic');
  final readCharacteristicChannel = const MethodChannel('com.layrz.ble.readCharacteristic');
  final startNotifyChannel = const MethodChannel('com.layrz.ble.startNotify');
  final stopNotifyChannel = const MethodChannel('com.layrz.ble.stopNotify');
  final eventsChannel = const MethodChannel('com.layrz.ble.events');

  final StreamController<BleDevice> _scanController = StreamController<BleDevice>.broadcast();
  final StreamController<BleEvent> _eventController = StreamController<BleEvent>.broadcast();
  final StreamController<BleCharacteristicNotification> _notifyController =
      StreamController<BleCharacteristicNotification>.broadcast();

  @override
  Stream<BleDevice> get onScan => _scanController.stream;

  @override
  Stream<BleEvent> get onEvent => _eventController.stream;

  @override
  Stream<BleCharacteristicNotification> get onNotify => _notifyController.stream;

  @override
  Future<bool?> startScan({String? macAddress, List<String>? servicesUuids}) => startScanChannel.invokeMethod<bool>(
        'startScan',
        {if (macAddress != null) 'macAddress': macAddress},
      );

  @override
  Future<bool?> stopScan() => stopScanChannel.invokeMethod<bool>('stopScan');

  @override
  Future<BleCapabilities> checkCapabilities() async {
    debugPrint("Calling");
    final result = await checkCapabilitiesChannel.invokeMethod<Map>('checkCapabilities');
    if (result == null) {
      log('Error checking BleCapabilities from native side');
      return BleCapabilities(
        locationPermission: false,
        bluetoothPermission: false,
        bluetoothAdminOrScanPermission: false,
        bluetoothConnectPermission: false,
      );
    }

    try {
      return BleCapabilities.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      log('Error parsing BleCapabilities: $e');
      return BleCapabilities(
        locationPermission: false,
        bluetoothPermission: false,
        bluetoothAdminOrScanPermission: false,
        bluetoothConnectPermission: false,
      );
    }
  }

  @override
  Future<int?> setMtu({required int newMtu}) => setMtuChannel.invokeMethod<int>('setMtu', newMtu);

  @override
  Future<bool?> connect({required String macAddress}) => connectChannel.invokeMethod<bool>('connect', macAddress);

  @override
  Future<bool?> disconnect() => disconnectChannel.invokeMethod<bool>('disconnect');

  @override
  Future<List<BleService>?> discoverServices({
    /// [timeout] is the duration to wait for the services to be discovered.
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await discoverServicesChannel.invokeMethod<List>('discoverServices', {
      'timeout': timeout.inSeconds,
    });
    if (result == null) {
      log('Error discovering services from native side');
      return null;
    }

    List<BleService> services = [];

    for (var service in result) {
      try {
        List<BleCharacteristic> characteristics = [];

        for (var characteristic in service['characteristics']) {
          try {
            characteristics.add(BleCharacteristic.fromJson(Map<String, dynamic>.from(characteristic)));
          } catch (e) {
            log('Error parsing BleCharacteristic: $e');
          }
        }

        services.add(BleService(
          uuid: service['uuid'],
          characteristics: characteristics,
        ));
      } catch (e) {
        log('Error parsing BleService: $e');
      }
    }
    return services;
  }

  @override
  Future<bool> writeCharacteristic({
    required String serviceUuid,
    required String characteristicUuid,
    required Uint8List payload,
    Duration timeout = const Duration(seconds: 30),
    required bool withResponse,
  }) async {
    final result = await writeCharacteristicChannel.invokeMethod<bool>('writeCharacteristic', <String, dynamic>{
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'payload': payload,
      'timeout': timeout.inSeconds,
      'withResponse': withResponse,
    });

    if (result == null) {
      log('Error sending payload from native side');
      return false;
    }

    debugPrint("---------------------> result: $result - $payload");

    return result;
  }

  @override
  Future<Uint8List?> readCharacteristic({
    required String serviceUuid,
    required String characteristicUuid,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await readCharacteristicChannel.invokeMethod<Uint8List>('readCharacteristic', <String, dynamic>{
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'timeout': timeout.inSeconds,
    });

    if (result == null) {
      log('Error reading characteristic from native side');
      return null;
    }

    return result;
  }

  @override
  Future<bool?> startNotify({
    required String serviceUuid,
    required String characteristicUuid,
  }) {
    return startNotifyChannel.invokeMethod<bool>('startNotify', <String, String>{
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
    });
  }

  @override
  Future<bool?> stopNotify({
    required String serviceUuid,
    required String characteristicUuid,
  }) {
    return stopNotifyChannel.invokeMethod<bool>('stopNotify', <String, String>{
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
    });
  }
}
