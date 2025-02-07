import 'package:flutter/foundation.dart' show kIsWeb;

abstract class UrlService {
  static UrlService? _instance;
  
  static UrlService get instance {
    _instance ??= kIsWeb ? WebUrlService() : MobileUrlService();
    return _instance!;
  }

  String? getCurrentOrigin();
  String? createObjectUrl(dynamic blob);
  void revokeObjectUrl(String url);
}

class MobileUrlService implements UrlService {
  @override
  String? getCurrentOrigin() => null;

  @override
  String? createObjectUrl(dynamic blob) => null;

  @override
  void revokeObjectUrl(String url) {}
}

// Stub implementation for non-web platforms
class WebUrlService implements UrlService {
  @override
  String? getCurrentOrigin() => null;

  @override
  String? createObjectUrl(dynamic blob) => null;

  @override
  void revokeObjectUrl(String url) {}
} 