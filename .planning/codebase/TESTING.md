# Testing Patterns

**Analysis Date:** 2026-01-22

## Test Framework

**Runner:**
- Not detected - No Jest, Vitest, pytest, or Godot test framework configured

**Assertion Library:**
- Not detected - No testing library present

**Run Commands:**
- No test commands available
- No CI/CD test pipeline configured

**Test Infrastructure Status:**
- No test files found (`*.test.*` or `*.spec.*`)
- No test configuration files (`jest.config.js`, `vitest.config.js`, etc.)
- No test runners installed (absence of test dependencies in package managers)

## Test File Organization

**Location:**
- Not applicable - No test infrastructure present

**Naming:**
- Not applicable - No tests found

**Structure:**
- Not applicable - No tests found

## Test Structure

**Manual Testing Pattern:**
- Games tested via browser/mobile WebSocket connection
- Host runs Godot application, web players connect via `web-player/`
- Test approach: Connect multiple clients and verify game flow

**Example Manual Test Flow (Charades):**
1. Start Godot host application
2. Web players connect via `http://host-ip:8080` or QR code
3. Players join and select characters
4. Host selects game
5. Verify prompts appear only to actor
6. Verify guesses are validated correctly
7. Verify scoring works
8. Verify game ends properly

## Mocking

**Framework:**
- Not used - No mocking library detected

**Patterns:**
- Manual WebSocket testing using actual connections
- No mock/stub implementations for testing isolation
- In-browser testing via WebSocket connects to real Godot server

**What to Mock:**
- Not applicable without test framework

**What NOT to Mock:**
- WebSocket connections tested as real protocol exchanges
- Game state transitions tested through actual game flow
- Network messages validated through live messaging

## Fixtures and Factories

**Test Data:**
- Prompt data stored in JSON files:
  - `data/prompts/charades_prompts.json` - Game prompts by category
  - `data/prompts/quick_draw_words.json` - Drawing prompts
  - `data/prompts/letter_combos.json` - Letter combinations for Word Bomb

Example from `data/prompts/charades_prompts.json`:
```json
{
  "movies_tv": ["Star Wars", "Harry Potter", "Frozen"],
  "actions": ["Swimming", "Dancing", "Cooking"],
  ...
}
```

**Location:**
- `/Users/adamgrow/PartyGameCollection/data/prompts/` - All prompt fixtures

**Character Data:**
- Defined in `GameManager.gd` as constant `CHARACTERS`:
```gdscript
const CHARACTERS = [
    {"id": 0, "name": "Red Knight", "color": Color.RED, "sprite": "res://assets/characters/red_knight/south.png"},
    {"id": 1, "name": "Blue Wizard", "color": Color.BLUE, "sprite": "res://assets/characters/blue_wizard/south.png"},
    ...
]
```

## Coverage

**Requirements:**
- None enforced - No test coverage tools or requirements

**View Coverage:**
- Not applicable - No coverage reporting configured

## Test Types

**Unit Tests:**
- Not present
- No isolated testing of individual functions/methods
- Game logic tightly coupled to UI and networking

**Integration Tests:**
- Manual - WebSocket connection between Godot server and web clients
- Game flow verified through manual testing
- No automated integration test suite

**E2E Tests:**
- Not used - Games tested by human players connecting via browser
- QR code generation tested manually: `scripts/utils/qr_generator.gd`
- Game state synchronization tested through multiple simultaneous connections

## Common Patterns in Existing Code

**Async Testing Patterns (GDScript):**
- Games use `await get_tree().create_timer(3.0).timeout` to wait before transitions
- Signals emitted and handled asynchronously rather than tested in isolation

Example from `charades.gd`:
```gdscript
func _apply_result(data: Dictionary) -> void:
    # ... update UI ...

    if GameManager.is_host:
        await get_tree().create_timer(3.0).timeout
        _next_turn()
```

**Async Testing Patterns (JavaScript):**
- Timer-based waits for state transitions
- WebSocket message handlers use `setInterval()` for polling
- No promises or async/await patterns

Example from `charades.js`:
```javascript
handleGameEnd(data) {
    this.stopTimer();
    this.app.showScreen('game-over');

    // ... populate scores ...

    setTimeout(() => {
        this.app.returnToLobby();
    }, 5000);
}
```

**Error Testing Patterns:**
- Try-catch blocks catch JSON parsing errors
- WebSocket state checked before operations: `if (!this.isConnected || !this.socket)`
- Guard clauses prevent errors: `if (!this.takenCharacters.includes(char.id))`

Example from `websocket.js`:
```javascript
send(data) {
    if (!this.isConnected || !this.socket) {
        console.error('Cannot send: not connected');
        return false;
    }

    try {
        this.socket.send(JSON.stringify(data));
        return true;
    } catch (e) {
        console.error('Send failed:', e);
        return false;
    }
}
```

## Testing Recommendations

**Current Gap:**
- Zero automated test coverage
- All validation manual through gameplay
- Risk: Game state transitions untested in isolation
- Risk: Network message handling untested for edge cases

**Where Tests Should Be Added:**
- `scripts/autoload/game_manager.gd` - State management (player add/remove, scoring)
- `scripts/autoload/network_manager.gd` - Message routing, connection handling
- `scripts/games/charades.gd` - Guess validation (fuzzy matching), turn logic
- `web-player/js/websocket.js` - Message parsing, event emission
- `web-player/js/app.js` - Screen transitions, character selection

**Testing Priority:**
1. **HIGH:** Game state validation (`game_manager.gd` add_player, remove_player, update_score)
2. **HIGH:** Guess validation logic (`charades.gd` fuzzy matching, `word_bomb.gd` word validation)
3. **MEDIUM:** Network message handling (`network_manager.gd` routing, `websocket.js` parsing)
4. **MEDIUM:** UI state transitions (`app.js` screen changes)
5. **LOW:** Canvas drawing in Quick Draw (visual testing difficult to automate)

---

*Testing analysis: 2026-01-22*
