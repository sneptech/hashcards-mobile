# Hashcards Mobile

A plain-text spaced repetition flashcard app for Android and iOS. Study smarter with scientifically-proven FSRS scheduling and progressive difficulty that adapts to your skill level.

## Features

### Smart Spaced Repetition
- **FSRS Algorithm** - Uses the Free Spaced Repetition Scheduler for optimal review timing
- **Adaptive Scheduling** - Cards you struggle with appear more often; easy cards space out
- **Progress Tracking** - Tracks your reviews, success rate, and proficiency level

### Progressive Difficulty
New users start with simple single-word fill-in-the-blank cards. As you demonstrate proficiency, harder multi-word cards are gradually unlocked:

| Reviews | Success Rate | Unlocks |
|---------|--------------|---------|
| 0+ | Any | 1-word clozes |
| 15+ | 50%+ | 2-word clozes |
| 30+ | 55%+ | 3-word clozes |
| 50+ | 60%+ | 4-word clozes |
| 75+ | 65%+ | 5-word clozes |
| 100+ | 70%+ | All cards |

### Interactive Answer Checking
- **Type your answers** - Active recall beats passive review
- **Case-insensitive** - "Hola" = "hola" = "HOLA"
- **Almost correct detection** - Catches accent mistakes like `mañana` vs `manana`
- **Alternative answers** - Accepts multiple correct answers (e.g., `gustar / encantar`)
- **Word count hints** - Shows "Type 2 words..." when multi-word answers are expected

### Plain-Text Flashcard Format
Create flashcards in simple Markdown files:

```markdown
---
name = "Spanish Vocabulary"
---

Q: "hello" in Spanish?
A: hola

Q: "good morning" in Spanish? (2 words)
A: buenos días

C: Yo [tengo] hambre. (I am hungry.)

C: Me llamo [María]. (My name is María.)
```

**Card Types:**
- `Q:` / `A:` - Question and answer cards
- `C:` - Cloze deletion cards with `[brackets]` around the hidden word

### Rendering
- **Markdown support** - Bold, italic, lists, etc.
- **LaTeX math** - Inline `$x^2$` and display `$$\sum_{i=1}^n$$` equations
- **Large readable text** - Optimized for mobile studying

## Getting Started

### Prerequisites
- Flutter SDK 3.10.4 or higher
- Android Studio / Xcode / VS Code with Flutter extension for device deployment

### Installation

```bash
# Clone the repository
git clone https://github.com/sneptech/hashcards-flutter.git
cd hashcards-flutter

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

### Bundled Decks
The app comes with a comprehensive Spanish vocabulary deck pre-installed. On first launch, it's automatically copied to your device.

### Creating Your Own Decks

1. Create a `.md` file with your flashcards
2. Add optional TOML frontmatter for the deck name:
   ```markdown
   ---
   name = "My Custom Deck"
   ---
   ```
3. Add cards using Q/A or Cloze format
4. Place the file in the app's documents directory

## Project Structure

```
lib/
├── core/
│   ├── crypto/        # Card hashing (content-addressed)
│   ├── database/      # SQLite for review history
│   ├── fsrs/          # Spaced repetition algorithm
│   ├── parser/        # Markdown card parser
│   └── services/      # Deck initialization, proficiency tracking
├── features/
│   ├── collection/    # Deck loading and management
│   └── drill/         # Review session UI and logic
├── widgets/
│   └── card_renderer.dart  # Card display with Markdown/LaTeX
└── main.dart
```

## Tech Stack

- **Flutter** - Cross-platform UI
- **flutter_bloc** - State management
- **sqflite** - Local SQLite database
- **flutter_markdown** - Markdown rendering
- **flutter_math_fork** - LaTeX math rendering
- **FSRS** - Spaced repetition scheduling

## Grading

After viewing each card, grade your recall:

| Grade | Color | Effect |
|-------|-------|--------|
| **Forgot** | Red | Card repeats soon |
| **Hard** | Orange | Card repeats soon |
| **Medium** | Yellow | Normal scheduling |
| **Easy** | Green | Longer interval |

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- FSRS algorithm by [open-spaced-repetition](https://github.com/open-spaced-repetition/fsrs4anki)
- Inspired by [Anki](https://apps.ankiweb.net/) and plain-text note-taking tools
