extends Control

@onready var timer_label: Label = $VBox/Header/TimerLabel
@onready var round_label: Label = $VBox/Header/RoundLabel
@onready var actor_name_label: Label = $VBox/ActorSection/ActorName
@onready var prompt_label: Label = $VBox/PromptSection/PromptLabel
@onready var guess_input: LineEdit = $VBox/GuessSection/GuessInput
@onready var guess_button: Button = $VBox/GuessSection/GuessButton
@onready var skip_button: Button = $VBox/GuessSection/SkipButton
@onready var start_turn_button: Button = $VBox/GuessSection/StartTurnButton
@onready var waiting_for_actor_label: Label = $VBox/GuessSection/WaitingForActorLabel
@onready var feedback_label: Label = $VBox/FeedbackLabel
@onready var players_status: HBoxContainer = $VBox/PlayersStatus
@onready var turn_timer: Timer = $TurnTimer

const TURN_TIME = 60
const ROUNDS_PER_PLAYER = 1

var prompts: Dictionary = {}
var current_prompt: String = ""
var player_scores: Dictionary = {}
var player_order: Array = []
var current_player_index: int = 0
var current_round: int = 1
var total_rounds: int = 1
var time_remaining: int = TURN_TIME
var is_actor: bool = false
var game_active: bool = false
var used_prompts: Array = []

func _ready() -> void:
	guess_button.pressed.connect(_on_guess_pressed)
	guess_input.text_submitted.connect(_on_guess_submitted)
	guess_input.focus_entered.connect(_on_input_focus)
	skip_button.pressed.connect(_on_skip_pressed)
	start_turn_button.pressed.connect(_on_start_turn_pressed)
	turn_timer.timeout.connect(_on_timer_tick)

	NetworkManager.message_received.connect(_on_message_received)

	_load_prompts()
	# Defer initialization to ensure UI is fully ready
	call_deferred("_initialize_game")

func _on_input_focus() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(guess_input.text, Rect2())

