extends Node3D

const CAR_SCENE = preload("res://scenes/vehicles/BasicCar.tscn")
const Civilian = preload("res://scripts/world/Civilian.gd")
const MAX_TRAFFIC := 10
const MAX_PEOPLE := 21
const CAR_COLORS := [
	Color("#666c7b"), Color("#944850"), Color("#cecbbe"), Color("#4c6261"),
	Color("#636768"), Color("#b59463"), Color("#455b78"), Color("#3e3d3b")
]
const CLOTHING := [
	Color("#f4e8d5"), Color("#c9dacf"), Color("#ded2e2"),
	Color("#f0d2bd"), Color("#c5d2eb"), Color("#c7c6c5")
]

var district: Node3D
var player_position := Vector3.ZERO
var active_car: RigidBody3D
var on_foot := true
var wanted := 0
var _patrol_clock := 0.0

var traffic: Array[Dictionary] = []
signal civilian_counter_hit(strength: float)

var civilians: Array[CharacterBody3D] = []
var _taken: Array[RigidBody3D] = []
var _links: Dictionary = {}
var _counts_refresh := 0.0
var _drive_refresh := 0.0
var _rng := RandomNumberGenerator.new()
var _vehicle_index := 0


func build(map_district: Node3D, start: Vector3) -> void:
	district = map_district
	player_position = start
	_rng.randomize()
	for road: Array in district.map_roads():
		if not bool(road[3]) or float(road[2]) < 5.15 or str(road[5]).is_empty():
			continue
		_join(road[0], road[1])
		_join(road[1], road[0])
	_maintain_population(3, 7)


func update_focus(at: Vector3, focus_car: RigidBody3D, pedestrian: bool) -> void:
	player_position = at
	active_car = focus_car
	on_foot = pedestrian


func _physics_process(delta: float) -> void:
	_drive_refresh -= delta
	if _drive_refresh <= 0.0:
		_drive_refresh = 0.088
		for row: Dictionary in traffic:
			_guide_car(row)
	_counts_refresh -= delta
	if _counts_refresh <= 0.0:
		_counts_refresh = 0.34
		_maintain_population(2, 4)
	_patrol_clock -= delta
	if _patrol_clock <= 0.0:
		_patrol_clock = 1.8
		_maintain_patrols()


func nearest_car(at: Vector3, reach := 4.6) -> RigidBody3D:
	var candidate: RigidBody3D
	var best := reach * reach
	for row: Dictionary in traffic:
		var vehicle: RigidBody3D = row.car
		var distance := vehicle.global_position.distance_squared_to(at)
		if distance <= best:
			candidate = vehicle
			best = distance
	for vehicle: RigidBody3D in _taken:
		if not is_instance_valid(vehicle):
			continue
		var distance := vehicle.global_position.distance_squared_to(at)
		if distance <= best:
			candidate = vehicle
			best = distance
	return candidate


func nearby_body(at: Vector3) -> CharacterBody3D:
	var result: CharacterBody3D
	var best := 2.25 ** 2
	for civilian: CharacterBody3D in civilians:
		if not is_instance_valid(civilian) or not civilian.can_carry():
			continue
		var squared: float = civilian.body_position().distance_squared_to(at)
		if squared < best:
			best = squared
			result = civilian
	return result


func nearest_person(at: Vector3, reach := 3.0) -> CharacterBody3D:
	var result: CharacterBody3D
	var best := reach * reach
	for civilian: CharacterBody3D in civilians:
		var distance := civilian.global_position.distance_squared_to(at)
		if distance < best:
			result = civilian
			best = distance
	return result


func take_car(target: RigidBody3D) -> bool:
	for index in traffic.size():
		if traffic[index].car != target:
			continue
		traffic.remove_at(index)
		target.autopilot = false
		target.set_pursuit(false)
		_taken.append(target)
		return true
	return false


func keep_car(target: RigidBody3D) -> void:
	if not _taken.has(target):
		_taken.append(target)


func _links_at(at: Vector2) -> Array:
	return _links.get(Vector2i(roundi(at.x * 10.0), roundi(at.y * 10.0)), [])


func _join(at: Vector2, to: Vector2) -> void:
	var key := Vector2i(roundi(at.x * 10.0), roundi(at.y * 10.0))
	if not _links.has(key):
		_links[key] = []
	if not _links[key].has(to):
		_links[key].append(to)


