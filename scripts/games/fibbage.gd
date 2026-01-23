extends Control

# UI References - Header
@onready var timer_label: Label = $VBox/Header/TimerLabel
@onready var round_label: Label = $VBox/Header/RoundLabel
@onready var phase_label: Label = $VBox/Header/PhaseLabel

# UI References - Prompt Section
@onready var prompt_section: PanelContainer = $VBox/PromptSection
@onready var prompt_label: Label = $VBox/PromptSection/PromptLabel

# UI References - Writing Section
@onready var writing_section: VBoxContainer = $VBox/WritingSection
@onready var answer_input: TextEdit = $VBox/WritingSection/AnswerInput
@onready var submit_button: Button = $VBox/WritingSection/SubmitButton
@onready var answers_status: Label = $VBox/WritingSection/AnswersStatus

# UI References - Voting Section
@onready var voting_section: VBoxContainer = $VBox/VotingSection
@onready var vote_instruction: Label = $VBox/VotingSection/VoteInstruction
@onready var vote_buttons: GridContainer = $VBox/VotingSection/VoteButtons
@onready var votes_status: Label = $VBox/VotingSection/VotesStatus

# UI References - Reveal Section
@onready var reveal_section: VBoxContainer = $VBox/RevealSection
@onready var reveal_answer: Label = $VBox/RevealSection/RevealAnswer
@onready var reveal_results: VBoxContainer = $VBox/RevealSection/RevealResults

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
const WRITING_TIME: int = 60
const VOTING_TIME: int = 30
const REVEAL_TIME: int = 5
const MIN_PLAYERS: int = 3
const POINTS_CORRECT: int = 200
const POINTS_FOOLED: int = 100

# Game State
enum GamePhase { WAITING, PRE_ROUND, WRITING, VOTING, REVEAL, ROUND_END, GAME_END }
var current_phase: GamePhase = GamePhase.WAITING
var current_round: int = 0
var total_rounds: int = 3

# Player Management
var player_order: Array = []
var player_scores: Dictionary = {}
var players_ready: Dictionary = {}

# Round Data
var current_question: Dictionary = {}
var player_answers: Dictionary = {}  # {player_id: "fake answer"}
var all_answers: Array = []  # [{id, text, is_real, author_id}]
var player_votes: Dictionary = {}  # {player_id: answer_id}

# Question Data
var questions: Array = []
var used_questions: Array = []

var time_remaining: int = 0
var has_submitted_answer: bool = false
var has_voted: bool = false
var is_ready: bool = false


func _ready() -> void:
	_load_questions()
	_connect_signals()
	_setup_timers()
	call_deferred("_initialize_game")


