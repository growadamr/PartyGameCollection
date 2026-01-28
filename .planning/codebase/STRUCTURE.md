# Codebase Structure

**Analysis Date:** 2026-01-22

## Directory Layout

```
PartyGameCollection/
├── .godot/                 # Godot engine cache (generated, not committed)
├── .planning/              # GSD planning documents
├── .github/                # GitHub workflows
├── assets/                 # Game assets (sprites, audio, etc.)
│   └── characters/         # Character sprites for player selection
├── data/                   # Game data files (JSON prompts)
│   └── prompts/            # Game prompt/word lists
├── scenes/                 # Godot scene files (UI and game layouts)
│   ├── main.tscn           # Main menu scene (Host/Join buttons)
│   ├── lobby/              # Lobby scenes (joining, waiting, game select)
│   └── games/              # Individual game scenes
│       ├── charades/
│       ├── quick_draw/
│       └── word_bomb/
├── scripts/                # Godot GDScript source code
│   ├── autoload/           # Singletons (GameManager, NetworkManager)
│   ├── games/              # Game logic (one per game type)
│   ├── lobby/              # Lobby UI controllers
│   └── utils/              # Utility scripts (QR generation)
├── web-player/             # Complete browser-based web client
│   ├── index.html          # Single HTML page with all screens
│   ├── css/
│   │   └── style.css       # Styling for all screens
│   ├── js/
│   │   ├── app.js          # Main application controller
│   │   ├── websocket.js    # WebSocket client manager
│   │   └── games/          # Game-specific handlers
│   │       ├── charades.js
│   │       ├── wordbomb.js
│   │       └── quickdraw.js
│   └── README.md           # Web player documentation
├── project.godot           # Godot project configuration
├── icon.svg                # Project icon
└── README.md               # Main project documentation
```

## Directory Purposes

**assets/:**
- Purpose: Game visuals and media
- Contains: Character sprite sheets, animations
- Key files: `assets/characters/*/south.png` (character preview images)

**data/prompts/:**
- Purpose: Game prompt data (words, phrases, acts)
- Contains: JSON files with game-specific word lists
- Key files: `data/prompts/charades_prompts.json`, `data/prompts/quick_draw_words.json`

**scenes/:**
- Purpose: Godot scene hierarchy and UI layout
- Contains: .tscn files defining node trees, properties, and connections
- Key files: `scenes/main.tscn` (entry point), game scene files

**scripts/autoload/:**
- Purpose: Global singletons for cross-scene state
- Contains: Network and game management
- Key files:
  - `scripts/autoload/game_manager.gd` - Player registry, session state, character data
  - `scripts/autoload/network_manager.gd` - WebSocket server (host) and client (web player)

**scripts/games/:**
- Purpose: Game-specific logic and round management
- Contains: Turn handling, scoring, message routing
- Key files: `scripts/games/quick_draw.gd`, `scripts/games/charades.gd`, `scripts/games/word_bomb.gd`

**scripts/lobby/:**
- Purpose: Join/host lobby UI controllers
- Contains: Connection logic, character selection, player waiting
- Key files: `scripts/lobby/host_lobby.gd`, `scripts/lobby/join_lobby.gd`, `scripts/lobby/game_select.gd`

**web-player/:**
- Purpose: Complete browser-based game client (alternative to mobile app)
- Contains: HTML, CSS, vanilla JavaScript (no build step)
- Key files: `web-player/index.html` (single page), `web-player/js/app.js` (orchestration)

## Key File Locations

**Entry Points:**
- `project.godot`: Godot configuration; `run/main_scene="res://scenes/main.tscn"`
- `scenes/main.tscn`: Main menu with Host/Join buttons
- `web-player/index.html`: Web player entry (open in browser)

**Global State:**
- `scripts/autoload/game_manager.gd`: Player data, session ID, character registry, scores
- `scripts/autoload/network_manager.gd`: Network state, message routing

**Core Networking:**
- `scripts/autoload/network_manager.gd`: Godot TCP/WebSocket server (host mode)
- `web-player/js/websocket.js`: Browser WebSocket client

