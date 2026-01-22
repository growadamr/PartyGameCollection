extends Control

# UI References - Header
@onready var timer_label: Label = $VBox/Header/TimerLabel
@onready var round_label: Label = $VBox/Header/RoundLabel
@onready var phase_label: Label = $VBox/Header/PhaseLabel

# UI References - Question Section
@onready var question_section: PanelContainer = $VBox/QuestionSection
@onready var category_label: Label = $VBox/QuestionSection/VBox/CategoryLabel
@onready var question_label: Label = $VBox/QuestionSection/VBox/QuestionLabel

# UI References - Answers Section
@onready var answers_section: VBoxContainer = $VBox/AnswersSection
@onready var answer_buttons: GridContainer = $VBox/AnswersSection/AnswerButtons
@onready var answers_status: Label = $VBox/AnswersSection/AnswersStatus

# UI References - Result Section
@onready var result_section: VBoxContainer = $VBox/ResultSection
@onready var result_label: Label = $VBox/ResultSection/ResultLabel
@onready var points_label: Label = $VBox/ResultSection/PointsLabel
@onready var correct_answer_label: Label = $VBox/ResultSection/CorrectAnswerLabel

# UI References - Leaderboard Section
@onready var leaderboard_section: VBoxContainer = $VBox/LeaderboardSection
@onready var leaderboard_list: VBoxContainer = $VBox/LeaderboardSection/LeaderboardList

# UI References - Ready Section
@onready var ready_section: VBoxContainer = $VBox/ReadySection
@onready var ready_button: Button = $VBox/ReadySection/ReadyButton
@onready var ready_status: Label = $VBox/ReadySection/ReadyStatus

# UI References - Players Display
@onready var players_status: HBoxContainer = $VBox/PlayersStatus

# Timers
@onready var phase_timer: Timer = $PhaseTimer
@onready var tick_timer: Timer = $TickTimer

# Constants
const QUESTION_TIME: int = 15
const REVEAL_TIME: int = 3
const LEADERBOARD_TIME: int = 3
const MIN_PLAYERS: int = 2
const QUESTIONS_PER_ROUND: int = 10
const BASE_POINTS: int = 100
const MAX_SPEED_BONUS: int = 100

# Game State
enum GamePhase { WAITING, PRE_ROUND, QUESTION, REVEAL, LEADERBOARD, ROUND_END, GAME_END }
var current_phase: GamePhase = GamePhase.WAITING
var current_round: int = 0
var total_rounds: int = 3
var current_question_num: int = 0

# Player Management
var player_order: Array = []
var player_scores: Dictionary = {}
var players_ready: Dictionary = {}

# Question Data
var all_questions: Array = []
var used_question_ids: Array = []
var current_question: Dictionary = {}
var player_answers: Dictionary = {}  # player_id -> {answer_index, time_taken}

var time_remaining: int = 0
var question_start_time: float = 0.0
var has_answered: bool = false
var is_ready: bool = false


func _ready() -> void:
	_load_questions()
	_connect_signals()
	_setup_timers()
	call_deferred("_initialize_game")


