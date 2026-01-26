extends Control

## Quick Draw - One player draws, others guess

@onready var timer_label: Label = $VBox/Header/TimerLabel
@onready var round_label: Label = $VBox/Header/RoundLabel
@onready var word_label: Label = $VBox/WordSection/WordLabel
@onready var word_section: VBoxContainer = $VBox/WordSection
@onready var drawing_canvas: Control = $VBox/CanvasSection/DrawingCanvas
@onready var tools_section: HBoxContainer = $VBox/ToolsSection
@onready var guess_section: VBoxContainer = $VBox/GuessSection
@onready var hint_label: Label = $VBox/GuessSection/HintLabel
@onready var wrong_guess_label: Label = $VBox/GuessSection/WrongGuessLabel
@onready var guess_input: LineEdit = $VBox/GuessSection/GuessInput
@onready var submit_guess_button: Button = $VBox/GuessSection/GuessButtons/SubmitGuessButton
@onready var hint_button: Button = $VBox/GuessSection/GuessButtons/HintButton
@onready var feedback_label: Label = $VBox/FeedbackLabel
@onready var players_status: HBoxContainer = $VBox/PlayersStatus

# Start section
@onready var start_section: VBoxContainer = $VBox/StartSection
@onready var start_button: Button = $VBox/StartSection/StartButton
@onready var waiting_label: Label = $VBox/StartSection/WaitingLabel

# Timers
@onready var round_timer: Timer = $RoundTimer
@onready var tick_timer: Timer = $TickTimer

# Color buttons
@onready var black_button: Button = $VBox/ToolsSection/BlackButton
@onready var red_button: Button = $VBox/ToolsSection/RedButton
@onready var blue_button: Button = $VBox/ToolsSection/BlueButton
@onready var green_button: Button = $VBox/ToolsSection/GreenButton
@onready var yellow_button: Button = $VBox/ToolsSection/YellowButton
@onready var eraser_button: Button = $VBox/ToolsSection/EraserButton
@onready var undo_button: Button = $VBox/ToolsSection/UndoButton
@onready var clear_button: Button = $VBox/ToolsSection/ClearButton

const ROUND_TIME = 60

# Game state
enum State { WAITING, READY, DRAWING, ROUND_END, GAME_OVER }
var state: State = State.WAITING

var words_data: Dictionary = {}
var player_order: Array = []
var current_round: int = 0
var total_rounds: int = 0
var drawer_id: String = ""
var current_word: String = ""
var time_remaining: int = ROUND_TIME
var correct_guessers: Array = []
var hints_used: int = 0  # For future hints feature - reduces max points
var max_guesser_points: int = 0  # Track highest points for drawer scoring

# Drawing
var is_drawing: bool = false
var strokes: Array = []
var current_stroke: Line2D = null
var current_color: Color = Color.BLACK
var stroke_id: int = 0

const COLORS = {
	"black": Color.BLACK,
	"red": Color.RED,
	"blue": Color.BLUE,
	"green": Color(0, 0.5, 0),
	"yellow": Color(0.8, 0.8, 0)
}

func _ready() -> void:
	# UI connections
	submit_guess_button.pressed.connect(_submit_guess)
	guess_input.text_submitted.connect(func(_t): _submit_guess())
	start_button.pressed.connect(_on_start_pressed)

	black_button.pressed.connect(func(): current_color = COLORS["black"])
	red_button.pressed.connect(func(): current_color = COLORS["red"])
	blue_button.pressed.connect(func(): current_color = COLORS["blue"])
	green_button.pressed.connect(func(): current_color = COLORS["green"])
	yellow_button.pressed.connect(func(): current_color = COLORS["yellow"])
	eraser_button.pressed.connect(func(): current_color = Color.WHITE)
	undo_button.pressed.connect(_undo_stroke)
	clear_button.pressed.connect(_clear_canvas)

	tick_timer.timeout.connect(_on_tick)
	round_timer.timeout.connect(_on_round_end)

	NetworkManager.message_received.connect(_on_network_message)

	_load_words()

	if GameManager.is_host:
		_setup_game()

func _load_words() -> void:
	var file = FileAccess.open("res://data/prompts/quick_draw_words.json", FileAccess.READ)
	if file:
		words_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		words_data = {"easy": ["cat", "dog", "sun"], "medium": ["house", "tree"], "hard": ["elephant"]}

