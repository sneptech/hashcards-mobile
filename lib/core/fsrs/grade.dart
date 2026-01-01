/// The grade a user gives to a card during review.
enum Grade {
  forgot,
  hard,
  good,
  easy;

  /// Convert to numeric value (1-4) for FSRS calculations.
  double toDouble() {
    return switch (this) {
      Grade.forgot => 1.0,
      Grade.hard => 2.0,
      Grade.good => 3.0,
      Grade.easy => 4.0,
    };
  }

  /// Serialize to string for database storage.
  String toDbString() {
    return switch (this) {
      Grade.forgot => 'forgot',
      Grade.hard => 'hard',
      Grade.good => 'good',
      Grade.easy => 'easy',
    };
  }

  /// Parse from database string.
  static Grade fromDbString(String s) {
    return switch (s) {
      'forgot' => Grade.forgot,
      'hard' => Grade.hard,
      'good' => Grade.good,
      'easy' => Grade.easy,
      _ => throw ArgumentError('Invalid grade string: $s'),
    };
  }

  /// Whether this grade requires repeating the card in the same session.
  bool get shouldRepeat => this == Grade.forgot || this == Grade.hard;

  /// Display name for UI.
  String get displayName {
    return switch (this) {
      Grade.forgot => 'Forgot',
      Grade.hard => 'Hard',
      Grade.good => 'Medium',
      Grade.easy => 'Easy',
    };
  }

  /// Keyboard shortcut (1-4).
  String get shortcut {
    return switch (this) {
      Grade.forgot => '1',
      Grade.hard => '2',
      Grade.good => '3',
      Grade.easy => '4',
    };
  }
}
