import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/fsrs/grade.dart';
import '../../core/parser/card_content.dart';
import '../../widgets/card_renderer.dart';
import '../collection/collection_bloc.dart';
import 'drill_bloc.dart';

class DrillScreen extends StatelessWidget {
  const DrillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final collectionState = context.read<CollectionBloc>().state;
    if (collectionState is! CollectionLoaded) {
      return const Scaffold(body: Center(child: Text('No collection loaded')));
    }

    return BlocProvider(
      create: (context) =>
          DrillBloc(collection: collectionState.collection)..add(const StartDrill()),
      child: const _DrillScreenContent(),
    );
  }
}

class _DrillScreenContent extends StatefulWidget {
  const _DrillScreenContent();

  @override
  State<_DrillScreenContent> createState() => _DrillScreenContentState();
}

class _DrillScreenContentState extends State<_DrillScreenContent> {
  // Key to access CardRenderer state
  final GlobalKey<CardRendererState> _cardRendererKey = GlobalKey();
  
  // Track answer state
  String? _userAnswer;
  AnswerResult _answerResult = AnswerResult.notChecked;
  String? _differenceHint;
  bool _answerChecked = false;

  void _resetAnswerState() {
    setState(() {
      _userAnswer = null;
      _answerResult = AnswerResult.notChecked;
      _differenceHint = null;
      _answerChecked = false;
    });
  }

  void _onAnswerSubmitted(String answer, AnswerCheckResult result) {
    setState(() {
      _userAnswer = answer;
      _answerResult = result.result;
      _differenceHint = result.differenceHint;
      _answerChecked = true;
    });
  }

  void _checkAnswer() {
    _cardRendererKey.currentState?.submitAnswer();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DrillBloc, DrillState>(
      listener: (context, state) {
        // Reset answer state when card changes
        if (state is DrillShowingFront) {
          _resetAnswerState();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: _buildTitle(state),
            actions: [
              if (state is DrillShowingFront || state is DrillShowingBack)
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () =>
                      context.read<DrillBloc>().add(const EndSession()),
                  tooltip: 'End session',
                ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildTitle(DrillState state) {
    return switch (state) {
      DrillLoading() => const Text('Loading...'),
      DrillError() => const Text('Error'),
      DrillShowingFront(:final currentIndex, :final totalCards) ||
      DrillShowingBack(:final currentIndex, :final totalCards) =>
        Text('Card ${currentIndex + 1} of $totalCards'),
      DrillCompleted() => const Text('Session Complete'),
    };
  }

  Widget _buildBody(BuildContext context, DrillState state) {
    return switch (state) {
      DrillLoading() => const Center(child: CircularProgressIndicator()),
      DrillError(:final message) => Center(child: Text('Error: $message')),
      DrillShowingFront(:final card, :final canUndo) =>
        _buildCardView(context, card, false, canUndo),
      DrillShowingBack(:final card, :final canUndo) =>
        _buildCardView(context, card, true, canUndo),
      DrillCompleted() => _buildCompletedView(context, state),
    };
  }

  Widget _buildCardView(
      BuildContext context, FlashCard card, bool showBack, bool canUndo) {
    // Show input when not showing back and answer hasn't been checked yet
    final showInput = !showBack && !_answerChecked;

    return Column(
      children: [
        // Deck name header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            card.deckName,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        // Card content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: CardRenderer(
              key: _cardRendererKey,
              card: card,
              showBack: showBack,
              interactive: showInput,
              onAnswerSubmitted: _onAnswerSubmitted,
              userAnswer: _userAnswer,
              answerResult: _answerResult,
              differenceHint: _differenceHint,
            ),
          ),
        ),
        // Bottom buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBottomButtons(context, card, showBack, canUndo),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(
      BuildContext context, FlashCard card, bool showBack, bool canUndo) {
    if (showBack) {
      // Answer revealed - show grade buttons
      return _buildGradeButtons(context, canUndo);
    } else if (_answerChecked) {
      // Answer checked - show grade buttons
      return _buildGradeButtons(context, canUndo);
    } else {
      // Waiting for input - show submit button and skip option
      return _buildInputButtons(context, canUndo);
    }
  }

  Widget _buildInputButtons(BuildContext context, bool canUndo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Submit button - actually checks the answer now!
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _checkAnswer,
            icon: const Icon(Icons.check),
            label: const Text('Check Answer'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Skip button
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<DrillBloc>().add(const RevealCard());
                },
                icon: const Icon(Icons.visibility),
                label: const Text("Don't Know"),
              ),
            ),
            if (canUndo) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () =>
                    context.read<DrillBloc>().add(const UndoReview()),
                icon: const Icon(Icons.undo),
                tooltip: 'Undo',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGradeButtons(BuildContext context, bool canUndo) {
    // If we just checked an answer, suggest a grade based on correctness
    Widget? suggestionBanner;
    if (_answerChecked) {
      final isCorrect = _answerResult == AnswerResult.correct;
      final isAlmostCorrect = _answerResult == AnswerResult.almostCorrect;
      
      Color bgColor;
      Color textColor;
      String message;
      
      if (isCorrect) {
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        message = 'Great job! How easy was it to recall?';
      } else if (isAlmostCorrect) {
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        message = 'So close! Just a small mistake. How well did you know it?';
      } else {
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        message = 'Review the correct answer above. How well did you know it?';
      }
      
      suggestionBanner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          style: TextStyle(color: textColor),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (suggestionBanner != null) suggestionBanner,
        Row(
          children: [
            Expanded(
                child: _GradeButton(grade: Grade.forgot, color: const Color(0xFFDD4231))),
            const SizedBox(width: 8),
            Expanded(
                child: _GradeButton(grade: Grade.hard, color: const Color(0xFFFF902A))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _GradeButton(grade: Grade.good, color: const Color(0xFFF8E210))),
            const SizedBox(width: 8),
            Expanded(
                child: _GradeButton(grade: Grade.easy, color: const Color(0xFF3CB71A))),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.read<DrillBloc>().add(const UndoReview()),
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
      ],
    );
  }

  Widget _buildCompletedView(BuildContext context, DrillCompleted state) {
    final duration = state.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration,
                size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text('Session Complete!',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _StatRow(
                        label: 'Cards Reviewed', value: '${state.uniqueCards}'),
                    const Divider(),
                    _StatRow(
                        label: 'Total Reviews', value: '${state.totalReviews}'),
                    const Divider(),
                    _StatRow(
                        label: 'Duration',
                        value:
                            '$minutes:${seconds.toString().padLeft(2, '0')}'),
                    if (state.proficiencyLevel != null) ...[
                      const Divider(),
                      _StatRow(
                          label: 'Level', value: state.proficiencyLevel!),
                    ],
                    if (state.proficiencyProgress != null) ...[
                      const Divider(),
                      _StatRow(
                          label: 'Progress', value: state.proficiencyProgress!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('Back to Collection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  final Grade grade;
  final Color color;

  const _GradeButton({required this.grade, required this.color});

  @override
  Widget build(BuildContext context) {
    // Use dark text for light backgrounds (yellow/Medium button)
    final textColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    
    return ElevatedButton(
      onPressed: () => context.read<DrillBloc>().add(GradeCard(grade)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(grade.displayName),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