func _load_prompts() -> void:
	var file = FileAccess.open("res://data/prompts/charades_prompts.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json:
			prompts = json
		file.close()
	else:
		# Fallback prompts
		prompts = {
			"movies_tv": ["Star Wars", "Harry Potter", "Frozen"],
			"actions": ["Swimming", "Dancing", "Cooking"]
		}

func _initialize_game() -> void:
	if GameManager.is_host:
		player_order = GameManager.players.keys()
		player_order.shuffle()

		for player_id in player_order:
			player_scores[player_id] = 0

		total_rounds = player_order.size() * ROUNDS_PER_PLAYER

		var init_data = {
			"type": "charades_init",
			"player_order": player_order,
			"scores": player_scores,
			"total_rounds": total_rounds
		}
		NetworkManager.broadcast(init_data)

		_update_players_display()
		game_active = true
		_start_new_turn()
	else:
		feedback_label.text = "Waiting for game to start..."

func _start_new_turn() -> void:
	var actor_id = player_order[current_player_index]

	# Pick a random prompt from a random category (host only)
	if GameManager.is_host:
		var categories = prompts.keys()
		var category = categories[randi() % categories.size()]
		var category_prompts = prompts[category]

		# Find an unused prompt
		var available = []
		for p in category_prompts:
			if p not in used_prompts:
				available.append(p)

		if available.is_empty():
			# Reset if all prompts used
			used_prompts.clear()
			available = category_prompts

		current_prompt = available[randi() % available.size()]
		used_prompts.append(current_prompt)

		# Broadcast preparation phase (no prompt yet)
		var prep_data = {
			"type": "charades_prepare",
			"actor_id": actor_id,
			"round": current_round,
			"total_rounds": total_rounds
		}
		NetworkManager.broadcast(prep_data)
		_apply_prepare_data(prep_data)

func _apply_prepare_data(data: Dictionary) -> void:
	var actor_id = data.get("actor_id", "")
	current_round = data.get("round", 1)
	total_rounds = data.get("total_rounds", 1)

	round_label.text = "Round %d/%d" % [current_round, total_rounds]
	timer_label.text = str(TURN_TIME)
	timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

	var actor_data = GameManager.players.get(actor_id, {})
	var actor_name = actor_data.get("name", "Unknown")
	actor_name_label.text = actor_name
	actor_name_label.remove_theme_color_override("font_color")  # Reset to default color

	is_actor = (actor_id == GameManager.local_player_id)

	# Hide all input controls first
	guess_input.visible = false
	guess_button.visible = false
	skip_button.visible = false
	start_turn_button.visible = false
	waiting_for_actor_label.visible = false

	prompt_label.text = "Get Ready!"
	prompt_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

	if is_actor:
		# Actor sees Start Turn button
		start_turn_button.visible = true
		feedback_label.text = "Press the button when you're ready to see your prompt!"
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	else:
		# Others wait for actor
		waiting_for_actor_label.text = "Waiting for %s to start..." % actor_name
		waiting_for_actor_label.visible = true
		feedback_label.text = "Get ready to guess!"
		feedback_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

func _on_start_turn_pressed() -> void:
	if is_actor:
		if GameManager.is_host:
			_begin_active_turn()
		else:
			NetworkManager.send_to_server({
				"type": "charades_start_turn"
			})

func _begin_active_turn() -> void:
	var actor_id = player_order[current_player_index]
	time_remaining = TURN_TIME

	var turn_data = {
		"type": "charades_turn",
		"actor_id": actor_id,
		"prompt": current_prompt,
		"round": current_round,
		"total_rounds": total_rounds,
		"time": TURN_TIME
	}
	NetworkManager.broadcast(turn_data)
	_apply_turn_data(turn_data)

func _apply_turn_data(data: Dictionary) -> void:
	var actor_id = data.get("actor_id", "")
	var prompt = data.get("prompt", "")
	current_round = data.get("round", 1)
	total_rounds = data.get("total_rounds", 1)
	time_remaining = data.get("time", TURN_TIME)

	current_prompt = prompt

	round_label.text = "Round %d/%d" % [current_round, total_rounds]

	var actor_data = GameManager.players.get(actor_id, {})
	actor_name_label.text = actor_data.get("name", "Unknown")

	is_actor = (actor_id == GameManager.local_player_id)

	# Hide preparation UI
	start_turn_button.visible = false
	waiting_for_actor_label.visible = false

	if is_actor:
		# Actor sees the prompt
		prompt_label.text = prompt
		prompt_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		guess_input.visible = false
		guess_button.visible = false
		skip_button.visible = true
		feedback_label.text = "Act this out! No talking!"
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	else:
		# Guessers see ???
		prompt_label.text = "???"
		prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		guess_input.visible = true
		guess_button.visible = true
		skip_button.visible = false
		guess_input.text = ""
		guess_input.editable = true
		guess_button.disabled = false
		guess_input.grab_focus()
		feedback_label.text = "Guess what they're acting!"
		feedback_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

	_update_timer_display()
	turn_timer.start()

func _on_timer_tick() -> void:
	time_remaining -= 1
	_update_timer_display()

	if time_remaining <= 0:
		turn_timer.stop()
		if GameManager.is_host:
			_time_expired()

func _update_timer_display() -> void:
	timer_label.text = str(time_remaining)

	if time_remaining <= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	elif time_remaining <= 20:
		timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

func _on_guess_pressed() -> void:
	if not is_actor and guess_input.text.strip_edges().length() > 0:
		_submit_guess(guess_input.text.strip_edges())

func _on_guess_submitted(text: String) -> void:
	if not is_actor and text.strip_edges().length() > 0:
		_submit_guess(text.strip_edges())

func _submit_guess(guess: String) -> void:
	if GameManager.is_host:
		_validate_guess(GameManager.local_player_id, guess)
	else:
		NetworkManager.send_to_server({
			"type": "charades_guess",
			"guess": guess
		})

	guess_input.text = ""

func _is_close_match(guess: String, answer: String) -> bool:
	# Exact match
	if guess == answer:
		return true

	# Calculate similarity using Levenshtein distance
	var similarity = _calculate_similarity(guess, answer)

	# Require 85% similarity for a match
	return similarity >= 0.85

func _calculate_similarity(s1: String, s2: String) -> float:
	# Levenshtein distance-based similarity
	var len1 = s1.length()
	var len2 = s2.length()

	if len1 == 0 and len2 == 0:
		return 1.0
	if len1 == 0 or len2 == 0:
		return 0.0

	# Create distance matrix
	var matrix = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)

	# Initialize first row and column
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j

	# Fill in the rest of the matrix
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i - 1] == s2[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1,      # deletion
				min(
					matrix[i][j - 1] + 1,  # insertion
					matrix[i - 1][j - 1] + cost  # substitution
				)
			)

	var distance = matrix[len1][len2]
	var max_len = max(len1, len2)
	return 1.0 - (float(distance) / float(max_len))

