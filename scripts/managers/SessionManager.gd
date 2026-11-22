extends Node

signal connected
signal ended(reason: String)
signal roster_changed
signal chat_received(username: String, message: String)
signal version_warning(server_build: int)
signal player_hit(damage: float, attacker: String)
signal passenger_seat_changed(driver: int, reason: String)
signal connection_notice(message: String)

const EquipmentProfiles = preload("res://scripts/world/EquipmentProfiles.gd")
const GAME_BUILD := 5
const CHEATS_EVERYONE := 0
const CHEATS_HOST := 1
const CHEATS_DISABLED := 2
const PVP_BUILD := 2
const PASSENGER_BUILD := 4
const PASSENGER_POSE := "passenger"
const CAR_POSES := ["hatchback", "sedan", "van", "coupe", "limbo", "police"]

const PORT := 31940
const MAX_PLAYERS := 8
const PROTOCOL := "mazeikiai-coop-2"
const ANNOUNCED_CODES := ["map", "skip", "skipad", "advert", "ihopeidontfall", "givemeeverything", "helli", "limbo"]
const RoomDiscovery = preload("res://scripts/managers/RoomDiscovery.gd")
const InternetInvite = preload("res://scripts/managers/InternetInvite.gd")

var active := false
var connecting := false
var roster: Dictionary = {}
var poses: Dictionary = {}
var history: Array[Array] = []
var spawn_slot := 0
var menu_notice := ""
var host_port := PORT
var discovery := RoomDiscovery.new()
var internet := InternetInvite.new()

var _api: SceneMultiplayer
var _connection: ENetMultiplayerPeer
var _host := false
var _connect_deadline := 0
var _retry_until := 0
var _retry_at := 0
var _server_address := ""
var _server_port := PORT
var cheat_policy := CHEATS_EVERYONE
var _username := ""
var _password := ""
var _challenges: Dictionary = {}
var _pending_names: Dictionary = {}
var _slots: Dictionary = {}
var _last_chat: Dictionary = {}
var _last_cheat: Dictionary = {}
var _last_pose: Dictionary = {}
var _local_chat_at := -1000
var _version_challenge: Dictionary = {}
var _builds: Dictionary = {}
var _last_strike: Dictionary = {}
var _passenger_drivers: Dictionary = {}
var _last_seat_request: Dictionary = {}
var _server_build := 1
var combat_space: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_api = multiplayer as SceneMultiplayer
	_api.allow_object_decoding = false
	_api.server_relay = false
	_api.auth_callback = _authenticate
	_api.auth_timeout = 40.0
	_api.peer_authenticating.connect(_start_auth)
	_api.peer_authentication_failed.connect(_auth_failed)
	_api.peer_connected.connect(_peer_joined)
	_api.peer_packet.connect(_on_game_packet)
	_api.peer_disconnected.connect(_peer_left)
	_api.connected_to_server.connect(_joined)
	_api.connection_failed.connect(_connection_failed)
	_api.server_disconnected.connect(_host_left)


func valid_name(username: String) -> bool:
	if username.is_empty() or username.length() > 20:
		return false
	for index in username.length():
		var code := username.unicode_at(index)
		if code < 32 or code == 127 or (code >= 0x202a and code <= 0x202e) or (code >= 0x2066 and code <= 0x2069):
			return false
	return true


func host_room(username: String, password: String, port: int, dedicated := false, policy := CHEATS_EVERYONE) -> String:
	if active or connecting:
		return "Leave your current session first."
	username = username.strip_edges()
	if not valid_name(username) or not _valid_port(port) or password.length() > 64:
		return "Enter a username and a port between 1 and 65535."
	var transport := ENetMultiplayerPeer.new()
	var result := transport.create_server(port, MAX_PLAYERS if dedicated else MAX_PLAYERS - 1, 3)
	if result != OK:
		return "Could not open UDP port %d. %s." % [port, error_string(result)]
	cheat_policy = clampi(policy, CHEATS_EVERYONE, CHEATS_DISABLED)
	_configure(transport, username, password, true)
	active = true
	if not dedicated:
		roster[1] = username
		_slots[1] = 0
		discovery.advertise(username, port, not password.is_empty())
	host_port = port
	connected.emit()
	return ""


