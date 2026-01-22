# Phase 1: Core Game Foundation - Research

**Researched:** 2026-01-22
**Domain:** Godot 4.5 game development, WebSocket-based multiplayer, social deduction game mechanics
**Confidence:** HIGH

## Summary

Phase 1 implements the Imposter game, a social deduction party game where players receive role assignments (secret word or "IMPOSTER" label) and engage in free-form discussion. This phase builds on the existing PartyGameCollection architecture which uses Godot 4.5 as host with GDScript controllers, vanilla JavaScript web players, and WebSocket communication.

The standard approach follows the established pattern: create a game controller script inheriting from Control, implement role assignment logic on the host, broadcast role data via NetworkManager, and create corresponding web handlers for the player devices. Role assignment for social deduction games typically uses 1 imposter for 4-5 players and 2 imposters for 6-8 players, consistent with the project's requirements.

The word list compilation task is straightforward: combine existing prompt data from charades_prompts.json and quick_draw_words.json into a new imposter_words.json file without modifying originals, ensuring a diverse word pool suitable for social deduction gameplay.

**Primary recommendation:** Follow the existing game implementation pattern (charades.gd, charades.js, and scene structure) as the template. Implement role assignment in _initialize_game() with host-authoritative logic, broadcast individual role data to each player via send_to_client(), and create a free-form discussion phase with no enforced turn structure or timers.

## Standard Stack

The established libraries/tools for this project domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot Engine | 4.5 | Game host and server | Project foundation, handles game logic and WebSocket server |
| GDScript | - | Game controller scripting | Native Godot language, type-safe, excellent editor integration |
| FileAccess API | Godot 4.5 | JSON file loading | Built-in Godot API for file I/O, stable across 4.x versions |
| JSON class | Godot 4.5 | JSON parsing | Native Godot JSON parser using parse_string() method |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| WebSocketPeer | Godot 4.5 | WebSocket connections | Already used by NetworkManager for host-client communication |
| Vanilla JavaScript | ES6+ | Web player handlers | No build step required, runs directly in mobile browsers |
| HTML5 Canvas | - | Drawing (future phases) | Native browser API, no dependencies |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Godot 4.5 | Godot 3.5 | Godot 4.x has breaking changes but better performance and modern APIs |
| Vanilla JS | React/Vue | Framework adds build complexity, contradicts "no build step" design |
| WebSocket | HTTP polling | WebSocket provides real-time bidirectional communication needed for party games |

**Installation:**
```bash
# No package installation needed - Godot and web tech are project foundations
# JSON data files are plain text, no processing required
```

## Architecture Patterns

### Recommended Project Structure
```
scripts/games/imposter.gd              # Game controller (host-authoritative)
scenes/games/imposter/imposter.tscn    # Game scene with UI layout
web-player/js/games/imposter.js        # Web player handler class
web-player/index.html                  # Add screen section for imposter
data/prompts/imposter_words.json       # Compiled word list
```

### Pattern 1: Host-Authoritative Game Controller
**What:** The Godot host controls all game state and logic. Clients only display UI and send player actions. Host validates and broadcasts state changes.

**When to use:** Always for multiplayer party games to prevent cheating and ensure synchronization.

**Example:**
```gdscript
# Source: Existing codebase pattern (charades.gd lines 63-86)
func _initialize_game() -> void:
    if GameManager.is_host:
        # Host generates game state
        player_order = GameManager.players.keys()
        player_order.shuffle()

        # Host determines role assignments
        var imposters = _select_imposters(player_order.size())
        var secret_word = _select_random_word()

        # Broadcast to each player individually (personalized data)
        for player_id in player_order:
            var is_imposter = player_id in imposters
            NetworkManager.send_to_client(_peer_id_for_player(player_id), {
                "type": "imposter_role",
                "is_imposter": is_imposter,
                "word": secret_word if not is_imposter else "",
                "imposter_count": imposters.size()
            })
    else:
        feedback_label.text = "Waiting for game to start..."
```

