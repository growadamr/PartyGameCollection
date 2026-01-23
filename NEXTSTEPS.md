# Next Steps - Party Game Collection

Specific, actionable tasks you can work on right now.

---

## 1. Fix QR Code Display (High Priority)

The QR code generator exists but may not be displaying properly. Debug it:

**File:** `scripts/lobby/waiting_lobby.gd` (line 53-91)

**Test steps:**
1. Run the game in Godot editor
2. Host a lobby
3. Check the Output panel for these debug prints:
   - `"Server running on port: 8080"`
   - `"Join info for QR code: IP:PORT"`
   - `"QR: Using version X (YxY) for Z bytes"`
   - `"QR image generated: WxH"` or `"QR generation failed..."`

**If QR fails**, the fallback text should show. If neither shows, check:
- Is `qr_placeholder` node path correct? (`$ScrollContainer/VBox/QRSection/QRPlaceholder`)
- Add more debug prints in `_display_qr_code()` function

---

## 2. Test Character Sprites Display

**Files to check:**
- `scripts/lobby/host_lobby.gd` (lines 39-73)
- `scripts/lobby/join_lobby.gd` (lines 48-84)

**Test steps:**
1. Run the game
2. Go to Host Game
3. Verify Red Knight, Blue Wizard, Green Ranger, Purple Rogue, Pink Princess show pixel art
4. Verify Yellow Bard, Orange Monk, Teal Robot show colored rectangles (fallback)

**If sprites don't load**, check:
```gdscript
# In _create_character_button(), add debug:
print("Loading sprite: ", sprite_path, " exists: ", ResourceLoader.exists(sprite_path))
```

---

## 3. Download Remaining 3 Characters (When Ready)

Check if PixelLab finished generating:

```bash
# In Claude Code, run:
mcp__pixellab__list_characters
```

If Yellow Bard, Orange Monk, or Teal Robot show completed, get their download URLs:

```bash
mcp__pixellab__get_character(character_id="a76fc607-79ac-477a-a9d7-16c24ff48f6e")  # Yellow Bard
mcp__pixellab__get_character(character_id="9a46ba4a-5a5c-4263-a3e5-2ee065950096")  # Orange Monk
mcp__pixellab__get_character(character_id="649694d4-ebea-4963-ade3-fc4a71a6632a")  # Teal Robot
```

Then download to:
- `assets/characters/yellow_bard/south.png` (etc.)
- `assets/characters/orange_monk/south.png` (etc.)
- `assets/characters/teal_robot/south.png` (etc.)

And update `GameManager.CHARACTERS` to add the sprite paths.

---

## 4. Add Sound Effects (Easy Win)

**Create folder:** `assets/audio/sfx/`

**Download or create these sounds:**
- `button_click.wav` - UI button press
- `player_join.wav` - When player joins lobby
- `game_start.wav` - When game begins
- `correct.wav` - Correct answer
- `wrong.wav` - Wrong answer / bomb explosion
- `timer_tick.wav` - Timer warning (last 5 seconds)
- `win.wav` - Victory sound
- `lose.wav` - Defeat sound

**Add AudioManager autoload:**

Create `scripts/autoload/audio_manager.gd`:
```gdscript
extends Node

var sfx_bus := "Master"

func play_sfx(sound_name: String) -> void:
    var path = "res://assets/audio/sfx/%s.wav" % sound_name
    if ResourceLoader.exists(path):
        var player = AudioStreamPlayer.new()
        player.stream = load(path)
        player.bus = sfx_bus
        add_child(player)
        player.play()
        player.finished.connect(player.queue_free)
```

Register in `project.godot` under `[autoload]`:
```
AudioManager="*res://scripts/autoload/audio_manager.gd"
```

Use it:
```gdscript
AudioManager.play_sfx("button_click")
```

---

## 5. Build Fibbage Game (Medium Effort)

**Core flow:**
1. Show obscure trivia question with blank: "The world's largest ____ is in Japan"
2. Each player submits a fake answer
3. All answers (including real one) shown shuffled
4. Players vote for what they think is real
5. Points: 200 for correct, 100 for each player fooled by your fake

