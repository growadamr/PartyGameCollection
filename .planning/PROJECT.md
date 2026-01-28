# Party Game Collection

## What This Is

A local multiplayer party game collection where one device (phone/computer) hosts the game via Godot, and other players join through their web browsers on the same WiFi network. Players see game-specific UI on their phones while the host displays shared game state. Currently includes Charades, Quick Draw, and Word Bomb — adding an Imposter-style social deduction game.

## Core Value

Players can quickly join and play party games together using just their phones and one host device, with no app installs required for players.

## Requirements

### Validated

- ✓ Host device runs WebSocket server, players connect via browser — existing
- ✓ Player joining with name and character selection — existing
- ✓ QR code display for easy connection — existing
- ✓ Game selection menu for host — existing
- ✓ Charades game (actor/guesser roles, timer, scoring) — existing
- ✓ Quick Draw game (real-time drawing sync, guessing) — existing
- ✓ Word Bomb game (letter combos, timed word input) — existing
- ✓ Web player client with game-specific screens — existing
- ✓ Round-based gameplay with score tracking — existing

### Active

- [ ] Imposter game: non-imposters see secret word, imposters see "IMPOSTER"
- [ ] Imposter count scales with player count (1 for 4-5 players, 2 for 6-8, etc.)
- [ ] Free-form discussion phase (no turns, players talk naturally)
- [ ] Real-time voting overlay — players can vote for suspects anytime
- [ ] Consensus detection — when everyone except accused votes for them, trigger warning
- [ ] Warning countdown before reveal (accused is imposter or not)
- [ ] Imposter elimination — caught imposters are out, game continues
- [ ] Wrong accusation handling — game continues, no penalty
- [ ] Imposter word guess — imposters can attempt to guess the word anytime
- [ ] Correct guess wins round — if imposter guesses correctly, imposters win
- [ ] Round win tracking — track wins per team across rounds
- [ ] Compiled word list from existing charades/quick draw data (new file, originals unmodified)
- [ ] Game added to game selection menu
- [ ] Web player Imposter game screen

### Out of Scope

- Turn-based clue giving — game uses free-form discussion instead
- Granular point scoring — using simple round win/lose tracking
- Custom word input by players — using pre-compiled word list
- Voice chat integration — players talk in person
- Remote play over internet — local WiFi only

## Context

**Existing Architecture:**
- Godot 4.5 host with WebSocket server on port 8080
- Vanilla JavaScript web player (no build step)
- JSON message protocol for all game communication
- Each game has: GDScript controller (`scripts/games/`), scene (`scenes/games/`), web handler (`web-player/js/games/`)
- Existing prompt data in `data/prompts/` (charades_prompts.json, quick_draw_words.json, letter_combos.json)

**Imposter Game Mechanics:**
- Round start: host randomly assigns imposter(s), broadcasts word to non-imposters
- Discussion: players give verbal clues about the word, imposters bluff
- Voting: real-time vote updates visible to all, votes can be changed
- Consensus: unanimous vote (minus target) triggers 3-second warning, then reveal
- Imposter guess: any imposter can submit a word guess; correct = imposters win round
- Round end: all imposters found (non-imposters win) OR correct imposter guess (imposters win)

## Constraints

- **Tech stack**: Godot 4.5 + vanilla JS — must follow existing patterns
- **No external dependencies**: keep web player dependency-free
- **Mobile-first UI**: all interfaces must work well on phone screens
- **Same WiFi**: players must be on same network as host

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Free-form discussion over turns | More natural party game feel, players talk in person | — Pending |
| Unanimous consensus (minus target) | Prevents hasty accusations, requires group agreement | — Pending |
| Imposters can guess anytime | Adds tension, imposters have escape route | — Pending |
| Compile new word list | Keep existing game data intact, curate for this game | — Pending |
| Scale imposters with player count | Balance gameplay for different group sizes | — Pending |

---
*Last updated: 2026-01-22 after initialization*
