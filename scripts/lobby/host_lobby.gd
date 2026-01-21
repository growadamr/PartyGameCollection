extends Control

@onready var back_button: Button = $ScrollContainer/VBox/BackButton
@onready var name_input: LineEdit = $ScrollContainer/VBox/NameSection/NameInput
@onready var character_grid: GridContainer = $ScrollContainer/VBox/CharacterSection/CharacterGrid
@onready var selected_char_name: Label = $ScrollContainer/VBox/SelectedPreview/SelectedCharName
@onready var create_button: Button = $ScrollContainer/VBox/CreateButton

var selected_character: int = -1
var character_buttons: Array[Button] = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	name_input.text_changed.connect(_on_name_changed)
	name_input.focus_entered.connect(_on_name_input_focus)
	create_button.pressed.connect(_on_create_pressed)

	_create_character_buttons()
	_update_create_button()

func _on_name_input_focus() -> void:
	# Show virtual keyboard on mobile
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(name_input.text, Rect2())

func _create_character_buttons() -> void:
	# Clear existing buttons
	for child in character_grid.get_children():
		child.queue_free()
	character_buttons.clear()

	# Create a button for each character
	for i in range(GameManager.CHARACTERS.size()):
		var char_data = GameManager.CHARACTERS[i]
		var btn = _create_character_button(i, char_data)
		character_grid.add_child(btn)
		character_buttons.append(btn)

func _create_character_button(index: int, char_data: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(140, 140)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create container for character display
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

	# Character name
	var label = Label.new()
	label.text = char_data["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass clicks to button

	vbox.add_child(label)
	btn.add_child(vbox)

	# Connect button
	btn.pressed.connect(_on_character_selected.bind(index))

	return btn

func _on_character_selected(index: int) -> void:
	selected_character = index
	var char_data = GameManager.get_character_data(index)
	selected_char_name.text = char_data["name"]

	# Update button styles to show selection
	for i in range(character_buttons.size()):
		var btn = character_buttons[i]
		if i == index:
			btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
			btn.add_theme_stylebox_override("normal", _get_selected_style())
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			btn.remove_theme_stylebox_override("normal")

	_update_create_button()

func _get_selected_style() -> StyleBox:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.8, 0.5)
	style.border_color = Color(0.4, 0.7, 1.0, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style

func _on_name_changed(_new_text: String) -> void:
	_update_create_button()

func _update_create_button() -> void:
	var name_valid = name_input.text.strip_edges().length() >= 2
	var char_valid = selected_character >= 0
	create_button.disabled = not (name_valid and char_valid)

func _on_create_pressed() -> void:
	var player_name = name_input.text.strip_edges()

	# Set up the session
	GameManager.create_session()
	GameManager.set_local_player(player_name, selected_character)

	# Go to waiting lobby
	get_tree().change_scene_to_file("res://scenes/lobby/waiting_lobby.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