func _validate_guess(player_id: String, guess: String) -> void:
	var guess_lower = guess.to_lower().strip_edges()
	var prompt_lower = current_prompt.to_lower().strip_edges()

	# Check if guess matches - require high similarity (85%+) or exact match
	var is_correct = _is_close_match(guess_lower, prompt_lower)

	if is_correct:
		turn_timer.stop()

		# Award points
		var actor_id = player_order[current_player_index]
		player_scores[player_id] = player_scores.get(player_id, 0) + 100
		player_scores[actor_id] = player_scores.get(actor_id, 0) + 50

		_broadcast_result(true, player_id, guess)
	else:
		_broadcast_wrong_guess(player_id, guess)

func _broadcast_wrong_guess(player_id: String, guess: String) -> void:
	var player_data = GameManager.players.get(player_id, {})
	var player_name = player_data.get("name", "Unknown")

	var data = {
		"type": "charades_wrong",
		"player_id": player_id,
		"player_name": player_name,
		"guess": guess
	}

	if GameManager.is_host:
		NetworkManager.broadcast(data)
		_apply_wrong_guess(data)

func _apply_wrong_guess(data: Dictionary) -> void:
	var player_name = data.get("player_name", "Unknown")
	var guess = data.get("guess", "")

	feedback_label.text = "%s guessed: %s" % [player_name, guess]
	feedback_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))

func _broadcast_result(correct: bool, guesser_id: String, guess: String) -> void:
	var actor_id = player_order[current_player_index]
	var data = {
		"type": "charades_result",
		"correct": correct,
		"guesser_id": guesser_id,
		"actor_id": actor_id,
		"prompt": current_prompt,
		"scores": player_scores,
		"guess": guess
	}

	if GameManager.is_host:
		NetworkManager.broadcast(data)
		_apply_result(data)

func _apply_result(data: Dictionary) -> void:
	var correct = data.get("correct", false)
	var guesser_id = data.get("guesser_id", "")
	var prompt = data.get("prompt", "")
	var scores = data.get("scores", {})

	turn_timer.stop()

	# Update scores from host
	for pid in scores:
		player_scores[pid] = scores[pid]

	# Hide all input controls
	guess_input.visible = false
	guess_button.visible = false
	skip_button.visible = false
	start_turn_button.visible = false
	waiting_for_actor_label.visible = false

	# Show the answer prominently
	prompt_label.text = prompt
	prompt_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))

	if correct:
		var guesser_data = GameManager.players.get(guesser_id, {})
		var guesser_name = guesser_data.get("name", "Unknown")
		var actor_id = data.get("actor_id", "")
		var actor_data = GameManager.players.get(actor_id, {})
		var actor_name = actor_data.get("name", "Unknown")

		actor_name_label.text = "Correct!"
		actor_name_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		feedback_label.text = "%s guessed it! (+100 pts)\n%s acted it! (+50 pts)" % [guesser_name, actor_name]
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))

	_update_players_display()

	if GameManager.is_host:
		await get_tree().create_timer(3.0).timeout
		_next_turn()

func _on_skip_pressed() -> void:
	if is_actor:
		if GameManager.is_host:
			_skip_turn()
		else:
			NetworkManager.send_to_server({
				"type": "charades_skip"
			})

func _skip_turn() -> void:
	# Pick a new prompt instead of ending the turn
	var categories = prompts.keys()
	var category = categories[randi() % categories.size()]
	var category_prompts = prompts[category]

	# Find an unused prompt
	var available = []
	for p in category_prompts:
		if p not in used_prompts:
			available.append(p)

	if available.is_empty():
		# Reset if all prompts used
		used_prompts.clear()
		available = category_prompts

	current_prompt = available[randi() % available.size()]
	used_prompts.append(current_prompt)

	var data = {
		"type": "charades_skipped",
		"prompt": current_prompt
	}

	if GameManager.is_host:
		NetworkManager.broadcast(data)
		_apply_skip(data)

func _apply_skip(data: Dictionary) -> void:
	var prompt = data.get("prompt", "")
	current_prompt = prompt

	# Timer continues running - no reset

	if is_actor:
		# Actor sees the new prompt
		prompt_label.text = prompt
		prompt_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		feedback_label.text = "New phrase! Act this out!"
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	else:
		# Guessers still see ??? and can keep guessing
		feedback_label.text = "They skipped - new phrase!"
		feedback_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))

func _time_expired() -> void:
	var data = {
		"type": "charades_timeout",
		"prompt": current_prompt
	}

	NetworkManager.broadcast(data)
	_apply_timeout(data)

