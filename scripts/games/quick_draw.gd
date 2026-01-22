extends Control

@onready var timer_label: Label = $VBox/Header/TimerLabel
@onready var round_label: Label = $VBox/Header/RoundLabel
@onready var word_section: VBoxContainer = $VBox/WordSection
@onready var word_label: Label = $VBox/WordSection/WordLabel
@onready var canvas_section: PanelContainer = $VBox/CanvasSection
@onready var drawing_canvas: Control = $VBox/CanvasSection/DrawingCanvas
@onready var tools_section: HBoxContainer = $VBox/ToolsSection
@onready var guess_section: VBoxContainer = $VBox/GuessSection
@onready var guess_input: LineEdit = $VBox/GuessSection/GuessInput
@onready var submit_guess_button: Button = $VBox/GuessSection/SubmitGuessButton
@onready var feedback_label: Label = $VBox/FeedbackLabel
@onready var players_status: HBoxContainer = $VBox/PlayersStatus
@onready var round_timer: Timer = $RoundTimer
@onready var tick_timer: Timer = $TickTimer

# Color buttons
@onready var black_button: Button = $VBox/ToolsSection/BlackButton
@onready var red_button: Button = $VBox/ToolsSection/RedButton
@onready var blue_button: Button = $VBox/ToolsSection/BlueButton
@onready var green_button: Button = $VBox/ToolsSection/GreenButton
@onready var yellow_button: Button = $VBox/ToolsSection/YellowButton
@onready var undo_button: Button = $VBox/ToolsSection/UndoButton
@onready var clear_button: Button = $VBox/ToolsSection/ClearButton

# Start round section
@onready var start_round_section: VBoxContainer = $VBox/StartRoundSection
@onready var drawer_name_label: Label = $VBox/StartRoundSection/DrawerNameLabel
@onready var start_round_button: Button = $VBox/StartRoundSection/StartRoundButton
@onready var waiting_label: Label = $VBox/StartRoundSection/WaitingLabel

# Correct guess overlay
@onready var correct_guess_overlay: ColorRect = $CorrectGuessOverlay
@onready var guesser_name_label: Label = $CorrectGuessOverlay/OverlayContent/GuesserNameLabel
@onready var points_label: Label = $CorrectGuessOverlay/OverlayContent/PointsLabel
@onready var overlay_timer: Timer = $OverlayTimer

const ROUND_TIME = 60
const MIN_POINT_DISTANCE = 3.0

var words_data: Dictionary = {}
var player_order: Array = []
var current_round: int = 0
var total_rounds: int = 0
var current_drawer_id: String = ""
var current_word: String = ""
var time_remaining: int = ROUND_TIME
var game_active: bool = false

# Drawing state
var is_drawing: bool = false
var current_stroke: Line2D = null
var strokes: Array = []
var current_color: Color = Color.BLACK
var stroke_width: float = 5.0
var stroke_id_counter: int = 0
var last_point: Vector2 = Vector2.ZERO

# Guessing state
var has_guessed_correctly: bool = false
var correct_guessers: Array = []

# Round start state
var waiting_for_drawer_start: bool = false
var pending_word: String = ""

# Color palette
const COLORS = {
	"black": Color.BLACK,
	"red": Color.RED,
	"blue": Color.BLUE,
	"green": Color(0, 0.5, 0),
	"yellow": Color(0.8, 0.8, 0)
}

func _ready() -> void:
	# Connect UI signals
	submit_guess_button.pressed.connect(_on_submit_guess_pressed)
	guess_input.text_submitted.connect(_on_guess_submitted)
	guess_input.focus_entered.connect(_on_guess_input_focus)

	# Connect tool buttons
	black_button.pressed.connect(_on_color_pressed.bind("black"))
	red_button.pressed.connect(_on_color_pressed.bind("red"))
	blue_button.pressed.connect(_on_color_pressed.bind("blue"))
	green_button.pressed.connect(_on_color_pressed.bind("green"))
	yellow_button.pressed.connect(_on_color_pressed.bind("yellow"))
	undo_button.pressed.connect(_on_undo_pressed)
	clear_button.pressed.connect(_on_clear_pressed)

	# Connect timers
	tick_timer.timeout.connect(_on_tick_timer)
	round_timer.timeout.connect(_on_round_timer_timeout)
	overlay_timer.timeout.connect(_on_overlay_timer_timeout)

	# Connect start round button
	start_round_button.pressed.connect(_on_start_round_pressed)

	# Connect network
	NetworkManager.message_received.connect(_on_message_received)

	_load_words()
	_initialize_game()

