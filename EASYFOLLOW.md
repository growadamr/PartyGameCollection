# Understanding This Game - A Beginner's Guide

Welcome! This document explains how this party game works, written for someone who's just starting to learn programming. We'll go step by step through everything.

---

## What Is This Project?

This is a **multiplayer party game** built with the Godot game engine. Think of it like Jackbox games - one person "hosts" the game on their phone, and friends join using their own phones. Everyone plays together!

**The games include:**
- Word Bomb - Type words containing certain letters before time runs out
- Act It Out (Charades) - Act out prompts while others guess
- Quick Draw - Draw something and others guess what it is
- Who Said It? - Write anonymous answers, then guess who wrote what
- Trivia Showdown - Fast-paced multiple choice trivia
- Fibbage - Write fake answers to trick your friends

---

## How The Files Are Organized

```
clGame/
├── project.godot          <- The main project file (like a config file)
├── scenes/                <- What players SEE (the screens/UI)
│   ├── main.tscn         <- The start screen with "Host" and "Join" buttons
│   ├── lobby/            <- All the lobby screens
│   └── games/            <- Each mini-game has its own folder
├── scripts/               <- The CODE that makes everything work
│   ├── autoload/         <- Always-running helper scripts
│   ├── lobby/            <- Code for lobby screens
│   ├── games/            <- Code for each mini-game
│   └── utils/            <- Helper tools (like QR code generator)
├── assets/                <- Images, sounds, fonts
│   └── characters/       <- The pixel art character sprites
└── data/                  <- Data files (word lists, questions, etc.)
    └── prompts/          <- Words and questions for games
```

### What's the difference between Scenes and Scripts?

- **Scenes (.tscn files)**: These define WHAT appears on screen - buttons, labels, images, their positions and sizes
- **Scripts (.gd files)**: These define WHAT HAPPENS when you interact - what code runs when you click a button

Think of it like a puppet show:
- The **scene** is the puppet and the stage
- The **script** is the puppeteer making it move

---

## Key Concept #1: Autoloads (Global Scripts)

Some scripts need to be available EVERYWHERE in the game. These are called **autoloads**.

This project has two autoloads (defined in `project.godot`):

```
GameManager   <- Keeps track of players, scores, characters
NetworkManager <- Handles sending/receiving messages between phones
```

**Why does this matter?**

Any script in the game can use these by just typing their name:

```gdscript
# Get the local player's name from anywhere
var name = GameManager.local_player_name

# Send a message to everyone from anywhere
NetworkManager.broadcast({"type": "hello"})
```

---

## Key Concept #2: Signals (Events)

Signals are how different parts of the code talk to each other. They're like sending a text message that anyone can listen for.

**Example from GameManager:**

```gdscript
# This DECLARES a signal (like creating a group chat)
signal player_joined(player_id: String, player_data: Dictionary)

# This EMITS the signal (like sending a message to the group)
player_joined.emit(player_id, players[player_id])
```

**Then in another script (like the lobby):**

```gdscript
# This CONNECTS to the signal (like joining the group chat)
GameManager.player_joined.connect(_on_player_joined)

# This function runs when the signal fires (like reading the message)
func _on_player_joined(player_id, player_data):
	print("Someone joined!")
	_refresh_player_list()
```

---

## Key Concept #3: Scene Transitions

To go from one screen to another, we use:

```gdscript
get_tree().change_scene_to_file("res://scenes/lobby/host_lobby.tscn")
```

This loads a completely new scene file and replaces the current one.

---

## How The Game Flows (Step by Step)

Let's trace what happens from opening the app to playing a game:

### Step 1: Main Menu (`scenes/main.tscn` + `scripts/main.gd`)

When you open the app, you see two buttons: **Host Game** and **Join Game**.

```gdscript
func _on_host_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/lobby/host_lobby.tscn")

func _on_join_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/lobby/join_lobby.tscn")
```

Simple! Clicking a button changes to a different scene.

---

### Step 2a: Hosting a Game (`scripts/lobby/host_lobby.gd`)

The host enters their name and picks a character:

```gdscript
func _on_create_pressed() -> void:
    var player_name = name_input.text.strip_edges()

    # Create a new game session
    GameManager.create_session()
    GameManager.set_local_player(player_name, selected_character)

    # Go to the waiting lobby
    get_tree().change_scene_to_file("res://scenes/lobby/waiting_lobby.tscn")
```

---

### Step 2b: The Waiting Lobby (`scripts/lobby/waiting_lobby.gd`)

This is where the host waits for players to join. It does three important things:

