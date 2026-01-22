# Roadmap: Party Game Collection - Imposter Game

## Overview

Adding an Imposter-style social deduction game to the existing party game collection. The game follows established patterns (Godot controller, web player handler, JSON prompts) while introducing new mechanics: secret role assignment, real-time voting with consensus detection, and an imposter word-guessing escape route. Three phases deliver the complete game from basic role assignment through voting mechanics to win conditions.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Game Foundation** - Role assignment, discussion phase, and integration ✓
- [ ] **Phase 2: Voting & Elimination** - Real-time voting with consensus detection and reveals
- [ ] **Phase 3: Imposter Guess & Round End** - Word guessing and win condition tracking

## Phase Details

### Phase 1: Core Game Foundation
**Goal**: Players can start an Imposter game, see their assigned role, and engage in discussion phase
**Depends on**: Nothing (first phase, builds on existing architecture)
**Requirements**: SETUP-01, SETUP-02, SETUP-03, SETUP-04, DISC-01, DISC-02, DATA-01, DATA-02, INT-01, INT-02, INT-03, INT-04
**Success Criteria** (what must be TRUE):
  1. Host can select Imposter game from the game selection menu
  2. Non-imposter players see the secret word on their device
  3. Imposter players see "IMPOSTER" label instead of the word
  4. Imposter count scales correctly with player count (1 for 4-5, 2 for 6-8)
  5. All players can participate in free-form discussion phase
**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Compile word list from existing game data
- [x] 01-02-PLAN.md — Godot game controller, scene, and menu integration
- [x] 01-03-PLAN.md — Web player handler and HTML screen

### Phase 2: Voting & Elimination
**Goal**: Players can vote for suspects, see consensus warnings, and witness reveals
**Depends on**: Phase 1
**Requirements**: VOTE-01, VOTE-02, VOTE-03, VOTE-04, ELIM-01, ELIM-02, ELIM-03, ELIM-04
**Success Criteria** (what must be TRUE):
  1. Players can vote for any other player in real-time via their device
  2. Vote counts update and display to all players as they change
  3. Players can change their vote at any time before reveal
  4. Consensus triggers warning countdown when all players except target vote the same
  5. Reveal shows whether accused was imposter or not
  6. Caught imposters are eliminated and removed from active play
  7. Wrong accusations allow the game to continue without penalty
**Plans**: TBD

Plans:
- [ ] TBD during planning

### Phase 3: Imposter Guess & Round End
**Goal**: Imposters can attempt word guesses and the game tracks round wins correctly
**Depends on**: Phase 2
**Requirements**: GUESS-01, GUESS-02, GUESS-03, END-01, END-02, END-03
**Success Criteria** (what must be TRUE):
  1. Imposters can submit a word guess at any time via input field
  2. Correct imposter guess ends the round immediately with imposters winning
  3. Wrong imposter guesses don't penalize imposters or end the round
  4. Round ends when all imposters are found (non-imposters win)
  5. Round wins are tracked for each team across the game session
**Plans**: TBD

Plans:
- [ ] TBD during planning

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Game Foundation | 3/3 | Complete ✓ | 2026-01-22 |
| 2. Voting & Elimination | 0/0 | Not started | - |
| 3. Imposter Guess & Round End | 0/0 | Not started | - |

---
*Roadmap created: 2026-01-22*
*Last updated: 2026-01-22*
