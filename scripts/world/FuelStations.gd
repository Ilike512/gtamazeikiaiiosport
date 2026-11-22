extends Node3D

signal notice(message: String)
signal robbery_committed
signal reward_paid(amount: int, armed: bool)
signal pump_exploded(at: Vector3)

const FuelPump = preload("res://scripts/world/FuelPump.gd")

const Geometry = preload("res://scripts/world/Geometry.gd")
const DEADLINE := 55.0
const RANGE := 2.45
const PALETTES := {
	"orlen": ["#bc253d", "#e6e8e7", "#343840"],
	"circle": ["#da252b", "#f5eae4", "#393b41"],
	"baltic": ["#107f7c", "#e6ebe7", "#303940"],
	"viada": ["#244985", "#f7a245", "#41495c"],
	"eniris": ["#376241", "#e4e6b8", "#494c4a"],
	"euro": ["#34609a", "#e4ad4b", "#4c535e"],
	"lpg": ["#a24d33", "#e1c593", "#555454"],
	"neste": ["#097a66", "#a9d348", "#474a51"],
	"tripletas": ["#275f68", "#f2e2a7", "#40535c"]
}

var sites: Dictionary = {}
var completed: Array[String] = []
var _geo := Geometry.new()
var _district: Node3D
var _job: Dictionary = {}
var _seconds_left := 0.0
var _carrying := false
var _visibility_refresh := 0.0
var _beacon: Label3D
var _lamp := StandardMaterial3D.new()


func build(district: Node3D, completed_sites: Variant, staged := false) -> void:
	_district = district
	_lamp.albedo_color = Color("#f4eee1")
	_lamp.emission_enabled = true
	_lamp.emission = Color("#ffeac2")
	_lamp.emission_energy_multiplier = 0.32
	if completed_sites is Array:
		for id: Variant in completed_sites:
			if id is String and not completed.has(id):
				completed.append(id)
	for spec: Dictionary in district.fuel_stations:
		if staged:
			await get_tree().process_frame
		var place := _build_site(spec)
		sites[spec.id] = place
	_beacon = _geo.signage(self, Vector3.ZERO, "◆  TAKE PARCEL", 29, Color("#ffc979"))
	_beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beacon.outline_size = 7
	_beacon.hide()


func map_pins() -> Array:
	var pins: Array = []
	for place: Dictionary in sites.values():
		var spec: Dictionary = place.spec
		pins.append({"point": place.center, "name": "%s · %s" % [spec.name, spec.address], "fuel": true, "home": false})
	return pins


func shop_near(at: Vector3) -> String:
	for place: Dictionary in sites.values():
		if at.distance_squared_to(place.shop_counter) < RANGE * RANGE:
			return str(place.spec.name)
	return ""


func can_start(at: Vector3) -> bool:
	return not _site_at_counter(at).is_empty()


func begin_at(at: Vector3, armed := false) -> bool:
	var place := _site_at_counter(at)
	if place.is_empty():
		return false
	if completed.has(place.spec.id):
		notice.emit("STATION JOB ALREADY COMPLETE")
	elif not _job.is_empty() and (not armed or _job.spec.id != place.spec.id):
		notice.emit("FINISH THE ACTIVE STATION JOB FIRST")
	elif armed:
		if not _job.is_empty():
			_clear_job()
		_animate_cashier(place.cashier)
		completed.append(place.spec.id)
		robbery_committed.emit()
		reward_paid.emit(int(place.payout), true)
	else:
		_job = place
		_seconds_left = DEADLINE
		_carrying = false
		_beacon.global_position = place.parcel + Vector3.UP * 1.05
		_beacon.show()
		place.crate.show()
		notice.emit("STATION ROBBERY  /  TAKE THE MARKED PARCEL")
	return true


func collect_at(at: Vector3) -> bool:
	if _job.is_empty() or _carrying or at.distance_to(_job.parcel) > RANGE:
		return false
	_carrying = true
	_beacon.hide()
	_job.crate.hide()
	robbery_committed.emit()
	return true


func update_job(delta: float, at: Vector3) -> void:
	_visibility_refresh -= delta
	if _visibility_refresh <= 0.0:
		_visibility_refresh = 0.42
		var radius := 220.0 if SettingsManager.mobile_battery_saver() else 440.0
		var location := Vector2(at.x, at.z)
		for site: Dictionary in sites.values():
			site.root.visible = location.distance_squared_to(site.center) < radius * radius
	if _job.is_empty():
		return
	_seconds_left -= delta
	if _seconds_left <= 0.0:
		cancel()
	elif _carrying and Vector2(at.x, at.z).distance_to(_job.center) >= float(_job.radius):
		var amount := int(_job.payout)
		completed.append(_job.spec.id)
		_clear_job()
		reward_paid.emit(amount, false)


