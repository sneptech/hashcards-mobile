import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/crypto/card_hash.dart';
import '../../core/database/database.dart';
import '../../core/fsrs/grade.dart';
import '../../core/fsrs/performance.dart';
import '../../core/parser/card_content.dart';
import '../../core/services/proficiency_tracker.dart';
import '../collection/collection_repository.dart';

// Events
sealed class DrillEvent extends Equatable {
  const DrillEvent();
  @override
  List<Object?> get props => [];
}

class StartDrill extends DrillEvent {
  final int? cardLimit;
  final int? newCardLimit;
  final bool shuffle;

  const StartDrill({this.cardLimit, this.newCardLimit, this.shuffle = true});

  @override
  List<Object?> get props => [cardLimit, newCardLimit, shuffle];
}

class RevealCard extends DrillEvent {
  const RevealCard();
}

class GradeCard extends DrillEvent {
  final Grade grade;
  const GradeCard(this.grade);
  @override
  List<Object?> get props => [grade];
}

class UndoReview extends DrillEvent {
  const UndoReview();
}

class EndSession extends DrillEvent {
  const EndSession();
}

// States
sealed class DrillState extends Equatable {
  const DrillState();
  @override
  List<Object?> get props => [];
}

class DrillLoading extends DrillState {
  const DrillLoading();
}

class DrillError extends DrillState {
  final String message;
  const DrillError(this.message);
  @override
  List<Object?> get props => [message];
}

class DrillShowingFront extends DrillState {
  final FlashCard card;
  final int currentIndex;
  final int totalCards;
  final bool canUndo;

  const DrillShowingFront({
    required this.card,
    required this.currentIndex,
    required this.totalCards,
    required this.canUndo,
  });

  @override
  List<Object?> get props => [card.hash, currentIndex, totalCards, canUndo];
}

class DrillShowingBack extends DrillState {
  final FlashCard card;
  final int currentIndex;
  final int totalCards;
  final bool canUndo;

  const DrillShowingBack({
    required this.card,
    required this.currentIndex,
    required this.totalCards,
    required this.canUndo,
  });

  @override
  List<Object?> get props => [card.hash, currentIndex, totalCards, canUndo];
}

class DrillCompleted extends DrillState {
  final DateTime startedAt;
  final DateTime endedAt;
  final int totalReviews;
  final int uniqueCards;
  final Map<Grade, int> gradeCounts;
  final String? proficiencyLevel;
  final String? proficiencyProgress;

  const DrillCompleted({
    required this.startedAt,
    required this.endedAt,
    required this.totalReviews,
    required this.uniqueCards,
    required this.gradeCounts,
    this.proficiencyLevel,
    this.proficiencyProgress,
  });

  Duration get duration => endedAt.difference(startedAt);

  @override
  List<Object?> get props =>
      [startedAt, endedAt, totalReviews, uniqueCards, gradeCounts, proficiencyLevel];
}

// Review record during session
class _SessionReview {
  final FlashCard card;
  final DateTime reviewedAt;
  final Grade grade;
  final double stability;
  final double difficulty;
  final double intervalRaw;
  final int intervalDays;
  final DateTime dueDate;

  _SessionReview({
    required this.card,
    required this.reviewedAt,
    required this.grade,
    required this.stability,
    required this.difficulty,
    required this.intervalRaw,
    required this.intervalDays,
    required this.dueDate,
  });
}

// BLoC
class DrillBloc extends Bloc<DrillEvent, DrillState> {
  final Collection collection;
  final Map<CardHash, Performance> _cache = {};
  final List<_SessionReview> _reviews = [];
  final List<FlashCard> _cards = [];
  final ProficiencyTracker _proficiency = ProficiencyTracker();

  DateTime? _sessionStartedAt;
  int _currentIndex = 0;