func _on_guess_input_focus() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(guess_input.text, Rect2())

func _load_words() -> void:
	var file = FileAccess.open("res://data/prompts/quick_draw_words.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json:
			words_data = json
		file.close()
	else:
		# Fallback words
		words_data = {
			"easy": ["cat", "dog", "sun", "tree", "house"],
			"medium": ["elephant", "bicycle", "rainbow"],
			"hard": ["astronaut", "earthquake"]
		}

func _initialize_game() -> void:
	if GameManager.is_host:
		# Host sets up and broadcasts initial state
		player_order = GameManager.players.keys()
		player_order.shuffle()
		total_rounds = player_order.size()

		var init_data = {
			"type": "quick_draw_init",
			"player_order": player_order,
			"total_rounds": total_rounds
		}
		NetworkManager.broadcast(init_data)

		_update_players_display()
		game_active = true
		_start_round()
	else:
		feedback_label.text = "Waiting for game to start..."

func _start_round() -> void:
	current_round += 1

	# Rotate drawer
	var drawer_index = (current_round - 1) % player_order.size()
	current_drawer_id = player_order[drawer_index]

	# Pick a word based on round progression
	
	var difficulty = "easy"
	if current_round > total_rounds * 0.66:
		difficulty = "hard"
	elif current_round > total_rounds * 0.33:
		difficulty = "medium"

	var word_list = words_data.get(difficulty, words_data["easy"])
	pending_word = word_list[randi() % word_list.size()]

	time_remaining = ROUND_TIME
	correct_guessers.clear()

	# Clear canvas
	_clear_canvas()

	# Get drawer name
	var drawer_data = GameManager.players.get(current_drawer_id, {})
	var drawer_name = drawer_data.get("name", "Unknown")

	# Broadcast waiting for drawer to start
	var wait_data = {
		"type": "quick_draw_wait",
		"round": current_round,
		"drawer_id": current_drawer_id,
		"drawer_name": drawer_name
	}
	NetworkManager.broadcast(wait_data)
	_apply_wait_data(wait_data)

	# Send word privately to drawer (they'll see it when they start)
	if current_drawer_id == GameManager.local_player_id:
		current_word = pending_word
	else:
		var peer_id = _get_peer_id_from_player_id(current_drawer_id)
		if peer_id > 0:
			NetworkManager.send_to_client(peer_id, {
				"type": "quick_draw_word",
				"word": pending_word
			})

func _apply_wait_data(data: Dictionary) -> void:
	current_round = data.get("round", 1)
	current_drawer_id = data.get("drawer_id", "")
	var drawer_name = data.get("drawer_name", "Unknown")

	waiting_for_drawer_start = true
	round_label.text = "Round %d/%d" % [current_round, total_rounds]

	# Clear canvas for new round
	_clear_canvas()

	# Hide game UI, show start section
	word_section.visible = false
	tools_section.visible = false
	guess_section.visible = false
	start_round_section.visible = true

	var is_drawer = (current_drawer_id == GameManager.local_player_id)
	drawer_name_label.text = drawer_name

	if is_drawer:
		start_round_button.visible = true
		waiting_label.visible = false
		feedback_label.text = "You're up next!"
		feedback_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1))
	else:
		start_round_button.visible = false
		waiting_label.visible = true
		feedback_label.text = "Waiting for %s to start..." % drawer_name
		feedback_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

	_update_players_display()

func _on_start_round_pressed() -> void:
	if not waiting_for_drawer_start:
		return

	if GameManager.is_host:
		# Host starts the round directly
		_begin_round()
	else:
		# Non-host drawer tells host to start
		var start_data = {
			"type": "quick_draw_start",
			"drawer_id": current_drawer_id
		}
		NetworkManager.send_to_server(start_data)

