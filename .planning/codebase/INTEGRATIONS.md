# External Integrations

**Analysis Date:** 2026-01-22

## APIs & External Services

**None Detected**

This codebase has no dependencies on external APIs or third-party services. All functionality is self-contained within the local network application.

## Data Storage

**Databases:**
- None. Application is stateless for persistence (no database).
- Game state exists only during active session in memory.

**Static Game Data:**
- JSON files (local filesystem only)
  - `data/prompts/charades_prompts.json` - Charades prompts by category
  - `data/prompts/quick_draw_words.json` - Quick Draw word list
  - `data/prompts/letter_combos.json` - Word Bomb letter combinations
- Character sprite assets: `assets/characters/*/south.png`

**File Storage:**
- Local filesystem only (no cloud storage)
- Godot loads assets via `FileAccess.open("res://...")`
- Web player serves no files (HTML, JS, CSS are embedded or static)

**Caching:**
- Browser caching: Standard HTTP caching via web server headers (if served via HTTP)
- No client-side persistent storage (no localStorage, IndexedDB)
- Application state reset on page refresh

## Authentication & Identity

**Auth Provider:**
- Custom simple authentication via player name + character selection
- No user accounts, passwords, or persistent identity
- Each session is anonymous
- Player identity: `peer_<id>` on host, UUID pattern in `GameManager.local_player_id`

**Implementation:**
- Client joins by sending `join_request` message with name and character ID
- Host validates character availability and sends `join_accepted` response
- No authentication tokens, sessions, or persistence

## Monitoring & Observability

**Error Tracking:**
- None. No integration with error tracking services.

**Logs:**
- Console output only
- Godot: `print()` and `push_error()` to Godot console
- Web: Browser `console.log()` and `console.error()`
- No persistent logging
- No log aggregation

**Debug Features:**
- Connection status messages logged to console
- WebSocket state transitions logged
- Message types logged for debugging

## CI/CD & Deployment

**Hosting:**
- Local network deployment only (no remote hosting)
- Host device runs Godot executable
- Web clients connect via browser on same WiFi

**Export Targets (Godot):**
- Linux (desktop)
- Windows (desktop)
- macOS (desktop)
- iOS (mobile)
- Android (mobile)
- Web (HTML5 export - for server only)

**Web Player Hosting:**
- Served from static file system (no build required)
- Can be hosted on any web server, or served locally
- Typically accessed via `file://` or local HTTP server
- No CDN or remote hosting used

**CI Pipeline:**
- None detected. No GitHub Actions, GitLab CI, or build automation.

## Environment Configuration

**Required env vars:**
- None. Server uses hardcoded defaults or command-line parameters.

**Configurable Parameters (hardcoded in code):**
- `DEFAULT_PORT = 8080` in `scripts/autoload/network_manager.gd`
- `CONNECTION_TIMEOUT = 10.0` seconds
- Max reconnect attempts: 3
- Game settings: `rounds_per_game`, `timer_duration`, `max_players`, `min_players` in `scripts/autoload/game_manager.gd`
- Viewport size: 720x1280 (portrait mobile) in `project.godot`

**Secrets location:**
- No secrets required. No API keys, tokens, or credentials.
- Application is fully offline-capable (local network only).

## Webhooks & Callbacks

**Incoming:**
- None. Server does not expose webhooks.

**Outgoing:**
- None. Application makes no outbound HTTP/webhook calls.

## Network Communication Protocol

**WebSocket Messages:**
All communication uses JSON over WebSocket (ws:// - unencrypted)

**Client → Server Messages:**
- `join_request`: `{"type": "join_request", "name": "Player Name", "character": 0}`
- Game-specific actions: `{"type": "guess", ...}`, `{"type": "draw_action", ...}`, etc.

**Server → Client Broadcasts:**
- `join_accepted`: `{"type": "join_accepted", "player_id": "peer_1", "session_id": "...", "players": {...}}`
- `player_joined`: `{"type": "player_joined", "player_id": "peer_2", "name": "Player", "character": 1}`
- `player_left`: `{"type": "player_left", "player_id": "peer_2"}`
- `game_starting`: `{"type": "game_starting", "game": "charades"}`
- `host_left`: `{"type": "host_left"}`
- Game-specific broadcasts: `{"type": "charades_init", ...}`, `{"type": "round_result", ...}`, etc.

**Connection Flow:**
1. Client: `gameSocket.connect(hostIP, 8080)` triggers WebSocket connection
2. Server: Accepts TCP connection, wraps in WebSocketPeer
3. Client: Sends `join_request` after WebSocket opens
4. Server: Validates, adds player to GameManager, broadcasts `join_accepted` + `player_joined`
5. Server: Emits `game_starting` when host starts game
6. Bidirectional: Game action messages during gameplay
7. Server: Broadcasts results, transitions, scoring updates

## Security Notes

**No encryption:**
- WebSocket connections are `ws://` (unencrypted), not `wss://`
- Suitable only for local network use
- Not suitable for public internet deployment

**No authentication/authorization:**
- Anyone on the network can join if they know the host IP
- No user authentication required
- No role-based access control

**Data exposure:**
- All player names, characters, scores visible to all clients
- No sensitive data transmitted
- Session is ephemeral (no persistence)

---

*Integration audit: 2026-01-22*