**Game Logic:**
- `scripts/games/quick_draw.gd`: Drawing game with real-time stroke sync (Godot)
- `scripts/games/charades.gd`: Acting/guessing game (Godot)
- `scripts/games/word_bomb.gd`: Word input game (Godot)
- `web-player/js/games/*.js`: Parallel game handlers for browser

**Game Data:**
- `data/prompts/charades_prompts.json`: Charades phrases/acts
- `data/prompts/quick_draw_words.json`: Drawing prompts by difficulty

**UI Controllers:**
- `scripts/lobby/host_lobby.gd`: Host setup and player waiting area
- `scripts/lobby/join_lobby.gd`: Client connection and character selection
- `web-player/js/app.js`: Web client screen management and DOM control

**Web Styling:**
- `web-player/css/style.css`: Layout, colors, responsive design for all screens

## Naming Conventions

**Files:**
- GDScript files: `snake_case.gd` (e.g., `quick_draw.gd`, `game_manager.gd`)
- Scene files: `PascalCase.tscn` matching their node name or purpose
- JavaScript files: `camelCase.js` (e.g., `websocket.js`, `charades.js`)
- Data files: `snake_case.json` (e.g., `quick_draw_words.json`)

**Directories:**
- Feature areas: `snake_case/` (e.g., `scripts/games/`, `web-player/js/games/`)
- Organization by layer: Clear separation (autoload, games, lobby, utils)

**GDScript Classes/Nodes:**
- Signals: `snake_case` (e.g., `player_joined`, `connection_established`)
- Variables: `snake_case` (e.g., `is_host`, `current_round`, `player_order`)
- Constants: `UPPER_CASE` (e.g., `ROUND_TIME`, `DEFAULT_PORT`)
- Functions: `snake_case` (e.g., `_on_message_received`, `_initialize_game`)
- Private methods: Leading underscore `_method_name()`

**JavaScript Classes/Variables:**
- Classes: `PascalCase` (e.g., `GameSocket`, `PartyGameApp`, `CharadesGame`)
- Methods: `camelCase` (e.g., `setupSocketHandlers`, `handleMessage`)
- Variables: `camelCase` (e.g., `isConnected`, `playerName`, `hostIP`)
- Constants: `UPPER_CASE` (e.g., `maxReconnectAttempts`)
- Private methods: Leading underscore `_methodName()`

## Where to Add New Code

**New Game:**
- Primary game logic: `scripts/games/[game_name].gd` - Extends Control, implements message handlers for game events
- Game scene: `scenes/games/[game_name]/[game_name].tscn` - Scene tree for game UI
- Web version: `web-player/js/games/[game_name].js` - Parallel implementation for browser
- Prompts: `data/prompts/[game_name]_[data_type].json` - Word lists or phase data
- Add game select option in: `scripts/lobby/game_select.gd` and `web-player/js/app.js`

**New Lobby Screen:**
- Script: `scripts/lobby/[screen_name].gd` - Extends Control
- Scene: Create corresponding .tscn in `scenes/lobby/`
- Register in main.gd and navigation flow

**New Utility:**
- Shared logic: `scripts/utils/[utility_name].gd` - Static helpers or reusable nodes
- If web-specific: `web-player/js/utils/[utility_name].js`

**Game Prompts/Data:**
- Location: `data/prompts/[game_type]_[category].json`
- Format: JSON dict with categories as keys (e.g., `{"easy": [...], "medium": [...], "hard": [...]}`)
- Load in game's `_load_prompts()` method using FileAccess.open()

## Special Directories

**scripts/autoload/:**
- Purpose: Auto-loaded singletons (defined in project.godot)
- Generated: No
- Committed: Yes
- Access: Global namespace by name (e.g., `GameManager.session_id`, `NetworkManager.send_to_server()`)

**.godot/:**
- Purpose: Godot engine cache (imported assets, compiled scenes, shader cache)
- Generated: Yes (automatically by editor)
- Committed: No (in .gitignore)

**web-player/:**
- Purpose: Standalone web client with no build step
- Generated: No (all files manually written)
- Committed: Yes
- Note: Self-contained; can be served directly by any web server

**data/prompts/:**
- Purpose: Game content data
- Generated: No (manually curated)
- Committed: Yes
- Format: JSON for easy editing and parsing in both Godot and JavaScript

---

*Structure analysis: 2026-01-22*
