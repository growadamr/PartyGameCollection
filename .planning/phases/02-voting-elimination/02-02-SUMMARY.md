---
phase: 02-voting-elimination
plan: 02
subsystem: ui
tags: [html, css, web-player, voting-ui, animations, responsive, mobile]

# Dependency graph
requires:
  - phase: 01-core-game-foundation
    provides: Web player basic structure and existing game screens
  - phase: 02-voting-elimination/02-01
    provides: Host-side voting state machine with message types
provides:
  - Web player voting UI structure with 6 view sections
  - CSS styles for vote list with tappable options
  - Consensus warning with pulsing red animation
  - Reveal and result views with dramatic animations
  - Spectator view for eliminated players
  - Visual states for my-vote, eliminated, and vote counts
affects: [02-03-voting-ui-handlers, 03-game-end-conditions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Multi-view game screen pattern (role, voting, spectator, consensus, reveal, result)"
    - "CSS animations for dramatic game moments (pulse-red, reveal-pulse)"
    - "Gradient backgrounds for result states (red for imposter, green for innocent)"
    - "Hidden class toggle for view switching via JavaScript"

key-files:
  created: []
  modified:
    - web-player/index.html
    - web-player/css/style.css

key-decisions:
  - "6 separate view divs instead of dynamic content replacement for cleaner state management"
  - "Pulsing red animation at 0.5s for consensus urgency without being jarring"
  - "Large 6rem countdown number for high visibility on mobile"
  - "Gradient backgrounds (red/green) for imposter/innocent reveal for instant recognition"
  - "Spectator view shows vote tallies but with pointer-events:none for read-only experience"

patterns-established:
  - "Game view switching via .hidden class toggle"
  - "Role-specific color coding (red accent for imposter, green for innocent)"
  - "Vote option cards with border highlight for own vote"
  - "Eliminated state: grayed, line-through, no pointer events"

# Metrics
duration: 1min
completed: 2026-01-22
---

# Phase 02 Plan 02: Web Voting UI Summary

**Voting UI structure with 6 view sections, tappable vote options, pulsing consensus warning, and dramatic reveal animations for mobile web player**

## Performance

- **Duration:** 1 min
- **Started:** 2026-01-22T22:28:00Z
- **Completed:** 2026-01-22T22:29:17Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- 6 distinct view sections for voting flow (role, voting, spectator, consensus, reveal, result)
- Tappable vote-option cards with visual feedback for own vote (accent-primary border)
- Eliminated player styling (40% opacity, line-through, no interaction)
- Pulsing red consensus warning with large 6rem countdown number
- Reveal view with pulsing animation for dramatic pause
- Result cards with gradient backgrounds (red for imposter, green for innocent)
- Spectator view for eliminated players showing read-only vote tallies

## Task Commits

Each task was committed atomically:

1. **Task 1: Add voting UI structure to index.html** - `081b452` (feat)
2. **Task 2: Add voting CSS styles** - `99bdc71` (feat)

## Files Created/Modified
- `web-player/index.html` - 6 view sections inside #screen-imposter with all required element IDs
- `web-player/css/style.css` - Voting styles including vote-option, my-vote, eliminated, consensus-warning, pulse-red animation, reveal-card, result-card variants

## Decisions Made

**1. 6 separate view divs instead of dynamic content replacement**
- Cleaner state management - JavaScript just toggles .hidden class
- Each view has its own static structure
- Easier to debug and maintain than template-based rendering

**2. Pulsing red animation at 0.5s interval**
- Creates urgency without being jarring or causing eye strain
- 0.5s tested to be noticeable but not annoying on mobile
- Opacity range 0.15-0.35 for subtle but clear pulsing effect

**3. Large 6rem countdown number**
- High visibility on mobile screens (primary device target)
- Line-height: 1 prevents layout shifting between numbers
- Red accent color matches consensus urgency

**4. Gradient backgrounds for result reveal**
- Red gradient (#ff4444 → #cc0000) for imposter instant recognition
- Green gradient (#44cc44 → #009900) for innocent
- White text with transparency for readability on both gradients

**5. Spectator view with pointer-events: none**
- Eliminated players see vote tallies but cannot interact
- Visual feedback that they're watching, not participating
- Maintains engagement while preventing ghost voting

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Plan 03 (Voting UI Handlers):**
- All required element IDs exist for JavaScript event handlers
- vote-player-list ready for dynamic population
- spectator-vote-list ready for eliminated player view
- consensus-countdown ready for ticker updates
- result-card ready for imposter/innocent class toggle
- All view sections have unique IDs for .hidden class toggle

**Ready for testing:**
- CSS classes can be manually tested in DevTools
- my-vote class shows accent-primary border
- eliminated class shows grayed/line-through state
- pulse-red animation visible on consensus-warning
- imposter/innocent classes show gradient backgrounds

**Blockers:**
None. JavaScript handlers can now wire up voting interactions to the host state machine.

---
*Phase: 02-voting-elimination*
*Completed: 2026-01-22*
