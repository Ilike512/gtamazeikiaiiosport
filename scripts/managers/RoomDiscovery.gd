extends RefCounted

const PORT := 31941
const PREFIX := "mazeikiai-room-2"
var _advertiser: PacketPeerUDP
var _scanner: PacketPeerUDP
var _room: Dictionary = {}
var _found: Dictionary = {}
var _token := ""
var _broadcast_at := 0
var _scan_targets := PackedStringArray()


static func supports_broadcast() -> bool:
	return not OS.has_feature("ios")


func advertise(username: String, port: int, locked: bool) -> void:
	stop_advertising()
	if not supports_broadcast():
		return
	_room = {"name": username, "port": port, "locked": locked}
	_advertiser = PacketPeerUDP.new()
	if _advertiser.bind(PORT, "0.0.0.0") != OK:
		_advertiser = null


func stop_advertising() -> void:
	if _advertiser != null:
		_advertiser.close()
	_advertiser = null


func begin_scan() -> void:
	stop_scan()
	if not supports_broadcast():
		return
	_scanner = PacketPeerUDP.new()
	if _scanner.bind(0, "0.0.0.0") != OK:
		_scanner = null
		return
	_scanner.set_broadcast_enabled(true)
	_scan_targets = ["255.255.255.255", "127.0.0.1"]
	# Also try the directed broadcast for common /24 Wi-Fi networks.
	for address: String in IP.get_local_addresses():
		var octets := address.split(".")
		if octets.size() != 4 or not address.is_valid_ip_address() or address.contains(":") or octets[0] == "127":
			continue
		var broadcast := address.get_slice(".", 0) + "." + octets[1] + "." + octets[2] + ".255"
		if not _scan_targets.has(broadcast):
			_scan_targets.append(broadcast)
	_token = Crypto.new().generate_random_bytes(8).hex_encode()
	_broadcast_at = 0


func stop_scan() -> void:
	if _scanner != null:
		_scanner.close()
	_scanner = null
	_found.clear()


func rooms() -> Array:
	var now := Time.get_ticks_msec()
	for key: String in _found.keys():
		if now - int(_found[key].heard) > 5000:
			_found.erase(key)
	var result := _found.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).nocasecmp_to(str(b.name)) < 0)
	return result


func poll() -> void:
	if _advertiser != null:
		_answer_scan()
	if _scanner != null:
		_listen_for_rooms()


func _answer_scan() -> void:
	for index in mini(8, _advertiser.get_available_packet_count()):
		var query := _advertiser.get_packet()
		if query.size() > 72:
			continue
		var words := query.get_string_from_utf8().split(" ", false, 2)
		if words.size() != 2 or words[0] != PREFIX or words[1].length() != 16 or not words[1].is_valid_hex_number():
			continue
		if _advertiser.set_dest_address(_advertiser.get_packet_ip(), _advertiser.get_packet_port()) != OK:
			continue
		_advertiser.put_packet(JSON.stringify({"token": words[1], "room": _room}).to_utf8_buffer())


func _listen_for_rooms() -> void:
	var now := Time.get_ticks_msec()
	if now >= _broadcast_at:
		_broadcast_at = now + 1400
		var query := ("%s %s" % [PREFIX, _token]).to_utf8_buffer()
		for address: String in _scan_targets:
			if _scanner.set_dest_address(address, PORT) == OK:
				_scanner.put_packet(query)
	for index in mini(16, _scanner.get_available_packet_count()):
		var data := _scanner.get_packet()
		if data.size() > 320:
			continue
		var response: Variant = JSON.parse_string(data.get_string_from_utf8())
		if not response is Dictionary or response.get("token") != _token:
			continue
		var room: Variant = response.get("room")
		if not room is Dictionary or room.get("port", 0) is not float:
			continue
		var port := int(room.port)
		var username := str(room.get("name", "")).left(20)
		if port <= 0 or port > 65535 or username.is_empty():
			continue
		var address := _scanner.get_packet_ip().trim_prefix("::ffff:")
		var key := "%s:%d" % [address, port]
		if _found.size() < 24 or _found.has(key):
			_found[key] = {"address": address, "port": port, "name": username, "locked": room.get("locked") == true, "heard": now}

