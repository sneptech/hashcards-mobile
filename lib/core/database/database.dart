import 'package:sqflite/sqflite.dart';

import '../crypto/card_hash.dart';
import '../fsrs/grade.dart';
import '../fsrs/performance.dart';

/// Database operations for hashcards.
class HashcardsDatabase {
  final Database _db;

  HashcardsDatabase._(this._db);

  /// Open or create a hashcards database at the given path.
  static Future<HashcardsDatabase> open(String path) async {
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cards (
            card_hash TEXT PRIMARY KEY,
            added_at TEXT NOT NULL,
            last_reviewed_at TEXT,
            stability REAL,
            difficulty REAL,
            interval_raw REAL,
            interval_days INTEGER,
            due_date TEXT,
            review_count INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            session_id INTEGER PRIMARY KEY,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reviews (
            review_id INTEGER PRIMARY KEY,
            session_id INTEGER NOT NULL
              REFERENCES sessions (session_id)
              ON UPDATE CASCADE ON DELETE CASCADE,
            card_hash TEXT NOT NULL
              REFERENCES cards (card_hash)
              ON UPDATE CASCADE ON DELETE CASCADE,
            reviewed_at TEXT NOT NULL,
            grade TEXT NOT NULL,
            stability REAL NOT NULL,
            difficulty REAL NOT NULL,
            interval_raw REAL NOT NULL,
            interval_days INTEGER NOT NULL,
            due_date TEXT NOT NULL
          )
        ''');
      },
    );
    return HashcardsDatabase._(db);
  }

  Future<void> insertCard(CardHash cardHash, DateTime addedAt) async {
    if (await cardExists(cardHash)) {
      throw StateError('Card already exists');
    }
    await _db.insert('cards', {
      'card_hash': cardHash.hexDigest,
      'added_at': _formatTimestamp(addedAt),
      'review_count': 0,
    });
  }

  Future<Set<CardHash>> cardHashes() async {
    final rows = await _db.query('cards', columns: ['card_hash']);
    return rows.map((r) => CardHash.fromHex(r['card_hash'] as String)).toSet();
  }

  Future<Set<CardHash>> dueToday(DateTime today) async {
    final todayStr = _formatDate(today);
    final rows = await _db.query('cards', columns: ['card_hash', 'due_date']);
    final due = <CardHash>{};
    for (final row in rows) {
      final hash = CardHash.fromHex(row['card_hash'] as String);
      final dueDate = row['due_date'] as String?;
      if (dueDate == null || dueDate.compareTo(todayStr) <= 0) {
        due.add(hash);
      }
    }
    return due;
  }

  Future<Performance?> getCardPerformanceOpt(CardHash cardHash) async {
    final rows = await _db.query(
      'cards',
      columns: [
        'last_reviewed_at',
        'stability',
        'difficulty',
        'interval_raw',
        'interval_days',
        'due_date',
        'review_count',
      ],
      where: 'card_hash = ?',
      whereArgs: [cardHash.hexDigest],
    );
    if (rows.isEmpty) return null;
    return _performanceFromRow(rows.first);
  }

  Future<Performance> getCardPerformance(CardHash cardHash) async {
    final perf = await getCardPerformanceOpt(cardHash);
    if (perf == null) {
      throw StateError(
          'No performance data found for card with hash $cardHash');
    }
    return perf;
  }

  Future<void> updateCardPerformance(
    CardHash cardHash,
    Performance performance,
  ) async {
    if (!await cardExists(cardHash)) {
      throw StateError('Card not found');
    }

    final Map<String, dynamic> values;
    switch (performance) {
      case NewPerformance():
        values = {
          'last_reviewed_at': null,
          'stability': null,
          'difficulty': null,
          'interval_raw': null,
          'interval_days': null,
          'due_date': null,
          'review_count': 0,
        };
      case ReviewedPerformance(
          :final lastReviewedAt,
          :final stability,
          :final difficulty,
          :final intervalRaw,
          :final intervalDays,
          :final dueDate,
          :final reviewCount,
        ):
        values = {
          'last_reviewed_at': _formatTimestamp(lastReviewedAt),
          'stability': stability,
          'difficulty': difficulty,
          'interval_raw': intervalRaw,
          'interval_days': intervalDays,
          'due_date': _formatDate(dueDate),
          'review_count': reviewCount,
        };
    }

    await _db.update(
      'cards',
      values,
      where: 'card_hash = ?',
      whereArgs: [cardHash.hexDigest],
    );
  }

  Future<void> saveSession(
    DateTime startedAt,
    DateTime endedAt,
    List<ReviewRecord> reviews,
  ) async {
    await _db.transaction((txn) async {
      final sessionId = await txn.insert('sessions', {
        'started_at': _formatTimestamp(startedAt),
        'ended_at': _formatTimestamp(endedAt),
      });

      for (final review in reviews) {
        await txn.insert('reviews', {
          'session_id': sessionId,
          'card_hash': review.cardHash.hexDigest,
          'reviewed_at': _formatTimestamp(review.reviewedAt),
          'grade': review.grade.toDbString(),
          'stability': review.stability,
          'difficulty': review.difficulty,
          'interval_raw': review.intervalRaw,
          'interval_days': review.intervalDays,
          'due_date': _formatDate(review.dueDate),
        });
      }
    });
  }

  Future<void> deleteCard(CardHash cardHash) async {
    if (!await cardExists(cardHash)) {
      throw StateError('Card not found');
    }
    await _db.delete('reviews',
        where: 'card_hash = ?', whereArgs: [cardHash.hexDigest]);
    await _db.delete('cards',
        where: 'card_hash = ?', whereArgs: [cardHash.hexDigest]);
  }

  Future<bool> cardExists(CardHash cardHash) async {
    final result = await _db.query(
      'cards',
      columns: ['card_hash'],
      where: 'card_hash = ?',
      whereArgs: [cardHash.hexDigest],
    );
    return result.isNotEmpty;
  }

  Future<void> close() async {
    await _db.close();
  }

  Performance _performanceFromRow(Map<String, dynamic> row) {
    final lastReviewedAt = row['last_reviewed_at'] as String?;
    if (lastReviewedAt == null) {
      return const NewPerformance();
    }

    return ReviewedPerformance(
      lastReviewedAt: _parseTimestamp(lastReviewedAt),
      stability: (row['stability'] as num).toDouble(),
      difficulty: (row['difficulty'] as num).toDouble(),
      intervalRaw: (row['interval_raw'] as num).toDouble(),
      intervalDays: row['interval_days'] as int,
      dueDate: _parseDate(row['due_date'] as String),
      reviewCount: row['review_count'] as int,
    );
  }
}

/// A record of a single review action.
class ReviewRecord {
  final CardHash cardHash;
  final DateTime reviewedAt;
  final Grade grade;
  final double stability;
  final double difficulty;
  final double intervalRaw;
  final int intervalDays;
  final DateTime dueDate;

  const ReviewRecord({
    required this.cardHash,
    required this.reviewedAt,
    required this.grade,
    required this.stability,
    required this.difficulty,
    required this.intervalRaw,
    required this.intervalDays,
    required this.dueDate,
  });
}

// Timestamp format: YYYY-MM-DDTHH:MM:SS.MMM
String _formatTimestamp(DateTime dt) {
  final ms = dt.millisecond.toString().padLeft(3, '0');
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}T'
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}.$ms';
}

DateTime _parseTimestamp(String s) {
  final parts = s.split('T');
  final dateParts = parts[0].split('-');
  final timeParts = parts[1].split(':');
  final secParts = timeParts[2].split('.');

  return DateTime(
    int.parse(dateParts[0]),
    int.parse(dateParts[1]),
    int.parse(dateParts[2]),
    int.parse(timeParts[0]),
    int.parse(timeParts[1]),
    int.parse(secParts[0]),
    secParts.length > 1 ? int.parse(secParts[1]) : 0,
  );
}

String _formatDate(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

DateTime _parseDate(String s) {
  final parts = s.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
