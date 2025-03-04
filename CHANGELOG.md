# Changelog

## 1.2.3

- Segmented MethodChannel's in different channels to prevent overloading.
- Fixed an issue on Android where the device would not disconnect properly. Now, when a disconnection is detected, the gatt will be closed.
- Unified iOS and macOS to use the same codebase (darwin).

## 1.2.2

- Added try/catch around the read and write characteristic functions to prevent crashes when the device is disconnected

## 1.2.1

- Added txPower to the data that can be received from the device

## 1.2.0

- Updated all platforms to support multiple manufacturer data

## 1.1.3

- Removed parser things from this library

## 1.1.2

- Added `BleCondition`, `BleConversion`, `BleParser`, `BleParserConfig`, `BleParserProperty`, `BleServiceData`, `BleOperation`, `BleParserSource` and `BleWatch` to the export.

## 1.1.1

- Added Advertisement data parsers to the main class.

## 1.1.0

- Changed service data schema

## 1.0.1

- Added auto-discovery of the servcices and characteristics of the device

## 1.0.0

- Initial release
