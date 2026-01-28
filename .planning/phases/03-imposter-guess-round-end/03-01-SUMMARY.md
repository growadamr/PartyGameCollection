---
phase: 03-imposter-guess-round-end
plan: 01
subsystem: game-logic
tags: [godot, gdscript, multiplayer, websocket, game-state]

# Dependency graph
requires:
  - phase: 02-voting-elimination
    provides: Voting system, consensus detection, reveal mechanism
provides:
  - Word guess processing with immediate imposter win on correct guess
  - Round-end detection for all-imposters-eliminated scenario
  - Score tracking across multiple rounds
  - Round restart with preserved scores
affects: [04-web-ui-guess-round]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Round state machine with ROUND_END state"
    - "Score persistence across round resets"
    - "Case-insensitive word comparison with strip_edges().to_lower()"

key-files:
  created: []
  modified:
    - scripts/games/imposter.gd

key-decisions:
  - "Case-insensitive word guess comparison to accommodate user input variations"
  - "Wrong guesses have no penalty to encourage imposter participation"
  - "5-second display delay before automatic round restart"
  - "Scores persist across rounds in dedicated dictionary"

patterns-established:
  - "Round lifecycle: DISCUSSION → VOTING → CONSENSUS_WARNING → REVEALING → RESULT_DISPLAY → ROUND_END → restart"
  - "Non-host clients sync state via _apply_* functions"
  - "Guess processing blocked during REVEALING and ROUND_END to prevent timing exploits"

# Metrics
duration: 1min
completed: 2026-01-27
---

# Phase 03 Plan 01: Imposter Guess & Round End Summary

**Word guess processing with immediate imposter win, all-imposters-eliminated detection, and cross-round score tracking**

## Performance

- **Duration:** 1 min
- **Started:** 2026-01-28T00:28:57Z
- **Completed:** 2026-01-28T00:30:19Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Imposters can guess the word anytime during gameplay for instant win
- Innocents win when all imposters eliminated via voting
- Team scores tracked and broadcast with each round-end
- Automatic round restart after 5-second result display

## Task Commits

Each task was committed atomically:

1. **Task 1: Add word guess processing and round-end detection** - `31cbdbb` (feat)

## Files Created/Modified
- `scripts/games/imposter.gd` - Extended host controller with ROUND_END state, word_guess message handler, _process_word_guess (case-insensitive comparison), _end_round (broadcasts winner/word/scores), _after_reveal (detects remaining_imposters <= 0), _return_to_lobby (resets round state, preserves scores)

## Decisions Made
- Case-insensitive word comparison (`guess.strip_edges().to_lower() == current_word.to_lower()`) to handle user input variations
- Wrong guesses broadcast `guess_result` with `correct: false` but have no penalty (encourages imposter participation)
- Guess processing blocked during REVEALING and ROUND_END states to prevent timing exploits
- 5-second delay between round_end broadcast and automatic restart gives players time to see results
- Scores dictionary persists across rounds but is reset with game restart

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Host game logic complete for word guessing and round-end scenarios
- Ready for web player UI implementation (Phase 04)
- All round-end messages broadcast with winner, word, imposters list, and scores
- Round restart automatically triggers new word assignment and role distribution

---
*Phase: 03-imposter-guess-round-end*
*Completed: 2026-01-27*
