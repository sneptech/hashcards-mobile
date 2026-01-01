import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../core/parser/card_content.dart';

/// Result of checking an answer
enum AnswerResult { correct, almostCorrect, incorrect, notChecked }

/// Details about the answer comparison
class AnswerCheckResult {
  final AnswerResult result;
  final String? differenceHint; // e.g., "Expected 'é' but got 'e' at position 3"
  
  const AnswerCheckResult(this.result, [this.differenceHint]);
}

/// Callback when user submits an answer
typedef OnAnswerSubmitted = void Function(String answer, AnswerCheckResult result);

/// Renders a flashcard with optional interactive input.
class CardRenderer extends StatefulWidget {
  final FlashCard card;
  final bool showBack;
  final bool interactive;
  final OnAnswerSubmitted? onAnswerSubmitted;
  final String? userAnswer;
  final AnswerResult answerResult;
  final String? differenceHint;
  final TextEditingController? answerController;

  const CardRenderer({
    super.key,
    required this.card,
    required this.showBack,
    this.interactive = false,
    this.onAnswerSubmitted,
    this.userAnswer,
    this.answerResult = AnswerResult.notChecked,
    this.differenceHint,
    this.answerController,
  });

  @override
  State<CardRenderer> createState() => CardRendererState();
}

class CardRendererState extends State<CardRenderer> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.answerController != null) {
      _controller = widget.answerController!;
    } else {
      _controller = TextEditingController(text: widget.userAnswer ?? '');
      _ownsController = true;
    }
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(CardRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset controller when card changes
    if (oldWidget.card.hash != widget.card.hash) {
      _controller.text = widget.userAnswer ?? '';
    }
    // Update controller reference if it changed
    if (widget.answerController != null && widget.answerController != _controller) {
      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }
      _controller = widget.answerController!;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  /// Get the correct answer for the current card
  String get correctAnswer {
    return switch (widget.card.content) {
      BasicCard(:final answer) => answer,
      ClozeCard(:final text, :final start, :final end) =>
        String.fromCharCodes(text.codeUnits.sublist(start, end + 1)),
    };
  }

  /// Submit the current answer
  void submitAnswer() {
    final userAnswer = _controller.text.trim();
    if (userAnswer.isEmpty) return;

    final correct = correctAnswer;
    final result = _checkAnswer(userAnswer, correct);

    widget.onAnswerSubmitted?.call(userAnswer, result);
  }

  /// Check the answer and return detailed result
  AnswerCheckResult _checkAnswer(String userAnswer, String correctAnswer) {
    // Handle multiple acceptable answers separated by " / "
    final alternatives = correctAnswer.split(' / ').map((s) => s.trim()).toList();
    
    final normalizedUser = userAnswer.toLowerCase().trim();
    
    // Check for exact match against any alternative
    for (final alt in alternatives) {
      final normalizedAlt = alt.toLowerCase().trim();
      if (normalizedUser == normalizedAlt) {
        return const AnswerCheckResult(AnswerResult.correct);
      }
    }
    
    // Check for "almost correct" against any alternative
    for (final alt in alternatives) {
      final normalizedAlt = alt.toLowerCase().trim();
      final difference = _findSingleCharDifference(normalizedUser, normalizedAlt, userAnswer, alt);
      if (difference != null) {
        return AnswerCheckResult(AnswerResult.almostCorrect, difference);
      }
    }
    
    // Completely wrong - show first alternative as the "correct" answer
    return const AnswerCheckResult(AnswerResult.incorrect);
  }

  /// Find if there's exactly one character difference (like a missing accent)
  /// Returns a hint string if almost correct, null otherwise
  String? _findSingleCharDifference(String normUser, String normCorrect, String origUser, String origCorrect) {
    // Must be same length for single char difference (catches accent mistakes)
    if (normUser.length != normCorrect.length) {
      return null;
    }
    
    int diffCount = 0;
    int diffIndex = -1;
    
    for (int i = 0; i < normUser.length; i++) {
      if (normUser[i] != normCorrect[i]) {
        diffCount++;
        diffIndex = i;
        if (diffCount > 1) return null; // More than 1 difference
      }
    }
    
    if (diffCount == 1) {
      // Find the original characters (preserving case/accents)
      final userChar = diffIndex < origUser.length ? origUser[diffIndex] : '?';
      final correctChar = diffIndex < origCorrect.length ? origCorrect[diffIndex] : '?';
      return "Expected '$correctChar' but got '$userChar'";
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.card.content) {
      BasicCard(:final question, :final answer) =>
        _buildBasicCard(context, question, answer),
      ClozeCard(:final text, :final start, :final end) =>
        _buildClozeCard(context, text, start, end),
    };
  }

  Widget _buildBasicCard(
    BuildContext context,
    String question,
    String answer,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question
        _MarkdownContent(content: question),
        
        const SizedBox(height: 24),
        
        // Answer input or revealed answer
        if (widget.showBack || widget.answerResult != AnswerResult.notChecked) ...[
          Divider(color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          // Show feedback if answer was checked
          if (widget.answerResult != AnswerResult.notChecked && widget.userAnswer != null)
            _buildAnswerFeedback(context, answer),
          if (widget.answerResult == AnswerResult.notChecked || widget.showBack) ...[
            const SizedBox(height: 8),
            Text(
              'Answer:',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _MarkdownContent(content: answer),
          ],
        ] else if (widget.interactive) ...[
          Divider(color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Your answer:',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          _buildAnswerInput(context, answer),
        ],
      ],
    );
  }

  /// Count words in an answer (handles alternatives with " / ")
  int _countWords(String answer) {
    // Use first alternative if there are multiple
    final firstAlt = answer.split(' / ').first.trim();
    // Split by whitespace and count non-empty parts
    final words = firstAlt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.length;
  }

  /// Get hint text based on word count
  String _getInputHint(String correctAnswer) {
    final wordCount = _countWords(correctAnswer);
    if (wordCount <= 1) {
      return 'Type answer...';
    } else {
      return 'Type $wordCount words...';
    }
  }

  Widget _buildAnswerInput(BuildContext context, String correctAnswer) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      maxLines: 3,
      minLines: 1,
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 32),
      decoration: InputDecoration(
        hintText: _getInputHint(correctAnswer),
        hintStyle: const TextStyle(fontSize: 32),
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      onSubmitted: (_) => submitAnswer(),
    );
  }

  Widget _buildClozeCard(
    BuildContext context,
    String text,
    int start,
    int end,
  ) {
    final bytes = text.codeUnits;
    final correctAnswer = String.fromCharCodes(bytes.sublist(start, end + 1));
    final beforeCloze = String.fromCharCodes(bytes.sublist(0, start));
    final afterCloze = String.fromCharCodes(bytes.sublist(end + 1));

    Widget clozeWidget;

    if (widget.showBack || widget.answerResult != AnswerResult.notChecked) {
      // Show the answer (revealed or after checking)
      clozeWidget = _buildRevealedCloze(context, correctAnswer);
    } else if (widget.interactive) {
      // Show input field
      clozeWidget = _buildClozeInput(context, correctAnswer);
    } else {
      // Show blank (tap to reveal mode)
      clozeWidget = _buildBlankCloze(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (beforeCloze.isNotEmpty)
              _MarkdownContent(content: beforeCloze, inline: true),
            clozeWidget,
            if (afterCloze.isNotEmpty)
              _MarkdownContent(content: afterCloze, inline: true),
          ],
        ),
        // Show user's answer feedback if checked
        if (widget.answerResult != AnswerResult.notChecked &&
            widget.userAnswer != null) ...[
          const SizedBox(height: 16),
          _buildAnswerFeedback(context, correctAnswer),
        ],
      ],
    );
  }

  Widget _buildBlankCloze(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '...............',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 40,
        ),
      ),
    );
  }

  Widget _buildClozeInput(BuildContext context, String correctAnswer) {
    return Container(
      constraints: BoxConstraints(
        minWidth: 150,
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        style: const TextStyle(fontSize: 32),
        decoration: InputDecoration(
          hintText: _getInputHint(correctAnswer),
          hintStyle: const TextStyle(fontSize: 28),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        onSubmitted: (_) => submitAnswer(),
      ),
    );
  }

  Widget _buildRevealedCloze(BuildContext context, String correctAnswer) {
    Color bgColor;
    Color textColor;

    if (widget.answerResult == AnswerResult.correct) {
      bgColor = const Color(0xFF3CB71A);  // Easy green
      textColor = Colors.white;
    } else if (widget.answerResult == AnswerResult.almostCorrect) {
      bgColor = const Color(0xFFFF902A);  // Hard orange
      textColor = Colors.white;
    } else if (widget.answerResult == AnswerResult.incorrect) {
      bgColor = const Color(0xFFDD4231);  // Forgot red
      textColor = Colors.white;
    } else {
      bgColor = Theme.of(context).colorScheme.primaryContainer;
      textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        correctAnswer,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: 40,
        ),
      ),
    );
  }

  Widget _buildAnswerFeedback(BuildContext context, String correctAnswer) {
    final isCorrect = widget.answerResult == AnswerResult.correct;
    final isAlmostCorrect = widget.answerResult == AnswerResult.almostCorrect;

    // Use grade button colors: Easy (correct), Hard (almost), Forgot (incorrect)
    Color bgColor;
    IconData icon;
    String title;

    if (isCorrect) {
      bgColor = const Color(0xFF3CB71A);  // Easy green
      icon = Icons.check_circle;
      title = 'Correct!';
    } else if (isAlmostCorrect) {
      bgColor = const Color(0xFFFF902A);  // Hard orange
      icon = Icons.info;
      title = 'Almost correct!';
    } else {
      bgColor = const Color(0xFFDD4231);  // Forgot red
      icon = Icons.cancel;
      title = 'Incorrect';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // Always show the user's answer
                const SizedBox(height: 4),
                Text(
                  'Your answer: ${widget.userAnswer}',
                  style: const TextStyle(color: Colors.white),
                ),
                // Show correct answer only when wrong
                if (!isCorrect) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Correct answer: $correctAnswer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Show hint for almost correct answers
                  if (isAlmostCorrect && widget.differenceHint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.differenceHint!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownContent extends StatelessWidget {
  final String content;
  final bool inline;

  const _MarkdownContent({required this.content, this.inline = false});

  @override
  Widget build(BuildContext context) {
    if (_containsLatex(content)) {
      return _buildWithLatex(context);
    }

    return MarkdownBody(
      data: content,
      shrinkWrap: true,
      softLineBreak: inline,
      styleSheet: _markdownStyleSheet(context),
    );
  }

  bool _containsLatex(String text) {
    return text.contains(r'$') || text.contains(r'\(') || text.contains(r'\[');
  }

  Widget _buildWithLatex(BuildContext context) {
    final parts = _splitLatex(content);

    if (parts.length == 1 && parts.first.isLatex) {
      return _renderLatex(context, parts.first.content, parts.first.isDisplay);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((part) {
        if (part.isLatex) {
          return _renderLatex(context, part.content, part.isDisplay);
        } else {
          return MarkdownBody(
            data: part.content,
            shrinkWrap: true,
            softLineBreak: true,
            styleSheet: _markdownStyleSheet(context),
          );
        }
      }).toList(),
    );
  }

  Widget _renderLatex(BuildContext context, String latex, bool display) {
    // Scale up 2.5x: 16 -> 40, 20 -> 50
    try {
      return Padding(
        padding:
            display ? const EdgeInsets.symmetric(vertical: 8) : EdgeInsets.zero,
        child: Math.tex(
          latex,
          textStyle: TextStyle(
            fontSize: display ? 50 : 40,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          mathStyle: display ? MathStyle.display : MathStyle.text,
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          latex,
          style: TextStyle(
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      );
    }
  }

  List<_ContentPart> _splitLatex(String text) {
    final parts = <_ContentPart>[];
    var current = text;

    while (current.isNotEmpty) {
      final displayMatch =
          RegExp(r'\$\$(.*?)\$\$|\\\[(.*?)\\\]', dotAll: true).firstMatch(current);
      final inlineMatch =
          RegExp(r'\$([^\$]+?)\$|\\\((.*?)\\\)').firstMatch(current);

      if (displayMatch != null &&
          (inlineMatch == null || displayMatch.start <= inlineMatch.start)) {
        if (displayMatch.start > 0) {
          parts.add(_ContentPart(
              content: current.substring(0, displayMatch.start), isLatex: false));
        }
        parts.add(_ContentPart(
          content: displayMatch.group(1) ?? displayMatch.group(2) ?? '',
          isLatex: true,
          isDisplay: true,
        ));
        current = current.substring(displayMatch.end);
      } else if (inlineMatch != null) {
        if (inlineMatch.start > 0) {
          parts.add(_ContentPart(
              content: current.substring(0, inlineMatch.start), isLatex: false));
        }
        parts.add(_ContentPart(
          content: inlineMatch.group(1) ?? inlineMatch.group(2) ?? '',
          isLatex: true,
          isDisplay: false,
        ));
        current = current.substring(inlineMatch.end);
      } else {
        parts.add(_ContentPart(content: current, isLatex: false));
        break;
      }
    }

    return parts;
  }

  MarkdownStyleSheet _markdownStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    // Base size ~16, scaled up 2.5x = 40
    const double scaledBodySize = 40;
    const double scaledH1Size = 56;
    const double scaledH2Size = 48;
    const double scaledH3Size = 44;
    
    return MarkdownStyleSheet(
      p: theme.textTheme.bodyLarge?.copyWith(fontSize: scaledBodySize),
      h1: theme.textTheme.headlineLarge?.copyWith(fontSize: scaledH1Size),
      h2: theme.textTheme.headlineMedium?.copyWith(fontSize: scaledH2Size),
      h3: theme.textTheme.headlineSmall?.copyWith(fontSize: scaledH3Size),
      em: const TextStyle(fontStyle: FontStyle.italic, fontSize: scaledBodySize),
      strong: const TextStyle(fontWeight: FontWeight.bold, fontSize: scaledBodySize),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: scaledBodySize * 0.9,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _ContentPart {
  final String content;
  final bool isLatex;
  final bool isDisplay;

  _ContentPart({
    required this.content,
    required this.isLatex,
    this.isDisplay = false,
  });
}