func _load_questions() -> void:
	var file = FileAccess.open("res://data/prompts/trivia_questions.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json and json.has("questions"):
			all_questions = json.questions
		file.close()

	if all_questions.is_empty():
		# Fallback questions
		all_questions = [
			{
				"id": 1,
				"category": "General",
				"difficulty": "easy",
				"question": "What is the capital of France?",
				"answers": ["London", "Berlin", "Paris", "Madrid"],
				"correct": 2
			}
		]


func _connect_signals() -> void:
	NetworkManager.message_received.connect(_on_message_received)
	ready_button.pressed.connect(_on_ready_pressed)


func _setup_timers() -> void:
	phase_timer.one_shot = true
	phase_timer.timeout.connect(_on_phase_timeout)
	tick_timer.wait_time = 1.0
	tick_timer.timeout.connect(_on_tick)


func _initialize_game() -> void:
	if GameManager.is_host:
		player_order = GameManager.players.keys()
		player_order.shuffle()

		for player_id in player_order:
			player_scores[player_id] = 0
			players_ready[player_id] = false

		var init_data = {
			"type": "trivia_init",
			"player_order": player_order,
			"total_rounds": total_rounds,
			"questions_per_round": QUESTIONS_PER_ROUND,
			"time_per_question": QUESTION_TIME,
			"scores": player_scores
		}
		NetworkManager.broadcast(init_data)
		_apply_init(init_data)

		_show_pre_round()
	else:
		_hide_all_sections()
		question_label.text = "Waiting for game to start..."


func _show_pre_round() -> void:
	current_phase = GamePhase.PRE_ROUND
	_reset_ready_state()
	current_question_num = 0

	var next_round = current_round + 1
	var data = {
		"type": "trivia_pre_round",
		"round": next_round,
		"total_rounds": total_rounds,
		"ready_players": []
	}
	NetworkManager.broadcast(data)
	_apply_pre_round(data)


func _reset_ready_state() -> void:
	is_ready = false
	for player_id in players_ready:
		players_ready[player_id] = false


func _start_round() -> void:
	current_round += 1
	current_question_num = 0
	_show_next_question()


func _get_random_question() -> Dictionary:
	# Filter out used questions
	var available = all_questions.filter(func(q): return q.id not in used_question_ids)

	# If we've used all questions, reset
	if available.is_empty():
		used_question_ids.clear()
		available = all_questions

	# Try to balance difficulty (3 easy, 5 medium, 2 hard per round of 10)
	var target_difficulty = "medium"
	var easy_count = used_question_ids.filter(func(id):
		var q = all_questions.filter(func(x): return x.id == id)
		return q.size() > 0 and q[0].get("difficulty", "medium") == "easy"
	).size() % QUESTIONS_PER_ROUND

	var hard_count = used_question_ids.filter(func(id):
		var q = all_questions.filter(func(x): return x.id == id)
		return q.size() > 0 and q[0].get("difficulty", "medium") == "hard"
	).size() % QUESTIONS_PER_ROUND

	if easy_count < 3:
		target_difficulty = "easy"
	elif hard_count < 2:
		target_difficulty = "hard"

	# Try to find a question with target difficulty
	var filtered = available.filter(func(q): return q.get("difficulty", "medium") == target_difficulty)
	if filtered.is_empty():
		filtered = available

	var question = filtered[randi() % filtered.size()]
	used_question_ids.append(question.id)
	return question


func _show_next_question() -> void:
	current_question_num += 1
	player_answers.clear()
	has_answered = false

	current_question = _get_random_question()

	var data = {
		"type": "trivia_question",
		"question_num": current_question_num,
		"total_questions": QUESTIONS_PER_ROUND,
		"category": current_question.get("category", "General"),
		"question": current_question.get("question", ""),
		"answers": current_question.get("answers", []),
		"time_limit": QUESTION_TIME
	}
	NetworkManager.broadcast(data)
	_apply_question(data)


func _calculate_points(time_taken: float) -> int:
	# Base 100 points + speed bonus up to 100 points
	var time_ratio = max(0, (QUESTION_TIME - time_taken) / QUESTION_TIME)
	var speed_bonus = int(time_ratio * MAX_SPEED_BONUS)
	return BASE_POINTS + speed_bonus


func _reveal_answer() -> void:
	current_phase = GamePhase.REVEAL

	var correct_index = current_question.get("correct", 0)
	var correct_answer = current_question.get("answers", [])[correct_index] if current_question.get("answers", []).size() > correct_index else ""

	var player_results: Dictionary = {}

	for player_id in player_order:
		if player_id in player_answers:
			var answer_data = player_answers[player_id]
			var is_correct = answer_data.answer_index == correct_index
			var points = _calculate_points(answer_data.time_taken) if is_correct else 0

			if is_correct:
				player_scores[player_id] = player_scores.get(player_id, 0) + points

			player_results[player_id] = {
				"answered": answer_data.answer_index,
				"correct": is_correct,
				"points": points,
				"time": answer_data.time_taken
			}
		else:
			# Player didn't answer
			player_results[player_id] = {
				"answered": -1,
				"correct": false,
				"points": 0,
				"time": null
			}

	var data = {
		"type": "trivia_reveal",
		"correct_answer_index": correct_index,
		"correct_answer": correct_answer,
		"player_results": player_results,
		"scores": player_scores.duplicate()
	}
	NetworkManager.broadcast(data)
	_apply_reveal(data)


func _show_leaderboard() -> void:
	current_phase = GamePhase.LEADERBOARD

	# Build standings array sorted by score
	var standings: Array = []
	for player_id in player_order:
		var player = GameManager.players.get(player_id, {"name": "Unknown"})
		standings.append({
			"player_id": player_id,
			"name": player.name,
			"score": player_scores.get(player_id, 0)
		})

	standings.sort_custom(func(a, b): return a.score > b.score)

	# Add rank
	for i in standings.size():
		standings[i]["rank"] = i + 1

	var data = {
		"type": "trivia_leaderboard",
		"standings": standings,
		"question_num": current_question_num,
		"total_questions": QUESTIONS_PER_ROUND
	}
	NetworkManager.broadcast(data)
	_apply_leaderboard(data)


func _end_round() -> void:
	current_phase = GamePhase.ROUND_END

	# Find round winner
	var round_winner_id = ""
	var highest_score = -1
	for player_id in player_scores:
		if player_scores[player_id] > highest_score:
			highest_score = player_scores[player_id]
			round_winner_id = player_id

	var round_winner_name = GameManager.players[round_winner_id].name if round_winner_id in GameManager.players else "Nobody"

	var data = {
		"type": "trivia_round_end",
		"round": current_round,
		"round_winner": round_winner_id,
		"round_winner_name": round_winner_name,
		"round_scores": player_scores.duplicate(),
		"is_final_round": current_round >= total_rounds
	}
	NetworkManager.broadcast(data)
	_apply_round_end(data)


func _end_game() -> void:
	current_phase = GamePhase.GAME_END

	var winner_id = ""
	var highest_score = -1
	for player_id in player_scores:
		if player_scores[player_id] > highest_score:
			highest_score = player_scores[player_id]
			winner_id = player_id

	var winner_name = GameManager.players[winner_id].name if winner_id in GameManager.players else "Nobody"

	# Update global scores
	for player_id in player_scores:
		GameManager.update_score(player_id, player_scores[player_id])

	var data = {
		"type": "trivia_end",
		"final_scores": player_scores.duplicate(),
		"winner_id": winner_id,
		"winner_name": winner_name
	}
	NetworkManager.broadcast(data)
	_apply_game_end(data)


# ============ UI METHODS ============

func _hide_all_sections() -> void:
	answers_section.visible = false
	result_section.visible = false
	leaderboard_section.visible = false
	ready_section.visible = false


func _show_ready_ui(title: String, button_text: String) -> void:
	_hide_all_sections()
	ready_section.visible = true

	question_label.text = title
	category_label.text = ""
	ready_button.text = button_text
	ready_button.disabled = is_ready
	ready_status.text = "0/%d ready" % player_order.size()
	timer_label.text = ""

	_update_players_display()


func _show_question_ui() -> void:
	_hide_all_sections()
	answers_section.visible = true

	category_label.text = current_question.get("category", "General")
	question_label.text = current_question.get("question", "")
	phase_label.text = "QUESTION %d/%d" % [current_question_num, QUESTIONS_PER_ROUND]
	round_label.text = "Round %d/%d" % [current_round, total_rounds]

	# Create answer buttons
	_populate_answer_buttons()

	answers_status.text = "0/%d answered" % player_order.size()

	question_start_time = Time.get_ticks_msec() / 1000.0
	_start_timer(QUESTION_TIME)
	_update_players_display()


func _populate_answer_buttons() -> void:
	for child in answer_buttons.get_children():
		child.queue_free()

	var answers = current_question.get("answers", [])
	var labels = ["A", "B", "C", "D"]

	for i in answers.size():
		var btn = Button.new()
		btn.text = "%s: %s" % [labels[i], answers[i]]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 18)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_answer_button_pressed.bind(i))
		answer_buttons.add_child(btn)


