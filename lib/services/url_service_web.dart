// ignore: avoid_web_libraries_in_flutter
@JS()
library url_service_web;

import 'package:js/js.dart';
import 'url_service.dart';

@JS('window.location.origin')
external String? get _windowOrigin;

@JS('URL.createObjectURL')
external String? _createObjectURL(dynamic blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);

class WebUrlService implements UrlService {
  @override
  String? getCurrentOrigin() {
    try {
      return _windowOrigin;
    } catch (e) {
      return null;
    }
  }

  @override
  String? createObjectUrl(dynamic blob) {
    try {
      return _createObjectURL(blob);
    } catch (e) {
      return null;
    }
  }

  @override
  void revokeObjectUrl(String url) {
    try {
      _revokeObjectURL(url);
    } catch (e) {
      // Ignore errors when revoking URLs
    }
  }
} 