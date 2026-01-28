extends Node

## Simple HTTP server to serve web-player files from the Godot app
## This allows the app to work completely offline on local WiFi

const HTTP_PORT = 8000
const WebFilesEmbedded = preload("res://scripts/autoload/web_files_embedded.gd")

var _tcp_server: TCPServer
var _clients: Array = []  # Array of connected TCP streams

# Web player files content (loaded from res://)
var _web_files: Dictionary = {}

func _ready() -> void:
	print("[HTTPServer] _ready() called")
	_load_web_files()

func _process(_delta: float) -> void:
	if not _tcp_server:
		return

	# Accept new connections
	if _tcp_server.is_connection_available():
		var client = _tcp_server.take_connection()
		print("[HTTPServer] New client connection accepted")
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
	print("[HTTPServer] start_server() called")
	_tcp_server = TCPServer.new()
	print("[HTTPServer] TCPServer object created")

	# Bind to all network interfaces ("*") to accept connections from other devices
	var err = _tcp_server.listen(HTTP_PORT, "*")
	print("[HTTPServer] listen() returned: ", err, " (", error_string(err), ")")

	if err != OK:
		push_error("[HTTPServer] Failed to start HTTP server on port %d: %s" % [HTTP_PORT, error_string(err)])
		_tcp_server = null  # Clean up on failure
		return err

	# Verify server is actually listening
	if _tcp_server.is_listening():
		print("[HTTPServer] ✓ Server confirmed listening on port ", HTTP_PORT, " (all interfaces)")
	else:
		push_error("[HTTPServer] ✗ Server not listening despite OK status!")
		_tcp_server.stop()
		_tcp_server = null
		return ERR_CANT_OPEN

	print("[HTTPServer] Server started successfully on port ", HTTP_PORT)
	return OK

func stop_server() -> void:
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null

	for client_data in _clients:
		client_data["stream"].disconnect_from_host()
	_clients.clear()

func _load_web_files() -> void:
	# Use embedded web files (guaranteed to be in export)
	print("[HTTPServer] Loading embedded web files...")

	# Access the constant directly from the preloaded script
	_web_files = WebFilesEmbedded.WEB_FILES.duplicate()

	var loaded_count = 0
	var total_size = 0
	for path in _web_files:
		var size = _web_files[path].length()
		if size > 0:
			loaded_count += 1
			total_size += size
		print("[HTTPServer]   ", path, " -> ", size, " bytes")

	print("[HTTPServer] Loaded ", _web_files.size(), " embedded web files (", loaded_count, " with content, ", total_size, " total bytes)")

	# Debug: print first 100 chars of index.html
	if _web_files.has("/"):
		var preview = _web_files["/"].substr(0, 100)
		print("[HTTPServer] Index preview: ", preview)

# No longer needed - using embedded files
# func _load_file(path: String) -> String:
#	...

func _handle_request(stream: StreamPeerTCP, request: String) -> void:
	# Parse the HTTP request
	var lines = request.split("\r\n")
	if lines.size() == 0:
		print("[HTTPServer] Empty request received")
		return

	var request_line = lines[0]
	var parts = request_line.split(" ")
	if parts.size() < 2:
		print("[HTTPServer] Invalid request line: ", request_line)
		return

	var method = parts[0]
	var path = parts[1]
	print("[HTTPServer] Request: ", method, " ", path)

	# Only handle GET requests
	if method != "GET":
		print("[HTTPServer] Method not allowed: ", method)
		_send_response(stream, 405, "text/plain", "Method Not Allowed")
		return

	# Serve the requested file
	if _web_files.has(path):
		var content = _web_files[path]
		var content_type = _get_content_type(path)
		print("[HTTPServer] Serving: ", path, " (", content.length(), " bytes, ", content_type, ")")
		_send_response(stream, 200, content_type, content)
	else:
		print("[HTTPServer] File not found: ", path)
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
	# Root path should be treated as HTML
	if path == "/" or path == "/index.html" or path.ends_with(".html"):
		return "text/html"
	elif path.ends_with(".css"):
		return "text/css"
	elif path.ends_with(".js"):
		return "application/javascript"
	else:
		return "text/plain"
