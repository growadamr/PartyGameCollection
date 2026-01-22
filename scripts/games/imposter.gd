extends Control

@onready var imposter_count_label: Label = $VBox/Header/ImposterCountLabel
@onready var role_label: Label = $VBox/RoleSection/RoleLabel
@onready var word_label: Label = $VBox/RoleSection/WordDisplay/WordLabel
@onready var instruction_label: Label = $VBox/InstructionLabel
@onready var players_status: HBoxContainer = $VBox/PlayersStatus

var words: Array = []
var current_word: String = ""
var imposters: Array = []
var player_roles: Dictionary = {}
var is_imposter: bool = false
var imposter_count: int = 1
var total_players: int = 0

func _ready() -> void:
	NetworkManager.message_received.connect(_on_message_received)
	_load_words()
	call_deferred("_initialize_game")

func _load_words() -> Array:
	var file = FileAccess.open("res://data/prompts/imposter_words.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json and json is Array:
			words = json
		file.close()
	else:
		# Fallback words
		words = ["apple", "banana", "car", "house", "tree"]

	return words

func _initialize_game() -> void:
	if not GameManager.is_host:
		return

	var player_ids = GameManager.players.keys()
	var player_count = player_ids.size()
	total_players = player_count

	# Calculate imposter count
	imposter_count = _get_imposter_count(player_count)

	# Shuffle and select imposters
	player_ids.shuffle()
	imposters.clear()
	for i in range(imposter_count):
		imposters.append(player_ids[i])

	# Select random word
	current_word = words[randi() % words.size()]

	# Send personalized role data to each player
	for player_id in player_ids:
		var peer_id = _get_peer_id_for_player(player_id)
		var is_player_imposter = player_id in imposters

		player_roles[player_id] = is_player_imposter

		NetworkManager.send_to_client(peer_id, {
			"type": "imposter_role",
			"is_imposter": is_player_imposter,
			"word": "" if is_player_imposter else current_word,
			"imposter_count": imposter_count,
			"total_players": total_players
		})

	# Broadcast discussion phase start
	NetworkManager.broadcast({
		"type": "discussion_started",
		"imposter_count": imposter_count,
		"total_players": total_players
	})

	# Update host UI
	_show_discussion_phase()
	_update_players_display()

func _get_imposter_count(player_count: int) -> int:
	if player_count >= 6:
		return 2
	elif player_count >= 4:
		return 1
	else:
		return 1  # Minimum

func _get_peer_id_for_player(player_id: String) -> int:
	return int(player_id.substr(5))

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"imposter_role":
			_apply_role_data(data)
		"discussion_started":
			_show_discussion_phase()

func _apply_role_data(data: Dictionary) -> void:
	is_imposter = data.get("is_imposter", false)
	current_word = data.get("word", "")
	imposter_count = data.get("imposter_count", 1)
	total_players = data.get("total_players", 0)

	# Update UI to show role
	if is_imposter:
		role_label.text = "You are..."
		word_label.text = "IMPOSTER"
		word_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	else:
		role_label.text = "Your word is..."
		word_label.text = current_word
		word_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))

	_show_discussion_phase()

func _show_discussion_phase() -> void:
	var count_text = "%d Imposter" % imposter_count
	if imposter_count > 1:
		count_text += "s"
	count_text += " among you"

	imposter_count_label.text = count_text
	imposter_count_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))

	instruction_label.text = "Discuss with your group! Imposters: blend in without revealing you don't know the word."
	instruction_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

func _update_players_display() -> void:
	for child in players_status.get_children():
		child.queue_free()

	for player_id in GameManager.players:
		var player = GameManager.players[player_id]

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)

		var char_data = GameManager.get_character_data(player["character"])
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(50, 50)
		color_rect.color = char_data["color"]

		var name_label = Label.new()
		name_label.text = player["name"]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		vbox.add_child(color_rect)
		vbox.add_child(name_label)

		players_status.add_child(vbox)
