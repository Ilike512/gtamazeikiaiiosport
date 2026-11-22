extends Node3D

const PlayerScene = preload("res://scenes/player/Player.tscn")
const CarScene = preload("res://scenes/vehicles/BasicCar.tscn")
const HelicopterScene = preload("res://scenes/vehicles/Helicopter.tscn")
const Car = preload("res://scripts/vehicles/BasicCar.gd")

var characters: Array = []
var _avatars: Dictionary = {}


func _process(delta: float) -> void:
	var me := multiplayer.get_unique_id()
	for id: int in _avatars.keys():
		if id == me or not SessionManager.roster.has(id):
			_avatars[id].root.queue_free()
			_avatars.erase(id)
	for id: int in SessionManager.roster:
		var pose: Dictionary = SessionManager.poses.get(id, {})
		if id == me or pose.is_empty():
			continue
		if not _avatars.has(id):
			_add_avatar(id, pose.at)
		_update_avatar(_avatars[id], pose, delta)


func car_for(player_id: int) -> RigidBody3D:
	var view: Dictionary = _avatars.get(player_id, {})
	if view.is_empty() or not is_instance_valid(view.car) or not view.root.visible:
		return null
	return view.car


func closest_passenger_car(at: Vector3) -> int:
	var nearest_sq := 4.35 ** 2
	var nearest := 0
	for player_id: int in _avatars:
		var vehicle := car_for(player_id)
		var pose: Dictionary = SessionManager.poses.get(player_id, {})
		if vehicle == null or pose.is_empty() or float(pose.pace) > 3.0 or vehicle.global_basis.y.y < 0.65:
			continue
		var distance := vehicle.global_position.distance_squared_to(at)
		if distance < nearest_sq:
			nearest_sq = distance
			nearest = player_id
	return nearest


func _add_avatar(id: int, at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	var avatar: CharacterBody3D = PlayerScene.instantiate()
	root.add_child(avatar)
	avatar.set_physics_process(false)
	avatar.collision_layer = 0
	avatar.collision_mask = 0
	var nameplate := Label3D.new()
	nameplate.position.y = 2.15
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.pixel_size = 0.004
	nameplate.font_size = 35
	nameplate.outline_size = 8
	nameplate.modulate = Color("#a7ffde")
	nameplate.text = SessionManager.roster[id]
	root.add_child(nameplate)
	_avatars[id] = {"root": root, "player": avatar, "nameplate": nameplate, "character": -1, "vehicle": "", "car": null, "helicopter": null}


func _update_avatar(view: Dictionary, pose: Dictionary, delta: float) -> void:
	var root: Node3D = view.root
	var avatar: CharacterBody3D = view.player
	var nameplate: Label3D = view.nameplate
	root.visible = Time.get_ticks_msec() - int(pose.received) < 20000
	if not root.visible:
		return
	var at: Vector3 = pose.at
	var amount := 1.0 - exp(-delta * 17.0)
	root.position = at if root.position.distance_squared_to(at) > 100.0 else root.position.lerp(at, amount)
	var index := mini(int(pose.character), characters.size() - 1)
	if view.character != index:
		view.character = index
		avatar.set_seated(false)
		avatar.apply_character(characters[index])
		avatar.set_seated(not str(view.vehicle).is_empty())
		avatar.set_physics_process(false)
		avatar.collision_layer = 0
		avatar.collision_mask = 0
	var vehicle := str(pose.vehicle)
	if vehicle not in ["helicopter", SessionManager.PASSENGER_POSE] and not Car.VARIANTS.has(vehicle):
		vehicle = ""
	if vehicle != view.vehicle:
		_change_vehicle(view, vehicle)
	var remote_car: RigidBody3D = view.car
	var remote_helicopter: CharacterBody3D = view.helicopter
	if remote_helicopter != null:
		remote_helicopter.basis = remote_helicopter.basis.slerp(Basis(pose.car_basis), amount).orthonormalized()
		avatar.hide()
		nameplate.position.y = 3.4
	elif remote_car != null:
		var rotation: Quaternion = pose.car_basis
		remote_car.basis = remote_car.basis.slerp(Basis(rotation), amount).orthonormalized()
		avatar.show()
		avatar.global_transform = remote_car.driver_avatar_transform()
		avatar.update_driver_pose(0.0, delta)
		nameplate.position.y = 1.5
	elif vehicle == SessionManager.PASSENGER_POSE:
		avatar.show()
		avatar.position = Vector3.ZERO
		avatar.basis = Basis(pose.car_basis)
		avatar.update_driver_pose(0.0, delta)
		nameplate.position.y = 1.5
	else:
		avatar.show()
		avatar.position = Vector3.ZERO
		avatar.rotation = Vector3(0, lerp_angle(avatar.rotation.y, float(pose.yaw), amount), 0)
		avatar.update_network_pose(float(pose.pace), delta)
		nameplate.position.y = 2.15


func _change_vehicle(view: Dictionary, vehicle: String) -> void:
	var old: RigidBody3D = view.car
	if is_instance_valid(old):
		old.queue_free()
	view.car = null
	if is_instance_valid(view.helicopter):
		view.helicopter.queue_free()
	view.helicopter = null
	if vehicle == "helicopter":
		var remote: CharacterBody3D = HelicopterScene.instantiate()
		remote.replica = true
		remote.occupied = true
		remote.collision_layer = 0
		remote.collision_mask = 0
		view.root.add_child(remote)
		view.helicopter = remote
	elif Car.VARIANTS.has(vehicle):
		var remote_car: RigidBody3D = CarScene.instantiate()
		remote_car.variant = vehicle
		remote_car.freeze = true
		remote_car.process_mode = Node.PROCESS_MODE_DISABLED
		view.root.add_child(remote_car)
		remote_car.collision_layer = 0
		remote_car.collision_mask = 0
		view.car = remote_car
	view.vehicle = vehicle
	view.player.set_seated(not vehicle.is_empty())
	view.player.set_physics_process(false)
	view.player.collision_layer = 0
	view.player.collision_mask = 0