  DrillBloc({required this.collection}) : super(const DrillLoading()) {
    on<StartDrill>(_onStartDrill);
    on<RevealCard>(_onRevealCard);
    on<GradeCard>(_onGradeCard);
    on<UndoReview>(_onUndoReview);
    on<EndSession>(_onEndSession);
  }
  
  /// Get word count for a card's answer (for cloze filtering)
  int _getCardWordCount(FlashCard card) {
    return switch (card.content) {
      BasicCard() => 1, // Q/A cards always allowed
      ClozeCard(:final text, :final start, :final end) =>
        countClozeWords(String.fromCharCodes(text.codeUnits.sublist(start, end + 1))),
    };
  }
  
  /// Check if a card should be shown based on proficiency
  bool _shouldShowCard(FlashCard card) {
    final wordCount = _getCardWordCount(card);
    return _proficiency.shouldShowCloze(wordCount);
  }

  Future<void> _onStartDrill(StartDrill event, Emitter<DrillState> emit) async {
    emit(const DrillLoading());
    _sessionStartedAt = DateTime.now();
    _reviews.clear();
    _cards.clear();
    _cache.clear();
    _currentIndex = 0;

    try {
      // Load proficiency to determine which cards to show
      await _proficiency.load();
      
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dueHashes = await collection.db.dueToday(todayDate);

      final dueCards = <FlashCard>[];
      final newCards = <FlashCard>[];

      for (final card in collection.cards) {
        // Filter cards based on proficiency (word count)
        if (!_shouldShowCard(card)) continue;
        
        final perf = await collection.db.getCardPerformanceOpt(card.hash);
        _cache[card.hash] = perf ?? const NewPerformance();

        if (perf == null || perf is NewPerformance) {
          newCards.add(card);
        } else if (dueHashes.contains(card.hash)) {
          dueCards.add(card);
        }
      }

      var limitedNewCards = newCards;
      if (event.newCardLimit != null && event.newCardLimit! < newCards.length) {
        limitedNewCards = newCards.sublist(0, event.newCardLimit!);
      }

      _cards.addAll(dueCards);
      _cards.addAll(limitedNewCards);

      if (event.cardLimit != null && event.cardLimit! < _cards.length) {
        _cards.removeRange(event.cardLimit!, _cards.length);
      }

      if (event.shuffle) _cards.shuffle();

      if (_cards.isEmpty) {
        emit(DrillCompleted(
          startedAt: _sessionStartedAt!,
          endedAt: DateTime.now(),
          totalReviews: 0,
          uniqueCards: 0,
          gradeCounts: {},
        ));
        return;
      }

      _emitCurrentCard(emit);
    } catch (e) {
      emit(DrillError(e.toString()));
    }
  }

  void _onRevealCard(RevealCard event, Emitter<DrillState> emit) {
    if (state is! DrillShowingFront) return;
    final frontState = state as DrillShowingFront;

    emit(DrillShowingBack(
      card: frontState.card,
      currentIndex: frontState.currentIndex,
      totalCards: frontState.totalCards,
      canUndo: frontState.canUndo,
    ));
  }

  Future<void> _onGradeCard(GradeCard event, Emitter<DrillState> emit) async {
    final FlashCard card;
    if (state is DrillShowingFront) {
      card = (state as DrillShowingFront).card;
    } else if (state is DrillShowingBack) {
      card = (state as DrillShowingBack).card;
    } else {
      return;
    }

    final now = DateTime.now();
    final currentPerf = _cache[card.hash] ?? const NewPerformance();
    final newPerf = updatePerformance(currentPerf, event.grade, now);

    _cache[card.hash] = newPerf;

    final review = _SessionReview(
      card: card,
      reviewedAt: now,
      grade: event.grade,
      stability: newPerf.stability,
      difficulty: newPerf.difficulty,
      intervalRaw: newPerf.intervalRaw,
      intervalDays: newPerf.intervalDays,
      dueDate: newPerf.dueDate,
    );
    _reviews.add(review);
    
    // Track proficiency: Easy/Medium = correct, Hard/Forgot = incorrect
    final wasCorrect = event.grade == Grade.easy || event.grade == Grade.good;
    _proficiency.recordReview(wasCorrect: wasCorrect);
    await _proficiency.save();

    if (event.grade.shouldRepeat) {
      _cards.add(card);
    }

    _currentIndex++;

    if (_currentIndex >= _cards.length) {
      await _finishSession(emit);
    } else {
      _emitCurrentCard(emit);
    }
  }

