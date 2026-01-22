extends Control

@onready var imposter_count_label: Label = $VBox/Header/ImposterCountLabel
@onready var role_label: Label = $VBox/RoleSection/RoleLabel
@onready var word_label: Label = $VBox/RoleSection/WordDisplay/WordLabel
@onready var instruction_label: Label = $VBox/InstructionLabel
@onready var players_status: HBoxContainer = $VBox/PlayersStatus
@onready var countdown_timer: Timer = $CountdownTimer
@onready var consensus_check_timer: Timer = $ConsensusCheckTimer

enum State { DISCUSSION, VOTING, CONSENSUS_WARNING, REVEALING, RESULT_DISPLAY }

var words: Array = []
var current_word: String = ""
var imposters: Array = []
var player_roles: Dictionary = {}
var is_imposter: bool = false
var imposter_count: int = 1
var total_players: int = 0

var current_state: State = State.DISCUSSION
var votes: Dictionary = {}              # voter_id -> target_id
var eliminated_players: Array = []      # List of eliminated player IDs
var consensus_target: String = ""       # Current consensus target
var countdown_remaining: int = 5        # Consensus countdown
var remaining_imposters: int = 0        # Living imposters count

func _ready() -> void:
	NetworkManager.message_received.connect(_on_message_received)
	countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	consensus_check_timer.timeout.connect(_on_consensus_check_timer_timeout)
	_load_words()
	call_deferred("_initialize_game")

func _input(event: InputEvent) -> void:
	if GameManager.is_host and event is InputEventKey and event.pressed:
		if event.keycode == KEY_V and current_state == State.DISCUSSION:
			start_voting()

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

	# Initialize remaining imposters
	remaining_imposters = imposter_count

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
		"vote_cast":
			if GameManager.is_host:
				var voter_id = "peer_%d" % _peer_id
				_process_vote(voter_id, data.get("target_id", ""))
		"start_voting":
			if GameManager.is_host:
				start_voting()
		"voting_started":
			_apply_voting_started(data)
		"vote_update":
			_apply_vote_update(data)
		"consensus_warning":
			_apply_consensus_warning(data)
		"consensus_countdown":
			_apply_consensus_countdown(data)
		"consensus_cancelled":
			_apply_consensus_cancelled()
		"reveal_start":
			_apply_reveal_start(data)
		"reveal_result":
			_apply_reveal_result(data)

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

# ============ VOTING STATE MACHINE ============

func start_voting() -> void:
	if not GameManager.is_host:
		return

	current_state = State.VOTING
	votes.clear()

	var player_list = []
	for player_id in GameManager.players:
		var p = GameManager.players[player_id]
		player_list.append({
			"id": player_id,
			"name": p.get("name", "Unknown"),
			"eliminated": player_id in eliminated_players
		})

	NetworkManager.broadcast({
		"type": "voting_started",
		"players": player_list,
		"eliminated": eliminated_players
	})

func _can_vote(voter_id: String) -> bool:
	return voter_id not in eliminated_players and current_state in [State.VOTING, State.CONSENSUS_WARNING]

func _process_vote(voter_id: String, target_id: String) -> void:
	if not _can_vote(voter_id):
		return
	if target_id == "" or not GameManager.players.has(target_id):
		return
	if target_id in eliminated_players:
		return

	votes[voter_id] = target_id
	_broadcast_vote_state()
	_check_consensus()

func _broadcast_vote_state() -> void:
	var tallies: Dictionary = {}
	for voter_id in votes:
		var target = votes[voter_id]
		tallies[target] = tallies.get(target, 0) + 1

	NetworkManager.broadcast({
		"type": "vote_update",
		"votes": votes,
		"tallies": tallies,
		"state": State.keys()[current_state].to_lower()
	})

func _check_consensus() -> void:
	if consensus_check_timer.is_stopped():
		consensus_check_timer.start()

func _on_consensus_check_timer_timeout() -> void:
	var eligible_voters = _get_eligible_voters()
	var vote_counts: Dictionary = {}

	for voter_id in votes:
		if voter_id in eligible_voters:
			var target = votes[voter_id]
			vote_counts[target] = vote_counts.get(target, 0) + 1

	for target_id in vote_counts:
		var voters_excluding_target = eligible_voters.filter(func(v): return v != target_id)
		if vote_counts[target_id] == voters_excluding_target.size() and voters_excluding_target.size() > 0:
			_start_consensus_warning(target_id)
			return

	if current_state == State.CONSENSUS_WARNING:
		_cancel_consensus_warning()

