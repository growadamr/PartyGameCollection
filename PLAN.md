# Party Game Collection - Development Plan

> **Engine:** Godot 4.5
> **Platform:** Mobile-first (Host on phone, players join via QR)
> **Genre:** Family Party Games (Charades, Pictionary-style)

---

## Table of Contents

1. [Game Overview](#game-overview)
2. [Core Architecture](#core-architecture)
3. [The Five Party Games](#the-five-party-games)
4. [Multiplayer System](#multiplayer-system)
5. [Scoring System](#scoring-system)
6. [PixelLab Asset Integration](#pixellab-asset-integration)
7. [Development Phases](#development-phases)
8. [File Structure](#file-structure)
9. [Progress Tracker](#progress-tracker)

---

## Game Overview

A mobile party game collection where one player hosts a session, others join via QR code, and the group plays various family-friendly games together. The host's device acts as the "game board" while player devices serve as personal controllers/input devices.

### Core Features
- **QR Code Lobby:** Host generates QR code, players scan to join
- **5+ Mini-Games:** Variety of party game modes
- **Scoring System:** Persistent scores across games in a session
- **Host Controls:** Game selection, timer management, round control
- **Player Notifications:** Push game-specific info to individual players

---

## Core Architecture

### Network Model
```
┌─────────────────┐
│   HOST DEVICE   │  ← Game state, display, QR generation
│   (WebSocket    │
│    Server)      │
└────────┬────────┘
         │
    ┌────┴────┬─────────┬─────────┐
    ▼         ▼         ▼         ▼
┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐
│Player1│ │Player2│ │Player3│ │Player4│  ← Personal screens, input
└───────┘ └───────┘ └───────┘ └───────┘
```

### Technology Stack
- **Networking:** Godot's built-in WebSocket or WebRTC
- **QR Generation:** GDScript QR library or native plugin
- **Local Discovery:** mDNS/Bonjour for same-network joining
- **State Management:** Centralized on host, synced to players

---

## The Five Party Games

### 1. **Quick Draw** (Pictionary-style)
- **How it works:** One player draws on their phone, others guess on their devices
- **Host display:** Shows the drawing in real-time
- **Player roles:** Drawer sees the word, guessers type answers
- **Round flow:** Drawer sees "Start Drawing!" prompt, presses to begin, round ends when first person guesses correctly
- **Scoring:** 1 point for correct guess, 1 point for drawer if someone guesses correctly
- **Min players:** 2
- **Prompts needed:** Word bank (easy, medium, hard categories - 150 words)

### 2. **Act It Out** (Charades)
- **How it works:** One player acts out a prompt (physically, away from screens), others guess
- **Host display:** Timer, current actor's name, guess input
- **Player roles:** Actor sees prompt on their device (hidden from others), guessers submit guesses
- **Scoring:** Points for correct guesses, actor earns points when guessed
- **Prompts needed:** Actions, movies, celebrities, objects, phrases

### 3. **Fibbage** (Bluffing Game)
- **How it works:** Given an obscure fact with a blank, players submit fake answers, then everyone guesses the real one
- **Host display:** Question, all submitted answers (shuffled)
- **Player roles:** Submit fake answer, then vote for what they think is real
- **Scoring:** Points for guessing correctly, points when others pick your fake answer
- **Prompts needed:** Trivia questions with fill-in-the-blank format

### Charades Prompt Categories
The charades game includes **799 prompts** across 5 categories:
- **movies_tv** (161): Popular films and TV shows
- **actions** (165): Physical activities and gestures
- **animals** (162): Creatures from pets to wildlife
- **occupations** (158): Jobs and professions
- **objects** (153): Everyday items and household objects

### 4. **Word Bomb** (Word Association)
- **How it works:** Given a letter combo (e.g., "PH"), players race to type a word containing it
- **Host display:** Current letter combo, countdown timer, elimination tracker
- **Player roles:** Type valid words quickly on their device
- **Scoring:** Last player standing wins; points for survival each round
- **Prompts needed:** Letter combinations (2-3 letters)

### 5. **Who Said It?** (Quote Attribution)
- **How it works:** Players write responses to prompts, then everyone guesses who wrote what
- **Host display:** The prompt, then anonymous answers
- **Player roles:** Write answer, then vote on who wrote each answer
- **Scoring:** Points for correct guesses, points when you're hard to identify
- **Prompts needed:** Personal questions, hypotheticals, "What would you do if..."

### 6. **Bonus: Trivia Showdown** (Quiz Game)
- **How it works:** Multiple choice trivia, fastest correct answer wins
- **Host display:** Question and timer
- **Player roles:** Select answer on device
- **Scoring:** Points based on correctness and speed
- **Prompts needed:** Trivia questions with 4 options

---

## Multiplayer System

### Lobby Flow
```
1. Host opens app → Creates session → Generates QR code
2. QR encodes: ws://[host-ip]:[port]/join?session=[id]
3. Players scan → Opens web view or app → Enters name
4. Host sees player list → Can kick/ready players
5. Host selects game → All players transition to game screen
```

### Session State
```gdscript
var session = {
	"id": "uuid",
	"host_id": "player_uuid",
	"players": {
		"uuid": {"name": "Alice", "score": 0, "connected": true},
		"uuid": {"name": "Bob", "score": 0, "connected": true}
	},
	"current_game": null,
	"game_state": {},
	"settings": {
		"rounds_per_game": 3,
		"timer_duration": 60
	}
}
```

### Message Protocol
```gdscript
# Host → Player
{"type": "game_start", "game": "quick_draw", "role": "drawer", "prompt": "elephant"}
{"type": "timer_update", "remaining": 45}
{"type": "score_update", "scores": {...}}

# Player → Host
{"type": "guess", "text": "elephant"}
{"type": "drawing_update", "strokes": [...]}
{"type": "vote", "choice": "answer_id"}
```

---

## Scoring System

### Universal Scoring Rules
- **Base points:** 100 points for correct action
- **Speed bonus:** Up to 50 bonus points for faster responses
- **Streak bonus:** 10% bonus per consecutive correct answer
- **Round winner:** Bonus 50 points for highest in a round

### Per-Game Scoring

| Game | Correct Guess | Speed Bonus | Special |
|------|--------------|-------------|---------|
| Quick Draw | 1 pt | None | Drawer: 1 pt if guessed |
| Act It Out | 100 pts | +50 max | Actor: 25 pts per guess |
| Fibbage | 200 pts | None | 100 pts per fooled player |
| Word Bomb | Survival | None | Winner: 100 pts |
| Who Said It? | 50 pts/correct | None | 50 pts when not guessed |
| Trivia | 100 pts | +100 max | None |

### Leaderboard
- Persistent across all games in session
- Displayed between games and at session end
- Tracks: Total score, games won, special achievements

---

## PixelLab Asset Integration

### Required Assets & Tools

#### Characters (Player Avatars)
**Tool:** `create_character`
```
- 8 unique player avatars
- Size: 64px
- Proportions: "chibi" (cute, family-friendly)
- Directions: 4 (front, back, left, right for lobby animations)
- Style: Colorful, distinct silhouettes
```

**Character Concepts:**
1. Red Knight - brave warrior
2. Blue Wizard - magical scholar
3. Green Ranger - forest archer
4. Yellow Bard - cheerful musician
5. Purple Rogue - sneaky trickster
6. Orange Monk - peaceful fighter
7. Pink Princess - royal adventurer
8. Teal Robot - friendly automaton

**Tool:** `animate_character`
- Idle animation for lobby
- Celebrate animation for winner
- Sad/defeated animation for last place

#### UI Elements (Map Objects)
**Tool:** `create_map_object`
```
- Trophy icons (gold, silver, bronze)
- Game mode icons (pencil, mask, question mark, bomb, quote)
- Timer hourglass
- Star/sparkle effects
- Crown for current leader
- Checkmark/X for correct/wrong
```

#### Backgrounds
**Tool:** `create_topdown_tileset`
```
- Cozy living room floor tiles
- Party/celebration themed tiles
- Game board background tiles
```

### Asset Generation Workflow
1. Generate all characters first (2-5 min processing each)
2. While characters process, generate map objects
3. Create tilesets for backgrounds
4. Download all assets via provided URLs
5. Import into Godot project under `res://assets/`

### Generated Character IDs (PixelLab)
```
# Completed Characters (downloaded to assets/characters/)
Red Knight:    70516208-051d-485e-8ea5-80b247e2c99a
Blue Wizard:   6c14a925-bc40-4c4c-bd13-d2445389ac38
Green Ranger:  189830ad-f32a-45e5-b096-2db95caffa60
Purple Rogue:  c1da2d9a-6b65-4f2f-9501-8079b221d43a
Pink Princess: e984de7a-5c33-4e88-8feb-7e76062bdd1f

# Pending Characters (still processing)
Yellow Bard:   a76fc607-79ac-477a-a9d7-16c24ff48f6e
Orange Monk:   9a46ba4a-5a5c-4263-a3e5-2ee065950096
Teal Robot:    649694d4-ebea-4963-ade3-fc4a71a6632a
```

### To Download Remaining Characters
When PixelLab completes processing, use:
```bash
# Check status
mcp__pixellab__get_character(character_id="CHARACTER_ID")

# Download URLs will be in the response
# Save to: assets/characters/CHARACTER_NAME/south.png (etc.)
```

---

## Development Phases

### Phase 1: Foundation (Core Systems)
- [ ] Project setup in Godot 4.5
- [ ] Basic scene structure
- [ ] WebSocket server/client implementation
- [ ] QR code generation
- [ ] Lobby system (create/join)
- [ ] Player management (add/remove/ready)
- [ ] Basic UI framework

### Phase 2: Game Framework
- [ ] Base game class (abstract)
- [ ] Game state machine
- [ ] Timer system
- [ ] Scoring manager
- [ ] Prompt/word bank system
- [ ] Turn management
- [ ] Round transitions

### Phase 3: Individual Games
- [x] Quick Draw (drawing sync, guess input)
- [x] Act It Out (prompt display, guess voting) - implemented as `charades`
- [x] Fibbage (answer submission, voting)
- [x] Word Bomb (word validation, elimination)
- [x] Who Said It? (anonymous answers, attribution voting)
- [x] Trivia Showdown (question display, answer selection, speed bonus scoring)

### Phase 4: Polish & Assets
- [ ] Generate PixelLab assets
- [ ] Implement asset integration
- [ ] Sound effects
- [ ] Music
- [ ] Animations and transitions
- [ ] Particle effects for celebrations

### Phase 5: Testing & Release
- [ ] Multiplayer stress testing
- [ ] Game balance tuning
- [ ] Mobile optimization
- [ ] Build for Android/iOS
- [ ] User testing with families

---

## File Structure

```
res://
├── project.godot
├── PLAN.md
│
├── web-player/               # Browser-based player interface
│   ├── index.html
│   ├── css/style.css
│   └── js/
│       ├── app.js
│       ├── websocket.js
│       └── games/
│           ├── charades.js
│           ├── quickdraw.js
│           ├── wordbomb.js
│           ├── whosaidit.js
│           └── trivia.js
│
├── assets/
│   ├── characters/           # PixelLab generated
│   │   ├── red_knight/
│   │   ├── blue_wizard/
│   │   └── ...
│   ├── ui/                   # PixelLab map objects
│   │   ├── trophy_gold.png
│   │   ├── icon_draw.png
│   │   └── ...
│   ├── tiles/                # PixelLab tilesets
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── fonts/
│
├── scenes/
│   ├── main.tscn             # Entry point
│   ├── lobby/
│   │   ├── host_lobby.tscn
│   │   └── player_lobby.tscn
│   ├── games/
│   │   ├── quick_draw/
│   │   ├── charades/            # Act It Out game
│   │   ├── fibbage/
│   │   ├── word_bomb/
│   │   ├── who_said_it/
│   │   └── trivia_showdown/
│   └── ui/
│       ├── scoreboard.tscn
│       ├── timer.tscn
│       └── player_card.tscn
│
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd   # Global game state
│   │   ├── network_manager.gd
│   │   └── audio_manager.gd
│   ├── networking/
│   │   ├── websocket_server.gd
│   │   ├── websocket_client.gd
│   │   └── message_handler.gd
│   ├── games/
│   │   ├── base_game.gd      # Abstract base class
│   │   ├── quick_draw.gd
│   │   ├── charades.gd       # Act It Out game
│   │   ├── fibbage.gd
│   │   ├── word_bomb.gd
│   │   ├── who_said_it.gd
│   │   └── trivia.gd
│   └── utils/
│       ├── qr_generator.gd
│       └── word_bank.gd
│
└── data/
	├── prompts/
	│   ├── quick_draw_words.json
	│   ├── charades_prompts.json
	│   ├── fibbage_questions.json
	│   ├── letter_combos.json
	│   ├── who_said_prompts.json
	│   └── trivia_questions.json
	└── settings/
		└── default_settings.json
```

---

## Progress Tracker

### Current Status: Phase 3 - Individual Games

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Foundation | Complete | Lobby, networking done |
| Phase 2: Game Framework | Complete | Base game class created |
| Phase 3: Individual Games | Complete | All 6 games complete |
| Phase 4: Polish & Assets | In Progress | 5/8 character sprites integrated |
| Phase 5: Testing | Not Started | |

### Completed Items
- [x] Initial planning document created
- [x] PixelLab MCP documentation reviewed
- [x] Game concepts defined
- [x] Technical architecture outlined
- [x] Project structure set up
- [x] GameManager autoload created
- [x] NetworkManager autoload created
- [x] Main menu scene (Host/Join buttons)
- [x] Host lobby scene (name input, character selection)
- [x] Waiting lobby scene (player list, connection info)
- [x] Join lobby scene (IP input, character selection)
- [x] Player waiting scene (waiting for host)
- [x] Game selection scene (6 game cards)
- [x] WebSocket server/client networking
- [x] Base game class
- [x] Word Bomb game (complete with timer, lives, validation)
- [x] Letter combinations data (easy/medium/hard)
- [x] Quick Draw game (drawing sync, guess input, scoring)
- [x] Act It Out (Charades) game (complete with actor/guesser roles, 60s timer, scoring)
- [x] Charades prompts data (799 prompts across 5 categories: movies_tv, actions, animals, occupations, objects)
- [x] Charades turn preparation phase (actor presses "Start My Turn" before seeing prompt)
- [x] Charades result screens (shows correct answer, who guessed, points awarded to all players)
- [x] Character selection click area fix (mouse_filter on child controls)
- [x] Game state sync for non-host players (word_bomb_init message)
- [x] Fixed player scene transition bug (message_received signal not emitting for handled messages)
- [x] QR code generation (pure GDScript implementation)
- [x] QR code display in waiting lobby (with URL fallback)
- [x] 8 PixelLab character avatars generated (chibi style, 64px)
- [x] Downloaded 5 completed character sprites (Red Knight, Blue Wizard, Green Ranger, Purple Rogue, Pink Princess)
- [x] Character selection UI shows sprites with color fallback for pending characters
- [x] Quick Draw simplified (reduced from 835 to ~580 lines)
- [x] Quick Draw drawer ready prompt ("Start Drawing!" button)
- [x] Quick Draw multiplayer fixes (UI updates, notifications to all guessers)
- [x] Quick Draw simplified scoring (1 point system)
- [x] Quick Draw min players reduced to 2
- [x] Web player interface (HTML/CSS/JS for browser-based players)
- [x] Who Said It game (anonymous answers, voting, reveals, scoring)
- [x] Who Said It prompts data (62 prompts across 5 categories: hypothetical, personal, opinions, creative, wouldyourather)
- [x] Who Said It web player interface
- [x] Fibbage game (lie submission, voting, reveal with fooled tracking)
- [x] Fibbage questions data (52 trivia questions with fill-in-the-blank format)
- [x] Fibbage web player interface
- [x] Fibbage duplicate answer detection (rejects lies matching the truth)
- [x] Trivia Showdown game (multiple choice, speed bonus scoring, leaderboard)
- [x] Trivia questions data (120 questions across 6 categories: Science, History, Geography, Entertainment, Sports, General)
- [x] Trivia Showdown web player interface
- [x] Character sprites display in lobby (waiting_lobby, player_waiting screens)
- [x] Character sprites display in all 6 games (replaced color blocks with actual sprites)

### In Progress
- [ ] Cross-device multiplayer testing (iPhone + macOS)
- [ ] Remaining 3 character sprites (Yellow Bard, Orange Monk, Teal Robot) - pending PixelLab generation

### Next Steps
1. Complete remaining character downloads when PixelLab finishes
2. Add sound effects and polish
3. Cross-device multiplayer testing

### Character Assets Status
| Character | Status | Sprite Path |
|-----------|--------|-------------|
| Red Knight | Complete | `assets/characters/red_knight/` |
| Blue Wizard | Complete | `assets/characters/blue_wizard/` |
| Green Ranger | Complete | `assets/characters/green_ranger/` |
| Yellow Bard | Pending | Color fallback |
| Purple Rogue | Complete | `assets/characters/purple_rogue/` |
| Orange Monk | Pending | Color fallback |
| Pink Princess | Complete | `assets/characters/pink_princess/` |
| Teal Robot | Pending | Color fallback |

---

## Notes & Decisions

### Design Decisions
- **Mobile-first:** UI optimized for phone screens, large touch targets
- **Host as server:** Simplifies NAT traversal, host phone runs game logic
- **WebSocket over WebRTC:** Simpler implementation, sufficient for turn-based/low-latency needs
- **JSON prompts:** Easy to extend/modify word banks without code changes

### Resolved Questions
- Maximum player count: 2-8 players
- Session timeout: Not yet implemented

### Open Questions
- WebSocket connectivity across different networks (NAT traversal)
- Reconnection handling for dropped connections

### Known Issues
- None currently

---

*Last Updated: 2026-01-23 (Character sprites now display in lobby and all games)*