func _show_result_ui(player_result: Dictionary, correct_answer: String) -> void:
	_hide_all_sections()
	result_section.visible = true

	var is_correct = player_result.get("correct", false)
	var points = player_result.get("points", 0)
	var answered = player_result.get("answered", -1)

	if answered == -1:
		result_label.text = "Time's Up!"
		result_label.add_theme_color_override("font_color", Color(1, 0.5, 0.2, 1))
		points_label.text = "0 points"
	elif is_correct:
		result_label.text = "Correct!"
		result_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		points_label.text = "+%d points" % points
	else:
		result_label.text = "Wrong!"
		result_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		points_label.text = "0 points"

	correct_answer_label.text = "Answer: %s" % correct_answer
	phase_label.text = "RESULT"

	_update_players_display()


func _show_leaderboard_ui(standings: Array) -> void:
	_hide_all_sections()
	leaderboard_section.visible = true

	for child in leaderboard_list.get_children():
		child.queue_free()

	for entry in standings:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 40)

		var rank_label = Label.new()
		rank_label.text = "#%d" % entry.rank
		rank_label.custom_minimum_size = Vector2(50, 0)
		rank_label.add_theme_font_size_override("font_size", 20)
		if entry.rank == 1:
			rank_label.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))
		elif entry.rank == 2:
			rank_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))
		elif entry.rank == 3:
			rank_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2, 1))
		row.add_child(rank_label)

		var name_label = Label.new()
		name_label.text = entry.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 20)
		row.add_child(name_label)

		var score_label = Label.new()
		score_label.text = str(entry.score)
		score_label.custom_minimum_size = Vector2(80, 0)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.add_theme_font_size_override("font_size", 20)
		score_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
		row.add_child(score_label)

		leaderboard_list.add_child(row)

	phase_label.text = "LEADERBOARD"
	question_label.text = "Question %d/%d Complete" % [current_question_num, QUESTIONS_PER_ROUND]
	category_label.text = ""