**1. Starts a server (so other phones can connect):**
```gdscript
func _start_server() -> void:
    var err = NetworkManager.start_server()
    # ...
```

**2. Generates a QR code:**
```gdscript
var join_info = "%s:%d" % [ip, ws_port]  # Like "192.168.1.5:8080"
_display_qr_code(join_info, ip)
```

**3. Shows players as they join:**
```gdscript
func _on_player_joined(_player_id: String, _player_data: Dictionary) -> void:
    _refresh_player_list()
```

---

### Step 3: Joining a Game (`scripts/lobby/join_lobby.gd`)

A player enters the host's IP address (or scans the QR code), their name, and picks a character:

```gdscript
func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	var err = NetworkManager.connect_to_server(ip)
	# ...
```

When connected, they send a join request:

```gdscript
func _on_connected() -> void:
	# Request to join the game
	NetworkManager.request_join(player_name, selected_character)
```

---

### Step 4: Starting a Game (`scripts/lobby/game_select.gd`)

The host picks which game to play:

```gdscript
func _on_game_selected(game_id: String) -> void:
	# Tell all players which game is starting
	NetworkManager.broadcast({
		"type": "game_starting",
		"game": game_id
	})

	# Load the game scene
	var scene_path = "res://scenes/games/%s/%s.tscn" % [game_id, game_id]
	get_tree().change_scene_to_file(scene_path)
```

All players' phones receive the "game_starting" message and automatically load the same game scene!

---

## How Word Bomb Works (`scripts/games/word_bomb.gd`)

Let's look at a complete game to understand how multiplayer games work.

### Game Setup

When the game loads, the HOST sets up the initial state:

```gdscript
func _initialize_game() -> void:
	if GameManager.is_host:
		# Randomize player order
		player_order = GameManager.players.keys()
		player_order.shuffle()

		# Give everyone 3 lives
		for player_id in player_order:
			player_lives[player_id] = STARTING_LIVES

		# Send this info to all players
		NetworkManager.broadcast({
			"type": "word_bomb_init",
			"player_order": player_order,
			"player_lives": player_lives
		})
```

### Taking Turns

Each turn, the host picks a letter combination and tells everyone:

```gdscript
func _start_new_turn() -> void:
	current_combo = combos[randi() % combos.size()]  # Random combo like "TH"

	NetworkManager.broadcast({
		"type": "word_bomb_turn",
		"combo": current_combo,
		"player_id": current_player_id,
		"time": TURN_TIME
	})
```

### Submitting Words

When a player types a word and submits:

```gdscript
func _submit_word(word: String) -> void:
	if GameManager.is_host:
		# Host validates immediately
		_validate_word(GameManager.local_player_id, word)
	else:
		# Other players send to host for validation
		NetworkManager.send_to_server({
			"type": "word_bomb_submit",
			"word": word
		})
```

### Validation

The host checks if the word is valid:

```gdscript
func _validate_word(player_id: String, word: String) -> bool:
	# Must contain the letter combo
	if not combo in word:
		_broadcast_result(player_id, word, false, "Doesn't contain '%s'" % combo)
		return false

	# Can't reuse words
    if word in used_words:
        _broadcast_result(player_id, word, false, "Already used!")
        return false

    # Word is valid!
    used_words.append(word)
    _broadcast_result(player_id, word, true, "")
    return true
```

### Receiving Messages

Every script that needs to respond to network messages connects to the signal:

```gdscript
func _ready() -> void:
    NetworkManager.message_received.connect(_on_message_received)

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
    var msg_type = data.get("type", "")

    match msg_type:
        "word_bomb_turn":
            _apply_turn_data(data)
        "word_bomb_result":
            _apply_result(data)
        "word_bomb_explode":
            _apply_explosion(data)
        # ...
```

---

## The Networking Model

Here's a diagram of how the phones communicate:

```
		HOST PHONE (runs the server)
		┌─────────────────────────┐
		│  - Has the "truth"      │
		│  - Validates everything │
		│  - Broadcasts updates   │
		└────────────┬────────────┘
					 │
	  ┌──────────────┼──────────────┐
	  │              │              │
	  ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Player 1 │  │ Player 2 │  │ Player 3 │
│ (Client) │  │ (Client) │  │ (Client) │
└──────────┘  └──────────┘  └──────────┘
```

**Important rule:** The HOST is always the "source of truth".

- Players send their ACTIONS to the host (like "I typed this word")
- The host VALIDATES them and sends RESULTS back to everyone
- This prevents cheating and keeps everyone synchronized

