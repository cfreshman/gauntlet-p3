import 'package:flutter/foundation.dart';

class AudioStateProvider extends ChangeNotifier {
  bool _isMuted = kIsWeb; // Default to muted only on web
  bool get isMuted => _isMuted;

  // Store in local storage for web persistence
  void setMuted(bool muted) {
    if (_isMuted != muted) {
      _isMuted = muted;
      notifyListeners();
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }
} 