extends Control

@onready var timer_label: Label = $VBox/Header/TimerLabel
@onready var player_name_label: Label = $VBox/CurrentPlayerSection/PlayerName
@onready var letter_combo_label: Label = $VBox/LettersSection/LetterCombo
@onready var bomb_icon: Label = $VBox/LettersSection/BombIcon
@onready var word_input: LineEdit = $VBox/InputSection/WordInput
@onready var submit_button: Button = $VBox/InputSection/SubmitButton
@onready var feedback_label: Label = $VBox/FeedbackLabel
@onready var players_status: HBoxContainer = $VBox/PlayersStatus
@onready var turn_timer: Timer = $TurnTimer

const TURN_TIME = 10
const STARTING_LIVES = 3

var letter_combos: Dictionary = {}
var current_combo: String = ""
var player_lives: Dictionary = {}  # player_id -> lives remaining
var player_order: Array = []
var current_player_index: int = 0
var time_remaining: int = TURN_TIME
var used_words: Array = []
var is_my_turn: bool = false
var game_active: bool = false

func _ready() -> void:
	submit_button.pressed.connect(_on_submit_pressed)
	word_input.text_submitted.connect(_on_word_submitted)
	word_input.focus_entered.connect(_on_word_input_focus)
	turn_timer.timeout.connect(_on_timer_tick)

	NetworkManager.message_received.connect(_on_message_received)

	_load_letter_combos()
	_initialize_game()

func _on_word_input_focus() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(word_input.text, Rect2())

func _load_letter_combos() -> void:
	var file = FileAccess.open("res://data/prompts/letter_combos.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json:
			letter_combos = json
		file.close()
	else:
		# Fallback combos
		letter_combos = {
			"easy": ["TH", "IN", "AN", "ER", "ON"],
			"medium": ["ING", "THE", "AND"],
			"hard": ["TION", "OUGH"]
		}

func _initialize_game() -> void:
	if GameManager.is_host:
		# Host sets up and broadcasts initial state
		player_order = GameManager.players.keys()
		player_order.shuffle()

		for player_id in player_order:
			player_lives[player_id] = STARTING_LIVES

		# Broadcast initial game state to all players
		var init_data = {
			"type": "word_bomb_init",
			"player_order": player_order,
			"player_lives": player_lives
		}
		NetworkManager.broadcast(init_data)

		_update_players_display()
		game_active = true
		_start_new_turn()
	else:
		# Non-host waits for init message
		feedback_label.text = "Waiting for game to start..."

func _start_new_turn() -> void:
	# Pick a random letter combo
	var difficulty = "easy"
	if used_words.size() > 10:
		difficulty = "medium"
	if used_words.size() > 25:
		difficulty = "hard"

	var combos = letter_combos.get(difficulty, letter_combos["easy"])
	current_combo = combos[randi() % combos.size()]

	time_remaining = TURN_TIME
	var current_player_id = player_order[current_player_index]

	# Broadcast turn info
	if GameManager.is_host:
		var turn_data = {
			"type": "word_bomb_turn",
			"combo": current_combo,
			"player_id": current_player_id,
			"time": TURN_TIME
		}
		NetworkManager.broadcast(turn_data)
		_apply_turn_data(turn_data)

func _apply_turn_data(data: Dictionary) -> void:
	current_combo = data.get("combo", "TH")
	var current_player_id = data.get("player_id", "")
	time_remaining = data.get("time", TURN_TIME)

	letter_combo_label.text = current_combo

	var player_data = GameManager.players.get(current_player_id, {})
	player_name_label.text = player_data.get("name", "Unknown")

	is_my_turn = (current_player_id == GameManager.local_player_id)

	word_input.editable = is_my_turn
	submit_button.disabled = not is_my_turn
	word_input.text = ""
	feedback_label.text = ""

	if is_my_turn:
		word_input.grab_focus()
		feedback_label.text = "Your turn! Type fast!"
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))

	_update_timer_display()
	turn_timer.start()

func _on_timer_tick() -> void:
	time_remaining -= 1
	_update_timer_display()

	if time_remaining <= 0:
		turn_timer.stop()
		if GameManager.is_host:
			_player_failed_turn()

func _update_timer_display() -> void:
	timer_label.text = str(time_remaining)

	if time_remaining <= 3:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		bomb_icon.text = "💥"
	elif time_remaining <= 5:
		timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
		bomb_icon.text = "💣"

func _on_submit_pressed() -> void:
	if is_my_turn and word_input.text.strip_edges().length() > 0:
		_submit_word(word_input.text.strip_edges())

func _on_word_submitted(text: String) -> void:
	if is_my_turn and text.strip_edges().length() > 0:
		_submit_word(text.strip_edges())

func _submit_word(word: String) -> void:
	word = word.to_upper()

	# Send to host for validation
	if GameManager.is_host:
		_validate_word(GameManager.local_player_id, word)
	else:
		NetworkManager.send_to_server({
			"type": "word_bomb_submit",
			"word": word
		})

func _validate_word(player_id: String, word: String) -> bool:
	word = word.to_upper()
	var combo = current_combo.to_upper()

	# Check if word contains the combo
	if not combo in word:
		_broadcast_result(player_id, word, false, "Doesn't contain '%s'" % current_combo)
		return false

	# Check if word was already used
	if word in used_words:
		_broadcast_result(player_id, word, false, "Already used!")
		return false

	# Check minimum length (at least combo length + 1)
	if word.length() <= combo.length():
		_broadcast_result(player_id, word, false, "Too short!")
		return false

	# Word is valid!
	used_words.append(word)
	_broadcast_result(player_id, word, true, "")
	return true