func _load_questions() -> void:
	var file = FileAccess.open("res://data/prompts/fibbage_questions.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json and json.has("questions"):
			questions = json.questions
		file.close()

	if questions.is_empty():
		questions = [
			{"text": "The world's largest _____ weighs over 500 pounds.", "answer": "potato", "category": "food"},
			{"text": "In 1932, Australia declared war on _____.", "answer": "emus", "category": "history"}
		]


func _connect_signals() -> void:
	NetworkManager.message_received.connect(_on_message_received)
	submit_button.pressed.connect(_on_submit_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	answer_input.focus_entered.connect(_on_input_focus)


func _on_input_focus() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(answer_input.text, Rect2())


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
			"type": "fibbage_init",
			"player_order": player_order,
			"total_rounds": total_rounds,
			"scores": player_scores
		}
		NetworkManager.broadcast(init_data)
		_apply_init(init_data)

		_show_pre_round()
	else:
		_hide_all_sections()
		prompt_label.text = "Waiting for game to start..."


func _show_pre_round() -> void:
	current_phase = GamePhase.PRE_ROUND
	_reset_ready_state()

	var next_round = current_round + 1
	var data = {
		"type": "fibbage_pre_round",
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
	player_answers.clear()
	all_answers.clear()
	player_votes.clear()

	# Pick a random unused question
	var available = []
	for q in questions:
		if q not in used_questions:
			available.append(q)

	if available.is_empty():
		used_questions.clear()
		available = questions

	current_question = available[randi() % available.size()]
	used_questions.append(current_question)

	_start_writing_phase()


func _start_writing_phase() -> void:
	current_phase = GamePhase.WRITING
	has_submitted_answer = false

	var data = {
		"type": "fibbage_question",
		"question": current_question.get("text", ""),
		"category": current_question.get("category", ""),
		"round": current_round,
		"total_rounds": total_rounds,
		"time_limit": WRITING_TIME
	}
	NetworkManager.broadcast(data)
	# Host just shows UI directly - don't call _apply_question which would overwrite current_question
	_show_writing_ui()


func _start_voting_phase() -> void:
	current_phase = GamePhase.VOTING

	# Build answer list: all fake answers + the real answer
	all_answers.clear()
	var answer_id = 0

	# Add fake answers from players
	for player_id in player_answers:
		all_answers.append({
			"id": answer_id,
			"text": player_answers[player_id],
			"is_real": false,
			"author_id": player_id
		})
		answer_id += 1

	# Add the real answer
	var real_answer_text = current_question.get("answer", "unknown")
	all_answers.append({
		"id": answer_id,
		"text": real_answer_text,
		"is_real": true,
		"author_id": ""
	})

	# Shuffle so real answer isn't always last
	all_answers.shuffle()

	# Reassign IDs after shuffle
	for i in range(all_answers.size()):
		all_answers[i]["id"] = i

	player_votes.clear()
	has_voted = false

	# Build answers array for broadcast (without is_real and author_id)
	var answers_for_broadcast: Array = []
	for answer in all_answers:
		answers_for_broadcast.append({
			"id": answer.get("id", 0),
			"text": answer.get("text", "")
		})

	var data = {
		"type": "fibbage_vote_start",
		"question": current_question.get("text", ""),
		"answers": answers_for_broadcast,
		"time_limit": VOTING_TIME
	}
	NetworkManager.broadcast(data)
	_apply_vote_start(data)


func _reveal_answer() -> void:
	current_phase = GamePhase.REVEAL

	# Calculate points
	var points_awarded: Dictionary = {}
	var correct_guessers: Array = []
	var fooled_by: Dictionary = {}  # {author_id: [list of fooled player ids]}

	# Process votes
	for voter_id in player_votes:
		var voted_for_id = player_votes[voter_id]

		# Find which answer they voted for
		var voted_answer = null
		for answer in all_answers:
			if answer.get("id", -1) == voted_for_id:
				voted_answer = answer
				break

		if voted_answer == null:
			continue

		if voted_answer.get("is_real", false):
			# Correct guess
			correct_guessers.append(voter_id)
			points_awarded[voter_id] = points_awarded.get(voter_id, 0) + POINTS_CORRECT
			player_scores[voter_id] = player_scores.get(voter_id, 0) + POINTS_CORRECT
		else:
			# Fooled by someone's fake answer
			var author_id = voted_answer.get("author_id", "")
			if author_id != "" and author_id != voter_id:  # Can't fool yourself
				if author_id not in fooled_by:
					fooled_by[author_id] = []
				fooled_by[author_id].append(voter_id)
				points_awarded[author_id] = points_awarded.get(author_id, 0) + POINTS_FOOLED
				player_scores[author_id] = player_scores.get(author_id, 0) + POINTS_FOOLED

	var data = {
		"type": "fibbage_reveal",
		"question": current_question.get("text", ""),
		"real_answer": current_question.get("answer", ""),
		"all_answers": all_answers,
		"votes": player_votes.duplicate(),
		"correct_guessers": correct_guessers,
		"fooled_by": fooled_by,
		"points_awarded": points_awarded,
		"scores": player_scores.duplicate()
	}
	NetworkManager.broadcast(data)
	_apply_reveal(data)


func _end_round() -> void:
	current_phase = GamePhase.ROUND_END

	var data = {
		"type": "fibbage_round_end",
		"round": current_round,
		"total_scores": player_scores.duplicate(),
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

	for player_id in player_scores:
		GameManager.update_score(player_id, player_scores[player_id])

	var data = {
		"type": "fibbage_end",
		"final_scores": player_scores.duplicate(),
		"winner_id": winner_id,
		"winner_name": winner_name
	}
	NetworkManager.broadcast(data)
	_apply_game_end(data)


# ============ UI METHODS ============

func _hide_all_sections() -> void:
	writing_section.visible = false
	voting_section.visible = false
	reveal_section.visible = false
	ready_section.visible = false


func _show_ready_ui(title: String, button_text: String) -> void:
	_hide_all_sections()
	ready_section.visible = true

	prompt_label.text = title
	prompt_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	ready_button.text = button_text
	ready_button.disabled = is_ready
	ready_status.text = "0/%d ready" % player_order.size()
	timer_label.text = ""

	_update_players_display()


func _show_writing_ui() -> void:
	_hide_all_sections()
	writing_section.visible = true

	prompt_label.text = current_question.text
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	answer_input.text = ""
	answer_input.editable = true
	submit_button.disabled = false
	answers_status.text = "0/%d lies submitted" % player_order.size()
	phase_label.text = "LIE"
	round_label.text = "Round %d/%d" % [current_round, total_rounds]

	_start_timer(WRITING_TIME)
	_update_players_display()


func _show_voting_ui(answers: Array) -> void:
	_hide_all_sections()
	voting_section.visible = true

	vote_instruction.text = "Which answer is the TRUTH?"
	phase_label.text = "VOTE"

	# Clear old buttons
	for child in vote_buttons.get_children():
		child.queue_free()

	# Create vote buttons for each answer
	for answer in answers:
		var btn = Button.new()
		btn.text = answer.get("text", "???")
		btn.custom_minimum_size = Vector2(280, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_vote_button_pressed.bind(answer.get("id", 0)))
		vote_buttons.add_child(btn)

	votes_status.text = "0/%d votes" % player_order.size()


func _show_reveal_ui(real_answer: String, correct: Array, fooled_by: Dictionary, _points: Dictionary) -> void:
	_hide_all_sections()
	reveal_section.visible = true

	reveal_answer.text = 'The truth: "%s"' % real_answer
	phase_label.text = "REVEAL"

	# Clear old results
	for child in reveal_results.get_children():
		child.queue_free()

	# Show who guessed correctly
	if correct.size() > 0:
		for player_id in correct:
			var player_name = GameManager.players[player_id].name if player_id in GameManager.players else "Unknown"
			var lbl = Label.new()
			lbl.text = "%s found the truth! (+%d pts)" % [player_name, POINTS_CORRECT]
			lbl.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
			lbl.add_theme_font_size_override("font_size", 16)
			reveal_results.add_child(lbl)
	else:
		var lbl = Label.new()
		lbl.text = "Nobody found the truth!"
		lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		lbl.add_theme_font_size_override("font_size", 16)
		reveal_results.add_child(lbl)

	# Show who fooled whom
	for author_id in fooled_by:
		var author_name = GameManager.players[author_id].name if author_id in GameManager.players else "Unknown"
		var fooled_count = fooled_by[author_id].size()
		var lbl = Label.new()
		lbl.text = "%s fooled %d player(s)! (+%d pts)" % [author_name, fooled_count, fooled_count * POINTS_FOOLED]
		lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
		lbl.add_theme_font_size_override("font_size", 16)
		reveal_results.add_child(lbl)

	_update_players_display()


func _update_players_display() -> void:
	for child in players_status.get_children():
		child.queue_free()

	for player_id in player_order:
		var player = GameManager.players.get(player_id, {"name": "Unknown", "character": 0})
		var score = player_scores.get(player_id, 0)
		var is_player_ready = players_ready.get(player_id, false)

		var container = VBoxContainer.new()
		container.custom_minimum_size = Vector2(60, 80)
		container.add_theme_constant_override("separation", 3)

		var char_container = Control.new()
		char_container.custom_minimum_size = Vector2(40, 40)

		var char_data = GameManager.get_character_data(player.character)
		var char_display: Control
		var sprite_path = char_data.get("sprite")
		if sprite_path and ResourceLoader.exists(sprite_path):
			var texture_rect = TextureRect.new()
			texture_rect.texture = load(sprite_path)
			texture_rect.custom_minimum_size = Vector2(40, 40)
			texture_rect.size = Vector2(40, 40)
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			char_display = texture_rect
		else:
			var color_rect = ColorRect.new()
			color_rect.custom_minimum_size = Vector2(40, 40)
			color_rect.size = Vector2(40, 40)
			color_rect.color = char_data.color
			char_display = color_rect
		char_container.add_child(char_display)

		if is_player_ready and current_phase == GamePhase.PRE_ROUND:
			var check_label = Label.new()
			check_label.text = "✓"
			check_label.add_theme_font_size_override("font_size", 24)
			check_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
			check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			check_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			check_label.size = Vector2(40, 40)
			char_container.add_child(check_label)
			char_display.modulate = Color(1.3, 1.3, 1.3, 1.0)

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

	if time_remaining <= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	elif time_remaining <= 20:
		timer_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))


func _on_phase_timeout() -> void:
	tick_timer.stop()

	match current_phase:
		GamePhase.WRITING:
			if GameManager.is_host:
				_start_voting_phase()
		GamePhase.VOTING:
			if GameManager.is_host:
				_reveal_answer()


# ============ INPUT HANDLERS ============

func _on_submit_pressed() -> void:
	if has_submitted_answer:
		return

	var answer = answer_input.text.strip_edges()
	if answer.is_empty():
		return

	has_submitted_answer = true
	submit_button.disabled = true
	answer_input.editable = false

	var data = {
		"type": "fibbage_answer",
		"player_id": GameManager.local_player_id,
		"answer": answer
	}

	if GameManager.is_host:
		_handle_answer(data)
	else:
		NetworkManager.send_to_server(data)


func _on_vote_button_pressed(answer_id: int) -> void:
	if has_voted:
		return

	has_voted = true

	for child in vote_buttons.get_children():
		if child is Button:
			child.disabled = true

	var data = {
		"type": "fibbage_vote",
		"player_id": GameManager.local_player_id,
		"answer_id": answer_id
	}

	if GameManager.is_host:
		_handle_vote(data)
	else:
		NetworkManager.send_to_server(data)


func _on_ready_pressed() -> void:
	if is_ready:
		return

	is_ready = true
	ready_button.disabled = true

	var data = {
		"type": "fibbage_ready",
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
		"fibbage_init":
			_apply_init(data)
		"fibbage_pre_round":
			_apply_pre_round(data)
		"fibbage_ready":
			if GameManager.is_host:
				_handle_ready(data)
		"fibbage_ready_status":
			_apply_ready_status(data)
		"fibbage_question":
			_apply_question(data)
		"fibbage_answer":
			if GameManager.is_host:
				_handle_answer(data)
		"fibbage_answer_rejected":
			_apply_answer_rejected(data)
		"fibbage_answer_received":
			_apply_answer_status(data)
		"fibbage_vote_start":
			_apply_vote_start(data)
		"fibbage_vote":
			if GameManager.is_host:
				_handle_vote(data)
		"fibbage_vote_received":
			_apply_vote_status(data)
		"fibbage_reveal":
			_apply_reveal(data)
		"fibbage_round_end":
			_apply_round_end(data)
		"fibbage_end":
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

	var title = "Round %d" % next_round
	if next_round == 1:
		title = "Ready to Lie?"
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
		"type": "fibbage_ready_status",
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
	current_question = {"text": data.get("question", ""), "category": data.get("category", "")}
	current_round = data.get("round", 1)
	total_rounds = data.get("total_rounds", 3)
	has_submitted_answer = false
	_show_writing_ui()


func _handle_answer(data: Dictionary) -> void:
	var player_id = data.get("player_id", "")
	var answer = data.get("answer", "")

	# Check if the answer matches the real answer (case-insensitive)
	var real_answer = current_question.get("answer", "").strip_edges().to_lower()
	var submitted = answer.strip_edges().to_lower()

	if submitted == real_answer:
		# Reject the answer - it matches the truth!
		var reject_data = {
			"type": "fibbage_answer_rejected",
			"player_id": player_id,
			"reason": "Too truthful! Try a different lie."
		}
		if player_id == GameManager.local_player_id:
			_apply_answer_rejected(reject_data)
		else:
			NetworkManager.send_to_client(int(player_id), reject_data)
		return

	player_answers[player_id] = answer

	var status_data = {
		"type": "fibbage_answer_received",
		"player_id": player_id,
		"answers_received": player_answers.size(),
		"answers_needed": player_order.size()
	}
	NetworkManager.broadcast(status_data)
	_apply_answer_status(status_data)

	if player_answers.size() >= player_order.size():
		phase_timer.stop()
		tick_timer.stop()
		_start_voting_phase()


func _apply_answer_status(data: Dictionary) -> void:
	var received = data.get("answers_received", 0)
	var needed = data.get("answers_needed", 0)
	answers_status.text = "%d/%d lies submitted" % [received, needed]


func _apply_answer_rejected(data: Dictionary) -> void:
	# Re-enable the input so player can try again
	has_submitted_answer = false
	submit_button.disabled = false
	answer_input.editable = true
	answer_input.text = ""
	answers_status.text = data.get("reason", "Too truthful! Try a different lie.")
	answers_status.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))


