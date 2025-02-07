import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher_string.dart';

class MinecraftSkinService {
  static const String _mineatar = 'https://api.mineatar.io';
  static const String _playerDb = 'https://playerdb.co/api/player/minecraft';
  
  // Cache UUIDs to prevent repeated requests
  static final Map<String, String> _uuidCache = {};
  static final Map<String, DateTime> _uuidCacheExpiry = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Get UUID from PlayerDB with caching
  Future<String> _getUUID(String username) async {
    // Return cached UUID if available and not expired
    final now = DateTime.now();
    if (_uuidCache.containsKey(username) && 
        _uuidCacheExpiry[username]!.isAfter(now)) {
      return _uuidCache[username]!;
    }

    try {
      print('Fetching UUID for username: $username');
      final response = await http.get(
        Uri.parse('$_playerDb/$username'),
        headers: {'User-Agent': 'TikBlok-App/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch player data');
      }

      final data = json.decode(response.body);
      if (data['success'] != true || data['code'] != 'player.found') {
        throw Exception('Player not found');
      }

      final uuid = data['data']['player']['id'];
      print('Found UUID: $uuid');
      
      // Cache the UUID with expiry
      _uuidCache[username] = uuid;
      _uuidCacheExpiry[username] = now.add(_cacheDuration);
      
      return uuid;
    } catch (e) {
      print('Error getting UUID: $e');
      rethrow;
    }
  }

  // Get face image URL directly (no UUID lookup needed)
  Future<String?> getFaceUrl(String username, {int scale = 10}) async {
    try {
      print('Getting face URL for: $username');
      if (!isValidUsername(username)) {
        throw Exception('Invalid Minecraft username format');
      }
      
      final uuid = await _getUUID(username);
      final faceUrl = '$_mineatar/face/$uuid?scale=$scale&overlay=true';
      print('Generated face URL: $faceUrl');
      
      // Verify the face exists by making a HEAD request
      final response = await http.head(Uri.parse(faceUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to get player skin');
      }
      
      return faceUrl;
    } catch (e) {
      print('Error getting face URL: $e');
      rethrow;
    }
  }

  // Get head render URL
  Future<String> getHeadUrl(String username, {bool overlay = true, int scale = 4}) async {
    final uuid = await _getUUID(username);
    return '$_mineatar/head/$uuid?scale=$scale&overlay=$overlay';
  }

  // Get full body render URL
  Future<String> getFullBodyUrl(String username, {bool overlay = true, int scale = 4}) async {
    final uuid = await _getUUID(username);
    return '$_mineatar/body/full/$uuid?scale=$scale&overlay=$overlay';
  }

  // Get front body render URL
  Future<String> getFrontBodyUrl(String username, {bool overlay = true, int scale = 4}) async {
    final uuid = await _getUUID(username);
    return '$_mineatar/body/front/$uuid?scale=$scale&overlay=$overlay';
  }

  // Get back body render URL
  Future<String> getBackBodyUrl(String username, {bool overlay = true, int scale = 4}) async {
    final uuid = await _getUUID(username);
    return '$_mineatar/body/back/$uuid?scale=$scale&overlay=$overlay';
  }

  // Get raw skin URL
  Future<String> getRawSkinUrl(String username) async {
    final uuid = await _getUUID(username);
    return '$_mineatar/skin/$uuid';
  }

  // Get skin download URL
  Future<String> getSkinDownloadUrl(String username) async {
    final uuid = await _getUUID(username);
    return '$_mineatar/skin/$uuid?download=true';
  }

  // Download skin using API's download parameter
  Future<void> downloadSkin(String username) async {
    try {
      final downloadUrl = await getSkinDownloadUrl(username);
      
      if (!await canLaunchUrlString(downloadUrl)) {
        throw Exception('Could not download skin');
      }
      await launchUrlString(
        downloadUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Error downloading skin: $e');
      rethrow;
    }
  }

  // Validate Minecraft username (2-16 characters, alphanumeric and underscore)
  bool isValidUsername(String username) {
    final regex = RegExp(r'^[a-zA-Z0-9_]{2,16}$');
    return regex.hasMatch(username);
  }
} 