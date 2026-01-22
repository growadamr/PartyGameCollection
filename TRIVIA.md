# Trivia Showdown - Implementation Plan

> **Game Type:** Multiple Choice Quiz
> **Min Players:** 2
> **Max Players:** 8
> **Round Duration:** 15 seconds per question

---

## Table of Contents

1. [Game Overview](#game-overview)
2. [Game Flow](#game-flow)
3. [Scoring System](#scoring-system)
4. [Message Protocol](#message-protocol)
5. [Implementation Tasks](#implementation-tasks)
6. [File Structure](#file-structure)
7. [Progress Tracker](#progress-tracker)

---

## Game Overview

Trivia Showdown is a fast-paced quiz game where all players compete to answer multiple-choice trivia questions. The faster you answer correctly, the more points you earn. Questions come from various categories, and each round consists of 10 questions.

### Core Features
- **Multiple Choice:** 4 answer options per question (A, B, C, D)
- **Speed Bonus:** Faster correct answers earn more points
- **Category Variety:** Questions from 6+ categories
- **Real-time Feedback:** See who answered after each question
- **Leaderboard Updates:** Running scores shown between questions

---

## Game Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     GAME PHASES                              │
└─────────────────────────────────────────────────────────────┘

1. PRE_ROUND (Ready Up)
   └─> All players press "Ready" to start
   └─> Shows round number and category preview

2. QUESTION_DISPLAY (2 seconds)
   └─> Question appears on host display
   └─> Players see question + 4 answer buttons
   └─> Timer starts

3. ANSWERING (15 seconds countdown)
   └─> Players tap their answer choice
   └─> First answer is locked (no changing)
   └─> Host shows how many have answered
   └─> Timer counts down

4. REVEAL (3 seconds)
   └─> Correct answer highlighted
   └─> Show who got it right/wrong
   └─> Display points earned (with speed bonus)

5. LEADERBOARD (3 seconds)
   └─> Show current standings
   └─> Highlight position changes

6. Repeat steps 2-5 for each question (10 questions per round)

7. ROUND_END
   └─> Show round summary
   └─> Display winner of round
   └─> "Ready Up" for next round or end game

8. GAME_END (after 3 rounds)
   └─> Final leaderboard
   └─> Crown the winner
   └─> Return to lobby
```

### Host Display States
| State | Host Shows |
|-------|-----------|
| Pre-Round | "Round X - Get Ready!" + ready count |
| Question | Question text + 4 large answer options + timer |
| Answering | Answer count indicator (X/Y answered) |
| Reveal | Correct answer highlighted, player results |
| Leaderboard | Ranked player list with scores |
| Game End | Winner celebration + final scores |

### Player Display States
| State | Player Shows |
|-------|-------------|
| Pre-Round | "Ready!" button |
| Question | Question + 4 tappable answer buttons |
| Answered | "Answer Locked!" with selected option shown |
| Reveal | Their result (correct/wrong) + points earned |
| Leaderboard | Their rank and score |

---

## Scoring System

### Base Points
- **Correct Answer:** 100 points base

### Speed Bonus
Points scale based on how quickly you answer (out of 15 seconds):
```
Speed Bonus = floor((time_remaining / 15) * 100)

Examples:
- Answer in 1 second:  +93 bonus (193 total)
- Answer in 5 seconds: +67 bonus (167 total)
- Answer in 10 seconds: +33 bonus (133 total)
- Answer in 14 seconds: +7 bonus (107 total)
- Answer at 15 seconds: +0 bonus (100 total)
```

### Wrong/No Answer
- **Wrong Answer:** 0 points
- **No Answer (timeout):** 0 points

### Streak Bonus (Optional Enhancement)
- 3 correct in a row: +10% bonus
- 5 correct in a row: +25% bonus
- 10 correct in a row: +50% bonus

---

## Message Protocol

### Host → All Players

```json
// Game initialization
{
  "type": "trivia_init",
  "total_rounds": 3,
  "questions_per_round": 10,
  "time_per_question": 15,
  "player_order": ["uuid1", "uuid2", ...]
}

// Pre-round ready phase
{
  "type": "trivia_pre_round",
  "round": 1,
  "category_hint": "Mixed Categories",
  "ready_players": ["uuid1"]
}

// Ready status update
{
  "type": "trivia_ready_status",
  "ready_players": ["uuid1", "uuid2"],
  "ready_count": 2,
  "players_needed": 4
}

// Question display
{
  "type": "trivia_question",
  "question_num": 1,
  "total_questions": 10,
  "category": "Science",
  "question": "What is the chemical symbol for gold?",
  "answers": ["Au", "Ag", "Fe", "Cu"],
  "time_limit": 15
}

// Answer count update (during answering phase)
{
  "type": "trivia_answer_count",
  "answered": 3,
  "total": 4
}

// Question result reveal
{
  "type": "trivia_reveal",
  "correct_answer_index": 0,
  "correct_answer": "Au",
  "player_results": {
    "uuid1": {"answered": 0, "correct": true, "points": 167, "time": 5.2},
    "uuid2": {"answered": 2, "correct": false, "points": 0, "time": 8.1},
    "uuid3": {"answered": -1, "correct": false, "points": 0, "time": null}
  }
}

// Leaderboard update
{
  "type": "trivia_leaderboard",
  "standings": [
    {"player_id": "uuid1", "name": "Alice", "score": 534, "rank": 1, "change": 0},
    {"player_id": "uuid2", "name": "Bob", "score": 412, "rank": 2, "change": 1}
  ],
  "question_num": 5,
  "total_questions": 10
}

// Round end
{
  "type": "trivia_round_end",
  "round": 1,
  "round_winner": "uuid1",
  "round_winner_name": "Alice",
  "round_scores": {...}
}

// Game end
{
  "type": "trivia_end",
  "winner_id": "uuid1",
  "winner_name": "Alice",
  "final_scores": {...},
  "stats": {
    "most_correct": "uuid1",
    "fastest_average": "uuid2",
    "best_streak": "uuid3"
  }
}
```

### Player → Host

```json
// Player ready
{
  "type": "trivia_ready",
  "player_id": "uuid1"
}

// Player answer
{
  "type": "trivia_answer",
  "player_id": "uuid1",
  "answer_index": 0,
  "time_taken": 5.2
}
```

---

## Implementation Tasks

### Phase 1: Data & Questions
1. [ ] Create `trivia_questions.json` with question bank
   - Minimum 100 questions across 6 categories
   - Categories: Science, History, Geography, Entertainment, Sports, General Knowledge
   - JSON structure with question, 4 answers, correct index, category, difficulty
2. [ ] Create question loader utility in GDScript

### Phase 2: Host Game Logic (Godot)
3. [ ] Create `trivia_showdown.gd` extending BaseGame
4. [ ] Implement game state machine (pre_round, question, answering, reveal, leaderboard)
5. [ ] Implement question selection (random, no repeats)
6. [ ] Implement answer collection and validation
7. [ ] Implement scoring with speed bonus calculation
8. [ ] Implement round/game progression
9. [ ] Create host UI scene `trivia_showdown_host.tscn`
   - Question display panel
   - Answer options display
   - Timer visualization
   - Player answer indicators
   - Leaderboard panel

### Phase 3: Player Interface (Godot - if needed)
10. [ ] Create player UI scene `trivia_showdown_player.tscn`
    - Ready button
    - Question display
    - 4 answer buttons (large, touch-friendly)
    - Result feedback

### Phase 4: Web Player Interface
11. [ ] Create `trivia.js` game handler
    - Socket event handlers for all trivia messages
    - Answer button interactions
    - Timer display
    - Result/leaderboard views
12. [ ] Add HTML structure to `index.html` for trivia game views
13. [ ] Add CSS styling for trivia UI elements

### Phase 5: Integration & Testing
14. [ ] Register trivia game in GameManager
15. [ ] Add trivia to game selection screen
16. [ ] Test 2-player minimum scenario
17. [ ] Test full 8-player game
18. [ ] Test edge cases (timeouts, disconnects)

### Phase 6: Polish
19. [ ] Add sound effects (correct/wrong buzzer, timer warning)
20. [ ] Add animations (answer reveal, score popup)
21. [ ] Add streak indicators
22. [ ] Balance difficulty distribution

---

## File Structure

```
New/Modified Files:
├── data/
│   └── prompts/
│       └── trivia_questions.json    # NEW - Question bank
│
├── scripts/
│   └── games/
│       └── trivia_showdown.gd       # NEW - Game logic
│
├── scenes/
│   └── games/
│       └── trivia_showdown/
│           ├── trivia_host.tscn     # NEW - Host display
│           └── trivia_player.tscn   # NEW - Player display (optional)
│
├── web-player/
│   ├── index.html                   # MODIFY - Add trivia views
│   ├── css/
│   │   └── style.css               # MODIFY - Add trivia styles
│   └── js/
│       └── games/
│           └── trivia.js           # NEW - Web player handler
│
└── TRIVIA.md                        # This file
```

---

## Progress Tracker

### Current Status: Not Started

| Task | Status | Notes |
|------|--------|-------|
| Question bank JSON | Not Started | Need 100+ questions |
| trivia_showdown.gd | Not Started | |
| Host UI scene | Not Started | |
| Web player JS | Not Started | |
| Web player HTML/CSS | Not Started | |
| Game registration | Not Started | |
| Testing | Not Started | |
| Polish | Not Started | |

### Implementation Order

**Recommended order for implementation:**

1. **trivia_questions.json** - Create the question bank first (can be done in parallel)
2. **trivia_showdown.gd** - Core game logic (depends on base_game.gd patterns)
3. **trivia_host.tscn** - Host display UI
4. **trivia.js** - Web player game handler
5. **index.html modifications** - Web player UI structure
6. **style.css modifications** - Web player styling
7. **Game registration** - Hook into game selection
8. **Testing & Polish** - Final integration

---

## Question Bank Format

```json
{
  "categories": ["Science", "History", "Geography", "Entertainment", "Sports", "General"],
  "questions": [
    {
      "id": 1,
      "category": "Science",
      "difficulty": "easy",
      "question": "What is the chemical symbol for gold?",
      "answers": ["Au", "Ag", "Fe", "Cu"],
      "correct": 0
    },
    {
      "id": 2,
      "category": "History",
      "difficulty": "medium",
      "question": "In what year did World War II end?",
      "answers": ["1943", "1944", "1945", "1946"],
      "correct": 2
    }
  ]
}
```

### Difficulty Distribution (per round of 10 questions)
- Easy: 3 questions
- Medium: 5 questions
- Hard: 2 questions

---

## Notes & Design Decisions

### Why 15 seconds per question?
- Fast enough to keep energy high
- Slow enough for reading comprehension
- Allows meaningful speed differentiation

### Why lock first answer?
- Prevents second-guessing abuse
- Rewards confident knowledge
- Matches quiz show format

### Category handling
- Round 1: Mixed categories (variety)
- Future enhancement: Let host pick category per round

---

*Created: 2026-01-22*
*Branch: trivia-showdown-game*