func join_room(username: String, address: String, password: String, port: int) -> String:
	if active or connecting:
		return "Leave your current session first."
	username = username.strip_edges()
	address = address.strip_edges()
	if not valid_name(username) or not _valid_port(port) or address.is_empty() or address.length() > 253 or password.length() > 64:
		return "Enter your username, the host address and a valid UDP port."
	var transport := ENetMultiplayerPeer.new()
	var result := transport.create_client(address, port, 3)
	if result != OK:
		return "Could not start the connection. %s." % error_string(result)
	_server_address = address
	_server_port = port
	_configure(transport, username, password, false)
	connecting = true
	_connect_deadline = Time.get_ticks_msec() + 15000
	return ""


func _configure(transport: ENetMultiplayerPeer, username: String, password: String, hosting: bool) -> void:
	menu_notice = ""
	_connection = transport
	_host = hosting
	_username = username
	_password = password
	_api.multiplayer_peer = transport


func leave() -> void:
	_retry_until = 0
	_retry_at = 0
	_server_address = ""
	cheat_policy = CHEATS_EVERYONE
	discovery.stop_advertising()
	discovery.stop_scan()
	internet.stop()
	connecting = false
	_connect_deadline = 0
	active = false
	_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _connection != null:
		_connection.close()
	_connection = null
	_host = false
	_password = ""
	_username = ""
	spawn_slot = 0
	_local_chat_at = -1000
	roster.clear()
	poses.clear()
	_version_challenge.clear()
	_builds.clear()
	_last_strike.clear()
	_passenger_drivers.clear()
	_last_seat_request.clear()
	_server_build = 1
	history.clear()
	_challenges.clear()
	_pending_names.clear()
	_slots.clear()
	_last_chat.clear()
	_last_cheat.clear()
	_last_pose.clear()


func _process(_delta: float) -> void:
	discovery.poll()
	internet.poll()
	var now := Time.get_ticks_msec()
	if _retry_until > 0 and now >= _retry_until:
		leave()
		ended.emit("Could not reconnect. You can keep playing offline.")
		return
	if _retry_at > 0 and now >= _retry_at:
		_retry_at = 0
		var peer := ENetMultiplayerPeer.new()
		if peer.create_client(_server_address, _server_port, 3) == OK:
			_configure(peer, _username, _password, false)
			connecting = true
			_connect_deadline = now + 6500
		else:
			_retry_at = now + 2200
	if connecting and _connect_deadline > 0 and Time.get_ticks_msec() >= _connect_deadline:
		_fail("No response from the host. For Wi-Fi, try the host’s LAN invite and check the host firewall.")


func _exit_tree() -> void:
	internet.shutdown()


func is_hosting() -> bool:
	return active and _host


func invite() -> String:
	var address := "127.0.0.1"
	for candidate: String in IP.get_local_addresses():
		if not candidate.contains(".") or candidate.begins_with("127.") or candidate.begins_with("169.254."):
			continue
		address = candidate
		if candidate.begins_with("192.168."):
			break
	return "mazeikiai://%s:%d" % [address, host_port]


func invitation_endpoint(value: String, default_port: int) -> Dictionary:
	value = value.strip_edges().trim_prefix("mazeikiai://").trim_suffix("/")
	var address := value
	var port := default_port
	var divider := value.rfind(":")
	var bracket := value.find("]")
	if value.begins_with("[") and bracket > 1:
		address = value.substr(1, bracket - 1)
		if divider == bracket + 1:
			port = int(value.substr(divider + 1)) if value.substr(divider + 1).is_valid_int() else 0
	elif divider >= 0 and value.count(":") == 1:
		address = value.left(divider)
		port = int(value.substr(divider + 1)) if value.substr(divider + 1).is_valid_int() else 0
	return {"address": address, "port": port}


func _valid_port(port: int) -> bool:
	return port >= 1 and port <= 65535


