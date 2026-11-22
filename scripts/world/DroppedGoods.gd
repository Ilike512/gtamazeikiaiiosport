extends Node3D

signal game_bomb_burst(at: Vector3)

const Product = preload("res://scripts/world/ProductModel.gd")
const LIMIT := 20

var _items: Array[RigidBody3D] = []
var _drip_timer := 0.0
var district: Node3D


func _physics_process(delta: float) -> void:
	for item: RigidBody3D in _items:
		_keep_above_surface(item)
	_drip_timer -= delta
	if _drip_timer > 0.0 or _items.is_empty():
		return
	_drip_timer = 0.32
	var effects := get_tree().get_first_node_in_group("city_impact")
	if effects == null:
		return
	for item: RigidBody3D in _items:
		if bool(item.get_meta("wet_stain", false)):
			if item.linear_velocity.length_squared() > 1.5:
				effects.drip(item.global_position, 0.09)
		elif item.linear_velocity.length_squared() < 1.0 and effects.blood_near(item.global_position):
			item.set_meta("wet_stain", true)


func _keep_above_surface(item: RigidBody3D) -> void:
	var at := item.global_position
	var previous: Vector3 = item.get_meta("last_position", at)
	item.set_meta("last_position", at)
	if item.sleeping or item.linear_velocity.y >= 0.0:
		return
	var space := get_world_3d().direct_space_state
	var floor_ray := PhysicsRayQueryParameters3D.create(previous, at - Vector3.UP * 0.06, 1, [item.get_rid()])
	var hit := space.intersect_ray(floor_ray)
	if not hit.is_empty() and hit.normal.y > 0.55 and at.y < float(hit.position.y) + 0.06:
		item.global_position = hit.position + Vector3.UP * 0.17
	elif is_instance_valid(district) and at.y > -35.0:
		var floor_y: float = district.elevation.height_at(Vector2(at.x, at.z))
		if at.y >= floor_y - 0.27 or not district.water_sample(at).is_empty():
			return
		item.global_position.y = floor_y + 0.18
	else:
		return
	item.set_meta("last_position", item.global_position)
	item.linear_velocity = item.linear_velocity.slide(Vector3.UP) * 0.67 + Vector3.UP * minf(1.7, -item.linear_velocity.y * 0.27)


func throw(item: Dictionary, origin: Vector3, direction: Vector3, power := 1.0) -> void:
	var body := _spawn(item, origin, direction * 8.5 * power + Vector3.UP * (1.35 + power * 0.95),
		Vector3(2.6, 4.1, -2.3) * power)
	if item.id == "cheat_bomb":
		body.set_meta("live", true)
		get_tree().create_timer(2.25, false, true).timeout.connect(func() -> void:
			if is_instance_valid(body) and not body.is_queued_for_deletion():
				game_bomb_burst.emit(body.global_position)
				take(body)
		)


func drop(item: Dictionary, origin: Vector3, direction: Vector3) -> void:
	_spawn(item, origin, direction * 0.55, Vector3(0.28, 0.21, 0.15))


func _spawn(item: Dictionary, origin: Vector3, movement: Vector3, spin: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = 32
	body.collision_mask = 1 | 4
	body.continuous_cd = true
	body.position = to_local(origin)
	body.set_meta("product", str(item.id))
	body.set_meta("last_position", origin)
	add_child(body)
	var product := Product.new()
	body.add_child(product)
	var span := product.build(item, 0.28)
	body.mass = clampf(0.23 + span.x * span.y * span.z * 68.0, 0.24, 2.2)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = span
	collision.shape = shape
	body.add_child(collision)
	body.linear_velocity = movement
	body.angular_velocity = spin
	_items.append(body)
	if _items.size() > LIMIT:
		_items.pop_front().queue_free()
	return body


func nearest(at: Vector3) -> RigidBody3D:
	var closest: RigidBody3D
	var best := 1.80 ** 2
	for item: RigidBody3D in _items:
		if item.get_meta("live", false):
			continue
		var distance := at.distance_squared_to(item.global_position)
		if distance < best and item.linear_velocity.length_squared() < 4.0:
			best = distance
			closest = item
	return closest


func take(body: RigidBody3D) -> void:
	_items.erase(body)
	body.queue_free()
