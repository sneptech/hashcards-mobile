import 'package:shared_preferences/shared_preferences.dart';

/// Tracks user proficiency to enable progressive difficulty.
/// Unlocks multi-word clozes as the user demonstrates competence.
class ProficiencyTracker {
  static const _totalReviewsKey = 'proficiency_total_reviews';
  static const _correctCountKey = 'proficiency_correct_count';
  
  /// Proficiency thresholds for unlocking word counts
  /// Format: (minReviews, minSuccessRate) -> maxWordCount
  static const _thresholds = [
    // (reviews, success rate) -> max words allowed
    (0, 0.0, 1),      // Start: only 1-word clozes
    (15, 0.50, 2),    // After 15 reviews with 50%+ success: allow 2-word
    (30, 0.55, 3),    // After 30 reviews with 55%+ success: allow 3-word
    (50, 0.60, 4),    // After 50 reviews with 60%+ success: allow 4-word
    (75, 0.65, 5),    // After 75 reviews with 65%+ success: allow 5-word
    (100, 0.70, 999), // After 100 reviews with 70%+ success: unlimited
  ];

  int _totalReviews = 0;
  int _correctCount = 0;
  
  int get totalReviews => _totalReviews;
  int get correctCount => _correctCount;
  
  double get successRate => _totalReviews > 0 
      ? _correctCount / _totalReviews 
      : 0.0;

  /// Load proficiency data from storage
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _totalReviews = prefs.getInt(_totalReviewsKey) ?? 0;
    _correctCount = prefs.getInt(_correctCountKey) ?? 0;
  }

  /// Save proficiency data to storage
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalReviewsKey, _totalReviews);
    await prefs.setInt(_correctCountKey, _correctCount);
  }

  /// Record a review result
  /// [wasCorrect] should be true for Easy/Medium grades, false for Hard/Forgot
  void recordReview({required bool wasCorrect}) {
    _totalReviews++;
    if (wasCorrect) {
      _correctCount++;
    }
  }

  /// Get the maximum word count allowed for cloze cards based on current proficiency
  int get maxAllowedWordCount {
    int maxWords = 1;
    
    for (final (minReviews, minSuccessRate, wordCount) in _thresholds) {
      if (_totalReviews >= minReviews && successRate >= minSuccessRate) {
        maxWords = wordCount;
      }
    }
    
    return maxWords;
  }

  /// Check if a cloze with the given word count should be shown
  bool shouldShowCloze(int wordCount) {
    return wordCount <= maxAllowedWordCount;
  }

  /// Get a description of current proficiency level
  String get levelDescription {
    final maxWords = maxAllowedWordCount;
    if (maxWords >= 999) {
      return 'Master (all cards unlocked)';
    } else if (maxWords >= 4) {
      return 'Advanced ($maxWords-word clozes)';
    } else if (maxWords >= 2) {
      return 'Intermediate ($maxWords-word clozes)';
    } else {
      return 'Beginner (single-word only)';
    }
  }
  
  /// Get progress info for UI display
  String get progressInfo {
    return '$_totalReviews reviews, ${(successRate * 100).toStringAsFixed(0)}% success';
  }
}

/// Count words in a cloze answer
int countClozeWords(String answer) {
  // Handle alternatives - use first one
  final firstAlt = answer.split(' / ').first.trim();
  // Split by whitespace and count non-empty parts
  final words = firstAlt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.length;
}
