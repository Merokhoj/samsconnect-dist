class DeviceInfo {
  final String manufacturer;
  final String model;
  final String brand;
  final String osVersion;
  final String sdkVersion;
  final String serialNumber;
  final int batteryLevel;
  final bool isCharging;
  final String totalStorage;
  final String availableStorage;
  final String displayResolution;
  final String deviceName;
  final String cpuInfo;
  final String ramInfo;

  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.brand,
    required this.osVersion,
    required this.sdkVersion,
    required this.serialNumber,
    this.batteryLevel = 0,
    this.isCharging = false,
    this.totalStorage = 'Unknown',
    this.availableStorage = 'Unknown',
    this.displayResolution = 'Unknown',
    this.deviceName = 'Android Device',
    this.cpuInfo = 'Unknown',
    this.ramInfo = 'Unknown',
  });

  factory DeviceInfo.fromProperties(Map<String, String> props) {
    return DeviceInfo(
      manufacturer: props['ro.product.manufacturer'] ?? 'Unknown',
      model: props['ro.product.model'] ?? 'Unknown',
      brand: props['ro.product.brand'] ?? 'Unknown',
      osVersion: props['ro.build.version.release'] ?? 'Unknown',
      sdkVersion: props['ro.build.version.sdk'] ?? 'Unknown',
      serialNumber: props['ro.serialno'] ?? 'Unknown',
      deviceName: props['ro.product.device'] ?? 'Android Device',
      cpuInfo: props['cpuInfo'] ?? 'Unknown',
      ramInfo: props['ramInfo'] ?? 'Unknown',
    );
  }

  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      manufacturer: map['manufacturer'] ?? 'Unknown',
      model: map['model'] ?? 'Unknown',
      brand: map['brand'] ?? 'Unknown',
      osVersion: map['osVersion'] ?? map['androidVersion'] ?? 'Unknown',
      sdkVersion: map['sdkVersion'] ?? 'Unknown',
      serialNumber: map['serialNumber'] ?? 'Unknown',
      batteryLevel: map['batteryLevel'] ?? 0,
      isCharging: map['isCharging'] ?? false,
      totalStorage: map['totalStorage'] ?? 'Unknown',
      availableStorage: map['availableStorage'] ?? 'Unknown',
      displayResolution: map['displayResolution'] ?? 'Unknown',
      deviceName: map['deviceName'] ?? 'Unknown',
      cpuInfo: map['cpuInfo'] ?? 'Unknown',
      ramInfo: map['ramInfo'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'manufacturer': manufacturer,
      'model': model,
      'brand': brand,
      'osVersion': osVersion,
      'sdkVersion': sdkVersion,
      'serialNumber': serialNumber,
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'totalStorage': totalStorage,
      'availableStorage': availableStorage,
      'displayResolution': displayResolution,
      'deviceName': deviceName,
      'cpuInfo': cpuInfo,
      'ramInfo': ramInfo,
    };
  }

  DeviceInfo copyWith({
    String? manufacturer,
    String? model,
    String? brand,
    String? osVersion,
    String? sdkVersion,
    String? serialNumber,
    int? batteryLevel,
    bool? isCharging,
    String? totalStorage,
    String? availableStorage,
    String? displayResolution,
    String? deviceName,
    String? cpuInfo,
    String? ramInfo,
  }) {
    return DeviceInfo(
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      osVersion: osVersion ?? this.osVersion,
      sdkVersion: sdkVersion ?? this.sdkVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      totalStorage: totalStorage ?? this.totalStorage,
      availableStorage: availableStorage ?? this.availableStorage,
      displayResolution: displayResolution ?? this.displayResolution,
      deviceName: deviceName ?? this.deviceName,
      cpuInfo: cpuInfo ?? this.cpuInfo,
      ramInfo: ramInfo ?? this.ramInfo,
    );
  }

  String get displayName {
    if (brand != 'Unknown' && model != 'Unknown') {
      return '$brand $model';
    }
    return deviceName;
  }

  @override
  String toString() {
    return 'DeviceInfo(brand: $brand, model: $model, os: $osVersion)';
  }
}