func _begin_round() -> void:
	waiting_for_drawer_start = false
	current_word = pending_word

	# Hide start section
	start_round_section.visible = false

	# Set up round data and broadcast (without word for security)
	var round_data = {
		"type": "quick_draw_round",
		"round": current_round,
		"drawer_id": current_drawer_id,
		"time": ROUND_TIME
	}
	NetworkManager.broadcast(round_data)

	# Apply round data locally first
	_apply_round_data(round_data)

	# Now send word to drawer
	if current_drawer_id == GameManager.local_player_id:
		# Host is the drawer - apply word locally
		word_label.text = current_word.to_upper()
		# Ensure UI is set up
		word_section.visible = true
		tools_section.visible = true
		guess_section.visible = false
	else:
		# Send word to non-host drawer
		var peer_id = _get_peer_id_from_player_id(current_drawer_id)
		if peer_id > 0:
			NetworkManager.send_to_client(peer_id, {
				"type": "quick_draw_word",
				"word": current_word
			})

func _get_peer_id_from_player_id(player_id: String) -> int:
	# Player IDs are formatted as "peer_X"
	if player_id.begins_with("peer_"):
		return int(player_id.substr(5))
	return -1

func _apply_round_data(data: Dictionary) -> void:
	current_round = data.get("round", 1)
	current_drawer_id = data.get("drawer_id", "")
	time_remaining = data.get("time", ROUND_TIME)
	waiting_for_drawer_start = false

	# Clear canvas for all players at the start of each round
	_clear_canvas()

	round_label.text = "Round %d/%d" % [current_round, total_rounds]

	var is_drawer = (current_drawer_id == GameManager.local_player_id)
	has_guessed_correctly = false

	# Hide start section, show game UI
	start_round_section.visible = false
	correct_guess_overlay.visible = false

	# Toggle UI based on role
	word_section.visible = is_drawer
	tools_section.visible = is_drawer
	guess_section.visible = not is_drawer

	if is_drawer:
		feedback_label.text = "You are drawing!"
		feedback_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1))
	else:
		var drawer_data = GameManager.players.get(current_drawer_id, {})
		var drawer_name = drawer_data.get("name", "Unknown")
		feedback_label.text = "%s is drawing..." % drawer_name
		feedback_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		guess_input.text = ""

	_update_timer_display()
	tick_timer.start()
	round_timer.wait_time = ROUND_TIME
	round_timer.start()

func _apply_word_data(data: Dictionary) -> void:
	current_word = data.get("word", "")
	word_label.text = current_word.to_upper()

	# Ensure drawer UI is set up (in case quick_draw_round wasn't received)
	if current_drawer_id == GameManager.local_player_id:
		waiting_for_drawer_start = false
		start_round_section.visible = false
		start_round_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word_section.visible = true
		tools_section.visible = true
		guess_section.visible = false
		tick_timer.start()
		round_timer.start()

func _on_tick_timer() -> void:
	time_remaining -= 1
	_update_timer_display()

	if time_remaining <= 0:
		tick_timer.stop()

func _update_timer_display() -> void:
	timer_label.text = str(time_remaining)

	if time_remaining <= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	elif time_remaining <= 20:
		timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

func _on_round_timer_timeout() -> void:
	if GameManager.is_host:
		_end_round()

func _end_round() -> void:
	tick_timer.stop()
	round_timer.stop()

	# Calculate scores for drawer
	var drawer_points = correct_guessers.size() * 25
	if drawer_points > 0:
		GameManager.update_score(current_drawer_id, drawer_points)

	# Broadcast round end
	var scores = {}
	for player_id in GameManager.players:
		scores[player_id] = GameManager.players[player_id]["score"]

	var end_data = {
		"type": "quick_draw_round_end",
		"word": current_word,
		"scores": scores
	}
	NetworkManager.broadcast(end_data)
	_apply_round_end(end_data)

