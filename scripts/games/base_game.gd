extends Node
class_name BaseGame

## Base class for all party games

signal game_ended(results: Dictionary)
signal round_ended(round_num: int, results: Dictionary)
signal turn_changed(player_id: String)
signal timer_tick(seconds_left: int)

var players: Array = []
var current_player_index: int = 0
var current_round: int = 0
var max_rounds: int = 3
var round_timer: Timer
var is_host: bool = false

func _ready() -> void:
	is_host = GameManager.is_host
	players = GameManager.players.keys()
	players.shuffle()

	round_timer = Timer.new()
	round_timer.one_shot = true
	round_timer.timeout.connect(_on_round_timer_timeout)
	add_child(round_timer)

func start_game() -> void:
	current_round = 0
	_start_round()

func _start_round() -> void:
	current_round += 1
	current_player_index = 0
	_on_round_start()

func _on_round_start() -> void:
	# Override in subclass
	pass

func _on_round_timer_timeout() -> void:
	# Override in subclass
	pass

func next_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	var player_id = players[current_player_index]
	turn_changed.emit(player_id)
	_on_turn_start(player_id)

func _on_turn_start(_player_id: String) -> void:
	# Override in subclass
	pass

func get_current_player_id() -> String:
	if players.size() == 0:
		return ""
	return players[current_player_index]

func end_game(results: Dictionary) -> void:
	game_ended.emit(results)

func _broadcast(data: Dictionary) -> void:
	if is_host:
		NetworkManager.broadcast(data)

func _send_to_player(player_id: String, data: Dictionary) -> void:
	if is_host:
		# Find peer_id for this player
		for peer_id in range(1, 100):  # Simple approach
			var uuid = "peer_%d" % peer_id
			if uuid == player_id:
				NetworkManager.send_to_client(peer_id, data)
				return