func _broadcast_result(player_id: String, word: String, valid: bool, reason: String) -> void:
	var data = {
		"type": "word_bomb_result",
		"player_id": player_id,
		"word": word,
		"valid": valid,
		"reason": reason
	}

	if GameManager.is_host:
		NetworkManager.broadcast(data)
		_apply_result(data)

func _apply_result(data: Dictionary) -> void:
	var valid = data.get("valid", false)
	var reason = data.get("reason", "")
	var word = data.get("word", "")

	turn_timer.stop()

	if valid:
		feedback_label.text = "'%s' - Correct!" % word
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))

		# Move to next player
		if GameManager.is_host:
			await get_tree().create_timer(1.0).timeout
			_next_player()
	else:
		feedback_label.text = "'%s' - %s" % [word, reason]
		feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))

		if is_my_turn:
			# Let player try again
			word_input.text = ""
			word_input.grab_focus()
			turn_timer.start()

func _player_failed_turn() -> void:
	var current_player_id = player_order[current_player_index]
	player_lives[current_player_id] -= 1

	var lives_left = player_lives[current_player_id]

	# Include updated player_order in case of elimination
	var updated_order = player_order.duplicate()
	if lives_left <= 0:
		updated_order.erase(current_player_id)

	var data = {
		"type": "word_bomb_explode",
		"player_id": current_player_id,
		"lives": lives_left,
		"player_order": updated_order,
		"current_index": current_player_index if lives_left > 0 else (current_player_index % max(updated_order.size(), 1))
	}

	NetworkManager.broadcast(data)
	_apply_explosion(data)

func _apply_explosion(data: Dictionary) -> void:
	var player_id = data.get("player_id", "")
	var lives = data.get("lives", 0)
	player_lives[player_id] = lives

	# Sync player_order from host
	if data.has("player_order"):
		player_order = data.get("player_order", player_order)
	if data.has("current_index"):
		current_player_index = data.get("current_index", current_player_index)

	var player_data = GameManager.players.get(player_id, {})
	var player_name = player_data.get("name", "Unknown")

	feedback_label.text = "💥 %s ran out of time! (%d lives left)" % [player_name, lives]
	feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))

	_update_players_display()

	# Check for winner
	if player_order.size() <= 1:
		if GameManager.is_host:
			await get_tree().create_timer(1.5).timeout
			_end_game()
		return

	if GameManager.is_host:
		await get_tree().create_timer(1.5).timeout
		_next_player()

func _next_player() -> void:
	current_player_index = (current_player_index + 1) % player_order.size()
	_start_new_turn()

func _update_players_display() -> void:
	# Clear existing
	for child in players_status.get_children():
		child.queue_free()

	# Add player status indicators
	for player_id in GameManager.players:
		var player = GameManager.players[player_id]
		var lives = player_lives.get(player_id, 0)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)

		var char_data = GameManager.get_character_data(player["character"])
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(50, 50)
		color_rect.color = char_data["color"]
		if lives <= 0:
			color_rect.modulate = Color(0.3, 0.3, 0.3, 1)

		var name_label = Label.new()
		name_label.text = player["name"]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var lives_label = Label.new()
		lives_label.text = "❤️".repeat(lives)
		lives_label.add_theme_font_size_override("font_size", 10)
		lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		vbox.add_child(color_rect)
		vbox.add_child(name_label)
		vbox.add_child(lives_label)

		players_status.add_child(vbox)

func _end_game() -> void:
	game_active = false
	turn_timer.stop()

	var winner_id = player_order[0] if player_order.size() > 0 else ""
	var winner_data = GameManager.players.get(winner_id, {})
	var winner_name = winner_data.get("name", "Nobody")

	# Award points
	if winner_id:
		GameManager.update_score(winner_id, 100)

	var data = {
		"type": "word_bomb_end",
		"winner_id": winner_id,
		"winner_name": winner_name
	}

	NetworkManager.broadcast(data)
	_show_game_over(data)

func _show_game_over(data: Dictionary) -> void:
	var winner_name = data.get("winner_name", "Nobody")

	game_active = false
	turn_timer.stop()

	letter_combo_label.text = "🏆"
	player_name_label.text = "%s Wins!" % winner_name
	feedback_label.text = "Game Over!"
	feedback_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

	word_input.visible = false
	submit_button.visible = false

	# Return to lobby after delay
	await get_tree().create_timer(3.0).timeout
	if GameManager.is_host:
		get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"word_bomb_init":
			_apply_init_data(data)
		"word_bomb_turn":
			_apply_turn_data(data)
		"word_bomb_submit":
			if GameManager.is_host:
				var word = data.get("word", "")
				# Find player_id from peer_id
				var player_id = "peer_%d" % _peer_id
				_validate_word(player_id, word)
		"word_bomb_result":
			_apply_result(data)
		"word_bomb_explode":
			_apply_explosion(data)
		"word_bomb_end":
			_show_game_over(data)

func _apply_init_data(data: Dictionary) -> void:
	# Non-host receives initial game state
	player_order = data.get("player_order", [])
	var lives_data = data.get("player_lives", {})

	# Convert lives data (JSON converts int keys to strings)
	player_lives.clear()
	for player_id in lives_data:
		player_lives[player_id] = lives_data[player_id]

	game_active = true
	_update_players_display()
	feedback_label.text = "Game started!"
