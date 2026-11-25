import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:layrz_ble/layrz_ble.dart';

class LayrzBlePluginLinux extends LayrzBlePlatform {
  LayrzBlePluginLinux() {
    try {
      _client = BlueZClient();
      _client!.connect().then((_) {
        _client!.deviceAdded.listen(_onScanAdded);
        _client!.deviceRemoved.listen(_onDeviceRemoved);
      });
    } catch (e) {
      log("Error initializing BlueZClient: $e");
    }
  }

  static void registerWith() {
    LayrzBlePlatform.instance = LayrzBlePluginLinux();
  }

  bool _isScanning = false;
  final Map<String, BlueZDevice> _devices = {};
  String? _macAddressFilter;
  BlueZClient? _client;
  BlueZDevice? _connectedDevice;

  final Map<BlueZUUID, StreamSubscription<List<String>>> _notifications = {};
  final List<BleService> _services = [];

  final StreamController<BleDevice> _scanController =
      StreamController<BleDevice>.broadcast();
  final StreamController<BleEvent> _eventController =
      StreamController<BleEvent>.broadcast();
  final StreamController<BleCharacteristicNotification> _notifyController =
      StreamController<BleCharacteristicNotification>.broadcast();

  @override
  Stream<BleDevice> get onScan => _scanController.stream;

  @override
  Stream<BleEvent> get onEvent => _eventController.stream;

  @override
  Stream<BleCharacteristicNotification> get onNotify =>
      _notifyController.stream;

  @override
  Future<BleCapabilities> checkCapabilities() async {
    bool can = false;
    try {
      can = _client?.adapters.isNotEmpty ?? false;
    } catch (e) {
      log("Error initializing BlueZClient: $e");
      can = false;
    }

    return BleCapabilities(
      bluetoothAdminOrScanPermission: can,
      locationPermission: can,
      bluetoothPermission: can,
      bluetoothConnectPermission: can,
    );
  }

  @override
  Future<bool?> startScan({
    String? macAddress,
    List<String>? servicesUuids,
    int? scanMode, // Android only
    List<int>? serviceDataUuids, // Android only
    List<int>? manufacturerIds, // Android only
  }) async {
    if (_client == null) {
      log("Error initializing BlueZClient");
      return false;
    }

    _isScanning = true;
    _macAddressFilter = macAddress;

    try {
      final adapter = _client!.adapters.firstOrNull;

      var toRem = [];
      for (final device in _client!.devices) {
        //if (!device.paired) toRem.add(device);
        _onScanAdded(device);
      }
      for (var device in toRem) {
        adapter?.removeDevice(device);
      }

      await adapter?.setDiscoveryFilter(duplicateData: true, transport: "le");
      await adapter?.startDiscovery();

      return true;
    } catch (e) {
      log("Error initializing BlueZClient: $e");
      return false;
    }
  }

  @override
  Future<bool?> stopScan() async {
    if (!_isScanning) return true;

    _eventController.add(BleEvent.scanStopped);
    try {
      final adapter = _client?.adapters.firstOrNull;
      await adapter?.stopDiscovery();
      _isScanning = false;

      for (var itm in _subscriptions.values) {
        itm.cancel();
      }
      _subscriptions.clear();

      return true;
    } catch (e) {
      log("Error initializing BlueZClient: $e");
      return false;
    }
  }

  @override
  Future<int?> setMtu({required int newMtu}) async {
    if (_connectedDevice == null) {
      log("Not connected to any device");
      return null;
    }

    // The MTU is per connection; any characteristic reports it. The first
    // service may have none, so look through all of them.
    final characteristic =
        _connectedDevice!.gattServices
            .expand((s) => s.characteristics)
            .firstOrNull;
    if (characteristic == null) {
      log("Characteristic not found");
      return null;
    }

    return characteristic.mtu;
  }

