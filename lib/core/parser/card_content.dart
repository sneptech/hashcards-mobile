import 'package:equatable/equatable.dart';

import '../crypto/card_hash.dart';

/// The content of a flashcard.
sealed class CardContent extends Equatable {
  const CardContent();

  CardHash hash();
  CardHash? familyHash() => null;
}

/// A basic question-answer card.
class BasicCard extends CardContent {
  final String question;
  final String answer;

  const BasicCard({required this.question, required this.answer});

  factory BasicCard.create(String question, String answer) {
    return BasicCard(question: question.trim(), answer: answer.trim());
  }

  @override
  CardHash hash() => CardHasher.hashBasicCard(question, answer);

  @override
  List<Object?> get props => [question, answer];
}

/// A cloze deletion card.
class ClozeCard extends CardContent {
  final String text;
  final int start;
  final int end;

  const ClozeCard({required this.text, required this.start, required this.end});

  @override
  CardHash hash() => CardHasher.hashClozeCard(text, start, end);

  @override
  CardHash? familyHash() => CardHasher.hashClozeFamily(text);

  String get deletedText {
    final bytes = text.codeUnits;
    if (start >= 0 && end < bytes.length) {
      return String.fromCharCodes(bytes.sublist(start, end + 1));
    }
    return '';
  }

  @override
  List<Object?> get props => [text, start, end];
}

/// Card type enum.
enum CardType { basic, cloze }

/// A parsed flashcard with metadata.
class FlashCard extends Equatable {
  final String deckName;
  final String filePath;
  final (int, int) range;
  final CardContent content;
  final CardHash _hash;

  FlashCard._({
    required this.deckName,
    required this.filePath,
    required this.range,
    required this.content,
  }) : _hash = content.hash();

  factory FlashCard.create({
    required String deckName,
    required String filePath,
    required (int, int) range,
    required CardContent content,
  }) {
    return FlashCard._(
      deckName: deckName,
      filePath: filePath,
      range: range,
      content: content,
    );
  }

  CardHash get hash => _hash;
  CardHash? get familyHash => content.familyHash();

  CardType get cardType => switch (content) {
        BasicCard() => CardType.basic,
        ClozeCard() => CardType.cloze,
      };

  @override
  List<Object?> get props => [_hash];
}