func _update_players_display() -> void:
	for child in players_status.get_children():
		child.queue_free()

	for player_id in player_order:
		var player = GameManager.players.get(player_id, {"name": "Unknown", "character": 0})
		var score = player_scores.get(player_id, 0)
		var is_player_ready = players_ready.get(player_id, false)
		var has_player_answered = player_id in player_answers

		var container = VBoxContainer.new()
		container.custom_minimum_size = Vector2(60, 80)
		container.add_theme_constant_override("separation", 3)

		var char_container = Control.new()
		char_container.custom_minimum_size = Vector2(40, 40)

		var char_data = GameManager.get_character_data(player.character)
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(40, 40)
		color_rect.size = Vector2(40, 40)
		color_rect.color = char_data.color
		char_container.add_child(color_rect)

		# Ready/Answered indicator
		if (is_player_ready and current_phase == GamePhase.PRE_ROUND) or (has_player_answered and current_phase == GamePhase.QUESTION):
			var check_label = Label.new()
			check_label.text = "✓"
			check_label.add_theme_font_size_override("font_size", 24)
			check_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
			check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			check_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			check_label.size = Vector2(40, 40)
			char_container.add_child(check_label)
			color_rect.color = color_rect.color.lightened(0.3)

		container.add_child(char_container)

		var name_label = Label.new()
		name_label.text = player.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		container.add_child(name_label)

		var score_label = Label.new()
		score_label.text = str(score)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", 13)
		score_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
		container.add_child(score_label)

		players_status.add_child(container)


# ============ TIMER METHODS ============

func _start_timer(duration: int) -> void:
	time_remaining = duration
	_update_timer_display()
	phase_timer.wait_time = duration
	phase_timer.start()
	tick_timer.start()


func _on_tick() -> void:
	time_remaining -= 1
	_update_timer_display()


func _update_timer_display() -> void:
	timer_label.text = "%ds" % time_remaining

	if time_remaining <= 5:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	elif time_remaining <= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))


