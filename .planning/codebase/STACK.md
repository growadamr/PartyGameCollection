# Technology Stack

**Analysis Date:** 2026-01-22

## Languages

**Primary:**
- GDScript (Godot 4.5) - Backend game logic and server
- JavaScript (Vanilla) - Web player frontend
- CSS3 - Web player styling

**Configuration:**
- JSON - Game prompts and static data

## Runtime

**Godot Engine:**
- Version: 4.5
- Mobile-optimized renderer (GL compatibility)
- Built-in WebSocket server support
- Built-in physics and rendering

**Web Browser:**
- HTML5 WebSocket API
- ES6+ JavaScript (no transpilation)
- Mobile-responsive viewport

## Frameworks

**Backend:**
- Godot Engine 4.5 - Game engine and networked game host
  - Built-in WebSocket server via `TCPServer` + `WebSocketPeer`
  - Built-in `JSON` parsing
  - Signal-based event system

**Frontend:**
- Vanilla JavaScript (no framework)
- HTML5 with mobile meta tags
- CSS3 with CSS variables

**Testing:**
- None detected

**Build/Dev:**
- Godot Editor for GDScript compilation
- HTML/JS/CSS requires no build step (served as-is)

## Key Dependencies

**Critical:**
- Godot 4.5 built-in WebSocket - Enables bidirectional communication between host and web clients
- Browser WebSocket API - Standard feature, no external dependencies

**Infrastructure:**
- TCPServer (Godot built-in) - Listens for client connections
- WebSocketPeer (Godot built-in) - Manages individual client connections
- FileAccess (Godot built-in) - Loads prompt data from JSON files

**No External Package Dependencies:**
- Web player uses 0 npm/external packages
- Godot uses only built-in features
- Pure vanilla JavaScript, HTML, CSS

## Configuration

**Environment:**
- Hardcoded defaults in source code
- No `.env` files or environment variable support
- Server port: Default 8080 (configurable at startup in `network_manager.gd`)
- Connection timeout: 10 seconds
- Max reconnect attempts: 3

**Build:**
- Godot project config: `project.godot`
  - Rendering method: mobile (GL compatibility)
  - Main scene: `res://scenes/main.tscn`
  - Autoloaded managers: `GameManager`, `NetworkManager`
  - Viewport: 720x1280 (portrait mobile)

**Runtime Configuration Files:**
- `scripts/autoload/game_manager.gd` - Game state and player management
- `scripts/autoload/network_manager.gd` - WebSocket server setup and message routing
- `data/prompts/charades_prompts.json` - Game prompts
- `data/prompts/quick_draw_words.json` - Drawing game words
- `data/prompts/letter_combos.json` - Word bomb letter combinations

## Platform Requirements

**Development:**
- Godot 4.5 editor
- Text editor/IDE for GDScript and JavaScript
- Web browser for testing web player (Chrome, Safari, Firefox with WebSocket support)

**Production:**
- Host Device: Runs Godot game as server
  - Needs WiFi connectivity to accept client connections
  - Listens on port 8080
  - Mobile-capable (iOS/Android export available)
- Client Device: Web browser
  - Any modern browser with WebSocket support
  - Same WiFi network as host
  - Mobile-optimized interface (responsive design)

## Architecture Overview

**Hybrid Local-Network Architecture:**
- **Host**: Godot 4.5 application running WebSocket server on port 8080
- **Clients**: Web browser connecting via WebSocket to host IP:8080
- **Communication**: Text-based JSON messages over WebSocket
- **State**: Host maintains authoritative game state; clients are thin UI clients

---

*Stack analysis: 2026-01-22*
