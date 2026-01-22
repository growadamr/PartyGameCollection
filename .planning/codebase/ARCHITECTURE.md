# Architecture

**Analysis Date:** 2026-01-22

## Pattern Overview

**Overall:** Multi-platform networked game framework using a host-client architecture with dual implementations (Godot desktop/mobile + Web browser client)

**Key Characteristics:**
- Asymmetric host-client networking model where the host (Godot) manages game state
- Server-side game logic with client-side rendering
- Real-time multiplayer synchronization via WebSocket
- Modular game system where games handle their own message flows
- Message-driven state updates across network boundaries

## Layers

**Network Layer:**
- Purpose: Manage WebSocket connections and message routing
- Location: `scripts/autoload/network_manager.gd` (Godot server), `web-player/js/websocket.js` (web client)
- Contains: Server/client connection handlers, message serialization, peer management
- Depends on: Nothing (pure networking)
- Used by: GameManager, game scripts, web app

**Game State Layer:**
- Purpose: Centralize player data, session management, and game-wide state
- Location: `scripts/autoload/game_manager.gd`
- Contains: Player registry, session ID, character data, score tracking, session lifecycle
- Depends on: Nothing (pure state)
- Used by: All game scripts, network manager, lobby scenes

**Game Logic Layer:**
- Purpose: Implement individual game rules and flow
- Location: `scripts/games/*.gd` (Charades, Quick Draw, Word Bomb), `web-player/js/games/*.js` (parallel implementations)
- Contains: Game initialization, round management, scoring logic, turn-based mechanics
- Depends on: NetworkManager, GameManager
- Used by: Scene controllers, UI handlers

**Scene/UI Layer:**
- Purpose: Manage visual presentation and user input
- Location: `scenes/` (Godot scenes), `web-player/index.html` + `js/app.js` (web UI)
- Contains: Screen controllers, button handlers, input validation, visual state
- Depends on: Game scripts, game manager, network manager
- Used by: Player (display)

**Web Application Layer (browser only):**
- Purpose: Browser-specific application orchestration
- Location: `web-player/js/app.js`
- Contains: Screen navigation, DOM manipulation, character selection, connection management
- Depends on: GameSocket, game handlers
- Used by: HTML markup, browser

## Data Flow

**Connection & Joining:**

1. Client initiates WebSocket connection to host IP/port
2. Host's NetworkManager accepts TCP, upgrades to WebSocket
3. Client sends `join_request` with player name and character ID
4. Host validates in NetworkManager._handle_join_request()
5. GameManager.add_player() adds to player registry
6. Host broadcasts `player_joined` to all clients
7. Client receives `join_accepted` with current player list

**Game Initialization:**

1. Host (is_host check) calls game's _initialize_game()
2. Game shuffles player_order and calculates total_rounds
3. Game broadcasts initialization message: `{type: "game_init", player_order: [...], total_rounds: N}`
4. Non-host players apply this data and wait
5. Host immediately starts game loop

**Game Round Flow (example: Quick Draw):**

1. Host calls _start_round() → broadcasts `quick_draw_wait`
2. All players see "waiting for drawer" state
3. Drawer (identified in wait message) presses "Start My Turn"
4. Host broadcasts `quick_draw_round` with timer start
5. Drawer's local canvas begins receiving input → strokes sent via `quick_draw_stroke`
6. Host relays strokes to non-drawer players
7. Non-drawers receive strokes, render locally
8. Players submit guesses → validated by host
9. Host broadcasts `quick_draw_correct` on match
10. Timer expires → host broadcasts `quick_draw_round_end` with scores
11. Loop repeats or game ends

**State Management:**

- Authoritative: Host holds all game state (current word, scores, player order, guesses)
- Eventual consistency: Clients apply state updates from host messages
- Client-local: UI state, drawing strokes (before transmission), input buffers
- Conflict resolution: Host is source of truth; client updates are validated by host

## Key Abstractions

**NetworkManager:**
- Purpose: Abstract WebSocket complexity from game logic
- Examples: `scripts/autoload/network_manager.gd` (Godot server), `web-player/js/websocket.js` (web client)
- Pattern: Singleton autoload (Godot) / Global instance (JS), event-driven via signals/emitters

**GameManager:**
- Purpose: Single source of truth for session and player data
- Examples: `scripts/autoload/game_manager.gd`
- Pattern: Singleton with public state dictionary; used by all game scripts

**Game Controllers:**
- Purpose: Encapsulate game-specific rules
- Examples: `scripts/games/quick_draw.gd`, `scripts/games/charades.gd`, `web-player/js/games/quickdraw.js`
- Pattern: Extends Control (Godot) or Class (JS), message handler pattern for network events

**Web App Controller:**
- Purpose: Manage browser client lifecycle and screen navigation
- Examples: `web-player/js/app.js`
- Pattern: MVC where Model is GameSocket state, View is DOM screens, Controller is PartyGameApp

## Entry Points

**Godot Desktop/Mobile:**
- Location: `res://scenes/main.tscn` (main scene in project.godot)
- Triggers: Game launch
- Responsibilities: Host/Join button selection

**Host Lobby (Godot):**
- Location: `scripts/lobby/host_lobby.gd`
- Triggers: Host button press
- Responsibilities: Create session, start server, show QR code, display player waiting area

**Join Lobby (Godot):**
- Location: `scripts/lobby/join_lobby.gd`
- Triggers: Join button press or QR scan
- Responsibilities: Collect player name/character, connect to host, enter waiting state

**Game Scenes (Godot):**
- Location: `scenes/games/*/` (quick_draw.tscn, charades.tscn)
- Triggers: Host selects game from game_select.tscn
- Responsibilities: Initialize game, handle rounds, manage UI, respond to network events

**Web Player (Browser):**
- Location: `web-player/index.html` → `web-player/js/app.js`
- Triggers: Browser open to web-player URL with ?host=IP parameter
- Responsibilities: Auto-connect or manual connection, screen routing, game UI sync

## Error Handling

**Strategy:** Graceful degradation with user-facing error messages and automatic reconnection

**Patterns:**

- Connection failures show error on join screen with IP entry fallback
- Network message errors logged to console, ignored (doesn't crash game)
- Player disconnection: NetworkManager emits `player_disconnected`, game removes from players dict
- Timeout: Client reconnection after 10 seconds of no activity (CONNECTION_TIMEOUT in network_manager.gd)
- Invalid guesses: Host validates server-side; invalid guesses trigger no broadcast, input cleared on client

## Cross-Cutting Concerns

**Logging:** GDScript print() statements for host (console), JavaScript console.log() for web (browser devtools)

**Validation:**
- Player names: 2-12 characters (enforced in lobby UI)
- Characters: Available character check before join (GameManager.is_character_available())
- Game inputs: Host-side validation (guesses, strokes, submissions)

**Authentication:** None - peer_id from TCP connection used as temporary player identifier

**State Synchronization:**
- Initial sync on join: full player list and current game state
- Delta sync during game: only message diffs (guesses, strokes, scores)
- No explicit state reconciliation; each message is applied immediately

---

*Architecture analysis: 2026-01-22*