  @override
  Future<bool?> connect({required String macAddress}) async {
    if (_client == null) {
      log("Error initializing BlueZClient");
      return false;
    }

    //stopScan();

    if (_devices[macAddress.toLowerCase()] == null) {
      log("Device not found: $macAddress");
      return false;
    }

    final device = _devices[macAddress.toLowerCase()]!;
    await device.connect();

    // BlueZ can report the connection before GATT discovery has finished.
    // Until then the services and the MTU are missing or incomplete.
    if (!await _waitServicesResolved(device)) {
      log("Services not resolved: $macAddress");
      try {
        await device.disconnect();
      } catch (e) {
        log("Error disconnecting: $e");
      }
      return false;
    }

    _connectedDevice = device;
    _services.clear();

    // Watch for the link dropping on the remote side (out of range, device
    // reboot, ...). BlueZ reports it as the Connected property going false.
    await _linkSub?.cancel();
    _linkSub = device.propertiesChanged.listen((props) {
      if (props.contains('Connected') &&
          !device.connected &&
          identical(_connectedDevice, device)) {
        log("Link lost: ${device.address}");
        _onDisconnected();
      }
    });

    _eventController.add(BleEvent.connected);

    for (final service in _connectedDevice!.gattServices) {
      for (final characteristic in service.characteristics) {
        _services.add(
          BleService(
            uuid: service.uuid.toString(),
            characteristics: [
              BleCharacteristic(
                uuid: characteristic.uuid.toString(),
                properties: [
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.read,
                  ))
                    BleProperty.read,
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.write,
                  ))
                    BleProperty.write,
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.notify,
                  ))
                    BleProperty.notify,
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.broadcast,
                  ))
                    BleProperty.broadcast,
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.writeWithoutResponse,
                  ))
                    BleProperty.writeWithoutResponse,
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.indicate,
                  ))
                    BleProperty.indicate,
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.authenticatedSignedWrites,
                  ))
                    BleProperty.authenticatedSignedWrites,
                  if (characteristic.flags.contains(
                    BlueZGattCharacteristicFlag.extendedProperties,
                  ))
                    BleProperty.extendedProperties,
                ],
              ),
            ],
          ),
        );
      }
    }
    return true;
  }

  /// Waits until BlueZ has discovered the GATT database of [device]. False if
  /// the link drops or [timeout] expires first.
  Future<bool> _waitServicesResolved(
    BlueZDevice device, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sw = Stopwatch()..start();
    while (!device.servicesResolved) {
      if (!device.connected || sw.elapsed >= timeout) return false;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  @override
  Future<bool?> pair({required String macAddress}) async {
    if (_client == null) {
      log("Error initializing BlueZClient");
      return false;
    }

    //stopScan();

    if (_devices[macAddress.toLowerCase()] == null) {
      log("Device not found: $macAddress");
      return false;
    }

    final device = _devices[macAddress.toLowerCase()]!;
    try {
      await _ensureAgent();
      if (!device.paired) {
        // A device left trusted without a bond (lost or removed keys) cannot
        // be paired again until the trust is cleared.
        if (device.trusted) await device.setTrusted(false);
        try {
          await device.pair();
        } on BlueZAlreadyExistsException {
          // Already paired (e.g. by another app): not an error.
        }
      }
      await device.setTrusted(true);
    } catch (e) {
      log("Error pairing $macAddress: $e");
      return false;
    }

    _eventController.add(BleEvent.paired);

    return true;
  }

  bool _agentRegistered = false;

  /// Registers a BlueZ pairing agent so passkey/PIN requests are routed to
  /// [passkeyRequest]. Without an agent BlueZ fails with AuthenticationFailed.
  Future<void> _ensureAgent() async {
    if (_agentRegistered) return;
    await _client!.registerAgent(
      _PairingAgent(this),
      capability: BlueZAgentCapability.keyboardDisplay,
    );
    _agentRegistered = true;
  }

  BlueZDevice? _findDevice(String macAddress) {
    final mac = macAddress.toLowerCase();
    return _devices[mac] ??
        _client?.devices.firstWhereOrNull(
          (d) => d.address.toLowerCase() == mac,
        );
  }

  @override
  Future<bool?> unpair({required String macAddress}) async {
    if (_client == null) {
      log("Error initializing BlueZClient");
      return false;
    }

    final device = _findDevice(macAddress);
    if (device == null) {
      log("Device not found: $macAddress");
      return false;
    }

    final adapter = _client!.adapters.firstOrNull;
    if (adapter == null) return false;

    try {
      // Drop the trust first, so it cannot outlive the bond if the removal
      // fails.
      if (device.trusted) await device.setTrusted(false);
      // Removing the device from BlueZ deletes its bonding keys.
      await adapter.removeDevice(device);
      _devices.remove(macAddress.toLowerCase());
      return true;
    } catch (e) {
      log("Error unpairing $macAddress: $e");
      return false;
    }
  }

  @override
  Future<bool?> isBonded({required String macAddress}) async {
    if (_client == null) return false;
    return _findDevice(macAddress)?.paired ?? false;
  }

  @override
  Future<bool> disconnect() async {
    final device = _connectedDevice;
    _onDisconnected();
    try {
      await device?.disconnect();
    } catch (e) {
      log("Error disconnecting: $e");
    }
    return true;
  }

  StreamSubscription<List<String>>? _linkSub;

  /// Clears per-connection state and notifies listeners exactly once (only
  /// if a device was connected).
  void _onDisconnected() {
    final wasConnected = _connectedDevice != null;
    _linkSub?.cancel();
    _linkSub = null;
    for (final sub in _notifications.values) {
      sub.cancel();
    }
    _notifications.clear();
    _connectedDevice = null;
    _services.clear();
    if (wasConnected) _eventController.add(BleEvent.disconnected);
  }

  @override
  Future<List<BleService>?> discoverServices({
    Duration timeout = const Duration(seconds: 30),
    List<String>? serviceUuids,
  }) async {
    if (_connectedDevice == null) {
      log("Not connected to any device");
      return null;
    }

    return _services;
  }

  @override
  Future<int> writeCharacteristic({
    required String serviceUuid,
    required String characteristicUuid,
    required Uint8List payload,
    Duration timeout = const Duration(seconds: 30),
    required bool withResponse,
  }) async {
    if (_connectedDevice == null) {
      log("Not connected to any device");
      return -1;
    }

    final service = _connectedDevice!.gattServices.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() == serviceUuid.toLowerCase();
    });
    if (service == null) {
      log("Service not found: $serviceUuid");
      return -1;
    }

    final characteristic = service.characteristics.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() ==
          characteristicUuid.toLowerCase();
    });

    if (characteristic == null) {
      log("Characteristic not found: $characteristicUuid");
      return -1;
    }

    await characteristic.writeValue(payload);
    return 0;
  }

  @override
  Future<Uint8List?> readCharacteristic({
    required String serviceUuid,
    required String characteristicUuid,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_connectedDevice == null) {
      log("Not connected to any device");
      return null;
    }

    final service = _connectedDevice!.gattServices.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() == serviceUuid.toLowerCase();
    });
    if (service == null) {
      log("Service not found: $serviceUuid");
      return null;
    }

    final characteristic = service.characteristics.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() ==
          characteristicUuid.toLowerCase();
    });

    if (characteristic == null) {
      log("Characteristic not found: $characteristicUuid");
      return null;
    }

    if (characteristic.notifying) {
      log("Characteristic is notifying: $characteristicUuid");
      return null;
    }

    final value = await characteristic.readValue();
    return Uint8List.fromList(value);
  }

  @override
  Future<bool?> startNotify({
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    if (_connectedDevice == null) {
      log("Not connected to any device");
      return false;
    }

    final service = _connectedDevice!.gattServices.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() == serviceUuid.toLowerCase();
    });
    if (service == null) {
      log("Service not found: $serviceUuid");
      return false;
    }

    final characteristic = service.characteristics.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() ==
          characteristicUuid.toLowerCase();
    });

    if (characteristic == null) {
      log("Characteristic not found: $characteristicUuid");
      return false;
    }

    if (characteristic.notifying) {
      log("Characteristic already notifying: $characteristicUuid");
      return false;
    }

    _notifications[characteristic.uuid] = characteristic.propertiesChanged
        .listen((events) {
          for (final event in events) {
            if (event == 'Value') {
              final receivedValue = characteristic.value;
              _notifyController.add(
                BleCharacteristicNotification(
                  serviceUuid: serviceUuid,
                  characteristicUuid: characteristicUuid,
                  value: Uint8List.fromList(receivedValue),
                ),
              );
            }
          }
        });
    await characteristic.startNotify();
    return true;
  }

  @override
  Future<bool?> stopNotify({
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    if (_connectedDevice == null) {
      log("Not connected to any device");
      return false;
    }

    final service = _connectedDevice!.gattServices.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() == serviceUuid.toLowerCase();
    });
    if (service == null) {
      log("Service not found: $serviceUuid");
      return false;
    }

    final characteristic = service.characteristics.firstWhereOrNull((element) {
      return element.uuid.toString().toLowerCase() ==
          characteristicUuid.toLowerCase();
    });

    if (characteristic == null) {
      log("Characteristic not found: $characteristicUuid");
      return false;
    }

    if (_notifications.containsKey(characteristic.uuid)) {
      _notifications[characteristic.uuid]?.cancel();
      _notifications.remove(characteristic.uuid);
    }

    if (!characteristic.notifying) {
      log("Characteristic not notifying: $characteristicUuid");
      return false;
    }

    await characteristic.stopNotify();
    return true;
  }

  void log(String message) {
    debugPrint("LayrzBlePlugin/Linux: $message");
  }

  final Map<String, StreamSubscription> _subscriptions = {};

  void _onScanAdded(BlueZDevice device) {
    if (!_isScanning) return;
    if (_macAddressFilter != null &&
        _macAddressFilter!.toLowerCase() != device.address.toLowerCase()) {
      return;
    }

    _scanController.add(_compose(device));

    if (device.address.startsWith("28")) {
      //print(device.address);
      //print(device.manufacturerData);
    }

    if (!_subscriptions.containsKey(device.address.toLowerCase())) {
      _subscriptions[device.address.toLowerCase()] = device.propertiesChanged
          .listen((List<String> lst) {
            _scanController.add(_compose(device));

            if (device.address.startsWith("28")) {
              //print("PC ${device.address} $lst");
              //print(device.manufacturerData);
            }
          });
    }
  }

  /// BlueZ dropped [device] (unpair, or it timed out of the cache). Cancel
  /// its property listener: when it is seen again BlueZ creates a new
  /// object, which [_onScanAdded] must subscribe to.
  void _onDeviceRemoved(BlueZDevice device) {
    final mac = device.address.toLowerCase();
    _subscriptions.remove(mac)?.cancel();
    _devices.remove(mac);
  }

  BleDevice _compose(BlueZDevice device) {
    List<BleManufacturerData> manufacturerData = [];
    for (final entry in device.manufacturerData.entries) {
      final companyId = entry.key;
      final data = entry.value;

      if (data.isEmpty) continue;

      manufacturerData.add(
        BleManufacturerData(
          companyId: companyId.id,
          data: Uint8List.fromList(data),
        ),
      );
    }

    List<BleServiceData> serviceData = [];

    for (final entry in device.serviceData.entries) {
      final bytes = entry.key.value;
      final serviceUuid = _standarizeServiceUuid([bytes[2], bytes[3]]);
      final data = entry.value;
      if (data.isEmpty) continue;

      serviceData.add(
        BleServiceData(uuid: serviceUuid, data: Uint8List.fromList(data)),
      );
    }

    _devices[device.address.toLowerCase()] = device;

    return BleDevice(
      macAddress: device.address.toUpperCase(),
      name: device.name.isEmpty ? 'Unknown' : device.name,
      rssi: device.rssi,
      txPower: device.txPower,
      isBonded: device.paired,
      manufacturerData: manufacturerData,
      serviceData: serviceData,
    );
  }

  int _standarizeServiceUuid(List<int> bytes) {
    return (bytes[0] << 8) | bytes[1];
  }
}

