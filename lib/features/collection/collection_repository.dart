import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../core/database/database.dart';
import '../../core/parser/card_content.dart';
import '../../core/parser/parser.dart';

class Collection {
  final String directoryPath;
  final HashcardsDatabase db;
  final List<FlashCard> cards;
  final List<(String, String)> macros;

  Collection({
    required this.directoryPath,
    required this.db,
    required this.cards,
    required this.macros,
  });
}

class CollectionRepository {
  Collection? _currentCollection;

  Collection? get currentCollection => _currentCollection;

  Future<Collection> loadCollection(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw StateError('Directory does not exist: $directoryPath');
    }

    final canonicalPath = directory.absolute.path;
    
    // Store database in app's private directory, not in the collection folder
    // Use a hash of the collection path to create a unique db name
    final dbPath = await _getDatabasePath(canonicalPath);
    final db = await HashcardsDatabase.open(dbPath);
    final macros = await _loadMacros(canonicalPath);
    final cards = await parseDeck(canonicalPath);

    await _syncCardsWithDb(db, cards);

    final collection = Collection(
      directoryPath: canonicalPath,
      db: db,
      cards: cards,
      macros: macros,
    );

    _currentCollection = collection;
    return collection;
  }

  /// Get the database path in app's private storage.
  /// Uses a hash of the collection path to create a unique database name.
  Future<String> _getDatabasePath(String collectionPath) async {
    final dbDir = await getDatabasesPath();
    
    // Create a short hash of the collection path for the db filename
    final pathHash = md5.convert(utf8.encode(collectionPath)).toString().substring(0, 8);
    final dbName = 'collection_$pathHash.db';
    
    return path.join(dbDir, dbName);
  }

  Future<List<(String, String)>> _loadMacros(String directoryPath) async {
    final macrosFile = File(path.join(directoryPath, 'macros.tex'));
    if (!await macrosFile.exists()) return [];

    final macros = <(String, String)>[];
    final content = await macrosFile.readAsString();

    for (final line in content.split('\n')) {
      if (line.trimLeft().startsWith('%')) continue;
      final idx = line.indexOf(' ');
      if (idx > 0) {
        final name = line.substring(0, idx);
        final definition = line.substring(idx + 1);
        macros.add((name, definition));
      }
    }
    return macros;
  }

  Future<void> _syncCardsWithDb(HashcardsDatabase db, List<FlashCard> cards) async {
    final now = DateTime.now();
    final dbHashes = await db.cardHashes();

    for (final card in cards) {
      if (!dbHashes.contains(card.hash)) {
        await db.insertCard(card.hash, now);
      }
    }
  }

  Future<void> closeCollection() async {
    final collection = _currentCollection;
    if (collection != null) {
      await collection.db.close();
      _currentCollection = null;
    }
  }
}
