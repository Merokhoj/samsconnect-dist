import 'device_info.dart';

enum ConnectionMethod { usb, wifi, qr }

enum ConnectionStatus { disconnected, connecting, connected, error }

enum MobilePlatform { android, ios }

class Device {
  final String id;
  final String name;
  final String model;
  final String osVersion;
  final MobilePlatform platform;
  final ConnectionMethod method;
  final bool isWireless;
  final String? ipAddress;
  final DeviceInfo? info;

  const Device({
    required this.id,
    required this.name,
    required this.model,
    required this.osVersion,
    required this.platform,
    required this.method,
    this.isWireless = false,
    this.ipAddress,
    this.info,
  });

  factory Device.fromAdbString(String adbOutput) {
    // Parse ADB output (handles both simple and detailed '-l' output)
    // Example: "192.168.1.5:5555	device"
    // Or: "RF8M926GJRY  device usb:1-2 product:SCV45_jp_kdi model:SCV45 device:SCV45"

    final parts = adbOutput.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      throw ArgumentError('Invalid ADB device string: $adbOutput');
    }

    final deviceId = parts[0].trim();
    final isWifi = deviceId.contains(':');

    String model = 'Unknown';
    String productName = 'Android Device';

    // Parse additional properties if available (from -l flag)
    for (var part in parts) {
      if (part.contains(':')) {
        final subParts = part.split(':');
        if (subParts.length == 2) {
          final key = subParts[0];
          final value = subParts[1];
          if (key == 'model') {
            model = value;
            productName = value; // Use model as default name
          } else if (key == 'product' && productName == 'Android Device') {
            // Only use product if we don't have a model yet
            productName = value;
          }
        }
      }
    }

    return Device(
      id: deviceId,
      name: productName,
      model: model,
      osVersion: 'Unknown',
      platform: MobilePlatform.android,
      method: isWifi ? ConnectionMethod.wifi : ConnectionMethod.usb,
      isWireless: isWifi,
      ipAddress: isWifi ? deviceId.split(':')[0] : null,
    );
  }

  factory Device.fromIosString(String iosOutput) {
    // Example output from ideviceinfo:
    // UniqueDeviceID: 00008101-000A1D2E3C4B5A6F
    // DeviceName: iPhone 13
    // ProductType: iPhone14,5
    // ProductVersion: 17.2

    final lines = iosOutput.split('\n');
    String id = 'Unknown';
    String name = 'iOS Device';
    String model = 'iPhone';
    String version = 'Unknown';

    for (var line in lines) {
      if (line.contains(':')) {
        final firstColonIndex = line.indexOf(':');
        final key = line.substring(0, firstColonIndex).trim();
        final value = line.substring(firstColonIndex + 1).trim();

        if (key == 'UniqueDeviceID') id = value;
        if (key == 'DeviceName') name = value;
        if (key == 'ProductType') model = value;
        if (key == 'ProductVersion') version = value;
      }
    }

    return Device(
      id: id,
      name: name,
      model: model,
      osVersion: version,
      platform: MobilePlatform.ios,
      method: ConnectionMethod.usb, // Default to USB for discovery
    );
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      name: map['name'] as String,
      model: map['model'] as String,
      osVersion: map['osVersion'] as String,
      platform: MobilePlatform.values[map['platform'] as int? ?? 0],
      method: ConnectionMethod.values[map['method'] as int],
      isWireless: map['isWireless'] as bool,
      ipAddress: map['ipAddress'] as String?,
      info: map['info'] != null
          ? DeviceInfo.fromMap(Map<String, dynamic>.from(map['info']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'osVersion': osVersion,
      'platform': platform.index,
      'method': method.index,
      'isWireless': isWireless,
      'ipAddress': ipAddress,
      'info': info?.toMap(),
    };
  }

  Device copyWith({
    String? id,
    String? name,
    String? model,
    String? osVersion,
    MobilePlatform? platform,
    ConnectionMethod? method,
    bool? isWireless,
    String? ipAddress,
    DeviceInfo? info,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      osVersion: osVersion ?? this.osVersion,
      platform: platform ?? this.platform,
      method: method ?? this.method,
      isWireless: isWireless ?? this.isWireless,
      ipAddress: ipAddress ?? this.ipAddress,
      info: info ?? this.info,
    );
  }

  @override
  String toString() {
    return 'Device(id: $id, name: $name, model: $model, method: $method, isWireless: $isWireless)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