func _start_auth(id: int) -> void:
	var peer := _connection.get_peer(id)
	if peer != null:
		# Give the other device time to finish loading or recover from a brief Wi-Fi interruption.
		peer.set_timeout(32, 12000, 45000)
		peer.ping_interval(1000)
	_connect_deadline = 0
	if _host:
		var nonce := Crypto.new().generate_random_bytes(24).hex_encode()
		_challenges[id] = nonce
		_send_auth(id, {"protocol": PROTOCOL, "nonce": nonce, "build": GAME_BUILD})


func _authenticate(id: int, data: PackedByteArray) -> void:
	if data.size() > 512:
		_api.disconnect_peer(id)
		return
	var packet: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not packet is Dictionary:
		_api.disconnect_peer(id)
		return
	if _host:
		_authenticate_guest(id, packet)
	elif id == 1 and connecting:
		_authenticate_host(packet)


func _authenticate_guest(id: int, packet: Dictionary) -> void:
	var nonce := str(_challenges.get(id, ""))
	var username := str(packet.get("name", "")).strip_edges()
	var proof := str(packet.get("proof", ""))
	var failure := ""
	if nonce.is_empty() or packet.get("protocol") != PROTOCOL:
		failure = "The host and guest need the same game version."
	elif cheat_policy != CHEATS_EVERYONE and int(packet.get("build", 1)) < 5:
		failure = "Update to BETA 0.5 to join this room with restricted cheats."
	elif not valid_name(username):
		failure = "Enter a username with 1–20 characters."
	elif _name_taken(username):
		failure = "That username is already in the room."
	elif not Crypto.new().constant_time_compare(proof.to_utf8_buffer(), _proof(nonce, username).to_utf8_buffer()):
		failure = "Incorrect room password."
	if not failure.is_empty():
		_send_auth(id, {"error": failure})
		return
	_challenges.erase(id)
	_builds[id] = clampi(int(packet.get("build", 1)), 1, GAME_BUILD)
	for slot in range(MAX_PLAYERS):
		if not _slots.values().has(slot):
			_slots[id] = slot
			_pending_names[id] = username
			_send_auth(id, {"accepted": true, "slot": slot, "cheats": cheat_policy})
			_api.complete_auth(id)
			return
	_send_auth(id, {"error": "The room is full."})


func _authenticate_host(packet: Dictionary) -> void:
	if packet.has("error"):
		_fail.call_deferred(str(packet.error).left(120))
	elif packet.get("accepted") == true:
		spawn_slot = clampi(int(packet.get("slot", 0)), 0, MAX_PLAYERS - 1)
		cheat_policy = clampi(int(packet.get("cheats", CHEATS_EVERYONE)), CHEATS_EVERYONE, CHEATS_DISABLED)
		_api.complete_auth(1)
	elif packet.get("protocol") == PROTOCOL and str(packet.get("nonce", "")).length() == 48:
		_server_build = int(packet.get("build", 1))
		if _server_build > GAME_BUILD and _retry_until == 0:
			_version_challenge = packet
			version_warning.emit(int(packet.build))
		else:
			_send_guest_proof(str(packet.nonce))
	else:
		_fail.call_deferred("The host and guest need the same game version.")


func respond_to_version(continue_join: bool) -> void:
	if _version_challenge.is_empty() or not connecting:
		return
	var nonce := str(_version_challenge.nonce)
	_version_challenge.clear()
	if continue_join:
		_send_guest_proof(nonce)
	else:
		_fail("Join cancelled.")


func _send_guest_proof(nonce: String) -> void:
	_send_auth(1, {"protocol": PROTOCOL, "name": _username, "build": GAME_BUILD, "proof": _proof(nonce, _username)})


func _send_auth(id: int, payload: Dictionary) -> void:
	_api.send_auth(id, JSON.stringify(payload).to_utf8_buffer())


func _proof(nonce: String, username: String) -> String:
	var key := ("multiplayer-room:" + _password).to_utf8_buffer()
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key, (nonce + ":" + username).to_utf8_buffer()).hex_encode()


func _name_taken(username: String) -> bool:
	for existing: String in roster.values() + _pending_names.values():
		if existing.nocasecmp_to(username) == 0:
			return true
	return false