func _maintain_population(cars_to_add: int, people_to_add: int) -> void:
	var low := int(GameManager.settings.quality) == 0 or SettingsManager.mobile_battery_saver()
	var car_limit := 5 if low else MAX_TRAFFIC
	var people_limit := (5 if SettingsManager.mobile_battery_saver() else 9) if low else MAX_PEOPLE
	var car_distance := 166.0 if low else 225.0
	var people_distance := 118.0 if low else 173.0
	for index in range(traffic.size() - 1, -1, -1):
		var vehicle: RigidBody3D = traffic[index].car
		if vehicle.global_position.distance_squared_to(player_position) > car_distance ** 2:
			traffic.remove_at(index)
			vehicle.queue_free()
	for index in range(_taken.size() - 1, -1, -1):
		var vehicle := _taken[index]
		if is_instance_valid(vehicle) and vehicle != active_car and vehicle.global_position.distance_squared_to(player_position) > 275.0 ** 2:
			_taken.remove_at(index)
			vehicle.queue_free()
	for index in range(civilians.size() - 1, -1, -1):
		if not civilians[index].carried and civilians[index].body_position().distance_squared_to(player_position) > people_distance ** 2:
			civilians[index].queue_free()
			civilians.remove_at(index)
	if traffic.size() >= car_limit and civilians.size() >= people_limit:
		return
	var roads: Array = district.map_segments(player_position, 161.0)
	roads.shuffle()
	for segment: Array in roads:
		if cars_to_add <= 0 and people_to_add <= 0:
			break
		if cars_to_add > 0 and traffic.size() < car_limit and _spawn_car(segment):
			cars_to_add -= 1
		if people_to_add > 0 and civilians.size() < people_limit and _spawn_person(segment):
			people_to_add -= 1


func _maintain_patrols() -> void:
	var count := 0
	for index in range(traffic.size() - 1, -1, -1):
		var row: Dictionary = traffic[index]
		if not row.get("patrol", false):
			continue
		var vehicle: RigidBody3D = row.car
		if wanted == 0:
			row.patrol = false
			vehicle.set_pursuit(false)
			continue
		if vehicle.wrecked:
			vehicle.set_pursuit(false)
		else:
			count += 1
	if count >= mini(wanted, 5):
		return
	var roads: Array = district.map_segments(player_position, 115.0)
	roads.shuffle()
	for road: Array in roads:
		if bool(road[4]) and _spawn_car(road, true):
			break


