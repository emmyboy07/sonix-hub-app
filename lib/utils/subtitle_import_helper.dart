import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../screens/player/universal_player_screen.dart';

class SubtitleImportHelper {
  /// Pick and import a subtitle file
  /// Returns a SubtitleSource if successful, null otherwise
  static Future<SubtitleSource?> importSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) return null;

      // Extract the filename for display
      final fileName = file.name;

      // Read the file as text
      final fileContent = await _readSubtitleFile(filePath);
      if (fileContent == null || fileContent.isEmpty) {
        throw Exception('Failed to read subtitle file');
      }

      // Create a SubtitleSource with inline content
      return SubtitleSource(
        url: 'file://$filePath', // File path as URL for reference
        headers: const {},
        label: fileName,
        lang: _guessLanguageFromFilename(fileName),
        inlineText: fileContent, // Store actual content inline
      );
    } catch (e) {
      print('[SubtitleImport] Error: $e');
      return null;
    }
  }

  /// Read subtitle file content as string
  static Future<String?> _readSubtitleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      // Try UTF-8 first, then fall back to other encodings
      try {
        return utf8.decode(bytes);
      } catch (_) {
        // Try Latin-1 as fallback
        return String.fromCharCodes(bytes);
      }
    } catch (e) {
      print('[SubtitleImport] Error reading file: $e');
      return null;
    }
  }

  /// Guess language from filename (e.g., "movie.en.srt" -> "en")
  static String? _guessLanguageFromFilename(String filename) {
    try {
      // Pattern: name.lang.ext or name_lang.ext or name (lang).ext
      final withoutExt = filename.replaceAll(
        RegExp(r'\.(srt|vtt|ass|ssa|sub)$', caseSensitive: false),
        '',
      );

      // Try pattern: name.lang or name_lang
      final parts = withoutExt.split(RegExp(r'[._\-]'));
      if (parts.length >= 2) {
        final lastPart = parts.last.toLowerCase();
        // Check if it looks like a language code (2-3 letters)
        if (lastPart.length <= 3 && RegExp(r'^[a-z]+$').hasMatch(lastPart)) {
          return lastPart;
        }
      }

      // Try pattern: name (lang)
      final langMatch = RegExp(
        r'\(([a-z]{2,3})\)',
        caseSensitive: false,
      ).firstMatch(withoutExt);
      if (langMatch != null) {
        return langMatch.group(1)?.toLowerCase();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Validate if a file is a valid subtitle file by extension
  static bool isValidSubtitleFile(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['srt', 'vtt', 'ass', 'ssa', 'sub'].contains(ext);
  }

  /// Get a user-friendly error message
  static String getErrorMessage(String? error) {
    if (error == null) return 'Unknown error occurred';
    if (error.contains('Permission')) return 'No permission to access files';
    if (error.contains('not found')) return 'File not found';
    return error;
  }
}