### Pattern 2: Message-Driven State Synchronization
**What:** Host broadcasts messages with type field. Both host and clients have message handlers that update local UI based on message type.

**When to use:** For all networked state changes in multiplayer games.

**Example:**
```gdscript
# Source: Existing pattern (charades.gd lines 547-577)
func _on_message_received(_peer_id: int, data: Dictionary) -> void:
    var msg_type = data.get("type", "")

    match msg_type:
        "imposter_role":
            _apply_role_assignment(data)
        "discussion_started":
            _show_discussion_phase(data)
        "game_end":
            _show_game_over(data)
```

### Pattern 3: Web Player Class Handler
**What:** Each game gets a JavaScript class that handles game-specific logic and UI. Class is instantiated as global singleton (window.gameName).

**When to use:** For each game's web player implementation.

**Example:**
```javascript
// Source: Existing pattern (charades.js lines 1-17)
class ImposterGame {
    constructor() {
        this.app = null;
        this.isImposter = false;
        this.secretWord = "";
    }

    init(app) {
        this.app = app;
        this.setupEventListeners();
        this.setupSocketHandlers();
    }

    setupSocketHandlers() {
        gameSocket.on('imposter_role', (data) => {
            this.handleRoleAssignment(data);
        });
    }
}

// Global singleton instance
window.imposterGame = new ImposterGame();
```

### Pattern 4: JSON File Loading in Godot 4.5
**What:** Use FileAccess.open() with READ mode, get_as_text(), then JSON.parse_string() to load data.

**When to use:** Loading static data files like word lists or configurations.

**Example:**
```gdscript
# Source: Existing pattern (charades.gd lines 49-61) + Godot 4.5 docs
func _load_words() -> Array:
    var file = FileAccess.open("res://data/prompts/imposter_words.json", FileAccess.READ)
    if file:
        var json_text = file.get_as_text()
        var json = JSON.parse_string(json_text)
        file.close()

        if json and json is Array:
            return json
        else:
            push_error("Invalid JSON format in imposter_words.json")
    else:
        push_error("Failed to open imposter_words.json")

    # Fallback words if file missing
    return ["apple", "car", "house", "tree", "book"]
```

### Pattern 5: Role Assignment Algorithm for Social Deduction
**What:** Determine imposter count based on player count, randomly select imposters without bias.

**When to use:** At game initialization for any social deduction game.

**Example:**
```gdscript
# Imposter scaling based on player count
func _get_imposter_count(player_count: int) -> int:
    if player_count >= 6:
        return 2  # 6-8 players: 2 imposters
    elif player_count >= 4:
        return 1  # 4-5 players: 1 imposter
    else:
        return 1  # Minimum 1 imposter even for small groups

func _select_imposters(player_ids: Array) -> Array:
    var imposter_count = _get_imposter_count(player_ids.size())
    var shuffled = player_ids.duplicate()
    shuffled.shuffle()

    var imposters = []
    for i in range(imposter_count):
        imposters.append(shuffled[i])

    return imposters
```

### Anti-Patterns to Avoid
- **Broadcasting sensitive role data globally:** Don't send imposter assignments to all players. Use send_to_client() for personalized data, not broadcast(). This prevents players from seeing network traffic in browser dev tools to cheat.
- **Client-side role assignment:** Never let web clients determine roles. Host must be authoritative to prevent tampering.
- **Modifying original data files:** Don't edit charades_prompts.json or quick_draw_words.json. Create new compiled file to preserve game-specific data.
- **Turn-based structure for free-form discussion:** Don't enforce turns or timers during discussion phase. Imposter games work best with natural conversation flow where players talk in-person.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WebSocket server | Custom TCP/HTTP server | Godot's WebSocketPeer | Built-in, handles handshake, frame parsing, state management automatically |
| Network message protocol | Binary protocol | JSON via NetworkManager | Already implemented, debuggable, works across Godot and web |
| Player session management | Custom player tracking | GameManager.players Dictionary | Centralized state, handles join/leave, character assignment |
| Random selection | Custom shuffle algorithm | Array.shuffle() in GDScript | Built-in cryptographic randomness, tested |
| JSON parsing | Manual string parsing | JSON.parse_string() | Handles edge cases, validation, error reporting |
| Web player routing | Custom screen manager | PartyGameApp.showScreen() | Already handles transitions, cleanup, initialization |

