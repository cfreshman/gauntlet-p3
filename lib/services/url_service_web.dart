// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as web;
import 'url_service.dart';

class WebUrlServiceImpl extends WebUrlService {
  @override
  String? createObjectUrl(dynamic blob) {
    if (blob is web.Blob) {
      return web.Url.createObjectUrlFromBlob(blob);
    }
    return null;
  }

  @override
  void revokeObjectUrl(String url) {
    web.Url.revokeObjectUrl(url);
  }
} 