---
phase: 02-voting-elimination
plan: 01
subsystem: game-logic
tags: [godot, gdscript, state-machine, voting, consensus, networking, websocket]

# Dependency graph
requires:
  - phase: 01-core-game-foundation
    provides: Imposter game with role assignment and discussion phase
provides:
  - Host-side voting state machine with five states
  - Consensus detection with unanimous-minus-target logic
  - 5-second countdown with cancellation on vote changes
  - Reveal sequence with dramatic pause
  - Vote broadcasting with live tallies
  - Eliminated player tracking
  - Word reveal to eliminated imposters
affects: [02-02-web-voting-ui, 02-03-elimination-display, 03-game-end-conditions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "State machine pattern for game phases (enum State with transitions)"
    - "Debounced consensus detection via Timer (100ms delay)"
    - "Dramatic reveal sequence with async delays (await get_tree().create_timer)"
    - "Vote tallying and broadcasting pattern"

key-files:
  created: []
  modified:
    - scripts/games/imposter.gd
    - scenes/games/imposter/imposter.tscn

key-decisions:
  - "Debounce consensus checks by 100ms to avoid excessive broadcasts"
  - "Use unanimous-minus-target consensus (all eligible voters except the target)"
  - "5-second countdown gives players time to reconsider before reveal"
  - "Send word_revealed only to eliminated imposter, not broadcast"
  - "Eliminated players cannot vote but remain in game"

patterns-established:
  - "Timer-based state transitions for game flow control"
  - "Separate apply functions for non-host clients to sync state"
  - "Voting eligibility checks (not eliminated, in correct state)"
  - "Broadcast vote_update with both votes dict and tallies for UI flexibility"

# Metrics
duration: 2min
completed: 2026-01-22
---

# Phase 02 Plan 01: Voting State Machine Summary

**Host-side voting state machine with consensus detection, 5-second countdown, and reveal sequence for Imposter game**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-22T22:23:07Z
- **Completed:** 2026-01-22T22:25:05Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Five-state voting state machine (DISCUSSION → VOTING → CONSENSUS_WARNING → REVEALING → RESULT_DISPLAY)
- Consensus detection with 100ms debounce prevents excessive re-checks
- 5-second countdown broadcasts each tick, cancellable if consensus breaks
- Reveal sequence shows 2-second pause then result with imposter/innocent status
- Eliminated imposters receive word via send_to_client (not broadcast)
- Vote tallies broadcast to all clients for real-time UI updates

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Timer nodes to imposter.tscn** - `cbc4213` (feat)
2. **Task 2: Implement voting state machine in imposter.gd** - `d8190c7` (feat)
3. **Task 3: Add start_voting trigger for testing** - `1955d87` (feat)

## Files Created/Modified
- `scenes/games/imposter/imposter.tscn` - Added CountdownTimer (1.0s) and ConsensusCheckTimer (0.1s one-shot)
- `scripts/games/imposter.gd` - Voting state machine with consensus logic, countdown, and reveal sequence

## Decisions Made

**1. Debounce consensus checks by 100ms**
- Prevents excessive consensus recalculation on rapid vote changes
- Uses ConsensusCheckTimer (one-shot) to batch checks

**2. Unanimous-minus-target consensus logic**
- All eligible voters except the target must vote for that person
- Prevents players from voting themselves to trigger consensus
- More natural party game feel than simple majority

**3. 5-second countdown before reveal**
- Gives players time to reconsider accusation
- Countdown cancels if anyone changes vote (consensus breaks)
- Broadcasts each second for UI updates

**4. Send word only to eliminated imposter**
- Uses send_to_client instead of broadcast for word reveal
- Prevents living imposters from seeing the word
- Security pattern established in Phase 1 Plan 02

**5. Keyboard shortcut (V key) for testing**
- Allows host to trigger voting phase without UI
- Temporary testing feature until Phase 2 Plan 02/03 adds UI

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Plan 02 (Web Voting UI):**
- State machine broadcasts voting_started with player list
- vote_update broadcasts contain votes dict and tallies
- All message types defined for UI to consume
- V key allows testing voting flow before UI exists

**Ready for Plan 03 (Elimination Display):**
- reveal_start and reveal_result messages contain target info
- eliminated_players array tracks who's eliminated
- remaining_imposters count updated after each elimination

**Blockers:**
None. Web UI can now implement voting interface and elimination animations.

---
*Phase: 02-voting-elimination*
*Completed: 2026-01-22*
