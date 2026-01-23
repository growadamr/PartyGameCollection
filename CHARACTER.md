# Character Image Display Bug - FIXED

## Problem
Character images did not show up in the lobby screens. Instead, a colored square (matching the character's color) appeared in place of the actual character sprite.

## Affected Screens
1. **Waiting Lobby** (`scripts/lobby/waiting_lobby.gd`) - Host view showing all player cards
2. **Player Waiting** (`scripts/lobby/player_waiting.gd`) - Individual player's waiting screen

## Root Cause
The lobby display code only used `ColorRect` to show character colors, even though the character data includes sprite paths. The character selection screen (`host_lobby.gd`) correctly checks for sprites and uses `TextureRect`, but this pattern was not replicated in the lobby display screens.

## Fix Applied

### 1. waiting_lobby.gd - Updated `_create_player_card()` (lines 132-147)
Now checks for sprite availability and uses `TextureRect` when a sprite exists:
```gdscript
var char_data = GameManager.get_character_data(player["character"])
var char_display: Control
var sprite_path = char_data.get("sprite")
if sprite_path and ResourceLoader.exists(sprite_path):
	var texture_rect = TextureRect.new()
	texture_rect.texture = load(sprite_path)
	texture_rect.custom_minimum_size = Vector2(40, 40)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_display = texture_rect
else:
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(40, 40)
	color_rect.color = char_data["color"]
	char_display = color_rect
```

### 2. player_waiting.tscn - Changed CharacterPreview node type
Changed from `ColorRect` to `Control` container to allow dynamic children:
```
[node name="CharacterPreview" type="Control" parent="VBox/PlayerInfo"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
size_flags_horizontal = 4
```

### 3. player_waiting.gd - Added `_update_character_preview()` function
New function that dynamically creates the appropriate display:
```gdscript
func _update_character_preview(char_data: Dictionary) -> void:
	for child in character_preview.get_children():
		child.queue_free()

	var sprite_path = char_data.get("sprite")
	if sprite_path and ResourceLoader.exists(sprite_path):
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(sprite_path)
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		character_preview.add_child(texture_rect)
	else:
		var color_rect = ColorRect.new()
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.color = char_data["color"]
		character_preview.add_child(color_rect)
```

## Files Modified - Lobby
1. `scripts/lobby/waiting_lobby.gd` - Lines 132-147, 161, 165
2. `scripts/lobby/player_waiting.gd` - Lines 4, 22, 26-44 (new function)
3. `scenes/lobby/player_waiting.tscn` - Line 59 (node type change)

## In-Game Character Display Fix

The same issue affected all 6 games - player status displays showed color blocks instead of sprites.

### Games Fixed
1. **trivia_showdown.gd** - `_update_players_display()` function
2. **quick_draw.gd** - `_update_display()` function
3. **fibbage.gd** - `_update_players_display()` function
4. **who_said_it.gd** - `_update_players_display()` function
5. **charades.gd** - `_update_players_display()` function
6. **word_bomb.gd** - `_update_players_display()` function

### Pattern Applied
Each game now uses the same sprite-aware pattern:
```gdscript
var char_data = GameManager.get_character_data(player.character)
var char_display: Control
var sprite_path = char_data.get("sprite")
if sprite_path and ResourceLoader.exists(sprite_path):
	var texture_rect = TextureRect.new()
	texture_rect.texture = load(sprite_path)
	texture_rect.custom_minimum_size = Vector2(40, 40)  # size varies by game
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_display = texture_rect
else:
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(40, 40)
	color_rect.color = char_data.color
	char_display = color_rect
```

### Visual Effects Preserved
- Ready/answered indicators (checkmarks) still overlay the character display
- Highlight effects changed from `color.lightened()` to `modulate = Color(1.3, 1.3, 1.3)` (works with both sprites and colors)
- Eliminated player graying (word_bomb) uses `modulate = Color(0.3, 0.3, 0.3)` (works with sprites)

## Character Sprite Availability
Characters with sprites (will show images):
- Red Knight, Blue Wizard, Green Ranger, Purple Rogue, Pink Princess

Characters without sprites (will show color fallback):
- Yellow Bard, Orange Monk, Teal Robot