  void _onUndoReview(UndoReview event, Emitter<DrillState> emit) {
    if (_reviews.isEmpty) {
      _emitCurrentCard(emit);
      return;
    }

    final lastReview = _reviews.removeLast();

    Performance previousPerf = const NewPerformance();
    for (final review in _reviews.reversed) {
      if (review.card.hash == lastReview.card.hash) {
        previousPerf = ReviewedPerformance(
          lastReviewedAt: review.reviewedAt,
          stability: review.stability,
          difficulty: review.difficulty,
          intervalRaw: review.intervalRaw,
          intervalDays: review.intervalDays,
          dueDate: review.dueDate,
          reviewCount: 1,
        );
        break;
      }
    }
    _cache[lastReview.card.hash] = previousPerf;

    if (lastReview.grade.shouldRepeat && _cards.isNotEmpty) {
      for (var i = _cards.length - 1; i >= _currentIndex; i--) {
        if (_cards[i].hash == lastReview.card.hash) {
          _cards.removeAt(i);
          break;
        }
      }
    }

    _currentIndex--;
    if (_currentIndex < 0) _currentIndex = 0;

    _emitCurrentCard(emit);
  }

  Future<void> _onEndSession(EndSession event, Emitter<DrillState> emit) async {
    await _finishSession(emit);
  }

  Future<void> _finishSession(Emitter<DrillState> emit) async {
    final endedAt = DateTime.now();

    if (_reviews.isNotEmpty) {
      for (final card in collection.cards) {
        final perf = _cache[card.hash];
        if (perf != null && perf is ReviewedPerformance) {
          await collection.db.updateCardPerformance(card.hash, perf);
        }
      }

      final records = _reviews
          .map((r) => ReviewRecord(
                cardHash: r.card.hash,
                reviewedAt: r.reviewedAt,
                grade: r.grade,
                stability: r.stability,
                difficulty: r.difficulty,
                intervalRaw: r.intervalRaw,
                intervalDays: r.intervalDays,
                dueDate: r.dueDate,
              ))
          .toList();

      await collection.db.saveSession(_sessionStartedAt!, endedAt, records);
    }

    final uniqueCards = _reviews.map((r) => r.card.hash).toSet().length;
    final gradeCounts = <Grade, int>{};
    for (final review in _reviews) {
      gradeCounts[review.grade] = (gradeCounts[review.grade] ?? 0) + 1;
    }

    emit(DrillCompleted(
      startedAt: _sessionStartedAt!,
      endedAt: endedAt,
      totalReviews: _reviews.length,
      uniqueCards: uniqueCards,
      gradeCounts: gradeCounts,
      proficiencyLevel: _proficiency.levelDescription,
      proficiencyProgress: _proficiency.progressInfo,
    ));
  }

  void _emitCurrentCard(Emitter<DrillState> emit) {
    if (_currentIndex >= _cards.length) {
      emit(DrillCompleted(
        startedAt: _sessionStartedAt!,
        endedAt: DateTime.now(),
        totalReviews: _reviews.length,
        uniqueCards: _reviews.map((r) => r.card.hash).toSet().length,
        gradeCounts: {},
      ));
      return;
    }

    final card = _cards[_currentIndex];

    emit(DrillShowingFront(
      card: card,
      currentIndex: _currentIndex,
      totalCards: _cards.length,
      canUndo: _reviews.isNotEmpty,
    ));
  }
}