func _setup_game() -> void:
	player_order = GameManager.players.keys()
	player_order.shuffle()
	total_rounds = player_order.size()

	NetworkManager.broadcast({
		"type": "qd_init",
		"order": player_order,
		"rounds": total_rounds
	})

	_start_round()

func _start_round() -> void:
	current_round += 1
	drawer_id = player_order[(current_round - 1) % player_order.size()]
	correct_guessers.clear()
	hints_used = 0
	max_guesser_points = 0
	_clear_all_strokes()

	# Pick word
	var diff = "easy"
	if current_round > total_rounds * 0.6:
		diff = "hard"
	elif current_round > total_rounds * 0.3:
		diff = "medium"
	var word_list = words_data.get(diff, ["cat"])
	current_word = word_list[randi() % word_list.size()]

	time_remaining = ROUND_TIME
	state = State.READY

	var drawer_name = GameManager.players.get(drawer_id, {}).get("name", "?")

	# Broadcast ready state
	NetworkManager.broadcast({
		"type": "qd_ready",
		"round": current_round,
		"drawer": drawer_id,
		"drawer_name": drawer_name
	})

	# Show ready UI
	_show_ready_ui(drawer_name)

	# Send word to drawer (they won't see it until they press start)
	if drawer_id != GameManager.local_player_id:
		var peer = int(drawer_id.substr(5)) if drawer_id.begins_with("peer_") else -1
		if peer > 0:
			NetworkManager.send_to_client(peer, {"type": "qd_word", "word": current_word})

func _show_ready_ui(drawer_name: String) -> void:
	word_section.visible = false
	tools_section.visible = false
	guess_section.visible = false
	start_section.visible = true

	
	round_label.text = "Round %d/%d" % [current_round, total_rounds]
	timer_label.text = str(ROUND_TIME)

	if drawer_id == GameManager.local_player_id:
		start_button.visible = true
		waiting_label.visible = false
		feedback_label.text = "You're up! Press Start when ready."
	else:
		start_button.visible = false
		waiting_label.visible = true
		waiting_label.text = "Waiting for %s..." % drawer_name
		feedback_label.text = "%s is getting ready..." % drawer_name

	_update_display()

func _on_start_pressed() -> void:
	if state != State.READY:
		return

	if GameManager.is_host:
		_begin_drawing()
	else:
		NetworkManager.send_to_server({"type": "qd_start"})

func _begin_drawing() -> void:
	state = State.DRAWING
	time_remaining = ROUND_TIME

	var drawer_name = GameManager.players.get(drawer_id, {}).get("name", "?")

	NetworkManager.broadcast({
		"type": "qd_drawing",
		"drawer": drawer_id,
		"drawer_name": drawer_name,
		"time": ROUND_TIME
	})

	# Update host UI
	if drawer_id == GameManager.local_player_id:
		_show_drawer_ui()
	else:
		_show_guesser_ui(drawer_name)

func _show_drawer_ui() -> void:
	start_section.visible = false
	word_section.visible = true
	word_label.text = current_word.to_upper()
	tools_section.visible = true
	guess_section.visible = false
	feedback_label.text = "Draw: " + current_word.to_upper()
	tick_timer.start()
	round_timer.wait_time = ROUND_TIME
	round_timer.start()
	_update_display()

func _show_guesser_ui(drawer_name: String) -> void:
	start_section.visible = false
	word_section.visible = false
	tools_section.visible = false
	guess_section.visible = true
	guess_input.text = ""
	guess_input.editable = true
	hint_label.text = ""
	wrong_guess_label.text = ""
	hint_button.visible = false  # Hints are now automatic
	feedback_label.text = drawer_name + " is drawing..."
	tick_timer.start()
	round_timer.wait_time = ROUND_TIME
	round_timer.start()
	_update_display()

func _on_tick() -> void:
	time_remaining -= 1
	timer_label.text = str(time_remaining)
	if time_remaining <= 10:
		timer_label.add_theme_color_override("font_color", Color.RED)
	elif time_remaining <= 20:
		timer_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))

	# Auto-hints at time thresholds (host only broadcasts)
	if GameManager.is_host:
		if time_remaining == 45 and hints_used < 1:
			_process_hint()
		elif time_remaining == 30 and hints_used < 2:
			_process_hint()
		elif time_remaining == 15 and hints_used < 3:
			_process_hint()

