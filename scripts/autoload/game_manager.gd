extends Node

## Global game state manager
## Handles session data, player management, and game transitions

signal player_joined(player_id: String, player_data: Dictionary)
signal player_left(player_id: String)
signal game_started(game_name: String)
signal score_updated(player_id: String, new_score: int)

# Session data
var session_id: String = ""
var is_host: bool = false
var local_player_id: String = ""
var local_player_name: String = ""
var local_player_character: int = 0

# All players in session
var players: Dictionary = {}

# Available characters
# sprite: path to south-facing sprite (null if not yet generated)
const CHARACTERS = [
	{"id": 0, "name": "Red Knight", "color": Color.RED, "sprite": "res://assets/characters/red_knight/south.png"},
	{"id": 1, "name": "Blue Wizard", "color": Color.BLUE, "sprite": "res://assets/characters/blue_wizard/south.png"},
	{"id": 2, "name": "Green Ranger", "color": Color.GREEN, "sprite": "res://assets/characters/green_ranger/south.png"},
	{"id": 3, "name": "Yellow Bard", "color": Color.YELLOW, "sprite": null},  # Pending generation
	{"id": 4, "name": "Purple Rogue", "color": Color.PURPLE, "sprite": "res://assets/characters/purple_rogue/south.png"},
	{"id": 5, "name": "Orange Monk", "color": Color.ORANGE, "sprite": null},  # Pending generation
	{"id": 6, "name": "Pink Princess", "color": Color.PINK, "sprite": "res://assets/characters/pink_princess/south.png"},
	{"id": 7, "name": "Teal Robot", "color": Color.TEAL, "sprite": null},  # Pending generation
]

# Game settings
var settings: Dictionary = {
	"rounds_per_game": 3,
	"timer_duration": 60,
	"max_players": 8,
	"min_players": 2
}

func _ready() -> void:
	# Generate unique player ID
	local_player_id = _generate_uuid()
	session_id = ""

func create_session() -> String:
	session_id = _generate_uuid()
	is_host = true
	return session_id

func join_session(id: String) -> void:
	session_id = id
	is_host = false

func set_local_player(player_name: String, character_id: int) -> void:
	local_player_name = player_name
	local_player_character = character_id

	# Add self to players dict
	players[local_player_id] = {
		"name": player_name,
		"character": character_id,
		"score": 0,
		"is_host": is_host,
		"connected": true
	}

func add_player(player_id: String, player_name: String, character_id: int) -> void:
	players[player_id] = {
		"name": player_name,
		"character": character_id,
		"score": 0,
		"is_host": false,
		"connected": true
	}
	player_joined.emit(player_id, players[player_id])

func remove_player(player_id: String) -> void:
	if players.has(player_id):
		players.erase(player_id)
		player_left.emit(player_id)

func update_score(player_id: String, points: int) -> void:
	if players.has(player_id):
		players[player_id]["score"] += points
		score_updated.emit(player_id, players[player_id]["score"])

func get_character_data(character_id: int) -> Dictionary:
	if character_id >= 0 and character_id < CHARACTERS.size():
		return CHARACTERS[character_id]
	return CHARACTERS[0]

func get_taken_characters() -> Array:
	var taken = []
	for player in players.values():
		taken.append(player["character"])
	return taken

func is_character_available(character_id: int) -> bool:
	return character_id not in get_taken_characters()

func reset_session() -> void:
	session_id = ""
	is_host = false
	players.clear()
	local_player_name = ""
	local_player_character = 0

func _generate_uuid() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var uuid = ""
	for i in range(8):
		uuid += chars[randi() % chars.length()]
	return uuid
