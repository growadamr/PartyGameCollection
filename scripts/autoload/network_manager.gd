extends Node

## Handles WebSocket networking for host and client modes

signal connection_established()
signal connection_failed(reason: String)
signal connection_closed()
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal message_received(peer_id: int, data: Dictionary)

const DEFAULT_PORT = 8080
const CONNECTION_TIMEOUT = 10.0  # seconds

var _server: TCPServer
var _clients: Dictionary = {}  # peer_id -> WebSocketPeer
var _client: WebSocketPeer
var _is_server: bool = false
var _is_connected: bool = false
var _next_peer_id: int = 1
var _connection_timer: float = 0.0
var _is_connecting: bool = false

func _process(_delta: float) -> void:
	if _is_server:
		_process_server()
	elif _client:
		_process_client()

# ============ SERVER MODE ============

func start_server(port: int = DEFAULT_PORT) -> Error:
	_server = TCPServer.new()
	# Bind to all network interfaces ("*") to accept connections from other devices
	var err = _server.listen(port, "*")
	if err != OK:
		push_error("Failed to start server on port %d: %s" % [port, error_string(err)])
		return err

	_is_server = true
	print("Server started on port ", port, " (listening on all interfaces)")
	return OK

func stop_server() -> void:
	if _server:
		_server.stop()
		_server = null

	for peer_id in _clients:
		_clients[peer_id].close()
	_clients.clear()

	_is_server = false
	print("Server stopped")

func _process_server() -> void:
	if not _server:
		return

	# Accept new connections
	while _server.is_connection_available():
		var tcp = _server.take_connection()
		if tcp:
			var ws = WebSocketPeer.new()
			ws.accept_stream(tcp)
			var peer_id = _next_peer_id
			_next_peer_id += 1
			_clients[peer_id] = ws
			print("New client connecting, assigned peer_id: ", peer_id)

	# Process existing clients
	var to_remove = []
	for peer_id in _clients:
		var ws: WebSocketPeer = _clients[peer_id]
		ws.poll()

		var state = ws.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					var packet = ws.get_packet()
					var text = packet.get_string_from_utf8()
					var data = JSON.parse_string(text)
					if data:
						_handle_server_message(peer_id, data)

			WebSocketPeer.STATE_CLOSING:
				pass

			WebSocketPeer.STATE_CLOSED:
				to_remove.append(peer_id)
				player_disconnected.emit(peer_id)
				print("Client disconnected: ", peer_id)

	for peer_id in to_remove:
		_clients.erase(peer_id)

func _handle_server_message(peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"join_request":
			_handle_join_request(peer_id, data)
		_:
			message_received.emit(peer_id, data)

func _handle_join_request(peer_id: int, data: Dictionary) -> void:
	var player_name = data.get("name", "Unknown")
	var character_id = data.get("character", 0)

	# Add player to game manager
	var player_uuid = "peer_%d" % peer_id
	GameManager.add_player(player_uuid, player_name, character_id)

	# Send confirmation
	send_to_client(peer_id, {
		"type": "join_accepted",
		"player_id": player_uuid,
		"session_id": GameManager.session_id,
		"players": _get_players_data()
	})

	# Notify all other clients
	broadcast({
		"type": "player_joined",
		"player_id": player_uuid,
		"name": player_name,
		"character": character_id
	}, peer_id)

	player_connected.emit(peer_id)

func _get_players_data() -> Dictionary:
	var data = {}
	for player_id in GameManager.players:
		var p = GameManager.players[player_id]
		data[player_id] = {
			"name": p["name"],
			"character": p["character"],
			"score": p["score"],
			"is_host": p["is_host"]
		}
	return data

func send_to_client(peer_id: int, data: Dictionary) -> void:
	if _clients.has(peer_id):
		var json = JSON.stringify(data)
		_clients[peer_id].send_text(json)

func broadcast(data: Dictionary, exclude_peer: int = -1) -> void:
	var json = JSON.stringify(data)
	for peer_id in _clients:
		if peer_id != exclude_peer:
			_clients[peer_id].send_text(json)

# ============ CLIENT MODE ============

func connect_to_server(address: String, port: int = DEFAULT_PORT) -> Error:
	_client = WebSocketPeer.new()
	var url = "ws://%s:%d" % [address, port]

	var err = _client.connect_to_url(url)
	if err != OK:
		push_error("Failed to connect to %s: %s" % [url, error_string(err)])
		_client = null
		return err

	_is_connecting = true
	_connection_timer = 0.0
	print("Connecting to ", url)
	return OK

func disconnect_from_server() -> void:
	if _client:
		_client.close()
		_client = null
	_is_connected = false
	_is_connecting = false
	connection_closed.emit()

func _process_client() -> void:
	_client.poll()

	var state = _client.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			# Track connection timeout
			_connection_timer += get_process_delta_time()
			if _connection_timer > CONNECTION_TIMEOUT:
				print("Connection timeout after ", CONNECTION_TIMEOUT, " seconds")
				_client.close()
				_client = null
				_is_connecting = false
				connection_failed.emit("Connection timeout")

		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_is_connected = true
				_is_connecting = false
				connection_established.emit()
				print("Connected to server")

			while _client.get_available_packet_count() > 0:
				var packet = _client.get_packet()
				var text = packet.get_string_from_utf8()
				var data = JSON.parse_string(text)
				if data:
					_handle_client_message(data)

		WebSocketPeer.STATE_CLOSING:
			pass

		WebSocketPeer.STATE_CLOSED:
			var code = _client.get_close_code()
			var reason = _client.get_close_reason()
			_is_connecting = false
			if _is_connected:
				connection_closed.emit()
			else:
				var msg = "Connection failed (code: %d)" % code
				if code == -1 or code == 1006:
					msg = "Connection failed - server not reachable. Check IP address and ensure host is running."
				elif reason:
					msg += " - " + reason
				connection_failed.emit(msg)
			_client = null
			_is_connected = false

func _handle_client_message(data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"join_accepted":
			GameManager.local_player_id = data.get("player_id", "")
			GameManager.session_id = data.get("session_id", "")
			# Sync all players
			var players = data.get("players", {})
			for player_id in players:
				var p = players[player_id]
				GameManager.players[player_id] = p

		"player_joined":
			var player_id = data.get("player_id", "")
			GameManager.add_player(
				player_id,
				data.get("name", ""),
				data.get("character", 0)
			)

		"player_left":
			var player_id = data.get("player_id", "")
			GameManager.remove_player(player_id)

	# Always emit message_received so scene scripts can react to all messages
	message_received.emit(0, data)

func send_to_server(data: Dictionary) -> void:
	if _client and _is_connected:
		var json = JSON.stringify(data)
		_client.send_text(json)

func request_join(player_name: String, character_id: int) -> void:
	send_to_server({
		"type": "join_request",
		"name": player_name,
		"character": character_id
	})

# ============ UTILITIES ============

func is_server() -> bool:
	return _is_server

func is_connected_to_server() -> bool:
	return _is_connected

func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Prefer IPv4 non-localhost addresses
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"