func _apply_timeout(data: Dictionary) -> void:
	var prompt = data.get("prompt", "")

	turn_timer.stop()

	# Hide all input controls
	guess_input.visible = false
	guess_button.visible = false
	skip_button.visible = false
	start_turn_button.visible = false
	waiting_for_actor_label.visible = false

	prompt_label.text = prompt
	prompt_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	actor_name_label.text = "Time's Up!"
	actor_name_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	feedback_label.text = "Nobody guessed it in time!"
	feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))

	if GameManager.is_host:
		await get_tree().create_timer(3.0).timeout
		_next_turn()

func _next_turn() -> void:
	current_player_index += 1

	if current_player_index >= player_order.size():
		current_player_index = 0
		current_round += 1

	if current_round > total_rounds:
		_end_game()
	else:
		_start_new_turn()

func _update_players_display() -> void:
	for child in players_status.get_children():
		child.queue_free()

	for player_id in GameManager.players:
		var player = GameManager.players[player_id]
		var score = player_scores.get(player_id, 0)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)

		var char_data = GameManager.get_character_data(player["character"])
		var char_display: Control
		var sprite_path = char_data.get("sprite")
		if sprite_path and ResourceLoader.exists(sprite_path):
			var texture_rect = TextureRect.new()
			texture_rect.texture = load(sprite_path)
			texture_rect.custom_minimum_size = Vector2(50, 50)
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			char_display = texture_rect
		else:
			var color_rect = ColorRect.new()
			color_rect.custom_minimum_size = Vector2(50, 50)
			color_rect.color = char_data["color"]
			char_display = color_rect

		var name_label = Label.new()
		name_label.text = player["name"]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var score_label = Label.new()
		score_label.text = str(score)
		score_label.add_theme_font_size_override("font_size", 14)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

		vbox.add_child(char_display)
		vbox.add_child(name_label)
		vbox.add_child(score_label)

		players_status.add_child(vbox)

func _end_game() -> void:
	game_active = false
	turn_timer.stop()

	# Find winner
	var winner_id = ""
	var max_score = -1
	for player_id in player_scores:
		if player_scores[player_id] > max_score:
			max_score = player_scores[player_id]
			winner_id = player_id

	var winner_data = GameManager.players.get(winner_id, {})
	var winner_name = winner_data.get("name", "Nobody")

	# Award bonus to winner
	if winner_id:
		GameManager.update_score(winner_id, max_score)

	var data = {
		"type": "charades_end",
		"final_scores": player_scores,
		"winner_id": winner_id,
		"winner_name": winner_name
	}

	NetworkManager.broadcast(data)
	_show_game_over(data)

func _show_game_over(data: Dictionary) -> void:
	var winner_name = data.get("winner_name", "Nobody")
	var final_scores = data.get("final_scores", {})

	game_active = false
	turn_timer.stop()

	# Update scores from final data
	for pid in final_scores:
		player_scores[pid] = final_scores[pid]

	# Hide all input controls
	guess_input.visible = false
	guess_button.visible = false
	skip_button.visible = false
	start_turn_button.visible = false
	waiting_for_actor_label.visible = false

	prompt_label.text = "Game Over!"
	prompt_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	actor_name_label.text = "%s Wins!" % winner_name
	actor_name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	feedback_label.text = "Thanks for playing!"
	feedback_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

	_update_players_display()

	await get_tree().create_timer(3.0).timeout
	if GameManager.is_host:
		get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"charades_init":
			_apply_init_data(data)
		"charades_prepare":
			_apply_prepare_data(data)
		"charades_start_turn":
			if GameManager.is_host:
				_begin_active_turn()
		"charades_turn":
			_apply_turn_data(data)
		"charades_guess":
			if GameManager.is_host:
				var guess = data.get("guess", "")
				var player_id = "peer_%d" % _peer_id
				_validate_guess(player_id, guess)
		"charades_wrong":
			_apply_wrong_guess(data)
		"charades_result":
			_apply_result(data)
		"charades_skip":
			if GameManager.is_host:
				_skip_turn()
		"charades_skipped":
			_apply_skip(data)
		"charades_timeout":
			_apply_timeout(data)
		"charades_end":
			_show_game_over(data)

func _apply_init_data(data: Dictionary) -> void:
	player_order = data.get("player_order", [])
	var scores_data = data.get("scores", {})
	total_rounds = data.get("total_rounds", 1)

	player_scores.clear()
	for player_id in scores_data:
		player_scores[player_id] = scores_data[player_id]

	game_active = true
	_update_players_display()
	feedback_label.text = "Game started!"