func _on_round_end() -> void:
	if not GameManager.is_host:
		return

	tick_timer.stop()
	state = State.ROUND_END

	# Drawer gets points equal to highest guesser's score
	if max_guesser_points > 0:
		GameManager.update_score(drawer_id, max_guesser_points)

	var scores = {}
	for pid in GameManager.players:
		scores[pid] = GameManager.players[pid]["score"]

	NetworkManager.broadcast({
		"type": "qd_end_round",
		"word": current_word,
		"scores": scores
	})

	await get_tree().create_timer(3.0).timeout

	if current_round >= total_rounds:
		_end_game()
	else:
		_start_round()

func _end_game() -> void:
	state = State.GAME_OVER

	var winner_id = ""
	var high_score = -1
	for pid in GameManager.players:
		var s = GameManager.players[pid]["score"]
		if s > high_score:
			high_score = s
			winner_id = pid

	NetworkManager.broadcast({
		"type": "qd_game_over",
		"winner": winner_id
	})

	await get_tree().create_timer(3.0).timeout

	if GameManager.is_host:
		get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")

# ===== DRAWING =====

func _input(event: InputEvent) -> void:
	if drawer_id != GameManager.local_player_id or state != State.DRAWING:
		return

	var pos = Vector2.ZERO
	var pressed = false
	var released = false
	var dragging = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pos = event.position
		dragging = true
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		pos = event.position
		dragging = true
	else:
		return

	var canvas_rect = drawing_canvas.get_global_rect()
	var local_pos = pos - canvas_rect.position

	if pressed and canvas_rect.has_point(pos):
		_begin_stroke(local_pos)
	elif dragging and is_drawing:
		_add_point(local_pos)
	elif released:
		_finish_stroke()

func _begin_stroke(pos: Vector2) -> void:
	is_drawing = true
	stroke_id += 1

	current_stroke = Line2D.new()
	current_stroke.width = 5.0
	current_stroke.default_color = current_color
	current_stroke.add_point(pos)
	current_stroke.set_meta("id", stroke_id)
	drawing_canvas.add_child(current_stroke)
	strokes.append(current_stroke)

	_send_stroke(stroke_id, [pos])

func _add_point(pos: Vector2) -> void:
	if current_stroke == null:
		return
	current_stroke.add_point(pos)
	_send_stroke(current_stroke.get_meta("id"), [pos])

func _finish_stroke() -> void:
	is_drawing = false
	current_stroke = null

func _send_stroke(id: int, points: Array) -> void:
	var pts = []
	for p in points:
		pts.append([p.x, p.y])

	var data = {
		"type": "qd_stroke",
		"id": id,
		"color": [current_color.r, current_color.g, current_color.b],
		"points": pts
	}

	if GameManager.is_host:
		NetworkManager.broadcast(data)
	else:
		NetworkManager.send_to_server(data)

func _apply_stroke(data: Dictionary) -> void:
	var id = data.get("id", 0)
	var c = data.get("color", [0, 0, 0])
	var pts = data.get("points", [])

	var stroke: Line2D = null
	for s in strokes:
		if s.get_meta("id") == id:
			stroke = s
			break

	if stroke == null:
		stroke = Line2D.new()
		stroke.width = 5.0
		stroke.default_color = Color(c[0], c[1], c[2])
		stroke.set_meta("id", id)
		drawing_canvas.add_child(stroke)
		strokes.append(stroke)

	for p in pts:
		stroke.add_point(Vector2(p[0], p[1]))

func _undo_stroke() -> void:
	if strokes.size() == 0:
		return
	var last = strokes.pop_back()
	last.queue_free()

	var data = {"type": "qd_undo"}
	if GameManager.is_host:
		NetworkManager.broadcast(data)
	else:
		NetworkManager.send_to_server(data)

func _clear_canvas() -> void:
	_clear_all_strokes()
	var data = {"type": "qd_clear"}
	if GameManager.is_host:
		NetworkManager.broadcast(data)
	else:
		NetworkManager.send_to_server(data)

func _clear_all_strokes() -> void:
	for s in strokes:
		s.queue_free()
	strokes.clear()
	stroke_id = 0

# ===== GUESSING =====

func _submit_guess() -> void:
	var guess = guess_input.text.strip_edges().to_lower()
	if guess.is_empty():
		return

	guess_input.text = ""

	if GameManager.is_host:
		_check_guess(GameManager.local_player_id, guess)
	else:
		NetworkManager.send_to_server({"type": "qd_guess", "guess": guess})

