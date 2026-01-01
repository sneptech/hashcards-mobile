import 'package:equatable/equatable.dart';

import 'fsrs.dart';
import 'grade.dart';

/// The desired recall probability.
const double targetRecall = 0.9;

/// The minimum review interval in days.
const double minInterval = 1.0;

/// The maximum review interval in days.
const double maxInterval = 256.0;

/// Represents performance information for a card.
sealed class Performance extends Equatable {
  const Performance();

  bool get isNew => this is NewPerformance;
}

/// A card that has never been reviewed.
class NewPerformance extends Performance {
  const NewPerformance();

  @override
  List<Object?> get props => [];
}

/// A card that has been reviewed at least once.
class ReviewedPerformance extends Performance {
  final DateTime lastReviewedAt;
  final Stability stability;
  final Difficulty difficulty;
  final Interval intervalRaw;
  final int intervalDays;
  final DateTime dueDate;
  final int reviewCount;

  const ReviewedPerformance({
    required this.lastReviewedAt,
    required this.stability,
    required this.difficulty,
    required this.intervalRaw,
    required this.intervalDays,
    required this.dueDate,
    required this.reviewCount,
  });

  @override
  List<Object?> get props => [
        lastReviewedAt,
        stability,
        difficulty,
        intervalRaw,
        intervalDays,
        dueDate,
        reviewCount,
      ];

  ReviewedPerformance copyWith({
    DateTime? lastReviewedAt,
    Stability? stability,
    Difficulty? difficulty,
    Interval? intervalRaw,
    int? intervalDays,
    DateTime? dueDate,
    int? reviewCount,
  }) {
    return ReviewedPerformance(
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      intervalRaw: intervalRaw ?? this.intervalRaw,
      intervalDays: intervalDays ?? this.intervalDays,
      dueDate: dueDate ?? this.dueDate,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }
}

/// Update card performance after a review.
ReviewedPerformance updatePerformance(
  Performance perf,
  Grade grade,
  DateTime reviewedAt,
) {
  final today = DateTime(reviewedAt.year, reviewedAt.month, reviewedAt.day);

  final (Stability stab, Difficulty diff, int count) = switch (perf) {
    NewPerformance() => (
        initialStability(grade),
        initialDifficulty(grade),
        0,
      ),
    ReviewedPerformance(
      :final lastReviewedAt,
      stability: final oldStability,
      difficulty: final oldDifficulty,
      reviewCount: final oldReviewCount,
    ) =>
      () {
        final lastReviewDate = DateTime(
          lastReviewedAt.year,
          lastReviewedAt.month,
          lastReviewedAt.day,
        );
        final time = today.difference(lastReviewDate).inDays.toDouble();
        final retr = retrievability(time, oldStability);
        final newStab = newStability(oldDifficulty, oldStability, retr, grade);
        final newDiff = newDifficulty(oldDifficulty, grade);
        return (newStab, newDiff, oldReviewCount);
      }(),
  };

  final intervalRaw = interval(targetRecall, stab);
  final intervalRounded = intervalRaw.roundToDouble();
  final intervalClamped = intervalRounded.clamp(minInterval, maxInterval);
  final intervalDays = intervalClamped.toInt();
  final dueDate = today.add(Duration(days: intervalDays));

  return ReviewedPerformance(
    lastReviewedAt: reviewedAt,
    stability: stab,
    difficulty: diff,
    intervalRaw: intervalRaw,
    intervalDays: intervalDays,
    dueDate: dueDate,
    reviewCount: count + 1,
  );
}
