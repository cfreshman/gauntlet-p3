import 'package:image_picker/image_picker.dart';

class VideoConverterService {
  /// Check if video needs processing
  static Future<bool> needsConversion(XFile video) async {
    // No conversion needed
    return false;
  }

  /// Simply return the original video path/url
  static Future<String?> convertToMp4(XFile inputVideo) async {
    return inputVideo.path;
  }
} 