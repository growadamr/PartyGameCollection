# Phase 3: Imposter Guess & Round End - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Imposters can attempt to guess the secret word at any time, and the game tracks round wins correctly. Round ends either when imposters guess correctly (imposters win) or when all imposters are eliminated (innocents win).

</domain>

<decisions>
## Implementation Decisions

### Guess submission UI & feedback
- Text input field appears on imposter screens from game start (always available)
- Submit button next to input - standard form pattern
- Wrong guesses show brief "Incorrect" toast (2 seconds), then input clears
- Correct guess immediately ends round - no intermediate confirmation
- Imposters can guess unlimited times (no penalty for wrong guesses)
- Input remains active even during voting (tension between guessing and voting strategy)

### Round end reveal & messaging
- Round end screen shows to ALL players simultaneously
- Large centered message: "IMPOSTERS WIN!" or "INNOCENTS WIN!"
- Display the secret word prominently for all players to see
- List which players were imposters (revealed after round ends)
- 5-second display duration before returning to lobby/next round
- Gradient background: red for imposter win, blue for innocent win (matches existing visual patterns)

### Win tracking & display
- Track team scores across rounds: "Imposters: 2 | Innocents: 1" format
- Score displayed at top of round end screen
- Score persists in game state but resets when returning to lobby
- No "best of X" enforcement - host decides when to stop
- Simple increment: +1 to winning team each round

### Timing & game flow
- Imposters can guess during any phase (discussion, voting, countdown)
- Correct guess takes priority over voting consensus (immediately ends round)
- After round end reveal (5 seconds), return to lobby (host can start new round)
- No automatic new round - host must manually start next round
- Game state resets for new round (new word, new roles, votes cleared)

### Claude's Discretion
- Exact input field styling (should match existing web player patterns)
- Toast notification animation details
- Whether to show guess history to imposters
- Sound effects or haptic feedback
- Network message debouncing/throttling

</decisions>

<specifics>
## Specific Ideas

- Keep it simple - this is a framework, not a polished product
- Follow existing patterns from Phases 1-2 (gradient backgrounds, view states, message naming)
- Party game needs fast pacing - avoid delays and confirmations
- Imposters guessing during voting adds strategic tension (guess now or wait for more info?)

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 03-imposter-guess-round-end*
*Context gathered: 2026-01-27*