**Files needed:**
- `scenes/games/fibbage/fibbage.tscn`
- `scripts/games/fibbage.gd`
- `data/prompts/fibbage_questions.json`
- `web-player/js/games/fibbage.js`

**Question format:**
```json
{
	"questions": [
        {
			"text": "The world's largest _____ weighs over 500 pounds",
            "answer": "potato",
            "category": "food"
        }
    ]
}
```

---

## 6. Build Trivia Showdown Game (Medium Effort)

**Core flow:**
1. Display multiple choice question (4 options)
2. All players select an answer
3. Points based on correctness and speed
4. After all rounds, highest score wins

**Files needed:**
- `scenes/games/trivia/trivia.tscn`
- `scripts/games/trivia.gd`
- `data/prompts/trivia_questions.json`
- `web-player/js/games/trivia.js`

**Question format:**
```json
{
    "questions": [
        {
            "question": "What is the capital of France?",
            "options": ["London", "Paris", "Berlin", "Madrid"],
            "correct": 1,
            "category": "geography"
        }
    ]
}
```

---

## 7. Improve Player List in Waiting Lobby

**File:** `scripts/lobby/waiting_lobby.gd` (lines 108-150)

Currently shows colored rectangle. Update `_create_player_card()` to show character sprite:

```gdscript
func _create_player_card(player_id: String, player: Dictionary) -> Control:
    # ... existing code ...

    # Replace ColorRect with sprite if available
    var char_data = GameManager.get_character_data(player["character"])
    var sprite_path = char_data.get("sprite")

    if sprite_path and ResourceLoader.exists(sprite_path):
        var texture_rect = TextureRect.new()
        texture_rect.texture = load(sprite_path)
        texture_rect.custom_minimum_size = Vector2(40, 40)
        texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        hbox.add_child(texture_rect)
    else:
        # Fallback to color
        var color_rect = ColorRect.new()
        color_rect.custom_minimum_size = Vector2(40, 40)
        color_rect.color = char_data["color"]
        hbox.add_child(color_rect)

    # ... rest of existing code ...
```

---

## 8. Add Reconnection Handling

**File:** `scripts/autoload/network_manager.gd`

Add reconnection logic for dropped connections:

```gdscript
var _reconnect_attempts: int = 0
const MAX_RECONNECT_ATTEMPTS = 3
var _last_server_address: String = ""

func _on_connection_lost():
    if _reconnect_attempts < MAX_RECONNECT_ATTEMPTS:
        _reconnect_attempts += 1
        print("Connection lost. Attempting reconnect %d/%d" % [_reconnect_attempts, MAX_RECONNECT_ATTEMPTS])
        await get_tree().create_timer(2.0).timeout
        connect_to_server(_last_server_address)
    else:
        connection_failed.emit("Connection lost after %d attempts" % MAX_RECONNECT_ATTEMPTS)
        _reconnect_attempts = 0
```

---

## File Locations Quick Reference

| Purpose | Path |
|---------|------|
| Game Manager | `scripts/autoload/game_manager.gd` |
| Network Manager | `scripts/autoload/network_manager.gd` |
| Character Sprites | `assets/characters/CHARACTER_NAME/*.png` |
| Word Bomb Game | `scripts/games/word_bomb.gd` |
| Quick Draw Game | `scripts/games/quick_draw.gd` |
| Charades Game | `scripts/games/charades.gd` |
| Who Said It Game | `scripts/games/who_said_it.gd` |
| Base Game Class | `scripts/games/base_game.gd` |
| Host Lobby | `scripts/lobby/host_lobby.gd` |
| Join Lobby | `scripts/lobby/join_lobby.gd` |
| Waiting Lobby | `scripts/lobby/waiting_lobby.gd` |
| QR Generator | `scripts/utils/qr_generator.gd` |
| Web Player | `web-player/` |

---

## Completed Games

| Game | Status | Notes |
|------|--------|-------|
| Word Bomb | Complete | Timer, lives, letter combo validation |
| Act It Out (Charades) | Complete | 799 prompts, actor/guesser roles |
| Quick Draw | Complete | Drawing sync, simplified scoring |
| Who Said It? | Complete | Ready-up system, web player support |

---

*Pick any task above and dive in! Each one is self-contained.*
