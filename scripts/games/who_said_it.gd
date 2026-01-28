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
@onready var char_counter: Label = $VBox/WritingSection/CharCounter
@onready var answers_status: Label = $VBox/WritingSection/AnswersStatus

# UI References - Voting Section
@onready var voting_section: VBoxContainer = $VBox/VotingSection
@onready var answer_display: Label = $VBox/VotingSection/AnswerDisplay
@onready var your_answer_label: Label = $VBox/VotingSection/YourAnswerLabel
@onready var vote_buttons: GridContainer = $VBox/VotingSection/VoteButtons
@onready var votes_status: Label = $VBox/VotingSection/VotesStatus

# UI References - Reveal Section
@onready var reveal_section: VBoxContainer = $VBox/RevealSection
@onready var reveal_answer: Label = $VBox/RevealSection/RevealAnswer
@onready var reveal_author: Label = $VBox/RevealSection/RevealAuthor
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
const MAX_ANSWER_LENGTH: int = 250
const TIMEOUT_ANSWERS: Array = [
	"I fell asleep on my phone",
	"My dog ate my answer",
	"¯\\_(ツ)_/¯",
	"*crickets*",
	"I plead the fifth",
]
const TIE_MESSAGES: Array = [
	"It's a tie! Blame the judges!",
	"Dead heat! Friendship wins... this time.",
	"Tied! You're all equally suspicious.",
	"A tie! Nobody out-tricked anybody!",
]

# Game State
enum GamePhase { WAITING, PRE_ROUND, WRITING, VOTING, REVEAL, CONTINUE, ROUND_END, GAME_END }
var current_phase: GamePhase = GamePhase.WAITING
var current_round: int = 0
var total_rounds: int = 3

# Player Management
var player_order: Array = []
var player_scores: Dictionary = {}
var players_ready: Dictionary = {}

# Round Data
var current_prompt: String = ""
var player_answers: Dictionary = {}
var shuffled_answers: Array = []
var current_answer_index: int = 0
var player_votes: Dictionary = {}

# Prompt Data
var prompts: Dictionary = {}
var used_prompts: Array = []

var time_remaining: int = 0
var has_submitted_answer: bool = false
var my_submitted_answer: String = ""
var has_voted: bool = false
var is_ready: bool = false


func _ready() -> void:
	_load_prompts()
	_connect_signals()
	_setup_timers()
	call_deferred("_initialize_game")


