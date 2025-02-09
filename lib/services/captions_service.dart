import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VttCaption {
  final Duration start;
  final Duration end;
  final String text;

  VttCaption({
    required this.start,
    required this.end,
    required this.text,
  });
}

class CaptionsService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  // Cache captions by URL to avoid re-fetching
  static final Map<String, List<VttCaption>> _captionsCache = {};

  // Parse VTT file content into VttCaption objects
  static Future<List<VttCaption>> parseCaptions(String url) async {
    try {
      print('Attempting to parse captions from URL: $url');
      
      if (_captionsCache.containsKey(url)) {
        print('Returning cached captions for URL: $url');
        return _captionsCache[url]!;
      }

      print('Fetching captions file...');
      
      // First try direct HTTP request since captions are public
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          print('Successfully fetched captions via HTTP');
          return _parseCaptionsContent(response.body, url);
        }
        print('HTTP request failed, falling back to Firebase Storage');
      } catch (e) {
        print('HTTP request failed: $e, falling back to Firebase Storage');
      }
      
      // Extract the path from the URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      final storagePath = pathSegments.sublist(pathSegments.indexOf('o') + 1).join('/');
      final decodedPath = Uri.decodeComponent(storagePath.split('?')[0]);
      
      print('Fetching from storage path: $decodedPath');
      
      // Get the file from Firebase Storage
      final ref = _storage.ref().child(decodedPath);
      final bytes = await ref.getData();
      
      if (bytes == null) {
        print('Error: Empty captions file');
        throw Exception('Captions file is empty');
      }
      
      // Convert bytes to string and parse
      final content = String.fromCharCodes(bytes);
      return _parseCaptionsContent(content, url);
    } catch (e, stackTrace) {
      print('Error parsing captions: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to load captions: $e');
    }
  }

  // Helper method to parse captions content
  static Future<List<VttCaption>> _parseCaptionsContent(String content, String url) async {
    final lines = content.split('\n');
    print('Found ${lines.length} lines in captions file');
    
    final List<VttCaption> captions = [];
    
    int i = 0;
    // Skip WebVTT header
    while (i < lines.length && !lines[i].contains('-->')) {
      i++;
    }

    while (i < lines.length) {
      // Skip empty lines and numeric identifiers
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }

      if (i >= lines.length) break;

      // Parse timestamp line
      final timestampLine = lines[i].trim();
      if (!timestampLine.contains('-->')) {
        i++;
        continue;
      }

      final timestamps = timestampLine.split('-->');
      if (timestamps.length != 2) {
        print('Invalid timestamp line: $timestampLine');
        i++;
        continue;
      }

      Duration? start;
      Duration? end;
      
      try {
        start = _parseTimestamp(timestamps[0].trim());
        end = _parseTimestamp(timestamps[1].trim());
      } catch (e) {
        print('Error parsing timestamp: $timestampLine');
        print('Error details: $e');
        i++;
        continue;
      }

      // Parse caption text
      i++;
      String text = '';
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        text += (text.isEmpty ? '' : '\n') + lines[i].trim();
        i++;
      }

      if (text.isNotEmpty) {
        captions.add(VttCaption(
          start: start,
          end: end,
          text: text,
        ));
      }
    }

    if (captions.isEmpty) {
      print('Warning: No valid captions found in file');
      throw Exception('No valid captions found in file');
    }

    print('Successfully parsed ${captions.length} captions');
    _captionsCache[url] = captions;
    return captions;
  }

  // Parse VTT timestamp into Duration
  static Duration _parseTimestamp(String timestamp) {
    try {
      final parts = timestamp.split(':');
      if (parts.length != 3) {
        print('Invalid timestamp format: $timestamp (expected HH:MM:SS.mmm)');
        throw Exception('Invalid timestamp format');
      }

      final seconds = parts[2].split('.');
      if (seconds.length != 2) {
        print('Invalid seconds format: ${parts[2]} (expected SS.mmm)');
        throw Exception('Invalid seconds format');
      }

      return Duration(
        hours: int.parse(parts[0]),
        minutes: int.parse(parts[1]),
        seconds: int.parse(seconds[0]),
        milliseconds: int.parse(seconds[1].padRight(3, '0').substring(0, 3)),
      );
    } catch (e) {
      print('Error parsing timestamp: $timestamp');
      print('Error details: $e');
      throw Exception('Failed to parse timestamp: $e');
    }
  }

  // Get caption text for current position
  static String? getCurrentCaption(List<VttCaption> captions, Duration position) {
    try {
      for (final caption in captions) {
        if (position >= caption.start && position <= caption.end) {
          return caption.text;
        }
      }
      return null;
    } catch (e) {
      print('Error getting current caption: $e');
      return null;
    }
  }
}