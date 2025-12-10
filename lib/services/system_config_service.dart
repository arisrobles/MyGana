import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class SystemConfigService {
  static final SystemConfigService _instance = SystemConfigService._internal();
  factory SystemConfigService() => _instance;
  SystemConfigService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Cache for system configuration
  Map<String, dynamic>? _configCache;
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get system configuration with caching
  Future<Map<String, dynamic>> getSystemConfig() async {
    try {
      // Check if cache is still valid
      if (_configCache != null &&
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry) {
        return _configCache!;
      }

      // Fetch fresh data
      final snapshot = await _db.child('systemConfig').get();
      if (snapshot.exists) {
        _configCache = Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
        _lastCacheUpdate = DateTime.now();
        return _configCache!;
      }

      // Return default config if no data exists
      return _getDefaultConfig();
    } catch (e) {
      debugPrint('Error fetching system config: $e');
      return _getDefaultConfig();
    }
  }

  /// Get specific configuration value
  Future<T> getConfigValue<T>(String key, T defaultValue) async {
    final config = await getSystemConfig();
    return config[key] as T? ?? defaultValue;
  }

  /// Check if maintenance mode is enabled
  Future<bool> isMaintenanceMode() async {
    return await getConfigValue('maintenanceMode', false);
  }

  /// Check if registration is enabled
  Future<bool> isRegistrationEnabled() async {
    return await getConfigValue('registrationEnabled', true);
  }

  /// Check if guest mode is enabled
  Future<bool> isGuestModeEnabled() async {
    return await getConfigValue('guestModeEnabled', true);
  }

  /// Get system announcement
  Future<String> getSystemAnnouncement() async {
    return await getConfigValue('systemAnnouncement', '');
  }

  /// Get app version
  Future<String> getAppVersion() async {
    return await getConfigValue('appVersion', '1.0.0');
  }

  /// Get max users per class
  Future<int> getMaxUsersPerClass() async {
    return await getConfigValue('maxUsersPerClass', 30);
  }

  /// Get session timeout in minutes
  Future<int> getSessionTimeoutMinutes() async {
    return await getConfigValue('sessionTimeoutMinutes', 30);
  }

  /// Clear cache to force refresh
  void clearCache() {
    _configCache = null;
    _lastCacheUpdate = null;
  }

  /// Listen to system config changes
  Stream<Map<String, dynamic>> watchSystemConfig() {
    return _db.child('systemConfig').onValue.map((event) {
      if (event.snapshot.exists) {
        final config = Map<String, dynamic>.from(event.snapshot.value as Map<dynamic, dynamic>);
        _configCache = config;
        _lastCacheUpdate = DateTime.now();
        return config;
      }
      return _getDefaultConfig();
    });
  }

  /// Default configuration values
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'maintenanceMode': false,
      'registrationEnabled': true,
      'guestModeEnabled': true,
      'appVersion': '1.0.0',
      'systemAnnouncement': '',
      'maxUsersPerClass': 30,
      'sessionTimeoutMinutes': 30,
    };
  }
}
