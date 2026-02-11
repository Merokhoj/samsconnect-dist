import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:logger/logger.dart';

class UpdateInfo {
  final String version;
  final String buildNumber;
  final String? releaseNotes;
  final String? downloadUrl;
  final DateTime? releaseDate;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    this.releaseNotes,
    this.downloadUrl,
    this.releaseDate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'],
      buildNumber: json['buildNumber'],
      releaseNotes: json['releaseNotes'],
      downloadUrl: json['downloadUrl'],
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'])
          : null,
    );
  }
}

class UpdateService {
  final Logger _logger = Logger();
  static const String _updateUrl =
      'https://raw.githubusercontent.com/merokhoj/samsconnect-dist/main/version.json';

  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(_updateUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final update = UpdateInfo.fromJson(data);

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        final currentBuild = packageInfo.buildNumber;

        _logger.i(
            'Checking for updates... Current: $currentVersion+$currentBuild, Latest: ${update.version}+${update.buildNumber}');

        if (_isNewer(update.version, currentVersion)) {
          return update;
        } else if (update.version == currentVersion) {
          final updBuild = int.tryParse(update.buildNumber) ?? 0;
          final curBuild = int.tryParse(currentBuild) ?? 0;
          if (updBuild > curBuild) {
            return update;
          }
        }
      }
    } catch (e) {
      _logger.w('Failed to check for updates: $e');
    }
    return null;
  }

  bool _isNewer(String newVer, String currentVer) {
    // Clean versions from build numbers if they exist (e.g. 1.1.0+2 -> 1.1.0)
    final cleanNew = newVer.split('+')[0];
    final cleanCur = currentVer.split('+')[0];

    final v1 = cleanNew.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final v2 = cleanCur.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (var i = 0; i < v1.length && i < v2.length; i++) {
      if (v1[i] > v2[i]) return true;
      if (v1[i] < v2[i]) return false;
    }
    return v1.length > v2.length;
  }
}