func _on_phase_timeout() -> void:
	tick_timer.stop()

	if current_phase == GamePhase.QUESTION:
		if GameManager.is_host:
			_reveal_answer()


# ============ INPUT HANDLERS ============

func _on_answer_button_pressed(answer_index: int) -> void:
	if has_answered:
		return

	has_answered = true
	var time_taken = (Time.get_ticks_msec() / 1000.0) - question_start_time

	# Disable all buttons
	for child in answer_buttons.get_children():
		if child is Button:
			child.disabled = true

	# Highlight selected answer
	var buttons = answer_buttons.get_children()
	if answer_index < buttons.size():
		buttons[answer_index].add_theme_color_override("font_color", Color(0.3, 0.7, 1, 1))

	var data = {
		"type": "trivia_answer",
		"player_id": GameManager.local_player_id,
		"answer_index": answer_index,
		"time_taken": time_taken
	}

	if GameManager.is_host:
		_handle_answer(data)
	else:
		NetworkManager.send_to_server(data)


func _on_ready_pressed() -> void:
	if is_ready:
		return

	is_ready = true
	ready_button.disabled = true

	var data = {
		"type": "trivia_ready",
		"player_id": GameManager.local_player_id
	}

	if GameManager.is_host:
		_handle_ready(data)
	else:
		NetworkManager.send_to_server(data)


# ============ MESSAGE HANDLING ============

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"trivia_init":
			_apply_init(data)
		"trivia_pre_round":
			_apply_pre_round(data)
		"trivia_ready":
			if GameManager.is_host:
				_handle_ready(data)
		"trivia_ready_status":
			_apply_ready_status(data)
		"trivia_question":
			_apply_question(data)
		"trivia_answer":
			if GameManager.is_host:
				_handle_answer(data)
		"trivia_answer_count":
			_apply_answer_count(data)
		"trivia_reveal":
			_apply_reveal(data)
		"trivia_leaderboard":
			_apply_leaderboard(data)
		"trivia_round_end":
			_apply_round_end(data)
		"trivia_end":
			_apply_game_end(data)


func _apply_init(data: Dictionary) -> void:
	player_order = data.get("player_order", [])
	total_rounds = data.get("total_rounds", 3)
	var scores_data = data.get("scores", {})
	player_scores.clear()
	players_ready.clear()
	for pid in player_order:
		player_scores[pid] = scores_data.get(pid, 0)
		players_ready[pid] = false
	_update_players_display()


func _apply_pre_round(data: Dictionary) -> void:
	current_phase = GamePhase.PRE_ROUND
	var next_round = data.get("round", 1)
	total_rounds = data.get("total_rounds", 3)
	is_ready = false

	var ready_list = data.get("ready_players", [])
	for pid in players_ready:
		players_ready[pid] = pid in ready_list

	phase_label.text = "GET READY"
	round_label.text = "Round %d/%d" % [next_round, total_rounds]

	var title = "Round %d - %d Questions" % [next_round, QUESTIONS_PER_ROUND]
	if next_round == 1:
		title = "Ready to Start?\n%d Questions" % QUESTIONS_PER_ROUND
	_show_ready_ui(title, "Ready!")

	ready_status.text = "%d/%d ready" % [ready_list.size(), player_order.size()]


func _handle_ready(data: Dictionary) -> void:
	var player_id = data.get("player_id", "")
	players_ready[player_id] = true

	var ready_list = []
	for pid in players_ready:
		if players_ready[pid]:
			ready_list.append(pid)

	var status_data = {
		"type": "trivia_ready_status",
		"ready_players": ready_list,
		"ready_count": ready_list.size(),
		"players_needed": player_order.size()
	}
	NetworkManager.broadcast(status_data)
	_apply_ready_status(status_data)

	if ready_list.size() >= player_order.size():
		if current_phase == GamePhase.PRE_ROUND:
			_start_round()