func _peer_joined(id: int) -> void:
	if not _host or not _pending_names.has(id):
		return
	var username: String = _pending_names[id]
	_pending_names.erase(id)
	roster[id] = username
	_send_roster.rpc(roster)
	roster_changed.emit()
	_publish_chat("", username + " joined the session.")
	if int(_builds.get(id, 1)) < GAME_BUILD:
		_receive_chat.rpc_id(id, "", "You are on an older build. You can stay in the room, but newer features may be unavailable.")


func _peer_left(id: int) -> void:
	if not _host:
		return
	_slots.erase(id)
	_last_chat.erase(id)
	_last_cheat.erase(id)
	_last_pose.erase(id)
	_builds.erase(id)
	_last_strike.erase(id)
	poses.erase(id)
	var username := str(roster.get(id, ""))
	roster.erase(id)
	_last_seat_request.erase(id)
	_passenger_drivers.erase(id)
	_release_driver_seat(id)
	if not username.is_empty():
		_send_roster.rpc(roster)
		roster_changed.emit()
		_publish_chat("", username + " left the session.")


func _auth_failed(id: int) -> void:
	if _host:
		_challenges.erase(id)
		_pending_names.erase(id)
		_slots.erase(id)
	elif connecting:
		_fail.call_deferred("The room did not accept the connection.")


func _joined() -> void:
	var rejoined := _retry_until > 0
	connecting = false
	_connect_deadline = 0
	_retry_until = 0
	_retry_at = 0
	active = true
	if rejoined:
		connection_notice.emit("Reconnected to the host.")
	else:
		connected.emit()


func _connection_failed() -> void:
	if connecting:
		_fail.call_deferred("Could not reach the host. Check the address, UDP port and firewall.")


func _host_left() -> void:
	if active and not _host:
		_begin_reconnect.call_deferred()
	elif connecting:
		_fail.call_deferred("Connection to the host was lost.")


func _begin_reconnect() -> void:
	if not active or _host:
		return
	if _retry_until == 0:
		_retry_until = Time.get_ticks_msec() + 65000
		connection_notice.emit("Connection lost. Reconnecting…")
		passenger_seat_changed.emit(0, "")
	_queue_retry()


func _queue_retry() -> void:
	connecting = true
	_connect_deadline = 0
	_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _connection != null:
		_connection.close()
	_connection = null
	poses.clear()
	_retry_at = Time.get_ticks_msec() + 1800


func cheats_allowed() -> bool:
	return not active or cheat_policy == CHEATS_EVERYONE or (is_hosting() and cheat_policy == CHEATS_HOST)


func _fail(reason: String) -> void:
	if _retry_until > 0:
		_queue_retry()
		return
	if active or connecting:
		leave()
		ended.emit(reason)


@rpc("authority", "call_remote", "reliable", 0)
func _send_roster(players: Dictionary) -> void:
	roster = players
	for id: int in poses.keys():
		if not roster.has(id):
			poses.erase(id)
	roster_changed.emit()


