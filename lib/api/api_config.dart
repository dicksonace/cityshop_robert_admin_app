import 'dart:io' show Platform;

/// CityShop Admin API endpoints.
/// Live site: https://cityunlock.net
class ApiConfig {
  static const productionBaseUrl = 'https://cityunlock.net/api/v1';
  static const productionMediaBaseUrl = 'https://cityunlock.net';

  /// Flip to `true` to hit a local Laravel API (emulator: 10.0.2.2).
  static const useLocalBackend = false;

  static String get _localHost =>
      Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';

  static String get localBaseUrl => 'http://$_localHost:8000/api/v1';
  static String get localMediaBaseUrl => 'http://$_localHost:8000';

  static String get baseUrl =>
      useLocalBackend ? localBaseUrl : productionBaseUrl;
  static String get mediaBaseUrl =>
      useLocalBackend ? localMediaBaseUrl : productionMediaBaseUrl;

  static String resolveMediaUrl(String? pathOrUrl) {
    if (pathOrUrl == null) return '';
    final value = pathOrUrl.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    final base = mediaBaseUrl.endsWith('/')
        ? mediaBaseUrl.substring(0, mediaBaseUrl.length - 1)
        : mediaBaseUrl;
    if (value.startsWith('/')) return '$base$value';
    return '$base/$value';
  }

  /// Separate from the shopper/seller app so both can stay signed in.
  static const tokenKey = 'cityshop_admin_auth_token';
  static const deviceName = 'cityshop_admin';
}