func cancel() -> void:
	if not _job.is_empty():
		_clear_job()
		notice.emit("STATION JOB FAILED")


func objective() -> String:
	if _job.is_empty():
		return ""
	var action := "Leave the station area." if _carrying else "Take the marked parcel."
	return "%s  [%02d s]  %s" % [str(_job.spec.name), ceili(_seconds_left), action]


func prompt(at: Vector3, interact: String, rob: String, armed := false) -> String:
	if not _job.is_empty() and not _carrying and at.distance_to(_job.parcel) <= RANGE:
		return "%s   TAKE MARKED PARCEL" % interact
	var store := shop_near(at)
	if not store.is_empty():
		return "%s   SHOP AT %s%s" % [interact, store, "   /   %s DEMAND CASH" % rob if armed else ""]
	var place := _site_at_counter(at)
	if _job.is_empty() and not place.is_empty():
		if completed.has(place.spec.id):
			return "STATION JOB COMPLETE"
		return ("%s   DEMAND CASH" % rob) if armed else ("%s   ROB %s" % [rob, place.spec.name])
	return ""


func _clear_job() -> void:
	_job.crate.hide()
	_job = {}
	_carrying = false
	_beacon.hide()


func _site_at_counter(at: Vector3) -> Dictionary:
	for place: Dictionary in sites.values():
		if at.distance_squared_to(place.counter) < RANGE * RANGE or at.distance_squared_to(place.shop_counter) < RANGE * RANGE:
			return place
	return {}


func _build_site(spec: Dictionary) -> Dictionary:
	var center := _point(spec.point)
	var office := _point(spec.kiosk)
	var shop := _point(spec.shop)
	var shade := _point(spec.canopy)
	var colors: Array = PALETTES[spec.style]
	var palette: Array[Color] = [Color(colors[0]), Color(colors[1]), Color(colors[2])]
	var direction := (center - office).normalized()
	var yaw := atan2(direction.x, direction.y)
	var stand := Node3D.new()
	stand.name = str(spec.id).to_pascal_case()
	add_child(stand)
	var kiosk := _anchored(stand, office, yaw, 0.21)
	var frame := Basis(Vector3.UP, yaw)
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			var corner := Vector3(office.x, 0.0, office.y) + frame * Vector3(shop.x * 0.45 * side, 0.0, shop.y * 0.44 * end)
			kiosk.position.y = maxf(kiosk.position.y, _district.elevation.height_at(Vector2(corner.x, corner.z)) + 0.15)
	var pump_cover := _anchored(stand, center, yaw)
	_kiosk(kiosk, spec, shop, palette)
	var cashier := _build_cashier(kiosk, shop, palette[0])
	_canopy(pump_cover, spec, shade, palette)
	var front := kiosk.to_global(Vector3(0, 0, shop.y * 0.5 + 1.0))
	var shop_counter := kiosk.to_global(Vector3(-shop.x * 0.18, 0.04, -shop.y * 0.5 + 1.55))
	var sign_at := pump_cover.to_global(Vector3(shade.x * 0.5 + 1.5, 0, 1.8))
	var sign := _anchored(stand, Vector2(sign_at.x, sign_at.z), yaw)
	_signpost(sign, spec.name, palette)
	var wide := maxf(shop.x, shade.x) * 0.5 + 2.3
	var span := office.distance_to(center)
	_pave(kiosk, wide, -shop.y * 0.5 - 1.4, span + shade.y * 0.5 + 3.2)
	var parcel := kiosk.to_global(Vector3(shop.x * 0.27, 0.42, -shop.y * 0.18))
	var crate := _geo.box(stand, parcel, Vector3(0.61, 0.43, 0.45), Color("#ba742c"))
	_geo.box(crate, Vector3(0, 0.224, 0), Vector3(0.08, 0.018, 0.46), Color("#ead19c"))
	crate.hide()
	_geo.batch_static(stand)
	return {"root": stand, "spec": spec, "center": center, "counter": front, "shop_counter": shop_counter, "parcel": parcel, "crate": crate, "cashier": cashier,
		"radius": maxf(27.0, span + 14.0), "payout": 100 + int(spec.pumps) * 30}


