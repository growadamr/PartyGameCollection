# Phase 2: Voting & Elimination - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Real-time voting system where players can vote for suspected imposters, with consensus detection triggering reveal countdowns. Includes elimination of caught imposters and handling of wrong accusations. Word guessing and round end conditions are Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Vote Display
- Tally per player — each player name shows vote count next to it (e.g., "Alex: 3 votes")
- Voting replaces the role screen entirely (not an overlay)
- Tap player name to vote, tap again to change vote
- Player's own vote is visually highlighted (border, checkmark, or similar)

### Consensus Warning
- 5 second countdown before reveal
- Votes CAN change during countdown — if consensus breaks, countdown resets
- Pulsing red screen + large countdown number in center
- Brief "Cancelled" animation if consensus breaks, then return to voting

### Reveal Presentation
- Dramatic pause + animation — "Revealing..." suspense, then result
- Show result + remaining imposters count ("Alex was an IMPOSTER! 1 imposter remaining")
- 3-4 seconds display, then auto-continue to next phase
- Color coding: red for imposter caught, green for innocent accused

### Eliminated Player State
- Eliminated players CANNOT vote — spectators only
- Spectator view shows votes in real time (can watch the game unfold)
- Eliminated imposters finally see the secret word
- Eliminated players shown crossed out / grayed in player list (not removed)

### Claude's Discretion
- Exact animation timings and easing
- Spectator UI layout
- Sound design (if any)
- Specific shades of red/green for reveals

</decisions>

<specifics>
## Specific Ideas

- Consensus warning should feel tense — the pulsing red creates urgency
- Reveals should have a brief dramatic pause to build anticipation before the result
- Eliminated imposters getting to see the word is a "reward" for getting caught — they can finally know what everyone was hinting at

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-voting-elimination*
*Context gathered: 2026-01-22*
