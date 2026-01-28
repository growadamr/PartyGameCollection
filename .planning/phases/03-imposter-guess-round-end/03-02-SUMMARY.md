---
phase: 03-imposter-guess-round-end
plan: 02
subsystem: ui
tags: [javascript, html, css, websocket, game-ui, imposter]

# Dependency graph
requires:
  - phase: 03-01
    provides: Word guess processing backend with round-end logic
  - phase: 02-voting-elimination
    provides: Voting views and consensus UI patterns
provides:
  - Guess input UI visible to imposters during active gameplay phases
  - Round-end view displaying winner, secret word, imposter reveals, team scores
  - Independent visibility control for guess section (sibling to views)
  - Socket handlers for guess_result, round_end, round_restart
affects: [future-games, game-ui-patterns]

# Tech tracking
tech-stack:
  added: []
  patterns: [independent-section-toggle, gradient-winner-cards, toast-feedback]

key-files:
  created: []
  modified:
    - web-player/index.html
    - web-player/js/games/imposter.js
    - web-player/css/style.css

key-decisions:
  - "Guess section positioned as sibling to views (not inside any view) for independent visibility control"
  - "toggleGuessSection() controls visibility separately from showView() for flexible state management"
  - "2-second toast feedback for incorrect guesses with no penalty"
  - "Gradient backgrounds differentiate winner (red for imposters, blue for innocents)"
  - "Guess input visible during discussion, voting, and consensus; hidden during reveal and round-end"
  - "setupGuessInput() clones button to remove old listeners before adding new ones"

patterns-established:
  - "Pattern 1: Independent section toggle - UI elements can be siblings to views with separate visibility control"
  - "Pattern 2: Toast feedback - Brief temporary messages for non-critical feedback (2s duration)"
  - "Pattern 3: Gradient winner cards - Visual differentiation via CSS gradients for team-based outcomes"

# Metrics
duration: 2min 27s
completed: 2026-01-27
---

# Phase 3 Plan 02: Imposter Guess & Round End UI Summary

**Imposters can guess the word anytime via text input during active phases; round-end screen shows winner, word, imposters, and scores with gradient backgrounds**

## Performance

- **Duration:** 2 min 27s
- **Started:** 2026-01-28T00:33:56Z
- **Completed:** 2026-01-28T00:36:23Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Imposters have persistent guess input visible during discussion, voting, and consensus phases
- Wrong guesses show 2-second "Incorrect!" toast without disrupting gameplay
- Round-end screen displays winner team, secret word, imposter names, and team scores
- Gradient backgrounds provide instant visual feedback for round outcome (red = imposters win, blue = innocents win)
- Non-imposters and eliminated players never see guess input

## Task Commits

Each task was committed atomically:

1. **Task 1: Add guess input and round-end HTML + CSS** - `0b1c8be` (feat)
2. **Task 2: Add guess submission and round-end handlers** - `ec4c3fe` (feat)

## Files Created/Modified
- `web-player/index.html` - Added imposter-guess-section (sibling to views) and imposter-round-end-view with winner/word/imposters/scores
- `web-player/js/games/imposter.js` - Added toggleGuessSection(), setupGuessInput(), submitGuess(), handleGuessResult(), handleRoundEnd(), handleRoundRestart() methods; integrated guess section visibility across all view transitions
- `web-player/css/style.css` - Added guess input styles (red theme) and round-end card styles (gradient backgrounds)

## Decisions Made
- **Guess section as sibling:** Positioned imposter-guess-section as a sibling to view divs rather than inside any view, enabling independent visibility control via toggleGuessSection() method (not managed by showView())
- **Button listener cleanup:** setupGuessInput() clones button to remove existing listeners before adding new ones, preventing duplicate event handlers
- **Toast feedback duration:** 2 seconds provides sufficient time to read "Incorrect!" without disrupting flow
- **Gradient differentiation:** Red gradient (imposters win) and blue gradient (innocents win) provide immediate visual feedback about round outcome
- **Visibility rules:** Guess input shows for imposters during discussion/voting/consensus, hidden for non-imposters, eliminated players, and during reveal/round-end phases

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed without issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 3 (Imposter Guess & Round End) is now complete with both backend (03-01) and frontend (03-02) implementations. The Imposter game is feature-complete with:
- Role assignment and discussion phase
- Voting and elimination mechanics
- Consensus warnings and countdown
- Word guessing for imposters
- Round-end displays with score tracking

**Game is ready for integration testing and gameplay verification.**

No blockers for future work.

---
*Phase: 03-imposter-guess-round-end*
*Completed: 2026-01-27*
