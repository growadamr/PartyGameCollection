# Next Steps - Party Game Collection

Specific, actionable tasks you can work on right now.

---

## Current Status

**All 6 games complete!**

| Game | Status |
|------|--------|
| Word Bomb | Complete |
| Act It Out (Charades) | Complete |
| Quick Draw | Complete |
| Who Said It? | Complete |
| Trivia Showdown | Complete |
| Fibbage | Complete |

---

## 1. Download Remaining 3 Characters (When Ready)

Check if PixelLab finished generating:

```bash
# In Claude Code, run:
mcp__pixellab__list_characters
```

If Yellow Bard, Orange Monk, or Teal Robot show as ready, get their download URLs:

```bash
mcp__pixellab__get_character(character_id="a76fc607-79ac-477a-a9d7-16c24ff48f6e")  # Yellow Bard
mcp__pixellab__get_character(character_id="9a46ba4a-5a5c-4263-a3e5-2ee065950096")  # Orange Monk
mcp__pixellab__get_character(character_id="649694d4-ebea-4963-ade3-fc4a71a6632a")  # Teal Robot
```

Then download to:
- `assets/characters/yellow_bard/south.png`
- `assets/characters/orange_monk/south.png`
- `assets/characters/teal_robot/south.png`

And update `GameManager.CHARACTERS` to add the sprite paths.

---

## 2. Add Sound Effects (Easy Win)

**Create folder:** `assets/audio/sfx/`

**Download or create these sounds:**
- `button_click.wav` - UI button press
- `player_join.wav` - When player joins lobby
- `game_start.wav` - When game begins
- `correct.wav` - Correct answer
- `wrong.wav` - Wrong answer / bomb explosion
- `timer_tick.wav` - Timer warning (last 5 seconds)
- `win.wav` - Victory sound

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

---

## 3. Add Reconnection Handling

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

## 4. Cross-Device Testing

Test the following scenarios:
- [ ] Host on iPhone, players on Android browsers
- [ ] Host on Android, players on iPhone browsers
- [ ] 8 players simultaneously
- [ ] Player disconnect/reconnect mid-game
- [ ] Host and players on different WiFi subnets

---

## File Locations Quick Reference

| Purpose | Path |
|---------|------|
| Game Manager | `scripts/autoload/game_manager.gd` |
| Network Manager | `scripts/autoload/network_manager.gd` |
| Character Sprites | `assets/characters/CHARACTER_NAME/*.png` |
| Base Game Class | `scripts/games/base_game.gd` |
| Game Selection | `scripts/lobby/game_select.gd` |
| Web Player | `web-player/` |

---

## Completed Games

| Game | Status | Notes |
|------|--------|-------|
| Word Bomb | Complete | Timer, lives, letter combo validation |
| Act It Out (Charades) | Complete | 799 prompts, actor/guesser roles |
| Quick Draw | Complete | Drawing sync, simplified scoring |
| Who Said It? | Complete | Ready-up system, web player support |
| Fibbage | Complete | 52 questions, lie detection, fooled tracking |
| Trivia Showdown | Complete | 120 questions, speed bonus scoring |

---

*Pick any task above and dive in! Each one is self-contained.*