func _apply_round_end(data: Dictionary) -> void:
	var word = data.get("word", "")
	var scores = data.get("scores", {})

	# Sync scores
	for player_id in scores:
		if GameManager.players.has(player_id):
			GameManager.players[player_id]["score"] = scores[player_id]

	# Hide game UI elements
	word_section.visible = false
	tools_section.visible = false
	guess_section.visible = false
	correct_guess_overlay.visible = false

	feedback_label.text = "The word was: %s" % word.to_upper()
	feedback_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))

	_update_players_display()

	# Check if game is over
	if GameManager.is_host:
		await get_tree().create_timer(3.0).timeout
		if current_round >= total_rounds:
			_end_game()
		else:
			_start_round()

func _end_game() -> void:
	game_active = false

	var final_scores = {}
	var winner_id = ""
	var highest_score = -1

	for player_id in GameManager.players:
		var score = GameManager.players[player_id]["score"]
		final_scores[player_id] = score
		if score > highest_score:
			highest_score = score
			winner_id = player_id

	var end_data = {
		"type": "quick_draw_end",
		"final_scores": final_scores,
		"winner_id": winner_id
	}
	NetworkManager.broadcast(end_data)
	_show_game_over(end_data)

func _show_game_over(data: Dictionary) -> void:
	game_active = false
	tick_timer.stop()
	round_timer.stop()

	var winner_id = data.get("winner_id", "")
	var winner_data = GameManager.players.get(winner_id, {})
	var winner_name = winner_data.get("name", "Nobody")

	word_section.visible = false
	tools_section.visible = false
	guess_section.visible = false

	feedback_label.text = "%s Wins!" % winner_name
	feedback_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

	_update_players_display()

	# Return to lobby
	await get_tree().create_timer(3.0).timeout
	if GameManager.is_host:
		get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")

# ============ DRAWING ============

func _input(event: InputEvent) -> void:
	# Only drawer can draw
	if current_drawer_id != GameManager.local_player_id:
		return

	# Get position in viewport coordinates
	var viewport_pos = Vector2.ZERO
	var is_press = false
	var is_release = false
	var is_drag = false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			viewport_pos = event.position
			is_press = event.pressed
			is_release = not event.pressed
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			viewport_pos = event.position
			is_drag = true
	elif event is InputEventScreenTouch:
		viewport_pos = event.position
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventScreenDrag:
		viewport_pos = event.position
		is_drag = true
	else:
		return

	# Convert viewport position to canvas local position
	var canvas_pos = _viewport_to_canvas(viewport_pos)

	# Check if position is within canvas bounds
	var canvas_rect = drawing_canvas.get_global_rect()
	var in_canvas = canvas_rect.has_point(viewport_pos)

	if is_press and in_canvas:
		_start_stroke(canvas_pos)
	elif is_drag and is_drawing:
		_continue_stroke(canvas_pos)
	elif is_release:
		_end_stroke()

func _viewport_to_canvas(viewport_pos: Vector2) -> Vector2:
	# Convert from viewport/screen coordinates to canvas local coordinates
	var canvas_global_pos = drawing_canvas.get_global_rect().position
	return viewport_pos - canvas_global_pos

func _start_stroke(pos: Vector2) -> void:
	# Prevent starting a new stroke if already drawing
	if is_drawing:
		return

	is_drawing = true
	stroke_id_counter += 1
	last_point = pos

	current_stroke = Line2D.new()
	current_stroke.width = stroke_width
	current_stroke.default_color = current_color
	current_stroke.add_point(pos)
	current_stroke.set_meta("stroke_id", stroke_id_counter)
	drawing_canvas.add_child(current_stroke)
	strokes.append(current_stroke)

	# Send stroke start
	_send_stroke_data(stroke_id_counter, [pos])

func _continue_stroke(pos: Vector2) -> void:
	if not is_drawing or current_stroke == null:
		return

	# Throttle points by distance
	if pos.distance_to(last_point) < MIN_POINT_DISTANCE:
		return

	last_point = pos
	current_stroke.add_point(pos)

	# Send point update
	var stroke_id = current_stroke.get_meta("stroke_id")
	_send_stroke_data(stroke_id, [pos])

func _end_stroke() -> void:
	is_drawing = false
	current_stroke = null

