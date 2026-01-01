/// FSRS (Free Spaced Repetition Scheduler) algorithm implementation.
/// This is an exact port of the Rust implementation in hashcards/src/fsrs.rs
library;

import 'dart:math' as math;

import 'grade.dart';

/// FSRS weight parameters (default values from FSRS-5).
/// These MUST match exactly the values in hashcards Rust implementation.
const List<double> w = [
  0.40255, // w[0]
  1.18385, // w[1]
  3.173, // w[2]
  15.69105, // w[3]
  7.1949, // w[4]
  0.5345, // w[5]
  1.4604, // w[6]
  0.0046, // w[7]
  1.54575, // w[8]
  0.1192, // w[9]
  1.01925, // w[10]
  1.9395, // w[11]
  0.11, // w[12]
  0.29605, // w[13]
  2.2698, // w[14]
  0.2315, // w[15]
  2.9898, // w[16]
  0.51655, // w[17]
  0.6621, // w[18]
];

/// Type aliases for clarity
typedef Recall = double;
typedef Stability = double;
typedef Difficulty = double;
typedef Interval = double;

/// Constants for retrievability calculation.
const double _f = 19.0 / 81.0;
const double _c = -0.5;

/// Calculate the probability of recall given time elapsed and stability.
Recall retrievability(Interval t, Stability s) {
  return math.pow(1.0 + _f * (t / s), _c).toDouble();
}

/// Calculate the optimal interval for a target recall probability.
Interval interval(Recall rD, Stability s) {
  return (s / _f) * (math.pow(rD, 1.0 / _c) - 1.0);
}

/// Calculate initial stability for a new card based on first grade.
Stability initialStability(Grade g) {
  return switch (g) {
    Grade.forgot => w[0],
    Grade.hard => w[1],
    Grade.good => w[2],
    Grade.easy => w[3],
  };
}

/// Calculate initial difficulty for a new card based on first grade.
Difficulty initialDifficulty(Grade g) {
  final gVal = g.toDouble();
  return _clampD(w[4] - math.exp(w[5] * (gVal - 1.0)) + 1.0);
}

/// Calculate new stability after a successful review (not forgot).
Stability _sSuccess(Difficulty d, Stability s, Recall r, Grade g) {
  final tD = 11.0 - d;
  final tS = math.pow(s, -w[9]);
  final tR = math.exp(w[10] * (1.0 - r)) - 1.0;
  final h = g == Grade.hard ? w[15] : 1.0;
  final b = g == Grade.easy ? w[16] : 1.0;
  final c = math.exp(w[8]);
  final alpha = 1.0 + tD * tS * tR * h * b * c;
  return s * alpha;
}

/// Calculate new stability after forgetting.
Stability _sFail(Difficulty d, Stability s, Recall r) {
  final dF = math.pow(d, -w[12]);
  final sF1 = math.pow(s + 1.0, w[13]) - 1.0;
  final rF = math.exp(w[14] * (1.0 - r));
  final cF = w[11];
  final sF = dF * sF1 * rF * cF;
  return math.min(sF, s);
}

/// Calculate new stability based on grade.
Stability newStability(Difficulty d, Stability s, Recall r, Grade g) {
  if (g == Grade.forgot) {
    return _sFail(d, s, r);
  } else {
    return _sSuccess(d, s, r, g);
  }
}

/// Clamp difficulty to valid range [1, 10].
Difficulty _clampD(Difficulty d) {
  return d.clamp(1.0, 10.0);
}

/// Calculate new difficulty after a review.
Difficulty newDifficulty(Difficulty d, Grade g) {
  return _clampD(
    w[7] * initialDifficulty(Grade.easy) + (1.0 - w[7]) * _dp(d, g),
  );
}

/// Helper for difficulty calculation.
double _dp(Difficulty d, Grade g) {
  return d + _deltaD(g) * ((10.0 - d) / 9.0);
}

/// Calculate difficulty delta based on grade.
double _deltaD(Grade g) {
  final gVal = g.toDouble();
  return -w[6] * (gVal - 3.0);
}