func send_chat(message: String) -> bool:
	message = _clean_message(message)
	var now := Time.get_ticks_msec()
	if not active or connecting or message.is_empty() or now - _local_chat_at < 650:
		return false
	_local_chat_at = now
	if _host:
		_publish_chat(_username, message)
	else:
		_submit_chat.rpc_id(1, message)
	return true


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_chat(message: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var now := Time.get_ticks_msec()
	if not _host or not roster.has(id) or now - int(_last_chat.get(id, -1000)) < 600:
		return
	message = _clean_message(message)
	if not message.is_empty():
		_last_chat[id] = now
		_publish_chat(roster[id], message)


func announce_cheat(code: String) -> void:
	if not active or connecting or not cheats_allowed() or code not in ANNOUNCED_CODES:
		return
	if _host:
		_publish_cheat(1, code)
	else:
		_submit_cheat_notice.rpc_id(1, code)


@rpc("any_peer", "call_remote", "reliable", 0)
func _submit_cheat_notice(code: String) -> void:
	if _host and cheat_policy == CHEATS_EVERYONE and code in ANNOUNCED_CODES:
		_publish_cheat(multiplayer.get_remote_sender_id(), code)


func _publish_cheat(id: int, code: String) -> void:
	var now := Time.get_ticks_msec()
	if not roster.has(id) or now - int(_last_cheat.get(id, -1000)) < 350:
		return
	_last_cheat[id] = now
	var announcement := "%s USED %s" % [roster[id], code.to_upper()]
	_receive_cheat_notice(announcement)
	_receive_cheat_notice.rpc(announcement)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_cheat_notice(announcement: String) -> void:
	_record_chat(["", announcement, true])


func _clean_message(message: String) -> String:
	return message.left(180).replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()


func _publish_chat(username: String, message: String) -> void:
	_receive_chat(username, message)
	_receive_chat.rpc(username, message)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_chat(username: String, message: String) -> void:
	_record_chat([username, message])


func _record_chat(entry: Array) -> void:
	history.append(entry)
	if history.size() > 32:
		history.pop_front()
	chat_received.emit(entry[0], entry[1])


func attack_players(kind: String, at: Vector3, direction: Vector3) -> void:
	if not active or connecting:
		return
	var packet := ["attack", kind, SaveManager.vector_data(at), SaveManager.vector_data(direction)]
	if _host:
		_check_strike(1, packet)
	else:
		_api.send_bytes(JSON.stringify(packet).to_utf8_buffer(), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)


func _on_game_packet(peer: int, packet: PackedByteArray) -> void:
	if not active or packet.size() > 240:
		return
	var payload: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if not payload is Array or payload.size() != 4:
		return
	if _host and payload[0] == "attack":
		_check_strike(peer, payload)
	elif _host and payload[0] == "seat" and typeof(payload[1]) in [TYPE_INT, TYPE_FLOAT]:
		_update_passenger_seat(peer, int(payload[1]))
	elif not _host and peer == 1 and payload[0] == "seat":
		passenger_seat_changed.emit(int(payload[1]), str(payload[2]))
	elif not _host and peer == 1 and payload[0] == "hit":
		player_hit.emit(clampf(float(payload[1]), 0.0, 35.0), str(payload[2]).left(20))


func supports_passengers() -> bool:
	return active and not connecting and (_host or _server_build >= PASSENGER_BUILD)


func seat_request(driver: int) -> void:
	if not supports_passengers():
		return
	if _host:
		_update_passenger_seat(1, driver)
	else:
		_send_seat_packet(1, driver, "")


func _update_passenger_seat(rider: int, driver: int) -> void:
	if not roster.has(rider):
		return
	if driver == 0:
		_passenger_drivers.erase(rider)
		_reply_seat(rider, 0, "")
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_seat_request.get(rider, -1000)) < 350:
		return
	_last_seat_request[rider] = now
	var source: Dictionary = poses.get(rider, {})
	var target: Dictionary = poses.get(driver, {})
	if _passenger_drivers.has(rider):
		return
	if rider == driver or target.is_empty() or source.is_empty() or target.vehicle not in CAR_POSES \
			or not str(source.vehicle).is_empty() or now - int(target.received) > 3500 \
			or source.at.distance_to(target.at) > 4.5 or float(target.pace) > 3.0:
		_reply_seat(rider, 0, "Get closer to a stopped player’s car.")
	elif _passenger_drivers.values().has(driver):
		_reply_seat(rider, 0, "The passenger seat is occupied.")
	else:
		_passenger_drivers[rider] = driver
		_reply_seat(rider, driver, "")


func _release_driver_seat(driver: int) -> void:
	var rider: int = _passenger_drivers.find_key(driver) if _passenger_drivers.values().has(driver) else 0
	if rider != 0:
		_passenger_drivers.erase(rider)
		_reply_seat(rider, 0, "")


func _reply_seat(rider: int, driver: int, reason: String) -> void:
	if rider == 1:
		passenger_seat_changed.emit(driver, reason)
	else:
		_send_seat_packet(rider, driver, reason)


func _send_seat_packet(peer: int, driver: int, reason: String) -> void:
	var packet := JSON.stringify(["seat", driver, reason, 0]).to_utf8_buffer()
	_api.send_bytes(packet, peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)