func _send_stroke_data(stroke_id: int, points: Array) -> void:
	var point_arrays = []
	for p in points:
		point_arrays.append([p.x, p.y])

	var data = {
		"type": "quick_draw_stroke",
		"stroke_id": stroke_id,
		"color": [current_color.r, current_color.g, current_color.b],
		"width": stroke_width,
		"points": point_arrays
	}

	if GameManager.is_host:
		NetworkManager.broadcast(data)
	else:
		NetworkManager.send_to_server(data)

func _apply_stroke_data(data: Dictionary) -> void:
	# If we're still on the waiting screen, switch to guessing mode
	if waiting_for_drawer_start and current_drawer_id != GameManager.local_player_id:
		waiting_for_drawer_start = false
		start_round_section.visible = false
		start_round_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guess_section.visible = true
		word_section.visible = false
		tools_section.visible = false
		guess_input.editable = true
		guess_input.grab_focus()
		tick_timer.start()
		round_timer.start()

	var stroke_id = int(data.get("stroke_id", 0))  # Ensure int type for comparison
	var color_arr = data.get("color", [0, 0, 0])
	var width = float(data.get("width", 5.0))
	var points_arr = data.get("points", [])

	var color = Color(color_arr[0], color_arr[1], color_arr[2])

	# Find existing stroke or create new one
	var stroke: Line2D = null
	for s in strokes:
		if int(s.get_meta("stroke_id")) == stroke_id:
			stroke = s
			break

	if stroke == null:
		stroke = Line2D.new()
		stroke.width = width
		stroke.default_color = color
		stroke.set_meta("stroke_id", stroke_id)
		drawing_canvas.add_child(stroke)
		strokes.append(stroke)

	# Add points
	for p in points_arr:
		stroke.add_point(Vector2(p[0], p[1]))

func _on_color_pressed(color_name: String) -> void:
	current_color = COLORS.get(color_name, Color.BLACK)

func _on_undo_pressed() -> void:
	if strokes.size() == 0:
		return

	var last_stroke = strokes.pop_back()
	last_stroke.queue_free()

	# Broadcast undo
	var data = {"type": "quick_draw_undo"}
	if GameManager.is_host:
		NetworkManager.broadcast(data)
	else:
		NetworkManager.send_to_server(data)

func _apply_undo() -> void:
	if strokes.size() > 0:
		var last_stroke = strokes.pop_back()
		last_stroke.queue_free()

func _on_clear_pressed() -> void:
	_clear_canvas()

	# Broadcast clear
	var data = {"type": "quick_draw_clear"}
	if GameManager.is_host:
		NetworkManager.broadcast(data)
	else:
		NetworkManager.send_to_server(data)

func _clear_canvas() -> void:
	for stroke in strokes:
		stroke.queue_free()
	strokes.clear()
	stroke_id_counter = 0

# ============ GUESSING ============

func _on_submit_guess_pressed() -> void:
	if not has_guessed_correctly and guess_input.text.strip_edges().length() > 0:
		_submit_guess(guess_input.text.strip_edges())

func _on_guess_submitted(text: String) -> void:
	if not has_guessed_correctly and text.strip_edges().length() > 0:
		_submit_guess(text.strip_edges())

func _submit_guess(guess: String) -> void:
	var data = {
		"type": "quick_draw_guess",
		"guess": guess
	}

	if GameManager.is_host:
		_validate_guess(GameManager.local_player_id, guess)
	else:
		NetworkManager.send_to_server(data)

	guess_input.text = ""

func _validate_guess(player_id: String, guess: String) -> void:
	# Check if already guessed correctly
	if player_id in correct_guessers:
		return

	# Case-insensitive comparison
	if guess.to_lower() == current_word.to_lower():
		# Correct guess
		correct_guessers.append(player_id)

		# Calculate points
		var speed_bonus = int(50.0 * (float(time_remaining) / float(ROUND_TIME)))
		var guesser_points = 100 + speed_bonus
		GameManager.update_score(player_id, guesser_points)

		var player_data = GameManager.players.get(player_id, {})
		var player_name = player_data.get("name", "Unknown")

		# Broadcast correct guess
		var data = {
			"type": "quick_draw_correct",
			"player_id": player_id,
			"player_name": player_name,
			"points": guesser_points
		}
		NetworkManager.broadcast(data)
		_apply_correct_guess(data)

		# Check if everyone has guessed
		var guessers_count = player_order.size() - 1  # Exclude drawer
		if correct_guessers.size() >= guessers_count:
			_end_round()