func _anchored(parent: Node3D, at: Vector2, yaw: float, lift := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = _district.elevation.point_at(at, lift)
	node.rotation.y = yaw
	parent.add_child(node)
	return node


func _point(data: Array) -> Vector2:
	return Vector2(float(data[0]), float(data[1]))


func _pave(kiosk: Node3D, half: float, back: float, front: float) -> void:
	var outline := PackedVector2Array()
	for corner: Vector2 in [Vector2(-half, back), Vector2(half, back), Vector2(half, front), Vector2(-half, front)]:
		var world := kiosk.to_global(Vector3(corner.x, 0, corner.y))
		outline.append(Vector2(world.x, world.z))
	_district.add_paved_apron(outline)


func _kiosk(kiosk: Node3D, spec: Dictionary, size: Vector2, palette: Array[Color]) -> void:
	var accent := palette[0]
	var trim := palette[1]
	var wall := palette[2]
	var paint := Color("#9a3443") if spec.style in ["orlen", "circle", "lpg"] else Color("#315982")
	var half := size * 0.5
	var height := 3.75 if size.x > 12.0 else 3.05
	var glass := Color(0.47, 0.62, 0.66, 0.53)
	var door := 1.05
	var window_width := half.x - door
	_geo.box(kiosk, Vector3(0, -0.14, 0), Vector3(size.x, 0.28, size.y), Color("#a8a7a0"), true)
	_geo.box(kiosk, Vector3(0, height * 0.5, -half.y), Vector3(size.x, height, 0.22), paint, true)
	for side: float in [-1.0, 1.0]:
		_geo.box(kiosk, Vector3(side * half.x, height * 0.5, 0), Vector3(0.22, height, size.y), paint, true)
		var x := side * (half.x + door) * 0.5
		_geo.box(kiosk, Vector3(x, 0.24, half.y), Vector3(window_width, 0.48, 0.22), wall, true)
		_geo.box(kiosk, Vector3(x, 1.28, half.y + 0.02), Vector3(window_width, 1.63, 0.15), glass, true)
		for column in range(1, ceili(window_width / 2.3)):
			var mullion := side * (door + column * window_width / float(ceili(window_width / 2.3)))
			_geo.box(kiosk, Vector3(mullion, 1.27, half.y + 0.12), Vector3(0.075, 1.72, 0.13), wall)
		_geo.box(kiosk, Vector3(side * door, 1.20, half.y + 0.12), Vector3(0.12, 2.4, 0.19), trim)
	_geo.box(kiosk, Vector3(0, (height + 2.1) * 0.5, half.y), Vector3(size.x, height - 2.1, 0.24), wall, true)
	_geo.box(kiosk, Vector3(0, height - 0.39, half.y + 0.16), Vector3(size.x + 0.1, 0.68, 0.17), accent)
	_geo.box(kiosk, Vector3(0, height + 0.05, 0), Vector3(size.x + 0.7, 0.3, size.y + 0.7), wall, true)
	var foot := kiosk.to_global(Vector3(0, 0, half.y + 3.65))
	var grade: float = _district.elevation.height_at(Vector2(foot.x, foot.z)) + 0.028
	var inner := Vector3(0, 0.013, half.y - 0.15)
	var outer := Vector3(0, grade - kiosk.global_position.y, half.y + 3.65)
	var ramp := _geo.box(kiosk, (inner + outer) * 0.5 - Vector3.UP * 0.105,
		Vector3(2.75, 0.21, inner.distance_to(outer)), Color("#aea9a0"), true)
	ramp.rotation.x = atan2(inner.y - outer.y, outer.z - inner.z)
	_geo.box(kiosk, Vector3(0, 0.015, half.y - 0.62), Vector3(1.79, 0.019, 1.12), Color("#343438"))
	_geo.signage(kiosk, Vector3(0, height - 0.39, half.y + 0.26), str(spec.name), 36 if size.x > 12 else 23, Color.WHITE)
	_geo.box(kiosk, Vector3(-half.x * 0.46, 0.53, -half.y + 0.82), Vector3(maxf(1.2, half.x * 0.72), 1.05, 0.65), Color("#737268"), true)
	_shop_fixtures(kiosk, size, height, paint, trim)
	_geo.box(kiosk, Vector3(0, height - 0.16, 0), Vector3(size.x * 0.61, 0.09, 0.22), trim).material_override = _lamp
	var light := OmniLight3D.new()
	light.position = Vector3(0, height - 0.4, 0)
	light.light_energy = 0.55
	light.visible = not SettingsManager.mobile_battery_saver()
	light.omni_range = maxf(5.0, half.x)
	kiosk.add_child(light)


func _shop_fixtures(kiosk: Node3D, size: Vector2, height: float, paint: Color, trim: Color) -> void:
	var front := size.y * 0.5
	var width := size.x * 0.5
	var charcoal := Color("#394147")
	var drinks := [Color("#7bba66"), Color("#deddd0"), Color("#bf4b4e"), Color("#5a81ac")]
	for side: float in [-1.0, 1.0]:
		_geo.box(kiosk, Vector3(side * (width + 0.10), 0.32, 0), Vector3(0.075, 0.62, size.y), charcoal)
		_geo.box(kiosk, Vector3(side * (width + 0.12), height - 0.46, 0), Vector3(0.095, 0.12, size.y), trim)
		for seam in range(1, ceili(size.y / 0.66)):
			_geo.box(kiosk, Vector3(side * (width + 0.118), height * 0.51, -front + seam * 0.66),
				Vector3(0.032, height - 0.86, 0.024), paint.lightened(0.15))
		_geo.box(kiosk, Vector3(side * 1.4, 0.62, front + 0.77), Vector3(0.12, 1.24, 0.12), trim)
	var fridge_x := width - 0.61
	for unit in mini(4, floori(size.y / 1.55)):
		var z := -front + 0.83 + unit * 1.23
		_geo.box(kiosk, Vector3(fridge_x, 1.02, z), Vector3(0.91, 2.04, 1.18), charcoal, true)
		_geo.box(kiosk, Vector3(fridge_x - 0.476, 1.1, z), Vector3(0.051, 1.47, 1.01), Color("#727e85"))
		for level in 3:
			for item in 6:
				var tint: Color = drinks[(unit + level + item) % drinks.size()]
				_geo.box(kiosk, Vector3(fridge_x - 0.51, 0.63 + level * 0.4, z - 0.42 + item * 0.165),
					Vector3(0.038, 0.19, 0.11), tint)
	for aisle in (3 if size.x > 12.0 else 1):
		var x := -width * 0.62 + aisle * width * 0.60
		if absf(x) < 1.35:
			continue
		var section := Vector3(x, 0, 0.10)
		var length := minf(size.y * 0.34, 3.6)
		_geo.box(kiosk, section + Vector3.UP * 0.65, Vector3(0.28, 1.30, length), charcoal, true)
		var products := maxi(3, floori(length / 0.245))
		for shelf in 3:
			var y := 0.27 + shelf * 0.37
			_geo.box(kiosk, section + Vector3.UP * y, Vector3(0.72, 0.07, length), charcoal)
			for product in products:
				var z := -length * 0.43 + product * length * 0.84 / products
				var tint: Color = drinks[(aisle + shelf + product) % drinks.size()]
				for side: float in [-1.0, 1.0]:
					_geo.box(kiosk, section + Vector3(side * 0.245, y + 0.15, z), Vector3(0.17, 0.22, 0.145), tint)
	if size.x > 12.0:
		_geo.box(kiosk, Vector3(width * 0.49, 0.52, -front + 0.64), Vector3(3.2, 1.04, 0.76), charcoal, true)
		_geo.signage(kiosk, Vector3(width * 0.49, 2.47, -front + 0.23), "KAVA  ·  UŽKANDŽIAI", 25, trim)
		for station in 3:
			_geo.box(kiosk, Vector3(width * 0.49 + (station - 1) * 0.82, 1.33, -front + 0.64),
				Vector3(0.58, 0.56, 0.53), trim.darkened(0.33))
	var counter := Vector3(-size.x * 0.23, 0.53, -front + 0.82)
	_geo.box(kiosk, counter + Vector3.UP * 0.55, Vector3(size.x * 0.37, 0.075, 0.77), trim)
	_geo.box(kiosk, counter + Vector3(0.02, 0.77, 0.09), Vector3(0.41, 0.33, 0.22), charcoal)
	_geo.signage(kiosk, Vector3(fridge_x - 0.54, 2.42, -front + 1.57), "GĖRIMAI", 19, trim, -PI * 0.5)
	_geo.signage(kiosk, counter + Vector3(0, 1.66, -0.28), "KASA", 22, trim)


func _build_cashier(kiosk: Node3D, shop: Vector2, vest: Color) -> Node3D:
	var cashier := Node3D.new()
	cashier.name = "StationClerk"
	cashier.position = Vector3(-shop.x * 0.23, 0.0, -shop.y * 0.5 + 0.37)
	kiosk.add_child(cashier)
	var skin := Color("#b68d75")
	var pants := Color("#343846")
	_geo.box(cashier, Vector3(0, 1.14, 0), Vector3(0.43, 0.54, 0.27), vest)
	_geo.taper(cashier, Vector3(0, 1.57, 0), 0.26, 0.094, 0.112, skin, 10)
	_geo.taper(cashier, Vector3(0, 1.72, 0), 0.115, 0.095, 0.118, pants, 10)
	for side: float in [-1.0, 1.0]:
		_geo.box(cashier, Vector3(0.107 * side, 0.45, 0), Vector3(0.17, 0.89, 0.21), pants)
	var arm := Node3D.new()
	arm.name = "CashHand"
	cashier.add_child(arm)
	arm.position = Vector3(0.27, 1.31, 0)
	_geo.box(arm, Vector3(0, -0.21, 0), Vector3(0.14, 0.43, 0.15), vest)
	_geo.box(arm, Vector3(0, -0.47, 0.014), Vector3(0.104, 0.14, 0.10), skin)
	var banknotes := _geo.box(arm, Vector3(0, -0.55, 0.07), Vector3(0.16, 0.075, 0.026), Color("#8f9b76"))
	banknotes.name = "Banknotes"
	banknotes.hide()
	return arm


func _animate_cashier(arm: Node3D) -> void:
	var cash := arm.get_node("Banknotes") as Node3D
	cash.show()
	var motion := arm.create_tween()
	motion.tween_property(arm, "rotation:x", -1.48, 0.26).set_trans(Tween.TRANS_QUAD)
	motion.tween_interval(0.45)
	motion.tween_callback(cash.hide)
	motion.tween_property(arm, "rotation:x", 0.0, 0.31).set_trans(Tween.TRANS_QUAD)


func _canopy(parent: Node3D, spec: Dictionary, size: Vector2, palette: Array[Color]) -> void:
	var height := 5.35 if int(spec.pumps) > 2 else 4.25
	_geo.box(parent, Vector3(0, height, 0), Vector3(size.x, 0.42, size.y), palette[0], true)
	_geo.box(parent, Vector3(0, height + 0.24, 0), Vector3(size.x + 0.08, 0.10, size.y + 0.08), palette[1])
	for side: float in [-1.0, 1.0]:
		_geo.signage(parent, Vector3(0, height - 0.01, side * (size.y * 0.5 + 0.017)), str(spec.name), 29, Color.WHITE,
			0.0 if side > 0 else PI)
	for index in int(spec.pumps):
		var x := (float(index) - (int(spec.pumps) - 1) * 0.5) * size.x / (int(spec.pumps) + 1.0)
		_geo.box(parent, Vector3(x, 0.08, 0), Vector3(1.15, 0.16, 3.3), Color("#999a96"), true)
		_geo.box(parent, Vector3(x, height * 0.5, -0.73), Vector3(0.25, height, 0.25), palette[2], true)
		var pump := FuelPump.new()
		pump.position.x = x
		pump.set_meta("moving_geometry", true)
		parent.add_child(pump)
		pump.ignited.connect(func(at: Vector3) -> void: pump_exploded.emit(at))
		pump.build()
		_geo.box(pump, Vector3(0, 0.92, 0.42), Vector3(0.68, 1.66, 0.53), palette[2])
		_geo.box(pump, Vector3(0, 1.49, 0.706), Vector3(0.62, 0.35, 0.037), palette[0])
		_geo.box(pump, Vector3(0, 1.12, 0.711), Vector3(0.29, 0.18, 0.033), Color("#a5d3b5"))
		_geo.box(parent, Vector3(x, height - 0.24, 0.55), Vector3(1.1, 0.07, 0.36), palette[1]).material_override = _lamp
		for side: float in [-1.0, 1.0]:
			_geo.box(pump, Vector3(side * 0.34, 0.81, 0.80), Vector3(0.036, 0.77, 0.053), Color("#272c2f"))
			_geo.box(pump, Vector3(side * 0.36, 1.28, 0.79), Vector3(0.063, 0.18, 0.075), Color("#3f9663") if side > 0.0 else Color("#cf763c"))
		_geo.signage(pump, Vector3(0, 1.51, 0.736), str(index + 1), 12, Color.WHITE)


func _signpost(parent: Node3D, title: String, palette: Array[Color]) -> void:
	_geo.box(parent, Vector3(0, 2.19, 0), Vector3(1.8, 4.35, 0.36), palette[2], true)
	_geo.box(parent, Vector3(0, 4.34, 0), Vector3(1.94, 0.88, 0.42), palette[0])
	for side: float in [-1.0, 1.0]:
		var yaw := 0.0 if side > 0 else PI
		var size := 18 if title.length() < 8 else 11
		_geo.signage(parent, Vector3(0, 4.35, side * 0.221), title, size, Color.WHITE, yaw)
		_geo.signage(parent, Vector3(0, 3.41, side * 0.191), "DEGALINĖ", 16, palette[1], yaw)