func patrol_near(at: Vector3, distance := 37.0) -> bool:
	for row: Dictionary in traffic:
		if not row.get("patrol", false) or row.car.wrecked:
			continue
		var at_car: Vector3 = row.car.global_position
		if at.distance_squared_to(at_car) > distance ** 2:
			continue
		var ray := PhysicsRayQueryParameters3D.create(at_car + Vector3.UP * 0.55, at + Vector3.UP * 0.8, 1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return true
	return false


func _spawn_car(segment: Array, patrol := false) -> bool:
	if not bool(segment[3]) or float(segment[2]) < 5.15 or str(segment[5]).is_empty():
		return false
	var a: Vector2 = segment[0]
	var b: Vector2 = segment[1]
	if a.distance_squared_to(b) < 63.0:
		return false
	if _rng.randf() > 0.5:
		var swap := a
		a = b
		b = swap
	var direction := a.direction_to(b)
	var origin := a.lerp(b, 0.19) + _right(direction) * minf(float(segment[2]) * 0.25, 1.8)
	var start: Vector3 = district.elevation.point_at(origin, 0.62)
	var range_to_player := start.distance_squared_to(player_position)
	if range_to_player < 34.0 ** 2 or range_to_player > (113.0 if patrol else 149.0) ** 2:
		return false
	for item: Dictionary in traffic:
		if start.distance_squared_to(item.car.global_position) < 11.8 ** 2:
			return false
	var vehicle: RigidBody3D = CAR_SCENE.instantiate()
	vehicle.variant = "police" if patrol else ["sedan", "van", "hatchback", "coupe"][_vehicle_index % 4]
	_vehicle_index += 1
	add_child(vehicle)
	vehicle.reset_pose(start, atan2(-direction.x, -direction.y))
	vehicle.set_paint(CAR_COLORS[_rng.randi_range(0, CAR_COLORS.size() - 1)])
	vehicle.autopilot = true
	vehicle.wallet = _rng.randi_range(8, 44)
	vehicle.set_pursuit(patrol)
	traffic.append({"car": vehicle, "prev": a, "next": b, "delay": 0.0,
		"speed": _rng.randf_range(7.1, 10.7), "patrol": patrol})
	return true


func _spawn_person(segment: Array) -> bool:
	var a: Vector2 = segment[0]
	var b: Vector2 = segment[1]
	var path_width := float(segment[2])
	if a.distance_squared_to(b) < 78.0 or (bool(segment[3]) and str(segment[5]).is_empty()):
		return false
	var side := _right(a.direction_to(b)) * (path_width * 0.5 + 0.9) if bool(segment[3]) else Vector2.ZERO
	if _rng.randf() < 0.5:
		side = -side
	a += side
	b += side
	var start: Vector3 = district.elevation.point_at(a.lerp(b, _rng.randf_range(0.12, 0.82)), 0.07)
	var range_to_player := start.distance_squared_to(player_position)
	if range_to_player < 19.0 ** 2 or range_to_player > 133.0 ** 2:
		return false
	for other: CharacterBody3D in civilians:
		if start.distance_squared_to(other.global_position) < 3.4 ** 2:
			return false
	var person := Civilian.new()
	person.model_variant = _rng.randi_range(0, 3)
	add_child(person)
	person.position = start
	person.route_a = district.elevation.point_at(a)
	person.route_b = district.elevation.point_at(b)
	person.appearance(CLOTHING[_rng.randi_range(0, CLOTHING.size() - 1)], _rng.randf_range(0.91, 1.10),
		_rng.randf_range(0.91, 1.70), _rng.randi_range(4, 27))
	person.counter_hit.connect(civilian_counter_hit.emit)
	civilians.append(person)
	return true


func _guide_car(row: Dictionary) -> void:
	var car: RigidBody3D = row.car
	if car.wrecked:
		car.set_traffic_input(0.0, 0.0, true)
		return
	var center := Vector2(car.global_position.x, car.global_position.z)
	var a: Vector2 = row.prev
	var b: Vector2 = row.next
	var advance := a.direction_to(b)
	var target := b + _right(advance) * 1.54
	var patrol := bool(row.get("patrol", false))
	var suspect := Vector2(player_position.x, player_position.z)
	var needs_next := target.distance_squared_to(center) < 7.0 ** 2 or (center - b).dot(advance) > 2.0
	if needs_next:
		var options := _links_at(b)
		var best_turn := -1.6
		var chosen := a
		for next: Vector2 in options:
			if next.distance_squared_to(a) < 0.05:
				continue
			var straight := advance.dot(b.direction_to(next)) + _rng.randf_range(-0.19, 0.19)
			if patrol:
				straight = 0.25 * straight + b.direction_to(next).dot(b.direction_to(suspect)) * 1.69
			if straight > best_turn:
				best_turn = straight
				chosen = next
		if chosen == a and options.size() <= 1:
			row.delay += 0.088
			car.set_traffic_input(0.0, 0.0, true)
			if row.delay > 5.2 and car.position.distance_to(player_position) > 55.0:
				car.reset_pose(district.elevation.point_at(b - _right(advance) * 1.55, 0.60), car.heading() + PI)
				row.prev = b
				row.next = a
				row.delay = 0.0
			return
		row.prev = b
		row.next = chosen
		advance = b.direction_to(chosen)
		target = chosen + _right(advance) * 1.54
	if patrol and center.distance_squared_to(suspect) < 20.0 ** 2:
		var closest := Geometry2D.get_closest_point_to_segment(suspect, a, b)
		if closest.distance_squared_to(suspect) < 24.0:
			target = closest
	var aim: Vector3 = district.elevation.point_at(target, 0.55)
	var direction := car.to_local(aim)
	var heading_error := atan2(direction.x, -direction.z)
	var steer := clampf(heading_error * 1.86, -1.0, 1.0)
	var facing := (-car.global_basis.z).slide(Vector3.UP).normalized()
	var forward_check := car.global_position + facing * (4.7 + absf(car.speed) * 0.61)
	var ray := PhysicsRayQueryParameters3D.create(car.global_position, forward_check, 4 | 8, [car.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var near_player := on_foot and car.global_position.distance_to(player_position) < 7.6
	var target_speed: float = (12.1 + wanted * 1.5) if patrol else float(row.speed)
	if patrol and on_foot and center.distance_squared_to(suspect) < 8.0 ** 2:
		target_speed = 0.0
	var speed_limit := target_speed * (1.0 - minf(absf(heading_error) * 0.43, 0.54))
	var brake: bool = not hit.is_empty() or near_player or car.speed > speed_limit + 0.9
	var throttle := clampf((speed_limit - car.speed) * 0.28, 0.0, 0.62)
	car.set_traffic_input(throttle, steer, brake)


func _right(heading: Vector2) -> Vector2:
	return Vector2(-heading.y, heading.x)
