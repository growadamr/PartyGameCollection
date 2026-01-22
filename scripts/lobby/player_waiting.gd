extends Control

@onready var name_label: Label = $VBox/PlayerInfo/NameLabel
@onready var character_preview: ColorRect = $VBox/PlayerInfo/CharacterPreview
@onready var players_label: Label = $VBox/PlayersInLobby
@onready var leave_button: Button = $VBox/LeaveButton

func _ready() -> void:
	leave_button.pressed.connect(_on_leave_pressed)

	GameManager.player_joined.connect(_on_player_changed)
	GameManager.player_left.connect(_on_player_changed)
	NetworkManager.connection_closed.connect(_on_disconnected)
	NetworkManager.message_received.connect(_on_message_received)

	_update_display()

func _update_display() -> void:
	name_label.text = "Playing as: " + GameManager.local_player_name

	var char_data = GameManager.get_character_data(GameManager.local_player_character)
	character_preview.color = char_data["color"]

	players_label.text = "Players in lobby: %d" % GameManager.players.size()

func _on_player_changed(_arg1, _arg2 = null) -> void:
	_update_display()

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"game_starting":
			var game_id = data.get("game", "")
			var scene_path = "res://scenes/games/%s/%s.tscn" % [game_id, game_id]
			get_tree().change_scene_to_file(scene_path)

		"host_left":
			_on_disconnected()

func _on_disconnected() -> void:
	# Host disconnected or we lost connection
	GameManager.reset_session()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_leave_pressed() -> void:
	NetworkManager.disconnect_from_server()
	GameManager.reset_session()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