**Key insight:** The PartyGameCollection architecture is already established and battle-tested with 3 existing games (Charades, Quick Draw, Word Bomb). Any deviation from these patterns creates inconsistency and increases maintenance burden. Follow existing patterns exactly.

## Common Pitfalls

### Pitfall 1: Revealing Roles via Global Broadcast
**What goes wrong:** Using NetworkManager.broadcast() to send role assignments means all clients receive all role data, allowing players to cheat by inspecting browser network traffic.

**Why it happens:** Broadcast is convenient and used for most game messages (like score updates, phase transitions). It's easy to default to broadcast for all messages.

**How to avoid:**
- Use NetworkManager.send_to_client(peer_id, data) for role assignments
- Map player IDs to peer IDs (existing pattern: "peer_%d" format in network_manager.gd line 111)
- Only broadcast non-sensitive data like "discussion phase started"

**Warning signs:**
- All players in testing see each other's roles
- Network inspector shows role data in messages to non-target players

### Pitfall 2: FileAccess API Confusion (Godot 4.x Breaking Changes)
**What goes wrong:** Using Godot 3.x FileAccess patterns (File.new(), open(...), etc.) which don't exist in Godot 4.x. Error: "Invalid call. Nonexistent function 'new' in base 'FileAccess'."

**Why it happens:** Godot 4.0+ changed FileAccess from instance-based to static methods. Many online tutorials still show Godot 3.x patterns.

**How to avoid:**
- Godot 4.x: `FileAccess.open(path, mode)` returns FileAccess object directly
- Godot 3.x: `var file = File.new(); file.open(path, mode)`
- Always check Godot docs for stable (4.x) version, not 3.x

**Warning signs:**
- "Nonexistent function 'new' in base 'FileAccess'" error
- Following tutorials dated before 2023 (Godot 4.0 released 2023-03-01)

### Pitfall 3: Web Player Class Not Initialized
**What goes wrong:** Web player screen shows but buttons don't work, no handlers respond to messages. Console shows "imposterGame is undefined" or similar.

**Why it happens:** Forgetting to initialize game handler in app.js startGame() switch statement, or forgetting to include script tag in index.html.

**How to avoid:**
- Add script tag: `<script src="js/games/imposter.js"></script>` in index.html before app.js
- Add case to PartyGameApp.startGame() method
- Follow exact pattern from charades.js (lines 260-279 in app.js)

**Warning signs:**
- Game screen shows but no interactivity
- Browser console errors about undefined game objects
- Socket messages received but no handlers fire

### Pitfall 4: Empty Discussion Phase Implementation
**What goes wrong:** After role reveal, players see their role but no guidance on what to do. Awkward silence or confusion about game flow.

**Why it happens:** Discussion phase has no enforced mechanics (no turns, no timer, no scoring), so it feels like there's "nothing to implement." But players still need UI feedback and context.

**How to avoid:**
- Show clear role display: "You are an Imposter!" or "Secret Word: BANANA"
- Add instructional text: "Discuss with your group to find the imposter!"
- Display imposter count: "There are 2 imposters among you"
- Keep screen simple but informative

**Warning signs:**
- Testers ask "what do we do now?" after role reveal
- Screen feels empty or unclear
- No indication of imposter count or game objective

### Pitfall 5: Synchronous Word List Compilation
**What goes wrong:** Building word list at runtime by reading multiple JSON files, causing lag or failed loads if files missing.

**Why it happens:** Thinking of word compilation as runtime operation instead of one-time data preparation task.

**How to avoid:**
- Compile imposter_words.json as ONE-TIME manual or scripted task
- Result is committed to repo as static data file
- Game loads single file at initialization, same as charades loads charades_prompts.json
- No runtime merging or processing needed