func _calculate_points() -> int:
	# Tiered scoring: 3 pts (first 20s), 2 pts (20-40s), 1 pt (40-60s)
	# Each hint reduces max by 1 (minimum 0 points)
	var base_points: int
	if time_remaining > 40:
		base_points = 3
	elif time_remaining > 20:
		base_points = 2
	else:
		base_points = 1

	# Reduce by hints used, minimum 0 points
	return max(0, base_points - hints_used)

func _check_guess(player_id: String, guess: String) -> void:
	if player_id in correct_guessers:
		return

	var pname = GameManager.players.get(player_id, {}).get("name", "?")

	if guess != current_word.to_lower():
		# Wrong guess - broadcast to all players
		NetworkManager.broadcast({
			"type": "qd_wrong",
			"player": player_id,
			"name": pname,
			"guess": guess
		})
		# Apply locally on host
		_apply_wrong_guess(pname, guess)
		return

	if guess == current_word.to_lower():
		correct_guessers.append(player_id)

		# Calculate speed-based points (reduced by hints)
		var points = _calculate_points()
		GameManager.update_score(player_id, points)

		# Track highest points for drawer scoring
		if points > max_guesser_points:
			max_guesser_points = points

		var new_score = GameManager.players.get(player_id, {}).get("score", 0)

		# Broadcast to all clients
		NetworkManager.broadcast({
			"type": "qd_correct",
			"player": player_id,
			"name": pname,
			"points": points,
			"score": new_score
		})

		# Also apply locally on host (host doesn't receive its own broadcast)
		_apply_correct_guess(player_id, pname, points)

		# Check if everyone (except drawer) has guessed
		var guessers_count = GameManager.players.size() - 1  # Exclude drawer
		if correct_guessers.size() >= guessers_count:
			round_timer.stop()
			_on_round_end()

func _apply_correct_guess(player_id: String, pname: String, pts: int) -> void:
	if player_id == GameManager.local_player_id:
		if pts == 0:
			feedback_label.text = "Congratulations, you have earned a participation trophy!"
		else:
			feedback_label.text = "Correct! +%d" % pts
		guess_section.visible = false
	else:
		if pts == 0:
			feedback_label.text = "%s earned a participation trophy!" % pname
		else:
			feedback_label.text = "%s got it! +%d" % [pname, pts]
	_update_display()

func _apply_wrong_guess(pname: String, guess: String) -> void:
	# Show wrong guess to all guessers (drawer doesn't see guess section)
	wrong_guess_label.text = "%s guessed: %s" % [pname, guess]

# ===== HINTS =====

const MAX_HINTS = 3

func _get_hint_text(hint_number: int) -> String:
	match hint_number:
		1:
			# 2nd letter
			if current_word.length() >= 2:
				return "2nd letter: %s" % current_word[1].to_upper()
			else:
				return "2nd letter: %s" % current_word[0].to_upper()
		2:
			# Letter count
			return "%d letters" % current_word.length()
		3:
			# First letter
			return "Starts with: %s" % current_word[0].to_upper()
		_:
			return ""

func _process_hint() -> void:
	if hints_used >= MAX_HINTS:
		return

	hints_used += 1
	var hint_text = _get_hint_text(hints_used)
	var hints_remaining = MAX_HINTS - hints_used

	NetworkManager.broadcast({
		"type": "qd_hint",
		"hint_number": hints_used,
		"hint_text": hint_text,
		"hints_remaining": hints_remaining
	})

	# Apply locally on host
	_apply_hint(hint_text, hints_remaining)

func _apply_hint(hint_text: String, _hints_remaining: int) -> void:
	# Update hint display (hints are now automatic at 45s, 30s, 15s)
	if hint_label.text.is_empty():
		hint_label.text = hint_text
	else:
		hint_label.text += "  |  " + hint_text

# ===== NETWORK =====

