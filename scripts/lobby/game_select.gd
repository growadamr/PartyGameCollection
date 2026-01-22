extends Control

@onready var back_button: Button = $ScrollContainer/VBox/BackButton
@onready var game_list: VBoxContainer = $ScrollContainer/VBox/GameList

const GAMES = [
	{
		"id": "quick_draw",
		"name": "Quick Draw",
		"description": "Draw and guess! One player draws, others guess the word.",
		"icon": "✏️",
		"min_players": 2,
		"color": Color(0.9, 0.6, 0.2)
	},
	{
		"id": "charades",
		"name": "Act It Out",
		"description": "Classic charades! Act out the prompt without speaking.",
		"icon": "🎭",
		"min_players": 3,
		"color": Color(0.8, 0.3, 0.5)
	},
	{
		"id": "fibbage",
		"name": "Fibbage",
		"description": "Bluff your way to victory! Write fake answers to fool others.",
		"icon": "🎲",
		"min_players": 3,
		"color": Color(0.3, 0.6, 0.9)
	},
	{
		"id": "word_bomb",
		"name": "Word Bomb",
		"description": "Think fast! Type a word containing the letters before time runs out.",
		"icon": "💣",
		"min_players": 2,
		"color": Color(0.9, 0.3, 0.3)
	},
	{
		"id": "who_said_it",
		"name": "Who Said It?",
		"description": "Guess who wrote each answer. Know your friends!",
		"icon": "💬",
		"min_players": 3,
		"color": Color(0.5, 0.8, 0.4)
	},
	{
		"id": "trivia",
		"name": "Trivia Showdown",
		"description": "Test your knowledge! Fastest correct answer wins.",
		"icon": "🧠",
		"min_players": 2,
		"color": Color(0.7, 0.4, 0.9)
	}
]

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_create_game_cards()

func _create_game_cards() -> void:
	for game in GAMES:
		var card = _create_game_card(game)
		game_list.add_child(card)

func _create_game_card(game: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 100)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.22, 1.0)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)

	# Icon with colored background
	var icon_bg = ColorRect.new()
	icon_bg.custom_minimum_size = Vector2(70, 70)
	icon_bg.color = game["color"]

	var icon_label = Label.new()
	icon_label.text = game["icon"]
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.anchors_preset = Control.PRESET_FULL_RECT
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_bg.add_child(icon_label)

	# Text content
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)

	var title = Label.new()
	title.text = game["name"]
	title.add_theme_font_size_override("font_size", 22)

	var desc = Label.new()
	desc.text = game["description"]
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD

	var player_req = Label.new()
	player_req.text = "Min %d players" % game["min_players"]
	player_req.add_theme_font_size_override("font_size", 12)
	player_req.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))

	vbox.add_child(title)
	vbox.add_child(desc)
	vbox.add_child(player_req)

	hbox.add_child(icon_bg)
	hbox.add_child(vbox)
	card.add_child(hbox)

	# Make card clickable
	var button = Button.new()
	button.flat = true
	button.anchors_preset = Control.PRESET_FULL_RECT
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_game_selected.bind(game["id"]))

	# Check if enough players
	var player_count = GameManager.players.size()
	if player_count < game["min_players"]:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
		button.disabled = true

	card.add_child(button)
	return card

func _on_game_selected(game_id: String) -> void:
	print("Selected game: ", game_id)

	# Notify all players which game is starting
	NetworkManager.broadcast({
		"type": "game_starting",
		"game": game_id
	})

	# Load the game scene
	var scene_path = "res://scenes/games/%s/%s.tscn" % [game_id, game_id]
	get_tree().change_scene_to_file(scene_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/waiting_lobby.tscn")