**Warning signs:**
- Loading multiple prompt files in _ready() or _initialize_game()
- Slow game start with file I/O
- Complex merge logic in game controller

## Code Examples

Verified patterns from official sources:

### Role Assignment and Personalized Broadcasting
```gdscript
# Host determines roles and sends personalized data to each player
func _initialize_game() -> void:
    if not GameManager.is_host:
        return

    var player_ids = GameManager.players.keys()
    var imposter_count = _get_imposter_count(player_ids.size())

    # Random imposter selection
    var shuffled = player_ids.duplicate()
    shuffled.shuffle()
    var imposters = shuffled.slice(0, imposter_count)

    # Select secret word
    var word = words[randi() % words.size()]

    # Send personalized role to each player
    for player_id in player_ids:
        var peer_id = _get_peer_id_for_player(player_id)
        var is_imposter = player_id in imposters

        NetworkManager.send_to_client(peer_id, {
            "type": "imposter_role",
            "is_imposter": is_imposter,
            "word": word if not is_imposter else "",
            "imposter_count": imposter_count,
            "total_players": player_ids.size()
        })

    # Broadcast non-sensitive phase transition
    NetworkManager.broadcast({
        "type": "discussion_started",
        "phase": "discussion",
        "imposter_count": imposter_count
    })

func _get_peer_id_for_player(player_id: String) -> int:
    # Player IDs follow "peer_N" format from network_manager.gd
    if player_id.begins_with("peer_"):
        return int(player_id.substr(5))
    return -1
```

### Web Player Role Display
```javascript
// Web player receives personalized role data
setupSocketHandlers() {
    gameSocket.on('imposter_role', (data) => {
        this.isImposter = data.is_imposter;
        this.secretWord = data.word;
        this.imposterCount = data.imposter_count;

        this.showRoleScreen();
    });

    gameSocket.on('discussion_started', (data) => {
        this.showDiscussionPhase();
    });
}

showRoleScreen() {
    const roleView = document.getElementById('imposter-role-view');
    const roleLabel = document.getElementById('imposter-role-label');
    const wordDisplay = document.getElementById('imposter-word');

    roleView.classList.remove('hidden');

    if (this.isImposter) {
        roleLabel.textContent = "You are an IMPOSTER!";
        roleLabel.className = 'role-label imposter';
        wordDisplay.textContent = "IMPOSTER";
        wordDisplay.className = 'word-display imposter';
    } else {
        roleLabel.textContent = "You are NOT the imposter!";
        roleLabel.className = 'role-label innocent';
        wordDisplay.textContent = this.secretWord;
        wordDisplay.className = 'word-display innocent';
    }
}
```