func _on_network_message(_peer: int, data: Dictionary) -> void:
	var t = data.get("type", "")

	match t:
		"qd_init":
			player_order = data.get("order", [])
			total_rounds = data.get("rounds", 1)
			feedback_label.text = "Game starting..."
			_update_display()

		"qd_ready":
			current_round = data.get("round", 1)
			drawer_id = data.get("drawer", "")
			state = State.READY
			correct_guessers.clear()
			hints_used = 0
			max_guesser_points = 0
			_clear_all_strokes()
			_show_ready_ui(data.get("drawer_name", "Someone"))

		"qd_word":
			current_word = data.get("word", "")

		"qd_start":
			if GameManager.is_host:
				_begin_drawing()

		"qd_drawing":
			drawer_id = data.get("drawer", "")
			time_remaining = data.get("time", ROUND_TIME)
			state = State.DRAWING

			if drawer_id == GameManager.local_player_id:
				_show_drawer_ui()
			else:
				_show_guesser_ui(data.get("drawer_name", "Someone"))

		"qd_stroke":
			if GameManager.is_host:
				NetworkManager.broadcast(data, _peer)
			if drawer_id != GameManager.local_player_id:
				_apply_stroke(data)

		"qd_undo":
			if GameManager.is_host:
				NetworkManager.broadcast(data, _peer)
			if drawer_id != GameManager.local_player_id and strokes.size() > 0:
				var last = strokes.pop_back()
				last.queue_free()

		"qd_clear":
			if GameManager.is_host:
				NetworkManager.broadcast(data, _peer)
			if drawer_id != GameManager.local_player_id:
				_clear_all_strokes()

		"qd_guess":
			if GameManager.is_host:
				var pid = "peer_%d" % _peer
				_check_guess(pid, data.get("guess", ""))

		"qd_wrong":
			var pname = data.get("name", "?")
			var guess = data.get("guess", "")
			_apply_wrong_guess(pname, guess)

		"qd_hint":
			hints_used = data.get("hint_number", hints_used)
			var hint_text = data.get("hint_text", "")
			var hints_remaining = data.get("hints_remaining", 0)
			_apply_hint(hint_text, hints_remaining)

		"qd_correct":
			var pid = data.get("player", "")
			var pname = data.get("name", "?")
			var pts = data.get("points", 0)
			var new_score = data.get("score", 0)

			# Update player's score immediately
			if GameManager.players.has(pid):
				GameManager.players[pid]["score"] = int(new_score)

			# Only process if we haven't already (host processes locally in _check_guess)
			if not pid in correct_guessers:
				correct_guessers.append(pid)
				_apply_correct_guess(pid, pname, pts)

		"qd_end_round":
			tick_timer.stop()
			round_timer.stop()
			state = State.ROUND_END
			var word = data.get("word", "")
			feedback_label.text = "Answer: " + word.to_upper()
			guess_section.visible = false
			tools_section.visible = false

			var scores = data.get("scores", {})
			for pid in scores:
				if GameManager.players.has(pid):
					GameManager.players[pid]["score"] = int(scores[pid])
			_update_display()

		"qd_game_over":
			state = State.GAME_OVER
			var winner = data.get("winner", "")
			var wname = GameManager.players.get(winner, {}).get("name", "Nobody")
			feedback_label.text = wname + " Wins!"

func _update_display() -> void:
	timer_label.text = str(time_remaining)
	round_label.text = "Round %d/%d" % [current_round, total_rounds]

	for child in players_status.get_children():
		child.queue_free()

	for pid in GameManager.players:
		var p = GameManager.players[pid]
		var vbox = VBoxContainer.new()

		var char_data = GameManager.get_character_data(p["character"])
		var char_display: Control
		var sprite_path = char_data.get("sprite")
		if sprite_path and ResourceLoader.exists(sprite_path):
			var texture_rect = TextureRect.new()
			texture_rect.texture = load(sprite_path)
			texture_rect.custom_minimum_size = Vector2(35, 35)
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			char_display = texture_rect
		else:
			var color_rect = ColorRect.new()
			color_rect.custom_minimum_size = Vector2(35, 35)
			color_rect.color = char_data["color"]
			char_display = color_rect

		if pid in correct_guessers:
			var check = Label.new()
			check.text = "OK"
			check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			char_display.add_child(check)

		if pid == drawer_id:
			char_display.modulate = Color(1.3, 1.3, 1.3)

		var name_lbl = Label.new()
		name_lbl.text = p["name"]
		name_lbl.add_theme_font_size_override("font_size", 10)

		var score_lbl = Label.new()
		score_lbl.text = str(int(p["score"]))
		score_lbl.add_theme_font_size_override("font_size", 11)

		vbox.add_child(char_display)
		vbox.add_child(name_lbl)
		vbox.add_child(score_lbl)
		players_status.add_child(vbox)
