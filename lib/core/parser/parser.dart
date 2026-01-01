import 'dart:io';

import 'package:toml/toml.dart';

import 'card_content.dart';

/// Parser errors.
class ParserError implements Exception {
  final String message;
  final String filePath;
  final int lineNum;

  ParserError({
    required this.message,
    required this.filePath,
    required this.lineNum,
  });

  @override
  String toString() => '$message Location: $filePath:${lineNum + 1}';
}

enum _State { initial, readingQuestion, readingAnswer, readingCloze }

sealed class _Line {
  const _Line();
}

class _StartQuestion extends _Line {
  final String text;
  const _StartQuestion(this.text);
}

class _StartAnswer extends _Line {
  final String text;
  const _StartAnswer(this.text);
}

class _StartCloze extends _Line {
  final String text;
  const _StartCloze(this.text);
}

class _Separator extends _Line {
  const _Separator();
}

class _Text extends _Line {
  final String text;
  const _Text(this.text);
}

_Line _readLine(String line) {
  if (line.startsWith('Q:')) {
    return _StartQuestion(line.substring(2).trim());
  } else if (line.startsWith('A:')) {
    return _StartAnswer(line.substring(2).trim());
  } else if (line.startsWith('C:')) {
    return _StartCloze(line.substring(2).trim());
  } else if (line.trim() == '---') {
    return const _Separator();
  } else {
    return _Text(line);
  }
}

class DeckMetadata {
  final String? name;
  const DeckMetadata({this.name});
}

(DeckMetadata, String) extractFrontmatter(String text) {
  final lines = text.split('\n');
  if (lines.isEmpty || lines[0].trim() != '---') {
    return (const DeckMetadata(), text);
  }

  int? closingIdx;
  final frontmatterLines = <String>[];
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      closingIdx = i;
      break;
    }
    frontmatterLines.add(lines[i]);
  }

  if (closingIdx == null) {
    throw FormatException(
        "Frontmatter opening '---' found but no closing '---'");
  }

  final frontmatterStr = frontmatterLines.join('\n');
  String? name;
  if (frontmatterStr.trim().isNotEmpty) {
    try {
      final doc = TomlDocument.parse(frontmatterStr);
      name = doc.toMap()['name'] as String?;
    } catch (e) {
      throw FormatException('Failed to parse TOML frontmatter: $e');
    }
  }

  final contentLines = lines.sublist(closingIdx + 1);
  final content = contentLines.join('\n');

  return (DeckMetadata(name: name), content);
}

class Parser {
  final String deckName;
  final String filePath;

  Parser({required this.deckName, required this.filePath});

  List<FlashCard> parse(String text) {
    final cards = <FlashCard>[];
    var state = _State.initial;
    final lines = text.split('\n');
    final lastLine = lines.isEmpty ? 0 : lines.length - 1;

    String question = '';
    String answer = '';
    String clozeText = '';
    int startLine = 0;

    for (var lineNum = 0; lineNum < lines.length; lineNum++) {
      final line = _readLine(lines[lineNum]);

      switch (state) {
        case _State.initial:
          switch (line) {
            case _StartQuestion(:final text):
              state = _State.readingQuestion;
              question = text;
              startLine = lineNum;
            case _StartAnswer():
              throw ParserError(
                message: 'Found answer tag without a question.',
                filePath: filePath,
                lineNum: lineNum,
              );
            case _StartCloze(:final text):
              state = _State.readingCloze;
              clozeText = text;
              startLine = lineNum;
            case _Separator():
            case _Text():
              break;
          }

        case _State.readingQuestion:
          switch (line) {
            case _StartQuestion():
              throw ParserError(
                message: 'New question without answer.',
                filePath: filePath,
                lineNum: lineNum,
              );
            case _StartAnswer(:final text):
              state = _State.readingAnswer;
              answer = text;
            case _StartCloze():
              throw ParserError(
                message: 'Found cloze tag while reading a question.',
                filePath: filePath,
                lineNum: lineNum,
              );
            case _Separator():
              throw ParserError(
                message:
                    'Found flashcard separator while reading a question.',
                filePath: filePath,
                lineNum: lineNum,
              );
            case _Text(:final text):
              question = '$question\n$text';
          }

        case _State.readingAnswer:
          switch (line) {
            case _StartQuestion(:final text):
              cards.add(_createBasicCard(question, answer, startLine, lineNum));
              state = _State.readingQuestion;
              question = text;
              startLine = lineNum;
            case _StartAnswer():
              throw ParserError(
                message: 'Found answer tag while reading an answer.',
                filePath: filePath,
                lineNum: lineNum,
              );
            case _StartCloze(:final text):
              cards.add(_createBasicCard(question, answer, startLine, lineNum));
              state = _State.readingCloze;
              clozeText = text;
              startLine = lineNum;
            case _Separator():
              cards.add(_createBasicCard(question, answer, startLine, lineNum));
              state = _State.initial;
            case _Text(:final text):
              answer = '$answer\n$text';
          }

        case _State.readingCloze:
          switch (line) {
            case _StartQuestion(:final text):
              cards.addAll(_parseClozeCards(clozeText, startLine, lineNum));
              state = _State.readingQuestion;
              question = text;
              startLine = lineNum;
            case _StartAnswer():
              throw ParserError(
                message: 'Found answer tag while reading a cloze card.',
                filePath: filePath,
                lineNum: lineNum,
              );
            case _StartCloze(:final text):
              cards.addAll(_parseClozeCards(clozeText, startLine, lineNum));
              clozeText = text;
              startLine = lineNum;
            case _Separator():
              cards.addAll(_parseClozeCards(clozeText, startLine, lineNum));
              state = _State.initial;
            case _Text(:final text):
              clozeText = '$clozeText\n$text';
          }
      }
    }

    switch (state) {
      case _State.initial:
        break;
      case _State.readingQuestion:
        throw ParserError(
          message: 'File ended while reading a question without answer.',
          filePath: filePath,
          lineNum: lastLine,
        );
      case _State.readingAnswer:
        cards.add(_createBasicCard(question, answer, startLine, lastLine));
      case _State.readingCloze:
        cards.addAll(_parseClozeCards(clozeText, startLine, lastLine));
    }

    final seen = <String>{};
    return cards.where((card) => seen.add(card.hash.hexDigest)).toList();
  }