### Word List Compilation Script (One-Time Task)
```javascript
// Node.js script to compile word list (run once, commit result)
// Usage: node scripts/compile_imposter_words.js

const fs = require('fs');

// Read source files
const charades = JSON.parse(fs.readFileSync('data/prompts/charades_prompts.json', 'utf8'));
const quickDraw = JSON.parse(fs.readFileSync('data/prompts/quick_draw_words.json', 'utf8'));

// Flatten charades categories
const charadesWords = [];
for (const category of Object.values(charades)) {
    charadesWords.push(...category);
}

// Flatten quick draw difficulties
const quickDrawWords = [];
for (const difficulty of Object.values(quickDraw)) {
    quickDrawWords.push(...difficulty);
}

// Combine and deduplicate
const allWords = [...new Set([...charadesWords, ...quickDrawWords])];

// Sort alphabetically
allWords.sort();

// Write output
fs.writeFileSync(
    'data/prompts/imposter_words.json',
    JSON.stringify(allWords, null, 2)
);

console.log(`Compiled ${allWords.length} unique words to imposter_words.json`);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Godot 3.x FileAccess | Godot 4.x static FileAccess | Godot 4.0 (2023-03) | Must use FileAccess.open() not File.new().open() |
| Broadcast all game state | Personalized messages via send_to_client() | Project inception | Prevents cheating via network inspection |
| Client-side game logic | Host-authoritative architecture | Project inception | Single source of truth, no client tampering |
| Build tools for web player | Vanilla JS, no build step | Project inception | Zero setup for players, works on any device |

**Deprecated/outdated:**
- **Godot 3.x File API**: Use FileAccess static methods in Godot 4.x
- **Global broadcast for roles**: Use send_to_client() for personalized data
- **Timer-based discussion**: Free-form discussion is standard for social deduction games

## Open Questions

Things that couldn't be fully resolved:

1. **Question: Should discussion phase have optional timer?**
   - What we know: Requirements specify free-form discussion with no enforced turn structure. Existing games (Charades, Quick Draw) use timers but they're turn-based drawing/acting games.
   - What's unclear: Whether hosts might want optional time limits for discussions to keep game moving.
   - Recommendation: Implement pure free-form for Phase 1 as specified. Phase 2+ can add optional timer if playtesting shows discussions drag.

2. **Question: How are player-to-peer ID mappings maintained?**
   - What we know: NetworkManager assigns peer IDs when clients connect (network_manager.gd line 65). Player IDs follow "peer_%d" format (line 111).
   - What's unclear: No explicit mapping dictionary found in codebase. Mapping appears to be implicit in ID string format.
   - Recommendation: Use string parsing approach: if player_id starts with "peer_", extract number. This matches existing pattern.

3. **Question: Error handling for missing word list file?**
   - What we know: Charades includes fallback prompts if file load fails (charades.gd lines 58-61).
   - What's unclear: Whether imposter game should fail gracefully or hard-fail since word list is critical game data.
   - Recommendation: Follow charades pattern with minimal fallback list (10-20 words) but log prominent warning. Game is playable but not ideal without full word list.

## Sources

### Primary (HIGH confidence)
- **Godot 4.5 Codebase Analysis**: Examined charades.gd, network_manager.gd, game_manager.gd, charades.js, app.js from existing project
- **Godot FileAccess Documentation**: [FileAccess — Godot Engine (stable) documentation](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)
- **Godot Best Practices**: [Best practices — Godot Engine (4.4) documentation](https://docs.godotengine.org/en/4.4/tutorials/best_practices/index.html)

### Secondary (MEDIUM confidence)
- **JSON Loading in Godot 4**: [Saving/loading data :: Godot 4 Recipes](https://kidscancode.org/godot_recipes/4.x/basics/file_io/index.html) - Verified with codebase pattern
- **Game State Management**: [State Management in Godot with a Vue.js Twist](https://tumeo.space/gamedev/2023/10/18/godot-states/) - Discusses autoload patterns
- **Social Deduction Game Balance**: [How to Play Imposter Game: Complete Tutorial Guide](https://impostergame.win/how-to-play) - Confirms 1-2 imposter scaling
- **JavaScript Singleton Pattern**: [Singleton Pattern | Patterns.dev](https://www.patterns.dev/vanilla/singleton-pattern/) - Explains global game handler pattern

### Tertiary (LOW confidence - marked for validation)
- **Imposter Role Algorithms**: [7 Best Social Deduction Games for Strategic Thinking in 2026](https://www.eneba.com/hub/collectibles/best-social-deduction-games/) - General social deduction practices
- **Free-Form Discussion Implementation**: [Game Rules — Undercover™: Word Party Game](https://www.yanstarstudio.com/undercover-how-to-play) - Similar imposter game mechanics

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All technologies are established in existing codebase, verified by reading 3 complete games
- Architecture: HIGH - Patterns extracted directly from working code (charades.gd 591 lines analyzed)
- Pitfalls: MEDIUM - Based on Godot 4.x breaking changes documentation and common multiplayer game issues, not project-specific testing

**Research date:** 2026-01-22
**Valid until:** ~2026-03-22 (60 days - Godot stable, patterns unlikely to change in short term)

**Note on sources:** Web search results supplement existing codebase analysis but are not primary drivers. The existing three games (Charades, Quick Draw, Word Bomb) provide HIGH confidence templates to follow. External research validates approaches (social deduction role scaling, JSON loading patterns) but implementation details come from codebase.
