extends Node

## Simple HTTP server to serve web-player files from the Godot app
## This allows the app to work completely offline on local WiFi

const HTTP_PORT = 8000
var _tcp_server: TCPServer
var _clients: Array = []  # Array of connected TCP streams

# Web player files content (loaded from res://)
var _web_files: Dictionary = {}

func _ready() -> void:
	_load_web_files()

func _process(_delta: float) -> void:
	if not _tcp_server:
		return

	# Accept new connections
	if _tcp_server.is_connection_available():
		var client = _tcp_server.take_connection()
		_clients.append({
			"stream": client,
			"request": "",
			"time": Time.get_ticks_msec()
		})

	# Process existing clients
	var i = 0
	while i < _clients.size():
		var client_data = _clients[i]
		var stream: StreamPeerTCP = client_data["stream"]

		# Check if connection is still alive
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			stream.disconnect_from_host()
			_clients.remove_at(i)
			continue

		# Read incoming data
		var available = stream.get_available_bytes()
		if available > 0:
			var data = stream.get_utf8_string(available)
			client_data["request"] += data

			# Check if we have a complete HTTP request (ends with \r\n\r\n)
			if client_data["request"].contains("\r\n\r\n"):
				_handle_request(stream, client_data["request"])
				stream.disconnect_from_host()
				_clients.remove_at(i)
				continue

		# Timeout after 5 seconds
		if Time.get_ticks_msec() - client_data["time"] > 5000:
			stream.disconnect_from_host()
			_clients.remove_at(i)
			continue

		i += 1

func start_server() -> Error:
	_tcp_server = TCPServer.new()
	# Bind to all network interfaces ("*") to accept connections from other devices
	var err = _tcp_server.listen(HTTP_PORT, "*")
	if err != OK:
		push_error("Failed to start HTTP server on port %d: %s" % [HTTP_PORT, error_string(err)])
		return err

	print("HTTP server started on port ", HTTP_PORT, " (listening on all interfaces)")
	return OK

func stop_server() -> void:
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null

	for client_data in _clients:
		client_data["stream"].disconnect_from_host()
	_clients.clear()

func _load_web_files() -> void:
	# Load all web-player files into memory
	_web_files = {
		"/": _load_file("res://web-player/index.html"),
		"/index.html": _load_file("res://web-player/index.html"),
		"/css/styles.css": _load_file("res://web-player/css/styles.css"),
		"/js/app.js": _load_file("res://web-player/js/app.js"),
		"/js/websocket.js": _load_file("res://web-player/js/websocket.js"),
		"/js/games/charades.js": _load_file("res://web-player/js/games/charades.js"),
		"/js/games/word_bomb.js": _load_file("res://web-player/js/games/word_bomb.js"),
		"/js/games/quick_draw.js": _load_file("res://web-player/js/games/quick_draw.js"),
		"/js/games/imposter.js": _load_file("res://web-player/js/games/imposter.js"),
		"/js/games/who_said_it.js": _load_file("res://web-player/js/games/who_said_it.js"),
		"/js/games/fibbage.js": _load_file("res://web-player/js/games/fibbage.js"),
		"/js/games/trivia.js": _load_file("res://web-player/js/games/trivia.js"),
	}

	print("Loaded ", _web_files.size(), " web files")

func _load_file(path: String) -> String:
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			return content

	push_warning("Web file not found: ", path)
	return ""

func _handle_request(stream: StreamPeerTCP, request: String) -> void:
	# Parse the HTTP request
	var lines = request.split("\r\n")
	if lines.size() == 0:
		return

	var request_line = lines[0]
	var parts = request_line.split(" ")
	if parts.size() < 2:
		return

	var method = parts[0]
	var path = parts[1]

	# Only handle GET requests
	if method != "GET":
		_send_response(stream, 405, "text/plain", "Method Not Allowed")
		return

	# Serve the requested file
	if _web_files.has(path):
		var content = _web_files[path]
		var content_type = _get_content_type(path)
		_send_response(stream, 200, content_type, content)
	else:
		_send_response(stream, 404, "text/plain", "File Not Found: " + path)

func _send_response(stream: StreamPeerTCP, status_code: int, content_type: String, body: String) -> void:
	var status_text = "OK" if status_code == 200 else ("Not Found" if status_code == 404 else "Method Not Allowed")

	var response = "HTTP/1.1 %d %s\r\n" % [status_code, status_text]
	response += "Content-Type: %s; charset=utf-8\r\n" % content_type
	response += "Content-Length: %d\r\n" % body.to_utf8_buffer().size()
	response += "Connection: close\r\n"
	response += "\r\n"
	response += body

	stream.put_data(response.to_utf8_buffer())

func _get_content_type(path: String) -> String:
	if path.ends_with(".html"):
		return "text/html"
	elif path.ends_with(".css"):
		return "text/css"
	elif path.ends_with(".js"):
		return "application/javascript"
	else:
		return "text/plain"
