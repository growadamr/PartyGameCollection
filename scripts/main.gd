extends Control

@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	# Auto-redirect to join lobby if URL has host parameter (from QR scan)
	if OS.has_feature("web"):
		var host_ip = JavaScriptBridge.eval("""
			(function() {
				var params = new URLSearchParams(window.location.search);
				return params.get('host') || '';
			})();
		""", true)

		if host_ip and host_ip.length() > 0:
			print("Detected host parameter in URL, redirecting to join lobby...")
			get_tree().change_scene_to_file.call_deferred("res://scenes/lobby/join_lobby.tscn")

func _on_host_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/host_lobby.tscn")

func _on_join_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby/join_lobby.tscn")