func _apply_vote_start(data: Dictionary) -> void:
	current_question.text = data.get("question", "")
	var answers = data.get("answers", [])
	has_voted = false
	prompt_label.text = current_question.text
	_show_voting_ui(answers)
	_start_timer(data.get("time_limit", VOTING_TIME))


func _handle_vote(data: Dictionary) -> void:
	var voter_id = data.get("player_id", "")
	var answer_id = data.get("answer_id", -1)

	player_votes[voter_id] = answer_id

	var status_data = {
		"type": "fibbage_vote_received",
		"votes_received": player_votes.size(),
		"votes_needed": player_order.size()
	}
	NetworkManager.broadcast(status_data)
	_apply_vote_status(status_data)

	if player_votes.size() >= player_order.size():
		phase_timer.stop()
		tick_timer.stop()
		_reveal_answer()


func _apply_vote_status(data: Dictionary) -> void:
	var received = data.get("votes_received", 0)
	var needed = data.get("votes_needed", 0)
	votes_status.text = "%d/%d votes" % [received, needed]


func _apply_reveal(data: Dictionary) -> void:
	tick_timer.stop()
	phase_timer.stop()

	var real_answer = data.get("real_answer", "")
	var correct = data.get("correct_guessers", [])
	var fooled_by = data.get("fooled_by", {})
	var points = data.get("points_awarded", {})
	var scores = data.get("scores", {})

	for pid in scores:
		player_scores[pid] = scores[pid]

	_show_reveal_ui(real_answer, correct, fooled_by, points)

	if GameManager.is_host:
		await get_tree().create_timer(REVEAL_TIME).timeout
		_end_round()


func _apply_round_end(data: Dictionary) -> void:
	var scores = data.get("total_scores", {})
	var is_final = data.get("is_final_round", false)

	for pid in scores:
		player_scores[pid] = scores[pid]
	_update_players_display()

	_hide_all_sections()
	prompt_label.text = "Round %d Complete!" % data.get("round", current_round)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	phase_label.text = "ROUND END"

	if GameManager.is_host:
		await get_tree().create_timer(3.0).timeout
		if is_final:
			_end_game()
		else:
			_show_pre_round()


func _apply_game_end(data: Dictionary) -> void:
	tick_timer.stop()
	phase_timer.stop()

	var winner_name = data.get("winner_name", "Nobody")
	var final_scores = data.get("final_scores", {})

	for pid in final_scores:
		player_scores[pid] = final_scores[pid]

	_hide_all_sections()
	prompt_label.text = "Game Over!\n%s Wins!" % winner_name
	prompt_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	phase_label.text = "GAME OVER"

	_update_players_display()

	await get_tree().create_timer(5.0).timeout
	if GameManager.is_host:
		get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")