  FlashCard _createBasicCard(
      String question, String answer, int startLine, int endLine) {
    return FlashCard.create(
      deckName: deckName,
      filePath: filePath,
      range: (startLine, endLine),
      content: BasicCard.create(question, answer),
    );
  }

  List<FlashCard> _parseClozeCards(String text, int startLine, int endLine) {
    text = text.trim();
    final cards = <FlashCard>[];

    final textBytes = text.codeUnits;
    final cleanBytes = <int>[];
    var imageMode = false;

    for (var bytePos = 0; bytePos < textBytes.length; bytePos++) {
      final c = textBytes[bytePos];
      if (c == 0x5B) {
        if (imageMode) cleanBytes.add(c);
      } else if (c == 0x5D) {
        if (imageMode) {
          imageMode = false;
          cleanBytes.add(c);
        }
      } else if (c == 0x21) {
        if (!imageMode) {
          final nextOpt =
              bytePos + 1 < textBytes.length ? textBytes[bytePos + 1] : null;
          if (nextOpt == 0x5B) imageMode = true;
        }
        cleanBytes.add(c);
      } else {
        cleanBytes.add(c);
      }
    }

    final cleanText = String.fromCharCodes(cleanBytes);

    int? start;
    var index = 0;
    imageMode = false;

    for (var bytePos = 0; bytePos < textBytes.length; bytePos++) {
      final c = textBytes[bytePos];
      if (c == 0x5B) {
        if (imageMode) {
          index += 1;
        } else {
          start = index;
        }
      } else if (c == 0x5D) {
        if (imageMode) {
          imageMode = false;
          index += 1;
        } else if (start != null) {
          final end = index;
          cards.add(FlashCard.create(
            deckName: deckName,
            filePath: filePath,
            range: (startLine, endLine),
            content: ClozeCard(text: cleanText, start: start, end: end - 1),
          ));
          start = null;
        }
      } else if (c == 0x21) {
        if (!imageMode) {
          final nextOpt =
              bytePos + 1 < textBytes.length ? textBytes[bytePos + 1] : null;
          if (nextOpt == 0x5B) imageMode = true;
        }
        index += 1;
      } else {
        index += 1;
      }
    }

    if (cards.isEmpty) {
      throw ParserError(
        message: 'Cloze card must contain at least one cloze deletion.',
        filePath: filePath,
        lineNum: startLine,
      );
    }

    return cards;
  }
}

Future<List<FlashCard>> parseDeck(String directoryPath) async {
  final directory = Directory(directoryPath);
  if (!await directory.exists()) {
    throw StateError('Directory does not exist: $directoryPath');
  }

  final allCards = <FlashCard>[];

  await for (final entity in directory.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.md')) {
      final text = await entity.readAsString();
      final (metadata, content) = extractFrontmatter(text);
      final deckName =
          metadata.name ?? entity.uri.pathSegments.last.replaceAll('.md', '');

      final parser = Parser(deckName: deckName, filePath: entity.path);
      try {
        final cards = parser.parse(content);
        allCards.addAll(cards);
      } catch (e) {
        if (e is ParserError) rethrow;
        throw ParserError(
          message: 'Failed to parse file: $e',
          filePath: entity.path,
          lineNum: 0,
        );
      }
    }
  }

  allCards.sort((a, b) => a.hash.hexDigest.compareTo(b.hash.hexDigest));
  final seen = <String>{};
  return allCards.where((card) => seen.add(card.hash.hexDigest)).toList();
}
