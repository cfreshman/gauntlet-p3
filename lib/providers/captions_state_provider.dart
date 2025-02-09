import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaptionsStateProvider extends ChangeNotifier {
  static const _key = 'captions_enabled';
  bool _showCaptions = true; // Default to true
  bool get showCaptions => _showCaptions;

  CaptionsStateProvider() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if no preference is set
    _showCaptions = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggleCaptions() async {
    _showCaptions = !_showCaptions;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _showCaptions);
    notifyListeners();
  }
} 