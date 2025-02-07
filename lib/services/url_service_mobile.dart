import 'url_service.dart';

// Stub implementation for non-web platforms
class WebUrlService implements UrlService {
  @override
  String? createObjectUrl(dynamic blob) => null;

  @override
  void revokeObjectUrl(String url) {}
}

class MobileUrlService implements UrlService {
  @override
  String? getCurrentOrigin() => null;

  @override
  String? createObjectUrl(dynamic blob) => null;

  @override
  void revokeObjectUrl(String url) {}
} 