func _get_eligible_voters() -> Array:
	var eligible = []
	for player_id in GameManager.players:
		if player_id not in eliminated_players:
			eligible.append(player_id)
	return eligible

func _start_consensus_warning(target_id: String) -> void:
	if current_state == State.CONSENSUS_WARNING and consensus_target == target_id:
		return  # Already warning for this target

	consensus_target = target_id
	current_state = State.CONSENSUS_WARNING
	countdown_remaining = 5
	countdown_timer.start(1.0)

	var target_data = GameManager.players.get(target_id, {})
	NetworkManager.broadcast({
		"type": "consensus_warning",
		"target_id": target_id,
		"target_name": target_data.get("name", "Unknown"),
		"countdown": countdown_remaining
	})

func _on_countdown_timer_timeout() -> void:
	countdown_remaining -= 1

	if countdown_remaining <= 0:
		countdown_timer.stop()
		_start_reveal()
	else:
		NetworkManager.broadcast({
			"type": "consensus_countdown",
			"countdown": countdown_remaining
		})

func _cancel_consensus_warning() -> void:
	countdown_timer.stop()
	consensus_target = ""
	current_state = State.VOTING

	NetworkManager.broadcast({
		"type": "consensus_cancelled"
	})

func _start_reveal() -> void:
	current_state = State.REVEALING

	var target_data = GameManager.players.get(consensus_target, {})
	NetworkManager.broadcast({
		"type": "reveal_start",
		"target_id": consensus_target,
		"target_name": target_data.get("name", "Unknown")
	})

	# Dramatic pause before result
	await get_tree().create_timer(2.0).timeout
	_show_reveal_result()

func _show_reveal_result() -> void:
	current_state = State.RESULT_DISPLAY

	var target_id = consensus_target
	var is_imposter_target = player_roles.get(target_id, false)
	var target_data = GameManager.players.get(target_id, {})

	if is_imposter_target:
		eliminated_players.append(target_id)
		remaining_imposters -= 1

		# Send word to eliminated imposter
		var peer_id = _get_peer_id_for_player(target_id)
		NetworkManager.send_to_client(peer_id, {
			"type": "word_revealed",
			"word": current_word
		})

	NetworkManager.broadcast({
		"type": "reveal_result",
		"target_id": target_id,
		"target_name": target_data.get("name", "Unknown"),
		"is_imposter": is_imposter_target,
		"remaining_imposters": remaining_imposters
	})

	# Clear vote from eliminated player if any
	votes.erase(target_id)

	# Wait then continue
	await get_tree().create_timer(4.0).timeout
	_after_reveal()

func _after_reveal() -> void:
	consensus_target = ""

	# Check if game should end (Phase 3 will handle this properly)
	# For now, just return to voting if game continues
	if remaining_imposters > 0 and _get_eligible_voters().size() > 2:
		current_state = State.VOTING
		votes.clear()
		_broadcast_vote_state()

		NetworkManager.broadcast({
			"type": "voting_resumed",
			"votes": votes,
			"tallies": {}
		})

# ============ APPLY FUNCTIONS FOR NON-HOST CLIENTS ============

func _apply_voting_started(data: Dictionary) -> void:
	current_state = State.VOTING
	# UI update will be handled by web player

func _apply_vote_update(data: Dictionary) -> void:
	votes = data.get("votes", {})
	# State sync for non-host Godot clients

func _apply_consensus_warning(data: Dictionary) -> void:
	current_state = State.CONSENSUS_WARNING
	consensus_target = data.get("target_id", "")
	countdown_remaining = data.get("countdown", 5)

func _apply_consensus_countdown(data: Dictionary) -> void:
	countdown_remaining = data.get("countdown", 0)

func _apply_consensus_cancelled() -> void:
	current_state = State.VOTING
	consensus_target = ""

func _apply_reveal_start(data: Dictionary) -> void:
	current_state = State.REVEALING

func _apply_reveal_result(data: Dictionary) -> void:
	current_state = State.RESULT_DISPLAY
	var target_id = data.get("target_id", "")
	var is_imposter_target = data.get("is_imposter", false)
	remaining_imposters = data.get("remaining_imposters", 0)

	if is_imposter_target and target_id not in eliminated_players:
		eliminated_players.append(target_id)
