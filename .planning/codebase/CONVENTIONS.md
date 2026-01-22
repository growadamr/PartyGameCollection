# Coding Conventions

**Analysis Date:** 2026-01-22

## Naming Patterns

**Files:**
- GDScript files: `snake_case.gd` (e.g., `game_manager.gd`, `quick_draw.gd`, `network_manager.gd`)
- JavaScript files: `camelCase.js` (e.g., `app.js`, `websocket.js`, `charades.js`, `quickdraw.js`)
- Scenes: `PascalCase.tscn` with descriptive names (e.g., `game_select.tscn`, `player_waiting.tscn`)

**Functions/Methods:**
- GDScript: `snake_case` with descriptive names (e.g., `_ready()`, `start_game()`, `add_player()`, `_on_timer_tick()`)
- GDScript private methods prefixed with underscore: `_method_name()` (e.g., `_load_prompts()`, `_initialize_game()`, `_validate_guess()`)
- JavaScript: `camelCase` (e.g., `setupEventListeners()`, `handlePrepare()`, `submitGuess()`)

**Variables:**
- GDScript: `snake_case` (e.g., `session_id`, `is_host`, `player_order`, `time_remaining`)
- JavaScript: `camelCase` (e.g., `playerId`, `playerName`, `selectedCharacter`, `messageHandlers`)
- Constants in GDScript: `SCREAMING_SNAKE_CASE` (e.g., `TURN_TIME`, `DEFAULT_PORT`)
- Private variables prefixed with underscore in GDScript (e.g., `_server`, `_clients`, `_is_connected`)

**Types:**
- GDScript uses type hints: `var player_id: String`, `func add_player(player_id: String) -> void`
- JavaScript uses JSDoc style comments for type information
- Dictionary/Object keys use snake_case: `{"player_id": ..., "character": ...}`

## Code Style

**Formatting:**
- GDScript: 4-space indentation (Godot standard)
- JavaScript: Consistent spacing, 4-space indentation in most files
- EditorConfig enforces UTF-8 charset (`.editorconfig` present)

**Linting:**
- No formal linter detected (no .eslintrc, .prettierrc, or biome.json)
- Code follows consistent style by convention

**Line Length:**
- No hard limit enforced, but lines generally kept reasonable (~100 characters)
- GDScript files maintain readability with wrapped statements

## Import Organization

**GDScript Order:**
1. `extends` declaration at top
2. `class_name` declaration (if applicable)
3. Comments/docstrings
4. Signal declarations
5. Variable declarations (public, then private)
6. Function definitions (`_ready()`, then public, then private)

Example from `game_manager.gd`:
```gdscript
extends Node

## Global game state manager
## Handles session data, player management, and game transitions

signal player_joined(player_id: String, player_data: Dictionary)
signal player_left(player_id: String)

var session_id: String = ""
var is_host: bool = false

func _ready() -> void:
    local_player_id = _generate_uuid()
```

**JavaScript Order:**
1. Class definition
2. Constructor
3. Initialization method (`init()`)
4. Public methods
5. Private/handler methods
6. Global instance at end

Example from `app.js`:
```javascript
class PartyGameApp {
    constructor() { ... }
    init() { ... }
    setupEventListeners() { ... }
    setupSocketHandlers() { ... }
    // ... other methods
}

document.addEventListener('DOMContentLoaded', () => {
    window.app = new PartyGameApp();
});
```

**No path aliases detected** - imports use relative paths or global instances.

## Error Handling

**GDScript Patterns:**
- Signals used for asynchronous event communication (e.g., `signal game_ended(results: Dictionary)`)
- Error functions prefixed with underscore convention for handlers (e.g., `_on_message_received()`)
- Guard clauses for null checks: `if not _server: return`
- Dictionary `.get()` with defaults: `data.get("type", "")` or `data.get("score", 0)`

Example from `network_manager.gd`:
```gdscript
func _handle_client_message(data: Dictionary) -> void:
    var msg_type = data.get("type", "")

    match msg_type:
        "join_accepted":
            GameManager.local_player_id = data.get("player_id", "")
```

