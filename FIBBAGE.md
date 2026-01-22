# Fibbage - Implementation Plan

> **Game Type:** Bluffing / Trivia
> **Min Players:** 3 | **Max Players:** 8
> **Round Time:** 60 seconds (writing) + 30 seconds (voting)

---

## Game Overview

**Fibbage** is a bluffing party game where players try to fool each other with fake answers to obscure trivia questions.

### Core Mechanics
- Host shows a trivia question with a blank (e.g., "The world's largest ____ weighs 500 pounds")
- Each player submits a fake answer to fill in the blank
- All answers (fakes + the real answer) are shuffled and displayed
- Players vote for what they think is the REAL answer
- Points for guessing correctly AND for fooling others with your fake

---

## Game Flow

### Phase 1: Writing (60 seconds)
- All players see the question with blank
- Each player writes a believable fake answer
- Host display shows submission progress

### Phase 2: Voting (30 seconds)
- All answers shown (shuffled, including real answer)
- Players vote for what they think is real
- Can't vote for your own fake answer

### Phase 3: Reveal
- Show the real answer
- Show who wrote each fake
- Show who got fooled by each fake
- Award points

---

## Scoring

| Action | Points |
|--------|--------|
| Guess the real answer | +200 |
| Fool another player | +100 per player |
| Nobody guesses real answer | +50 bonus to all fakers |

---

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/games/fibbage.gd` | Main game logic |
| `scenes/games/fibbage/fibbage.tscn` | Game scene |
| `data/prompts/fibbage_questions.json` | Questions with blanks and answers |
| `web-player/js/games/fibbage.js` | Web player interface |

---

## Message Protocol

### Host → Players
```
fibbage_init        - Game setup, player order
fibbage_question    - Question text with blank
fibbage_vote_start  - All answers to vote on
fibbage_reveal      - Real answer + who fooled who
fibbage_round_end   - Scores
fibbage_end         - Final results
```

### Players → Host
```
fibbage_answer      - Submit fake answer
fibbage_vote        - Vote for an answer
```

---

## Question Format

```json
{
  "questions": [
    {
      "text": "The world's largest _____ weighs over 500 pounds.",
      "answer": "potato",
      "category": "food"
    },
    {
      "text": "In 1932, Australia declared war on _____.",
      "answer": "emus",
      "category": "history"
    }
  ]
}
```

---

## Implementation Checklist

- [ ] Create `fibbage_questions.json` with 50+ questions
- [ ] Create `fibbage.gd` with game logic
- [ ] Create `fibbage.tscn` scene
- [ ] Create `fibbage.js` for web player
- [ ] Add to game select screen
- [ ] Test with 3+ players

---

*Last Updated: 2026-01-22*