---

## Reading Data Files

Games use JSON files for their word lists. Here's the letter combos file:

**`data/prompts/letter_combos.json`:**
```json
{
  "easy": ["TH", "IN", "AN", "ER", "ON"],
  "medium": ["ING", "THE", "AND", "TIO"],
  "hard": ["TION", "OUGH", "MENT", "NESS"]
}
```

**Loading it in GDScript:**
```gdscript
func _load_letter_combos() -> void:
    var file = FileAccess.open("res://data/prompts/letter_combos.json", FileAccess.READ)
    if file:
        var json = JSON.parse_string(file.get_as_text())
        letter_combos = json
        file.close()
```

---

## Character System

Characters are defined in GameManager with their properties:

```gdscript
const CHARACTERS = [
    {"id": 0, "name": "Red Knight", "color": Color.RED, "sprite": "res://assets/characters/red_knight/south.png"},
    {"id": 1, "name": "Blue Wizard", "color": Color.BLUE, "sprite": "res://assets/characters/blue_wizard/south.png"},
    # ...
]
```

If a character's sprite isn't available yet, the game shows a colored square instead (graceful fallback):

```gdscript
if sprite_path and ResourceLoader.exists(sprite_path):
    # Show the sprite image
    var texture_rect = TextureRect.new()
    texture_rect.texture = load(sprite_path)
else:
    # Fallback: show a colored rectangle
    var color_rect = ColorRect.new()
    color_rect.color = char_data["color"]
```

---

## Common Patterns You'll See

### Pattern 1: Check if Host

Many functions behave differently for host vs. regular player:

```gdscript
if GameManager.is_host:
	# Do host-only stuff (validate, broadcast)
else:
	# Do client stuff (send request to host)
```

### Pattern 2: Connect Signals in _ready()

```gdscript
func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	GameManager.player_joined.connect(_on_player_joined)
	NetworkManager.message_received.connect(_on_message_received)
```

### Pattern 3: Match Statement for Message Types

```gdscript
match msg_type:
	"game_starting":
		_start_game()
	"player_joined":
		_add_player()
	"score_update":
		_update_scores()
```

### Pattern 4: Broadcast Then Apply Locally

```gdscript
func _something_happened() -> void:
	var data = {"type": "event", "value": 42}

	if GameManager.is_host:
		NetworkManager.broadcast(data)  # Send to others
		_apply_event(data)              # Also apply to self
```

---

## Glossary

| Term | Meaning |
|------|---------|
| **Scene** | A file (.tscn) that describes what appears on screen |
| **Script** | A file (.gd) with GDScript code that controls behavior |
| **Autoload** | A script that's always available globally |
| **Signal** | A way for code to notify other code that something happened |
| **Node** | The basic building block in Godot (buttons, labels, etc. are all nodes) |
| **Host** | The player whose phone runs the game server |
| **Client** | A player connected to the host's server |
| **Broadcast** | Sending a message to ALL connected players |
| **WebSocket** | The technology used to send messages between phones |

---

## Next Steps for Learning

1. **Run the game** in the Godot editor and watch the Output panel for print statements
2. **Add print() statements** to functions to see when they run
3. **Try modifying** simple values (like `TURN_TIME = 10` to `TURN_TIME = 20`)
4. **Read the NEXTSTEPS.md** file for specific tasks you can try

---

## Quick Reference: File Locations

| What | Where |
|------|-------|
| Main menu code | `scripts/main.gd` |
| Player/game data | `scripts/autoload/game_manager.gd` |
| Network code | `scripts/autoload/network_manager.gd` |
| Host lobby | `scripts/lobby/host_lobby.gd` |
| Join lobby | `scripts/lobby/join_lobby.gd` |
| Word Bomb game | `scripts/games/word_bomb.gd` |
| Charades game | `scripts/games/charades.gd` |
| Quick Draw game | `scripts/games/quick_draw.gd` |
| Who Said It game | `scripts/games/who_said_it.gd` |
| Fibbage game | `scripts/games/fibbage.gd` |
| Trivia Showdown game | `scripts/games/trivia_showdown.gd` |
| Letter combos | `data/prompts/letter_combos.json` |
| Charades prompts | `data/prompts/charades_prompts.json` |
| Who Said It prompts | `data/prompts/who_said_prompts.json` |
| Fibbage questions | `data/prompts/fibbage_questions.json` |
| Character sprites | `assets/characters/CHARACTER_NAME/` |
| Web player | `web-player/` |

---

*Happy coding! Don't be afraid to experiment - that's how you learn!*
