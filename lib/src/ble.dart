library;

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ble.freezed.dart';
part 'ble.g.dart';

/// [BleProperty] is the representation of a BLE property of a characteristic.
///
/// All of the declarated properties are based on the BLE specification, not a
/// custom implementation or custom properties based on own needs.
enum BleProperty {
  /// [broadcast] is the broadcast property of a characteristic.
  /// Means the value can be broadcasted.
  ///
  /// BLE specification identifier: `0x01`
  @JsonValue('BROADCAST')
  broadcast,

  /// [read] is the read property of a characteristic.
  /// Means the value can be read.
  ///
  /// BLE specification identifier: `0x02`
  @JsonValue('READ')
  read,

  /// [writeWithoutResponse] is the write without response property of a characteristic.
  /// Means the value can be written without acknowledgement. For example, the UART peripheral example
  /// uses this characteristic properly to receive UART data from the central device.
  ///
  /// BLE specification identifier: `0x04`
  @JsonValue('WRITE_WO_RSP')
  writeWithoutResponse,

  /// [write] is the write property of a characteristic.
  /// Means the value can be written to the peripheral from the central device.
  ///
  /// BLE specification identifier: `0x08`
  @JsonValue('WRITE')
  write,

  /// [notify] is the notify property of a characteristic.
  /// Means the value is published by the peripheral without acknowledgement.
  /// This is the standard way peripherals periodically publish data.
  ///
  /// BLE specification identifier: `0x10`
  @JsonValue('NOTIFY')
  notify,

  /// [indicate] is the indicate property of a characteristic.
  /// Means the value can be indicated, basically publish with acknowledgement.
  ///
  /// BLE specification identifier: `0x20`
  @JsonValue('INDICATE')
  indicate,

  /// [authenticatedSignedWrites] is the authenticated signed writes property of a characteristic.
  /// Means the value supports signed writes. This is operation not supported.
  ///
  /// BLE specification identifier: `0x40`
  @JsonValue('AUTH_SIGN_WRITES')
  authenticatedSignedWrites,

  /// [extendedProperties] is the extended properties property of a characteristic.
  /// Means the value supports extended properties. This operation is not supported.
  ///
  /// BLE specification identifier: `0x80`
  @JsonValue('EXTENDED_PROP')
  extendedProperties,

  /// [unknown] is the unknown property of a characteristic.
  /// This used when the property is not recognized or not registered as a BLE property in the BLE specification.
  @JsonValue('UNKNOWN')
  unknown;

  @override
  String toString() => toJson();

  /// [toJson] returns the string representation of the enum value.
  String toJson() => _$BlePropertyEnumMap[this] ?? 'UNKNOWN';

  /// [fromJson] returns the enum value from a string representation.
  static BleProperty fromJson(String json) {
    final found = _$BlePropertyEnumMap.entries.firstWhereOrNull(
      (e) => e.value == json,
    );
    return found?.key ?? BleProperty.unknown;
  }
}

@freezed
abstract class BleCharacteristic with _$BleCharacteristic {
  const BleCharacteristic._();

  /// [BleCharacteristic] is the representation of a BLE characteristic.
  const factory BleCharacteristic({
    /// [uuid] is the UUID of the BLE characteristic.
    required String uuid,

    /// [properties] is the list of properties of the BLE characteristic.
    //@JsonKey(unknownEnumValue: BleProperty.unknown)
    @Default([]) List<BleProperty> properties,
  }) = _BleCharacteristic;

  factory BleCharacteristic.fromJson(Map<String, dynamic> json) =>
      _$BleCharacteristicFromJson(json);
}

@freezed
abstract class BleService with _$BleService {
  const BleService._();

  /// [BleService] is the representation of a BLE service.
  const factory BleService({
    /// [uuid] is the UUID of the BLE service.
    required String uuid,

    /// [characteristics] is the list of characteristics of the BLE service.
    List<BleCharacteristic>? characteristics,
  }) = _BleService;

  factory BleService.fromJson(Map<String, dynamic> json) =>
      _$BleServiceFromJson(json);
}

@freezed
abstract class BleServiceData with _$BleServiceData {
  const BleServiceData._();

  /// [BleServiceData] is the representation of a BLE service.
  const factory BleServiceData({
    /// [uuid] is the UUID of the BLE service.
    required int uuid,

    /// [characteristics] is the list of characteristics of the BLE service.
    List<int>? data,
  }) = _BleServiceData;

  factory BleServiceData.fromJson(Map<String, dynamic> json) =>
      _$BleServiceDataFromJson(json);
}

@freezed
abstract class BleManufacturerData with _$BleManufacturerData {
  const BleManufacturerData._();

  /// [BleManufacturerData] is the representation of the manufacturer data of a BLE device.
  const factory BleManufacturerData({
    /// [companyId] is the company identifier of the manufacturer.
    @Default(0x0000) int companyId,

    /// [data] is the raw data of the manufacturer.
    List<int>? data,
  }) = _BleManufacturerData;

  factory BleManufacturerData.fromJson(Map<String, dynamic> json) =>
      _$BleManufacturerDataFromJson(json);
}

@freezed
abstract class BleDevice with _$BleDevice {
  const BleDevice._();

  /// [BleDevice] is the representation of a BLE device.
  const factory BleDevice({
    /// [macAddress] is the MAC address of the BLE device.
    /// Be careful, on Apple ecosystem, the MAC address is not the real identifier, is a generated by the platform
    /// and is hidden from the developer.
    required String macAddress,

    /// [name] is the name of the BLE device.
    /// Can be null if the device does not have a name or is not broadcasted.
    String? name,

    /// [rssi] is the signal strength of the BLE device.
    /// Can be null if the device does not have a signal strength due to a platform limitation.
    int? rssi,

    /// [txPower] is the transmission power of the BLE device.
    /// Can be null if the device does not have a transmission power due to a platform limitation.
    int? txPower,

    bool? isBonded,

    /// [manufacturerData] is the manufacturer data of the BLE device.
    @Default([]) List<BleManufacturerData> manufacturerData,

    /// [serviceData] is the service data of the BLE device.
    @Default([]) List<BleServiceData> serviceData,
  }) = _BleDevice;

  factory BleDevice.fromJson(Map<String, dynamic> json) =>
      _$BleDeviceFromJson(json);

  Map<int, List<int>> get serviceDataMap {
    final map = Map<int, List<int>>.from({});
    for (final serviceData in serviceData) {
      map[serviceData.uuid] = serviceData.data ?? <int>[];
    }

    return map;
  }

  Map<int, List<int>> get manufacturerDataMap {
    final map = Map<int, List<int>>.from({});
    for (final manufacturerData in manufacturerData) {
      map[manufacturerData.companyId] = manufacturerData.data ?? <int>[];
    }

    return map;
  }
}