func _load_prompts() -> void:
	var file = FileAccess.open("res://data/prompts/who_said_prompts.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json:
			prompts = json
		file.close()
	else:
		prompts = {
			"hypothetical": [
				"What would you do with a million dollars?",
				"If you could have dinner with anyone, who would it be?"
			],
			"personal": [
				"What's your most embarrassing moment?",
				"What's your secret talent?"
			]
		}


func _connect_signals() -> void:
	NetworkManager.message_received.connect(_on_message_received)
	submit_button.pressed.connect(_on_submit_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	answer_input.focus_entered.connect(_on_input_focus)
	answer_input.text_changed.connect(_on_answer_text_changed)


func _on_input_focus() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(answer_input.text, Rect2())


func _on_answer_text_changed() -> void:
	if answer_input.text.length() > MAX_ANSWER_LENGTH:
		answer_input.text = answer_input.text.substr(0, MAX_ANSWER_LENGTH)
		answer_input.set_caret_column(MAX_ANSWER_LENGTH)
		answer_input.set_caret_line(answer_input.get_line_count() - 1)
	_update_char_counter()


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
			"type": "whosaid_init",
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
		"type": "whosaid_pre_round",
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
	shuffled_answers.clear()
	current_answer_index = 0
	player_votes.clear()

	var categories = prompts.keys()
	var category = categories[randi() % categories.size()]
	var category_prompts = prompts[category]

	var available = []
	for p in category_prompts:
		if p not in used_prompts:
			available.append(p)

	if available.is_empty():
		used_prompts.clear()
		available = category_prompts

	current_prompt = available[randi() % available.size()]
	used_prompts.append(current_prompt)

	_start_writing_phase()


func _start_writing_phase() -> void:
	current_phase = GamePhase.WRITING
	has_submitted_answer = false
	my_submitted_answer = ""

	var data = {
		"type": "whosaid_prompt",
		"prompt": current_prompt,
		"round": current_round,
		"total_rounds": total_rounds,
		"time_limit": WRITING_TIME
	}
	NetworkManager.broadcast(data)
	_apply_prompt(data)


func _start_voting_phase() -> void:
	current_phase = GamePhase.VOTING

	shuffled_answers.clear()
	for player_id in player_answers:
		shuffled_answers.append({
			"author_id": player_id,
			"answer_text": player_answers[player_id]
		})
	shuffled_answers.shuffle()

	current_answer_index = 0
	_show_next_answer_for_voting()


func _show_next_answer_for_voting() -> void:
	if current_answer_index >= shuffled_answers.size():
		_end_round()
		return

	player_votes.clear()
	has_voted = false
	var answer_data = shuffled_answers[current_answer_index]
	var author_id = answer_data.author_id

	var voters = player_order.filter(func(pid): return pid != author_id)

	var data = {
		"type": "whosaid_vote_start",
		"answer_index": current_answer_index,
		"answer_total": shuffled_answers.size(),
		"answer_text": answer_data.answer_text,
		"voters": voters,
		"time_limit": VOTING_TIME
	}
	NetworkManager.broadcast(data)
	_apply_vote_start(data)


func _reveal_answer() -> void:
	current_phase = GamePhase.REVEAL

	var answer_data = shuffled_answers[current_answer_index]
	var author_id = answer_data.author_id
	var author_name = GameManager.players[author_id].name if author_id in GameManager.players else "Unknown"

	var correct_guessers: Array = []
	var fooled_players: Array = []
	var points_awarded: Dictionary = {}

	for voter_id in player_votes:
		var voted_for = player_votes[voter_id]
		if voted_for == author_id:
			correct_guessers.append(voter_id)
			points_awarded[voter_id] = points_awarded.get(voter_id, 0) + 50
			player_scores[voter_id] = player_scores.get(voter_id, 0) + 50
		else:
			fooled_players.append(voter_id)
			points_awarded[author_id] = points_awarded.get(author_id, 0) + 50
			player_scores[author_id] = player_scores.get(author_id, 0) + 50

	var data = {
		"type": "whosaid_reveal",
		"answer_index": current_answer_index,
		"answer_text": answer_data.answer_text,
		"author_id": author_id,
		"author_name": author_name,
		"votes": player_votes.duplicate(),
		"correct_guessers": correct_guessers,
		"fooled_players": fooled_players,
		"points_awarded": points_awarded,
		"scores": player_scores.duplicate(),
		"answers_remaining": shuffled_answers.size() - current_answer_index - 1
	}
	NetworkManager.broadcast(data)
	_apply_reveal(data)


func _show_continue_screen() -> void:
	current_phase = GamePhase.CONTINUE
	_reset_ready_state()

	var is_last_answer = current_answer_index >= shuffled_answers.size() - 1
	var data = {
		"type": "whosaid_continue",
		"answer_index": current_answer_index,
		"is_last_answer": is_last_answer,
		"ready_players": []
	}
	NetworkManager.broadcast(data)
	_apply_continue(data)


func _end_round() -> void:
	current_phase = GamePhase.ROUND_END

	var data = {
		"type": "whosaid_round_end",
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

	# Check for ties
	var winners = []
	for player_id in player_scores:
		if player_scores[player_id] == highest_score:
			winners.append(player_id)

	var winner_name: String
	if winners.size() > 1:
		winner_name = TIE_MESSAGES[randi() % TIE_MESSAGES.size()]
	else:
		winner_name = GameManager.players[winner_id].name if winner_id in GameManager.players else "Nobody"

	for player_id in player_scores:
		GameManager.update_score(player_id, player_scores[player_id])

	var data = {
		"type": "whosaid_end",
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

	prompt_label.text = current_prompt
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	answer_input.text = ""
	answer_input.editable = true
	submit_button.disabled = false
	answers_status.text = "0/%d answers received" % player_order.size()
	_update_char_counter()
	phase_label.text = "WRITE"
	round_label.text = "Round %d/%d" % [current_round, total_rounds]

	_start_timer(WRITING_TIME)
	_update_players_display()


func _update_char_counter() -> void:
	var remaining = MAX_ANSWER_LENGTH - answer_input.text.length()
	char_counter.text = "%d / %d" % [answer_input.text.length(), MAX_ANSWER_LENGTH]
	if remaining <= 25:
		char_counter.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	elif remaining <= 50:
		char_counter.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	else:
		char_counter.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))


func _show_voting_ui(answer_data: Dictionary, is_author: bool, answer_total: int = 0) -> void:
	_hide_all_sections()
	voting_section.visible = true

	answer_display.text = '"%s"' % answer_data.answer_text
	if answer_total > 0:
		phase_label.text = "VOTE  %d / %d" % [current_answer_index + 1, answer_total]
	else:
		phase_label.text = "VOTE"

	if is_author:
		your_answer_label.visible = true
		your_answer_label.text = "This is YOUR answer! Wait for votes..."
		vote_buttons.visible = false
	else:
		your_answer_label.visible = false
		vote_buttons.visible = true
		_populate_vote_buttons()

	var voters_count = player_order.size() - 1
	votes_status.text = "0/%d votes" % voters_count

	_start_timer(VOTING_TIME)


func _populate_vote_buttons() -> void:
	for child in vote_buttons.get_children():
		child.queue_free()

	# Show all players except yourself (you can't vote for yourself)
	# Players CAN vote for the author - that's the correct answer!
	for player_id in player_order:
		if player_id == GameManager.local_player_id:
			continue

		var player = GameManager.players.get(player_id, {"name": "Unknown", "character": 0})
		var btn = Button.new()
		btn.text = player.name
		btn.custom_minimum_size = Vector2(120, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_vote_button_pressed.bind(player_id))
		vote_buttons.add_child(btn)


func _show_reveal_ui(answer_data: Dictionary, author_id: String,
					 correct: Array, fooled: Array, _points: Dictionary) -> void:
	_hide_all_sections()
	reveal_section.visible = true

	var author_name = GameManager.players[author_id].name if author_id in GameManager.players else "Unknown"
	reveal_answer.text = '"%s"' % answer_data.answer_text
	reveal_author.text = "Written by: %s" % author_name
	phase_label.text = "REVEAL"

	for child in reveal_results.get_children():
		child.queue_free()

	for player_id in correct:
		var player_name = GameManager.players[player_id].name if player_id in GameManager.players else "Unknown"
		var lbl = Label.new()
		lbl.text = "%s guessed correctly (+50 pts)" % player_name
		lbl.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		lbl.add_theme_font_size_override("font_size", 16)
		reveal_results.add_child(lbl)

	if fooled.size() > 0:
		var lbl = Label.new()
		lbl.text = "%s fooled %d player(s) (+%d pts)" % [
			author_name, fooled.size(), fooled.size() * 50
		]
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

		# Character color with ready indicator
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

		# Ready checkmark overlay
		if is_player_ready and current_phase in [GamePhase.PRE_ROUND, GamePhase.CONTINUE]:
			var check_label = Label.new()
			check_label.text = "✓"
			check_label.add_theme_font_size_override("font_size", 24)
			check_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
			check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			check_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			check_label.size = Vector2(40, 40)
			char_container.add_child(check_label)

			# Add highlight effect
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
				for player_id in player_order:
					if player_id not in player_answers:
						player_answers[player_id] = TIMEOUT_ANSWERS[randi() % TIMEOUT_ANSWERS.size()]
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
	if answer.length() > MAX_ANSWER_LENGTH:
		answer = answer.substr(0, MAX_ANSWER_LENGTH)

	has_submitted_answer = true
	my_submitted_answer = answer
	submit_button.disabled = true
	answer_input.editable = false

	var data = {
		"type": "whosaid_answer",
		"player_id": GameManager.local_player_id,
		"answer": answer
	}

	if GameManager.is_host:
		_handle_answer(data)
	else:
		NetworkManager.send_to_server(data)


func _on_vote_button_pressed(voted_for_id: String) -> void:
	if has_voted:
		return

	has_voted = true

	for child in vote_buttons.get_children():
		if child is Button:
			child.disabled = true

	var data = {
		"type": "whosaid_vote",
		"player_id": GameManager.local_player_id,
		"voted_for": voted_for_id
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
		"type": "whosaid_ready",
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
		"whosaid_init":
			_apply_init(data)
		"whosaid_pre_round":
			_apply_pre_round(data)
		"whosaid_ready":
			if GameManager.is_host:
				_handle_ready(data)
		"whosaid_ready_status":
			_apply_ready_status(data)
		"whosaid_prompt":
			_apply_prompt(data)
		"whosaid_answer":
			if GameManager.is_host:
				_handle_answer(data)
		"whosaid_answer_received":
			_apply_answer_status(data)
		"whosaid_vote_start":
			_apply_vote_start(data)
		"whosaid_vote":
			if GameManager.is_host:
				_handle_vote(data)
		"whosaid_vote_received":
			_apply_vote_status(data)
		"whosaid_reveal":
			_apply_reveal(data)
		"whosaid_continue":
			_apply_continue(data)
		"whosaid_round_end":
			_apply_round_end(data)
		"whosaid_end":
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

	# Update ready states
	var ready_list = data.get("ready_players", [])
	for pid in players_ready:
		players_ready[pid] = pid in ready_list

	phase_label.text = "GET READY"
	round_label.text = "Round %d/%d" % [next_round, total_rounds]

	var title = "Round %d" % next_round
	if next_round == 1:
		title = "Ready to Start?"
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
		"type": "whosaid_ready_status",
		"ready_players": ready_list,
		"ready_count": ready_list.size(),
		"players_needed": player_order.size()
	}
	NetworkManager.broadcast(status_data)
	_apply_ready_status(status_data)

	# Check if all players are ready
	if ready_list.size() >= player_order.size():
		if current_phase == GamePhase.PRE_ROUND:
			_start_round()
		elif current_phase == GamePhase.CONTINUE:
			current_answer_index += 1
			if current_answer_index < shuffled_answers.size():
				_show_next_answer_for_voting()
			else:
				_end_round()


func _apply_ready_status(data: Dictionary) -> void:
	var ready_list = data.get("ready_players", [])
	var ready_count = data.get("ready_count", 0)
	var needed = data.get("players_needed", player_order.size())

	for pid in players_ready:
		players_ready[pid] = pid in ready_list

	ready_status.text = "%d/%d ready" % [ready_count, needed]
	_update_players_display()


func _apply_prompt(data: Dictionary) -> void:
	current_prompt = data.get("prompt", "")
	current_round = data.get("round", 1)
	total_rounds = data.get("total_rounds", 3)
	has_submitted_answer = false
	_show_writing_ui()


func _handle_answer(data: Dictionary) -> void:
	var player_id = data.get("player_id", "")
	var answer = data.get("answer", "")

	player_answers[player_id] = answer

	var status_data = {
		"type": "whosaid_answer_received",
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
	answers_status.text = "%d/%d answers received" % [received, needed]


func _apply_vote_start(data: Dictionary) -> void:
	current_answer_index = data.get("answer_index", 0)
	var answer_total = data.get("answer_total", 0)
	var answer_text = data.get("answer_text", "")
	var is_author = (answer_text == my_submitted_answer)
	var answer_data = {"answer_text": answer_text}
	has_voted = false
	_show_voting_ui(answer_data, is_author, answer_total)


func _handle_vote(data: Dictionary) -> void:
	var voter_id = data.get("player_id", "")
	var voted_for = data.get("voted_for", "")

	player_votes[voter_id] = voted_for

	var voters_needed = player_order.size() - 1

	var status_data = {
		"type": "whosaid_vote_received",
		"votes_received": player_votes.size(),
		"votes_needed": voters_needed
	}
	NetworkManager.broadcast(status_data)
	_apply_vote_status(status_data)

	if player_votes.size() >= voters_needed:
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

	var answer_data = {"answer_text": data.get("answer_text", "")}
	var author_id = data.get("author_id", "")
	var correct = data.get("correct_guessers", [])
	var fooled = data.get("fooled_players", [])
	var points = data.get("points_awarded", {})
	var scores = data.get("scores", {})

	for pid in scores:
		player_scores[pid] = scores[pid]

	_show_reveal_ui(answer_data, author_id, correct, fooled, points)

	# Host will trigger continue screen after a delay
	if GameManager.is_host:
		await get_tree().create_timer(REVEAL_TIME).timeout
		_show_continue_screen()


func _apply_continue(data: Dictionary) -> void:
	current_phase = GamePhase.CONTINUE
	is_ready = false
	var is_last = data.get("is_last_answer", false)

	var ready_list = data.get("ready_players", [])
	for pid in players_ready:
		players_ready[pid] = pid in ready_list

	phase_label.text = "CONTINUE"

	var button_text = "Next Answer"
	var title = "Ready for next answer?"
	if is_last:
		button_text = "See Results"
		title = "That was the last answer!"

	_show_ready_ui(title, button_text)
	ready_status.text = "%d/%d ready" % [ready_list.size(), player_order.size()]


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
