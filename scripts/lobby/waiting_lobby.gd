extends Control

@onready var back_button: Button = $ScrollContainer/VBox/Header/BackButton
@onready var session_code: Label = $ScrollContainer/VBox/Header/SessionCode
@onready var players_label: Label = $ScrollContainer/VBox/PlayersSection/PlayersLabel
@onready var player_list: VBoxContainer = $ScrollContainer/VBox/PlayersSection/PlayerList
@onready var start_button: Button = $ScrollContainer/VBox/StartButton
@onready var qr_placeholder: ColorRect = $ScrollContainer/VBox/QRSection/QRPlaceholder
@onready var qr_text: Label = $ScrollContainer/VBox/QRSection/QRPlaceholder/QRPlaceholderText

var server_started: bool = false
var qr_texture: TextureRect

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)

	GameManager.player_joined.connect(_on_player_joined)
	GameManager.player_left.connect(_on_player_left)
	NetworkManager.player_connected.connect(_on_network_player_connected)
	NetworkManager.player_disconnected.connect(_on_network_player_disconnected)

	session_code.text = "Code: " + GameManager.session_id.to_upper()

	# Start WebSocket server
	_start_server()

	_refresh_player_list()
	_update_start_button()

func _start_server() -> void:
	var err = NetworkManager.start_server()
	if err == OK:
		server_started = true
		var ip = NetworkManager.get_local_ip()
		var ws_port = NetworkManager.DEFAULT_PORT

		# Generate connection info for QR code
		# Players scan this to get the host IP address
		var join_info = "%s:%d" % [ip, ws_port]

		print("Server running on port: ", ws_port)
		print("Join info for QR code: ", join_info)

		# Generate and display QR code
		_display_qr_code(join_info, ip)
	else:
		qr_text.text = "Server\nError"
		push_error("Failed to start server")

func _display_qr_code(connection_info: String, ip: String) -> void:
	# Try to generate QR code image
	var qr_image: Image = null

	# Attempt QR generation with error handling
	# module_size=8 and quiet_zone=4 for better scannability
	if ClassDB.class_exists("QRGenerator") or ResourceLoader.exists("res://scripts/utils/qr_generator.gd"):
		qr_image = QRGenerator.generate(connection_info, 8, 4)

	if qr_image and qr_image.get_width() > 0:
		print("QR image generated: ", qr_image.get_width(), "x", qr_image.get_height())

		# Create texture from image
		var texture = ImageTexture.create_from_image(qr_image)

		# Hide placeholder text
		qr_text.visible = false

		# Create TextureRect to display QR code
		qr_texture = TextureRect.new()
		qr_texture.texture = texture
		qr_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		qr_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		qr_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		qr_texture.offset_left = 10
		qr_texture.offset_top = 10
		qr_texture.offset_right = -10
		qr_texture.offset_bottom = -30

		qr_placeholder.add_child(qr_texture)

		# Update the placeholder text to show IP below the QR
		var ip_label = Label.new()
		ip_label.text = ip
		ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ip_label.add_theme_color_override("font_color", Color.BLACK)
		ip_label.add_theme_font_size_override("font_size", 12)
		ip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		ip_label.offset_top = -25
		ip_label.offset_bottom = -5
		qr_placeholder.add_child(ip_label)

		print("QR code displayed for: ", connection_info)
	else:
		# Fallback: show connection info as text
		print("QR generation failed, showing connection info instead")
		qr_text.text = "Join at:\n%s" % connection_info
		qr_text.add_theme_font_size_override("font_size", 14)
		qr_placeholder.custom_minimum_size = Vector2(280, 100)

func _refresh_player_list() -> void:
	# Clear existing player cards
	for child in player_list.get_children():
		child.queue_free()

	# Add a card for each player
	for player_id in GameManager.players:
		var player = GameManager.players[player_id]
		var card = _create_player_card(player_id, player)
		player_list.add_child(card)

	# Update player count
	var count = GameManager.players.size()
	players_label.text = "Players (%d/8)" % count

func _create_player_card(player_id: String, player: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 60)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)

	# Character indicator - use sprite if available, otherwise color
	var char_data = GameManager.get_character_data(player["character"])
	var char_display: Control
	var sprite_path = char_data.get("sprite")
	if sprite_path and ResourceLoader.exists(sprite_path):
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(sprite_path)
		texture_rect.custom_minimum_size = Vector2(40, 40)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		char_display = texture_rect
	else:
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(40, 40)
		color_rect.color = char_data["color"]
		char_display = color_rect

	# Player name
	var name_label = Label.new()
	name_label.text = player["name"]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Host badge
	if player["is_host"]:
		var host_badge = Label.new()
		host_badge.text = "HOST"
		host_badge.add_theme_font_size_override("font_size", 14)
		host_badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
		hbox.add_child(char_display)
		hbox.add_child(name_label)
		hbox.add_child(host_badge)
	else:
		hbox.add_child(char_display)
		hbox.add_child(name_label)

	card.add_child(hbox)
	return card

func _on_player_joined(_player_id: String, _player_data: Dictionary) -> void:
	_refresh_player_list()
	_update_start_button()

func _on_player_left(_player_id: String) -> void:
	_refresh_player_list()
	_update_start_button()

func _on_network_player_connected(_peer_id: int) -> void:
	# Player list updates via GameManager signals
	pass

func _on_network_player_disconnected(_peer_id: int) -> void:
	# Player list updates via GameManager signals
	pass

func _update_start_button() -> void:
	var count = GameManager.players.size()
	if count >= GameManager.settings["min_players"]:
		start_button.disabled = false
		start_button.text = "Start Game"
	else:
		start_button.disabled = true
		start_button.text = "Start Game (Need %d+ players)" % GameManager.settings["min_players"]

func _on_start_pressed() -> void:
	# Go to game selection
	get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")

func _on_back_pressed() -> void:
	if server_started:
		NetworkManager.stop_server()
	GameManager.reset_session()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
