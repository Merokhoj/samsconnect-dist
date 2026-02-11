import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import '../../data/models/device.dart';

class ConnectionHistoryService {
  final Logger _logger = Logger();
  static const String _fileName = 'connection_history.json';

  Future<String> get _filePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  /// Save a device to connection history
  Future<void> saveDevice(Device device) async {
    try {
      final devices = await getAllDevices();

      // Remove existing entry with same ID
      devices.removeWhere((d) => d.id == device.id);

      // Add to front
      devices.insert(0, device);

      // Keep only last 10 devices
      if (devices.length > 10) {
        devices.removeRange(10, devices.length);
      }

      await _writeDevices(devices);
      _logger.i('Saved device to history: ${device.id}');
    } catch (e) {
      _logger.e('Failed to save device', error: e);
    }
  }

  /// Get all saved devices
  Future<List<Device>> getAllDevices() async {
    try {
      final path = await _filePath;
      final file = File(path);

      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) return [];

      try {
        final List<dynamic> jsonList = json.decode(contents);
        return jsonList
            .map((json) => Device.fromMap(Map<String, dynamic>.from(json)))
            .toList();
      } catch (e) {
        _logger.w('Corrupt history file, resetting.', error: e);
        await file.delete(); // Reset corrupt file
        return [];
      }
    } catch (e) {
      _logger.e('Failed to read devices', error: e);
      return [];
    }
  }

  /// Get last connected device
  Future<Device?> getLastConnectedDevice() async {
    final devices = await getAllDevices();
    return devices.isNotEmpty ? devices.first : null;
  }

  /// Remove a device from history
  Future<void> removeDevice(String deviceId) async {
    try {
      final devices = await getAllDevices();
      devices.removeWhere((d) => d.id == deviceId);
      await _writeDevices(devices);
      _logger.i('Removed device from history: $deviceId');
    } catch (e) {
      _logger.e('Failed to remove device', error: e);
    }
  }

  /// Clear all connection history
  Future<void> clearHistory() async {
    try {
      await _writeDevices([]);
      _logger.i('Cleared connection history');
    } catch (e) {
      _logger.e('Failed to clear history', error: e);
    }
  }

  /// Check if a device exists in history
  Future<bool> hasDevice(String deviceId) async {
    final devices = await getAllDevices();
    return devices.any((d) => d.id == deviceId);
  }

  Future<void> _writeDevices(List<Device> devices) async {
    final path = await _filePath;
    final file = File(path);

    final jsonList = devices.map((d) => d.toMap()).toList();
    await file.writeAsString(json.encode(jsonList));
  }
}
