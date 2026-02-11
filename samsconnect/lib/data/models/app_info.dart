class AppInfo {
  final String name;
  final String packageName;
  final String version;
  final String size; // Human readable size
  final bool isSystemApp;
  final String? iconPath; // Local path to cached icon if available
  final String? apkPath; // Remote path to APK
  final DateTime? installDate;

  const AppInfo({
    required this.name,
    required this.packageName,
    this.version = 'Unknown',
    this.size = 'Unknown',
    required this.isSystemApp,
    this.iconPath,
    this.apkPath,
    this.installDate,
  });

  factory AppInfo.fromAdbString(String line) {
    // Format: package:com.example.app
    // Or with -f: package:/data/app/~~.../base.apk=com.example.app
    final regex = RegExp(r'^package:(?:(.+)=)?(.+)$');
    final match = regex.firstMatch(line.trim());

    if (match != null) {
      final path = match.group(1);
      final pkgName = match.group(2)!;

      // Determine if it's a system app based on path
      // /data/app/... usually means user app
      // /system/..., /product/..., /vendor/... means system app
      bool isSystem = false;
      if (path != null) {
        if (!path.startsWith('/data/')) {
          isSystem = true;
        }
      }

      return AppInfo(
        name: pkgName.split('.').last, // Fallback name
        packageName: pkgName,
        isSystemApp: isSystem,
        apkPath: path,
      );
    }

    // Fallback for lines that might strictly follow 'package:name' without path
    if (line.trim().startsWith('package:')) {
      final simpleName = line.trim().replaceAll('package:', '');
      if (simpleName.isNotEmpty) {
        return AppInfo(
          name: simpleName.split('.').last,
          packageName: simpleName,
          isSystemApp:
              false, // Assume user if uncertain, or handle logic elsewhere
          apkPath: null,
        );
      }
    }

    throw FormatException('Invalid app line: $line');
  }

  AppInfo copyWith({
    String? name,
    String? packageName,
    String? version,
    String? size,
    bool? isSystemApp,
    String? iconPath,
    String? apkPath,
    DateTime? installDate,
  }) {
    return AppInfo(
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      version: version ?? this.version,
      size: size ?? this.size,
      isSystemApp: isSystemApp ?? this.isSystemApp,
      iconPath: iconPath ?? this.iconPath,
      apkPath: apkPath ?? this.apkPath,
      installDate: installDate ?? this.installDate,
    );
  }
}
