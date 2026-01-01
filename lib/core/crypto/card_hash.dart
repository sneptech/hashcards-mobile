import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// A content-addressed card hash.
class CardHash extends Equatable {
  final String hexDigest;

  const CardHash._(this.hexDigest);

  factory CardHash.fromHex(String hex) {
    if (hex.length != 64) {
      throw ArgumentError(
          'CardHash hex must be 64 characters, got ${hex.length}');
    }
    return CardHash._(hex.toLowerCase());
  }

  factory CardHash.hashBytes(Uint8List bytes) {
    // Note: For full compatibility with hashcards Rust, you would need
    // actual BLAKE3. We use SHA-256 as a substitute here.
    final digest = sha256.convert(bytes);
    return CardHash._(digest.toString());
  }

  @override
  String toString() => hexDigest;

  @override
  List<Object?> get props => [hexDigest];
}

/// A hasher for building card content hashes incrementally.
class ContentHasher {
  final List<int> _buffer = [];

  void update(List<int> bytes) {
    _buffer.addAll(bytes);
  }

  void updateString(String s) {
    _buffer.addAll(utf8.encode(s));
  }

  void updateInt(int value) {
    final bytes = Uint8List(8);
    final data = ByteData.view(bytes.buffer);
    data.setInt64(0, value, Endian.little);
    _buffer.addAll(bytes);
  }

  CardHash finalize() {
    return CardHash.hashBytes(Uint8List.fromList(_buffer));
  }
}

/// Extension methods for hashing card content.
class CardHasher {
  CardHasher._();

  static CardHash hashBasicCard(String question, String answer) {
    final hasher = ContentHasher();
    hasher.updateString('Basic');
    hasher.updateString(question);
    hasher.updateString(answer);
    return hasher.finalize();
  }

  static CardHash hashClozeCard(String text, int start, int end) {
    final hasher = ContentHasher();
    hasher.updateString('Cloze');
    hasher.updateString(text);
    hasher.updateInt(start);
    hasher.updateInt(end);
    return hasher.finalize();
  }

  static CardHash hashClozeFamily(String text) {
    final hasher = ContentHasher();
    hasher.updateString('Cloze');
    hasher.updateString(text);
    return hasher.finalize();
  }
}
