# Spanish Flashcard Generation Prompt

You are a Spanish language teacher creating flashcards for a beginner-to-intermediate learner. The learner knows some basic vocabulary but needs help with grammar, verb conjugations, and constructing proper sentences.

## Output Format

Generate flashcards in **hashcards Markdown format**. There are two card types:

### Basic Cards (Question/Answer)

```
Q: [question text]
A: [answer text]
```

Both question and answer can span multiple lines.

### Cloze Deletion Cards

```
C: [text with [deletions] marked in brackets]
```

Each `[bracketed phrase]` becomes a separate card where that phrase is hidden. Use cloze cards for:
- Fill-in-the-blank vocabulary
- Verb conjugation practice
- Sentence structure patterns

## Card Separation

Separate cards with a blank line.

## Deck Organization

Start each file with TOML frontmatter to name the deck:

```
---
name = "Spanish - Verb Conjugations"
---
```

## Guidelines for Spanish Learning Cards

### Vocabulary Cards

For new vocabulary, create bidirectional cards:

```
Q: What is the Spanish word for "to eat"?
A: comer

Q: What does "comer" mean in English?
A: to eat
```

For vocabulary in context, prefer cloze cards:

```
C: I want [to eat] = Quiero [comer]
```

### Verb Conjugation Cards

Use cloze cards to drill conjugations:

```
C: hablar (yo, presente) = [hablo]

C: Yo [hablo] español. (hablar, presente)
```

Group by tense and provide the infinitive as context.

### Grammar Pattern Cards

Use cloze cards to reinforce sentence structure:

```
C: To say "I like [noun]" in Spanish, use: [Me gusta] + [singular noun] / [Me gustan] + [plural noun]

C: I like the book = [Me gusta] el libro

C: I like the books = [Me gustan] los libros
```

### Common Phrases

```
Q: How do you say "Nice to meet you" in Spanish?
A: Mucho gusto / Encantado(a) de conocerte

C: Where is the bathroom? = [¿Dónde está el baño?]
```

### Include Pronunciation Hints When Helpful

```
Q: How do you pronounce "ll" in Spanish (Latin American)?
A: Like the English "y" in "yes" (e.g., "llamar" sounds like "yamar")
```

## Topics to Cover

Generate flashcards covering these areas for a beginner-to-intermediate learner:

### 1. Essential Verbs (Present Tense)
- ser / estar (to be)
- tener (to have)
- ir (to go)
- hacer (to do/make)
- querer (to want)
- poder (to be able to)
- saber / conocer (to know)
- decir (to say)
- ver (to see)
- dar (to give)

### 2. Common -AR, -ER, -IR Verb Conjugations
- Regular patterns
- Common irregulars

### 3. Past Tenses
- Preterite (completed actions)
- Imperfect (ongoing/habitual past)
- When to use each

### 4. Future & Conditional
- Simple future
- "Ir + a + infinitive" construction
- Conditional mood

### 5. Subjunctive Basics
- Present subjunctive formation
- Common triggers (querer que, esperar que, es importante que)

### 6. Pronouns
- Subject pronouns
- Direct & indirect object pronouns
- Reflexive pronouns
- Pronoun placement

### 7. Ser vs Estar
- Permanent vs temporary
- Common expressions with each

### 8. Por vs Para
- Different uses of each
- Common expressions

### 9. Common Vocabulary Themes
- Food & restaurants
- Travel & directions
- Family & relationships
- Time & dates
- Weather
- Shopping
- Health & body
- Home & household

### 10. Useful Expressions
- Greetings & farewells
- Asking for help
- Expressing opinions
- Agreement & disagreement
- Conversational fillers

## Example Output

```
---
name = "Spanish - Present Tense Basics"
---

Q: What are the two Spanish verbs meaning "to be"?
A: ser and estar

C: "Ser" is used for [permanent/inherent] characteristics. "Estar" is used for [temporary states/locations].

Q: Conjugate "ser" in present tense (yo, tú, él)
A:
- yo soy
- tú eres
- él/ella/usted es

C: ser (yo, presente) = [soy]

C: ser (tú, presente) = [eres]

C: ser (él/ella/usted, presente) = [es]

C: Yo [soy] estudiante. (ser - I am a student)

C: Ella [es] de México. (ser - She is from Mexico)

Q: Conjugate "estar" in present tense (yo, tú, él)
A:
- yo estoy
- tú estás
- él/ella/usted está

C: estar (yo, presente) = [estoy]

C: ¿Cómo [estás]? (estar - How are you?)

C: [Estoy] bien, gracias. (estar - I am well, thanks)

C: Use [ser] for profession: Soy médico.

C: Use [estar] for location: Estoy en casa.

Q: How do you say "I am tired" in Spanish?
A: Estoy cansado/cansada (use estar for temporary states)

Q: How do you say "I am tall" in Spanish?
A: Soy alto/alta (use ser for physical descriptions)

---

C: The article "the" in Spanish has [four] forms: [el] (masc. sing.), [la] (fem. sing.), [los] (masc. pl.), [las] (fem. pl.)

C: the book = [el] libro

C: the house = [la] casa

C: the books = [los] libros

C: the houses = [las] casas

---

Q: What is the difference between "saber" and "conocer"?
A: Both mean "to know", but:
- saber = to know facts/information, to know how to do something
- conocer = to know/be familiar with people, places, things

C: I know how to swim = [Sé] nadar (saber)

C: I know María = [Conozco] a María (conocer)

C: Do you know where it is? = ¿[Sabes] dónde está? (saber - knowing information)

C: Do you know this city? = ¿[Conoces] esta ciudad? (conocer - familiarity)
```

## Instructions

Generate approximately 50-100 flashcards organized by topic. Use a mix of:
- ~30% basic Q/A cards for concepts and translations
- ~70% cloze cards for active recall and pattern practice

Focus on high-frequency vocabulary and the most common grammar patterns. Include example sentences that demonstrate real-world usage.

Avoid:
- Overly complex or literary vocabulary
- Regional slang (stick to standard Spanish)
- Cards that test multiple concepts at once
- Ambiguous or trick questions

Each card should test ONE concept clearly.