func _apply_ready_status(data: Dictionary) -> void:
	var ready_list = data.get("ready_players", [])
	var ready_count = data.get("ready_count", 0)
	var needed = data.get("players_needed", player_order.size())

	for pid in players_ready:
		players_ready[pid] = pid in ready_list

	ready_status.text = "%d/%d ready" % [ready_count, needed]
	_update_players_display()


func _apply_question(data: Dictionary) -> void:
	current_phase = GamePhase.QUESTION
	current_question_num = data.get("question_num", 1)
	current_question = {
		"category": data.get("category", "General"),
		"question": data.get("question", ""),
		"answers": data.get("answers", [])
	}
	has_answered = false
	player_answers.clear()
	_show_question_ui()


func _handle_answer(data: Dictionary) -> void:
	var player_id = data.get("player_id", "")
	var answer_index = data.get("answer_index", -1)
	var time_taken = data.get("time_taken", QUESTION_TIME)

	player_answers[player_id] = {
		"answer_index": answer_index,
		"time_taken": time_taken
	}

	var count_data = {
		"type": "trivia_answer_count",
		"answered": player_answers.size(),
		"total": player_order.size()
	}
	NetworkManager.broadcast(count_data)
	_apply_answer_count(count_data)

	# If everyone has answered, reveal immediately
	if player_answers.size() >= player_order.size():
		phase_timer.stop()
		tick_timer.stop()
		_reveal_answer()


func _apply_answer_count(data: Dictionary) -> void:
	var answered = data.get("answered", 0)
	var total = data.get("total", 0)
	answers_status.text = "%d/%d answered" % [answered, total]
	_update_players_display()


func _apply_reveal(data: Dictionary) -> void:
	current_phase = GamePhase.REVEAL
	tick_timer.stop()
	phase_timer.stop()

	var correct_answer = data.get("correct_answer", "")
	var player_results = data.get("player_results", {})
	var scores = data.get("scores", {})

	for pid in scores:
		player_scores[pid] = scores[pid]

	# Show local player's result
	var my_result = player_results.get(GameManager.local_player_id, {"answered": -1, "correct": false, "points": 0})
	_show_result_ui(my_result, correct_answer)

	# Host triggers leaderboard after delay
	if GameManager.is_host:
		await get_tree().create_timer(REVEAL_TIME).timeout
		_show_leaderboard()


func _apply_leaderboard(data: Dictionary) -> void:
	current_phase = GamePhase.LEADERBOARD
	var standings = data.get("standings", [])
	current_question_num = data.get("question_num", 0)

	_show_leaderboard_ui(standings)

	# Host triggers next question or round end after delay
	if GameManager.is_host:
		await get_tree().create_timer(LEADERBOARD_TIME).timeout
		if current_question_num >= QUESTIONS_PER_ROUND:
			_end_round()
		else:
			_show_next_question()


func _apply_round_end(data: Dictionary) -> void:
	current_phase = GamePhase.ROUND_END
	var scores = data.get("round_scores", {})
	var is_final = data.get("is_final_round", false)
	var winner_name = data.get("round_winner_name", "")

	for pid in scores:
		player_scores[pid] = scores[pid]
	_update_players_display()

	_hide_all_sections()
	question_label.text = "Round %d Complete!\nWinner: %s" % [data.get("round", current_round), winner_name]
	category_label.text = ""
	phase_label.text = "ROUND END"

	if GameManager.is_host:
		await get_tree().create_timer(3.0).timeout
		if is_final:
			_end_game()
		else:
			_show_pre_round()


func _apply_game_end(data: Dictionary) -> void:
	current_phase = GamePhase.GAME_END
	tick_timer.stop()
	phase_timer.stop()

	var winner_name = data.get("winner_name", "Nobody")
	var final_scores = data.get("final_scores", {})

	for pid in final_scores:
		player_scores[pid] = final_scores[pid]

	_hide_all_sections()
	question_label.text = "Game Over!\n%s Wins!" % winner_name
	category_label.text = ""
	phase_label.text = "GAME OVER"

	_update_players_display()

	await get_tree().create_timer(5.0).timeout
	if GameManager.is_host:
		get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")
