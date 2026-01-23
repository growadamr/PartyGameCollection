# Requirements: Party Game Collection - Imposter Game

**Defined:** 2026-01-22
**Core Value:** Players can quickly join and play party games together using just their phones and one host device

## v1 Requirements

Requirements for the Imposter game addition.

### Game Setup

- [x] **SETUP-01**: Host can select Imposter game from game selection menu
- [x] **SETUP-02**: System assigns imposter count based on player count (1 for 4-5 players, 2 for 6-8 players)
- [x] **SETUP-03**: Non-imposters see the secret word, imposters see "IMPOSTER"
- [x] **SETUP-04**: Word selected randomly from compiled word list

### Discussion Phase

- [x] **DISC-01**: Players see their role assignment (word or "IMPOSTER") on their device
- [x] **DISC-02**: Free-form discussion phase - no turn structure enforced by game (players talk in person)

### Voting System

- [x] **VOTE-01**: Players can vote for any other player in real-time via their device
- [x] **VOTE-02**: Vote counts visible to all players as they update
- [x] **VOTE-03**: Players can change their vote at any time
- [x] **VOTE-04**: Consensus detected when all players except accused vote for same person

### Reveal & Elimination

- [x] **ELIM-01**: Warning countdown (3 seconds) before reveal when consensus reached
- [x] **ELIM-02**: Reveal shows if accused was imposter or not
- [x] **ELIM-03**: Caught imposters are eliminated from the round
- [x] **ELIM-04**: Wrong accusation - game continues without penalty

### Imposter Guess

- [ ] **GUESS-01**: Imposters can submit a word guess at any time via input field
- [ ] **GUESS-02**: Correct guess ends round immediately - imposters win
- [ ] **GUESS-03**: Wrong guess - no penalty, game continues

### Round End & Scoring

- [ ] **END-01**: Round ends when all imposters found (non-imposters win)
- [ ] **END-02**: Round ends when imposter guesses word correctly (imposters win)
- [ ] **END-03**: Track round wins for each team across game session

### Data

- [x] **DATA-01**: Compile word list from existing charades/quick draw prompts into new file
- [x] **DATA-02**: Original prompt files remain unmodified

### Integration

- [x] **INT-01**: Godot game controller at `scripts/games/imposter.gd`
- [x] **INT-02**: Godot game scene at `scenes/games/imposter/imposter.tscn`
- [x] **INT-03**: Web player handler at `web-player/js/games/imposter.js`
- [x] **INT-04**: Web player screen added to `web-player/index.html`

## v2 Requirements

Deferred to future release.

### Enhanced Gameplay

- **V2-01**: Multiple word difficulty levels (easy/medium/hard)
- **V2-02**: Category selection before round
- **V2-03**: Timer option for rounds
- **V2-04**: Spectator mode for eliminated players

### Polish

- **V2-05**: Sound effects for reveals and wins
- **V2-06**: Animations for voting and elimination

## Out of Scope

| Feature | Reason |
|---------|--------|
| Turn-based clue giving | Game uses free-form verbal discussion |
| Anonymous voting | All votes visible for strategic play |
| Granular point scoring | Simple round win/lose tracking preferred |
| Custom word input | Using curated word list |
| Voice chat | Players talk in person |
| Internet play | Local WiFi only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SETUP-01 | Phase 1 | Complete |
| SETUP-02 | Phase 1 | Complete |
| SETUP-03 | Phase 1 | Complete |
| SETUP-04 | Phase 1 | Complete |
| DISC-01 | Phase 1 | Complete |
| DISC-02 | Phase 1 | Complete |
| VOTE-01 | Phase 2 | Complete |
| VOTE-02 | Phase 2 | Complete |
| VOTE-03 | Phase 2 | Complete |
| VOTE-04 | Phase 2 | Complete |
| ELIM-01 | Phase 2 | Complete |
| ELIM-02 | Phase 2 | Complete |
| ELIM-03 | Phase 2 | Complete |
| ELIM-04 | Phase 2 | Complete |
| GUESS-01 | Phase 3 | Pending |
| GUESS-02 | Phase 3 | Pending |
| GUESS-03 | Phase 3 | Pending |
| END-01 | Phase 3 | Pending |
| END-02 | Phase 3 | Pending |
| END-03 | Phase 3 | Pending |
| DATA-01 | Phase 1 | Complete |
| DATA-02 | Phase 1 | Complete |
| INT-01 | Phase 1 | Complete |
| INT-02 | Phase 1 | Complete |
| INT-03 | Phase 1 | Complete |
| INT-04 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-01-22*
*Last updated: 2026-01-23 after Phase 2 completion*