**JavaScript Patterns:**
- Try-catch for JSON parsing: `try { const data = JSON.parse(...) } catch(e) { console.error(...) }`
- Early returns to prevent errors: `if (!this.isConnected || !this.socket) { return false; }`
- Nullish coalescing with `?.` operator: `document.getElementById('btn-start')?.addEventListener(...)`
- Console logging for debugging: `console.log()`, `console.error()`, `console.warn()`

Example from `websocket.js`:
```javascript
try {
    const data = JSON.parse(event.data);
    this.handleMessage(data);
} catch (e) {
    console.error('Failed to parse message:', e);
}
```

## Logging

**Framework:**
- GDScript: `print()` for general logs, `push_error()` for errors, `push_warning()` for warnings
- JavaScript: `console.log()`, `console.error()`, `console.warn()`

**Patterns:**
- Connection events logged: `print("Server started on port ", port)`
- Message types logged for debugging: `console.log('Received:', type, data)`
- Errors include context: `push_error("Failed to start server on port %d: %s" % [port, error_string(err)])`
- No structured logging framework (no winston, pino, or serilog)

Example from `game_manager.gd`:
```gdscript
print("Server started on port ", port)
push_error("Failed to start server on port %d: %s" % [port, error_string(err)])
```

## Comments

**When to Comment:**
- File headers with purpose: `/** Main application controller for Party Games web player */`
- Method/function purpose when non-obvious
- Complex game logic with explanation of state transitions
- Network message types documented

**JSDoc/TSDoc:**
- GDScript uses doc comments: `## Global game state manager`
- JavaScript uses block comments for classes: `/** Class description */`
- Inline comments explain non-obvious logic (e.g., `# Prefer IPv4 non-localhost addresses`)

Example from `charades.gd`:
```gdscript
## Base class for all party games
##
## Handles turn management and round structure

signal game_ended(results: Dictionary)
```

**Comment Styles:**
- GDScript: `#` for single-line, `##` for documentation
- JavaScript: `//` for single-line, `/** */` for multi-line/documentation

## Function Design

**Size:**
- Most functions 15-50 lines (reasonable length)
- Game state handlers tend to be longer (50-100 lines) but focused on single game
- Private helper functions are concise

**Parameters:**
- Dictionary-based when multiple related parameters needed
- Type hints in GDScript: `func set_local_player(player_name: String, character_id: int) -> void`
- JavaScript methods accept single app context or specific values

**Return Values:**
- GDScript uses `-> void`, `-> String`, `-> Dictionary` type hints
- Early returns to avoid nested conditions
- Signals used for async return values instead of return statements

Example from `game_manager.gd`:
```gdscript
func update_score(player_id: String, points: int) -> void:
    if players.has(player_id):
        players[player_id]["score"] += points
        score_updated.emit(player_id, players[player_id]["score"])
```

## Module Design

**Exports:**
- GDScript autoload singletons: `GameManager` and `NetworkManager` as global managers
- JavaScript global instances: `window.app`, `window.gameSocket`, `window.charadesGame`
- JavaScript classes instantiated and assigned to window object for global access

**Barrel Files:**
- Not used - each script file is independent

Example from `app.js`:
```javascript
// Global instance at end of file
document.addEventListener('DOMContentLoaded', () => {
    window.app = new PartyGameApp();
});
```

**Class Structure:**
- Each game has separate handler class: `CharadesGame`, `QuickDrawGame`, `WordBombGame`
- Base game class in GDScript: `scripts/games/base_game.gd` extends `Node`
- Game-specific implementations extend base or Control

## Interdependencies

**GDScript Patterns:**
- Managers accessed as `GameManager.*` and `NetworkManager.*` (autoload singletons)
- @onready attribute for node references: `@onready var timer_label: Label = $VBox/Header/TimerLabel`
- Signal-driven communication between managers and scene scripts

**JavaScript Patterns:**
- Global socket instance: `gameSocket.send()`, `gameSocket.on()`
- Parent app context passed to game handlers: `charadesGame.init(app)`
- Window globals prevent need for import statements

---

*Convention analysis: 2026-01-22*