func _apply_correct_guess(data: Dictionary) -> void:
	var player_id = data.get("player_id", "")
	var player_name = data.get("player_name", "Unknown")
	var points = data.get("points", 0)

	# Show the overlay for all players
	_show_correct_overlay(player_name, points)

	if player_id == GameManager.local_player_id:
		has_guessed_correctly = true
		guess_section.visible = false
		feedback_label.text = "Correct! +%d points" % points
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
	else:
		feedback_label.text = "%s guessed it! (+%d)" % [player_name, points]
		feedback_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))

	if not player_id in correct_guessers:
		correct_guessers.append(player_id)

	_update_players_display()

func _show_correct_overlay(player_name: String, points: int) -> void:
	guesser_name_label.text = "%s guessed it!" % player_name
	points_label.text = "+%d points" % points
	correct_guess_overlay.visible = true
	overlay_timer.start()

func _on_overlay_timer_timeout() -> void:
	correct_guess_overlay.visible = false

# ============ NETWORK ============

func _on_message_received(peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"quick_draw_init":
			_apply_init_data(data)
		"quick_draw_wait":
			_apply_wait_data(data)
		"quick_draw_start":
			if GameManager.is_host:
				# Non-host drawer pressed start, begin the round
				_begin_round()
		"quick_draw_round":
			# All players (including host) apply round data when received
			if not GameManager.is_host:
				_apply_round_data(data)
		"quick_draw_word":
			_apply_word_data(data)
		"quick_draw_stroke":
			if GameManager.is_host:
				# Relay to all other players
				NetworkManager.broadcast(data, peer_id)
			# Only apply if we're not the drawer (drawer already has local strokes)
			if current_drawer_id != GameManager.local_player_id:
				_apply_stroke_data(data)
		"quick_draw_clear":
			if GameManager.is_host:
				NetworkManager.broadcast(data, peer_id)
			if current_drawer_id != GameManager.local_player_id:
				_clear_canvas()
		"quick_draw_undo":
			if GameManager.is_host:
				NetworkManager.broadcast(data, peer_id)
			if current_drawer_id != GameManager.local_player_id:
				_apply_undo()
		"quick_draw_guess":
			if GameManager.is_host:
				var guess = data.get("guess", "")
				var player_id = "peer_%d" % peer_id
				_validate_guess(player_id, guess)
		"quick_draw_correct":
			_apply_correct_guess(data)
		"quick_draw_round_end":
			_apply_round_end(data)
		"quick_draw_end":
			_show_game_over(data)

func _apply_init_data(data: Dictionary) -> void:
	player_order = data.get("player_order", [])
	total_rounds = data.get("total_rounds", player_order.size())

	game_active = true
	_update_players_display()
	feedback_label.text = "Game started!"

# ============ UI ============

func _update_players_display() -> void:
	# Clear existing
	for child in players_status.get_children():
		child.queue_free()

	# Add player status indicators
	for player_id in GameManager.players:
		var player = GameManager.players[player_id]

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)

		var char_data = GameManager.get_character_data(player["character"])
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(40, 40)
		color_rect.color = char_data["color"]

		# Show checkmark for correct guessers
		if player_id in correct_guessers:
			var check = Label.new()
			check.text = "V"
			check.add_theme_font_size_override("font_size", 20)
			check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			check.anchors_preset = Control.PRESET_FULL_RECT
			check.set_anchors_preset(Control.PRESET_FULL_RECT)
			color_rect.add_child(check)

		# Highlight drawer
		if player_id == current_drawer_id:
			color_rect.modulate = Color(1.2, 1.2, 1.2, 1)

		var name_label = Label.new()
		name_label.text = player["name"]
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var score_label = Label.new()
		score_label.text = str(player["score"])
		score_label.add_theme_font_size_override("font_size", 12)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))

		vbox.add_child(color_rect)
		vbox.add_child(name_label)
		vbox.add_child(score_label)

		players_status.add_child(vbox)
