extends RefCounted

var status := ""
var code := ""
var _job: Thread
var _wanted := false
var _device: UPNPDevice
var _port := 0


func start(internal_port: int) -> void:
	if _job != null or _device != null:
		return
	status = "Checking your router…"
	_wanted = true
	_job = Thread.new()
	if _job.start(_find_gateway.bind(internal_port)) != OK:
		_job = null
		status = "Could not start router setup."


func poll() -> void:
	if _job == null or _job.is_alive():
		return
	var result: Variant = _job.wait_to_finish()
	_job = null
	if result is Dictionary:
		status = result.text
		if result.has("device"):
			_device = result.device
			_port = result.port
			code = result.invite
			if not _wanted:
				stop()


func stop() -> void:
	_wanted = false
	code = ""
	if _device == null:
		return
	_job = Thread.new()
	if _job.start(_remove_mapping.bind(_device, _port)) != OK:
		_job = null
	_device = null
	_port = 0


func shutdown() -> void:
	stop()
	while _job != null:
		var result: Variant = _job.wait_to_finish()
		_job = null
		if result is Dictionary and result.has("device"):
			_device = result.device
			_port = result.port
			stop()


static func _remove_mapping(device: UPNPDevice, port: int) -> void:
	device.delete_port_mapping(port, "UDP")


static func _find_gateway(internal_port: int) -> Dictionary:
	var upnp := UPNP.new()
	if upnp.discover(1800) != UPNP.UPNP_RESULT_SUCCESS:
		return {"text": "Automatic forwarding is unavailable on this network."}
	var gateway := upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		return {"text": "No router with automatic forwarding was found."}
	var address := gateway.query_external_address()
	if not _public_ipv4(address):
		return {"text": "This connection needs a public server or a shared VPN."}
	var port := randi_range(49152, 65535)
	if gateway.add_port_mapping(port, internal_port, "Mazeikiai private room", "UDP", 3600) != UPNP.UPNP_RESULT_SUCCESS:
		return {"text": "The router did not open the port."}
	return {"device": gateway, "port": port, "invite": "mazeikiai://%s:%d" % [address, port],
		"text": "Internet invite ready for copying."}


static func _public_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or address.contains(":"):
		return false
	var numbers := address.split(".")
	var a := int(numbers[0])
	var b := int(numbers[1])
	return a >= 1 and a < 224 and a not in [10, 127] and not (a == 192 and b == 168) \
		and not (a == 172 and b >= 16 and b <= 31) and not (a == 100 and b >= 64 and b <= 127) \
		and not (a == 169 and b == 254)

