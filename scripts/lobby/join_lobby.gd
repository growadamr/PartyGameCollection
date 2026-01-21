extends Control

@onready var back_button: Button = $ScrollContainer/VBox/BackButton
@onready var ip_input: LineEdit = $ScrollContainer/VBox/ConnectionSection/IPInput
@onready var name_input: LineEdit = $ScrollContainer/VBox/NameSection/NameInput
@onready var character_grid: GridContainer = $ScrollContainer/VBox/CharacterSection/CharacterGrid
@onready var status_label: Label = $ScrollContainer/VBox/StatusLabel
@onready var join_button: Button = $ScrollContainer/VBox/JoinButton

var selected_character: int = -1
var character_buttons: Array[Button] = []
var is_connecting: bool = false

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	ip_input.text_changed.connect(_on_input_changed)
	ip_input.focus_entered.connect(_on_ip_input_focus)
	name_input.text_changed.connect(_on_input_changed)
	name_input.focus_entered.connect(_on_name_input_focus)
	join_button.pressed.connect(_on_join_pressed)

	NetworkManager.connection_established.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.message_received.connect(_on_message_received)

	_create_character_buttons()

	# Check for URL parameters (from QR code scan)
	_check_url_parameters()

	_update_join_button()

func _check_url_parameters() -> void:
	if not OS.has_feature("web"):
		return

	# Use JavaScript to get URL parameters
	var host_ip = JavaScriptBridge.eval("""
		(function() {
			var params = new URLSearchParams(window.location.search);
			return params.get('host') || '';
		})();
	""", true)

	if host_ip and host_ip.length() > 0:
		ip_input.text = host_ip
		status_label.text = "Host IP detected from QR code"
		status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		print("Pre-filled host IP from URL: ", host_ip)

		# Focus the name input since IP is already filled
		name_input.grab_focus.call_deferred()

func _on_ip_input_focus() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(ip_input.text, Rect2())

func _on_name_input_focus() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(name_input.text, Rect2())

func _create_character_buttons() -> void:
	for child in character_grid.get_children():
		child.queue_free()
	character_buttons.clear()

	for i in range(GameManager.CHARACTERS.size()):
		var char_data = GameManager.CHARACTERS[i]
		var btn = _create_character_button(i, char_data)
		character_grid.add_child(btn)
		character_buttons.append(btn)

func _create_character_button(index: int, char_data: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(140, 140)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass clicks to button

	# Character preview - use sprite if available, otherwise color placeholder
	var sprite_path = char_data.get("sprite")
	if sprite_path and ResourceLoader.exists(sprite_path):
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(sprite_path)
		texture_rect.custom_minimum_size = Vector2(80, 80)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(texture_rect)
	else:
		# Fallback to color rectangle
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(80, 80)
		color_rect.color = char_data["color"]
		color_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(color_rect)

	var label = Label.new()
	label.text = char_data["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass clicks to button

	vbox.add_child(label)
	btn.add_child(vbox)

	btn.pressed.connect(_on_character_selected.bind(index))
	return btn

func _on_character_selected(index: int) -> void:
	selected_character = index

	for i in range(character_buttons.size()):
		var btn = character_buttons[i]
		if i == index:
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
			btn.add_theme_stylebox_override("normal", _get_selected_style())
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			btn.remove_theme_stylebox_override("normal")

	_update_join_button()

func _get_selected_style() -> StyleBox:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.8, 0.5)
	style.border_color = Color(0.4, 0.7, 1.0, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style

func _on_input_changed(_text: String) -> void:
	_update_join_button()

func _update_join_button() -> void:
	if is_connecting:
		join_button.disabled = true
		join_button.text = "Connecting..."
		return

	var ip_valid = ip_input.text.strip_edges().length() >= 7  # Minimum IP like 1.1.1.1
	var name_valid = name_input.text.strip_edges().length() >= 2
	var char_valid = selected_character >= 0

	join_button.disabled = not (ip_valid and name_valid and char_valid)
	join_button.text = "Join Game"

func _on_join_pressed() -> void:
	if is_connecting:
		return

	is_connecting = true
	status_label.text = "Connecting..."
	_update_join_button()

	var ip = ip_input.text.strip_edges()
	var err = NetworkManager.connect_to_server(ip)

	if err != OK:
		is_connecting = false
		status_label.text = "Failed to connect"
		status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		_update_join_button()

func _on_connected() -> void:
	status_label.text = "Connected! Joining..."
	status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))

	# Set local player info
	var player_name = name_input.text.strip_edges()
	GameManager.local_player_name = player_name
	GameManager.local_player_character = selected_character
	GameManager.is_host = false

	# Request to join
	NetworkManager.request_join(player_name, selected_character)

func _on_connection_failed(reason: String) -> void:
	is_connecting = false
	status_label.text = "Connection failed: " + reason
	status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	_update_join_button()

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	if msg_type == "join_accepted":
		# Successfully joined, go to player waiting screen
		get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")

func _on_back_pressed() -> void:
	if is_connecting:
		NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
