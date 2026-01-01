import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle bundled deck initialization.
/// Copies bundled flashcard decks to app's documents directory on first launch.
class DeckInitializer {
  static const _initializedKey = 'decks_initialized';
  static const _deckVersionKey = 'deck_version';
  static const _hashcardsDir = 'hashcards';
  
  // Increment this when bundled decks are updated to force a refresh
  static const _currentDeckVersion = 3;

  /// Get the default hashcards directory path.
  static Future<String> getDefaultDeckPath() async {
    final directory = await _getHashcardsDirectory();
    return directory.path;
  }

  /// Check if the default deck directory exists and has content.
  static Future<bool> hasDefaultDecks() async {
    try {
      final directory = await _getHashcardsDirectory();
      if (!await directory.exists()) return false;
      
      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.md'))
          .toList();
      
      return files.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Initialize bundled decks if this is the first launch or if decks were updated.
  /// Returns the path to the hashcards directory.
  static Future<String> initializeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(_initializedKey) ?? false;
    final savedVersion = prefs.getInt(_deckVersionKey) ?? 0;
    
    final directory = await _getHashcardsDirectory();
    
    // Always ensure directory exists
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    // Copy bundled decks if not initialized OR if version has been updated
    if (!initialized || savedVersion < _currentDeckVersion) {
      await _copyBundledDecks(directory, forceOverwrite: savedVersion < _currentDeckVersion);
      await prefs.setBool(_initializedKey, true);
      await prefs.setInt(_deckVersionKey, _currentDeckVersion);
    }
    
    return directory.path;
  }

  /// Force re-copy bundled decks (useful for updates).
  static Future<void> reinstallBundledDecks() async {
    final directory = await _getHashcardsDirectory();
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    await _copyBundledDecks(directory, forceOverwrite: true);
    
    // Update version
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deckVersionKey, _currentDeckVersion);
  }

  /// Get the hashcards directory in app's private documents folder.
  /// This doesn't require any special permissions.
  static Future<Directory> _getHashcardsDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    return Directory('${baseDir.path}/$_hashcardsDir');
  }

  /// Copy all bundled deck assets to the target directory.
  static Future<void> _copyBundledDecks(Directory targetDir, {bool forceOverwrite = false}) async {
    // List of bundled deck files
    const bundledDecks = [
      'assets/decks/Spanish.md',
    ];
    
    for (final assetPath in bundledDecks) {
      try {
        final content = await rootBundle.loadString(assetPath);
        final filename = assetPath.split('/').last;
        final targetFile = File('${targetDir.path}/$filename');
        
        // Copy if file doesn't exist OR if we're forcing an overwrite (deck update)
        if (!await targetFile.exists() || forceOverwrite) {
          await targetFile.writeAsString(content);
        }
      } catch (e) {
        // Asset not found or error copying - continue with other files
        print('Warning: Could not copy $assetPath: $e');
      }
    }
  }
}