class _PairingAgent extends BlueZAgent {
  _PairingAgent(this._plugin);

  final LayrzBlePluginLinux _plugin;

  Future<String?> _ask(BlueZDevice device) async {
    final cb = _plugin.passkeyRequest;
    if (cb == null) return null;
    return cb(device.address.toUpperCase());
  }

  @override
  Future<BlueZAgentPasskeyResponse> requestPasskey(BlueZDevice device) async {
    final code = int.tryParse((await _ask(device))?.trim() ?? '');
    if (code == null || code < 0 || code > 999999) {
      return BlueZAgentPasskeyResponse.canceled();
    }
    return BlueZAgentPasskeyResponse.success(code);
  }

  @override
  Future<BlueZAgentPinCodeResponse> requestPinCode(BlueZDevice device) async {
    final pin = (await _ask(device))?.trim();
    if (pin == null || pin.isEmpty) return BlueZAgentPinCodeResponse.canceled();
    return BlueZAgentPinCodeResponse.success(pin);
  }

  // Pairing is always initiated by the user from the app, so accept
  // "just works" / numeric-comparison confirmations.
  @override
  Future<BlueZAgentResponse> requestConfirmation(
    BlueZDevice device,
    int passkey,
  ) async {
    _plugin.log(
      "Pairing ${device.address}: confirming passkey "
      "${passkey.toString().padLeft(6, '0')}",
    );
    return BlueZAgentResponse.success();
  }

  @override
  Future<BlueZAgentResponse> requestAuthorization(BlueZDevice device) async =>
      BlueZAgentResponse.success();

  @override
  Future<BlueZAgentResponse> authorizeService(
    BlueZDevice device,
    BlueZUUID uuid,
  ) async => BlueZAgentResponse.success();

  @override
  Future<void> displayPasskey(
    BlueZDevice device,
    int passkey,
    int entered,
  ) async {
    _plugin.log(
      "Pairing ${device.address}: enter passkey "
      "${passkey.toString().padLeft(6, '0')} on the device",
    );
  }
}