func _check_strike(peer: int, payload: Array) -> void:
	var profile: Array = EquipmentProfiles.STATS.get(str(payload[1]), [])
	var pose: Dictionary = poses.get(peer, {})
	if profile.is_empty() or pose.is_empty() or not str(pose.vehicle).is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_strike.get(peer, -1000)) < int(profile[3]) - 25:
		return
	var from := SaveManager.read_vector(payload[2], Vector3.INF)
	var direction := SaveManager.read_vector(payload[3], Vector3.ZERO)
	if not from.is_finite() or not direction.is_finite() or not is_equal_approx(direction.length(), 1.0):
		return
	if from.distance_squared_to(pose.at + Vector3.UP * 1.3) > 2.9 * 2.9:
		return
	_last_strike[peer] = now
	var length := float(profile[0])
	if is_instance_valid(combat_space):
		var line := PhysicsRayQueryParameters3D.create(from, from + direction * length, 1 | 4)
		var hit := combat_space.get_world_3d().direct_space_state.intersect_ray(line)
		if not hit.is_empty():
			length = from.distance_to(hit.position)
	var victim := 0
	var nearest := length
	var radius := 0.47 if bool(profile[2]) else 0.72
	for id: int in poses:
		if id == peer or not roster.has(id) or int(_builds.get(id, GAME_BUILD)) < PVP_BUILD:
			continue
		var target: Dictionary = poses[id]
		if not str(target.vehicle).is_empty() or now - int(target.received) > 1300:
			continue
		for height: float in [0.62, 1.09, 1.50]:
			var point: Vector3 = target.at + Vector3.UP * height
			var along := (point - from).dot(direction)
			if along > 0 and along < nearest and point.distance_squared_to(from + direction * along) < radius * radius:
				nearest = along
				victim = id
	if victim == 0:
		return
	var strength := clampf(float(profile[1]) * 1.65, 0, 35)
	if victim == 1:
		player_hit.emit(strength, str(roster[peer]))
	else:
		var hit := JSON.stringify(["hit", strength, roster[peer], 0]).to_utf8_buffer()
		_api.send_bytes(hit, victim, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)


func publish_pose(at: Vector3, yaw: float, pace: float, character: int, vehicle: String, car_basis: Quaternion) -> void:
	if not active or connecting:
		return
	if _host:
		_accept_pose(1, at, yaw, pace, character, vehicle, car_basis)
	else:
		_submit_pose.rpc_id(1, at, yaw, pace, character, vehicle, car_basis)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_pose(at: Vector3, yaw: float, pace: float, character: int, vehicle: String, car_basis: Quaternion) -> void:
	if _host:
		_accept_pose(multiplayer.get_remote_sender_id(), at, yaw, pace, character, vehicle, car_basis)


func _accept_pose(id: int, at: Vector3, yaw: float, pace: float, character: int, vehicle: String, car_basis: Quaternion) -> void:
	var now := Time.get_ticks_msec()
	if not roster.has(id) or now - int(_last_pose.get(id, -1000)) < 25:
		return
	if not at.is_finite() or at.abs()[at.abs().max_axis_index()] > 20000.0:
		return
	if not is_finite(yaw) or not is_finite(pace) or not car_basis.is_finite() or car_basis.length_squared() < 0.01:
		return
	_last_pose[id] = now
	if vehicle not in CAR_POSES:
		_release_driver_seat(id)
	var seat := PASSENGER_POSE if _passenger_drivers.has(id) else (vehicle.left(32) if vehicle != PASSENGER_POSE else "")
	_receive_pose(id, at, wrapf(yaw, -PI, PI), clampf(pace, 0.0, 9.0), clampi(character, 0, 1),
		seat, car_basis.normalized())
	var pose: Dictionary = poses[id]
	_receive_pose.rpc(id, pose.at, pose.yaw, pose.pace, pose.character, pose.vehicle, pose.car_basis)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_pose(id: int, at: Vector3, yaw: float, pace: float, character: int, vehicle: String, car_basis: Quaternion) -> void:
	poses[id] = {"at": at, "yaw": yaw, "pace": pace, "character": character,
		"vehicle": vehicle, "car_basis": car_basis, "received": Time.get_ticks_msec()}

