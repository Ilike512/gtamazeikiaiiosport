extends Control

const Style = preload("res://scripts/ui/Style.gd")
const MapDiscovery = preload("res://scripts/world/MapDiscovery.gd")
const CATEGORY_NAMES := {"normal": "NORMAL ITEMS", "banned": "BANNED ITEMS", "illegal": "ILLEGAL ITEMS"}
const MAP_SCALE := 1.07

var focus_position := Vector3.ZERO
var focus_heading := 0.0
var nearby_roads: Array = []
var landmarks: Array = []
var street_name := ""
var discovery: RefCounted
var map_expanded := false
var checkpoint := Vector3.ZERO
var navigation: RefCounted
var character: Dictionary = {}
var items: Array[Dictionary] = []
var equipped := ""
var aiming := false
var slot := 0
var money := 70
var wanted_stars := 0
var city_time := 0.0
var health := 100.0
var stamina := 100.0
var patience := 100.0
var driving := false
var flying := false
var flight_height := 0.0
var speed := 0.0
var car_condition := 100.0
var vehicle_name := "Car"
var objective := ""
var prompt := ""
var radio_tip := ""
var _notice := ""
var _notice_until := 0
var _location_until := 0


func _process(_delta: float) -> void:
	queue_redraw()


func notify(text: String, seconds := 3.1) -> void:
	_notice = text
	_notice_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func show_location() -> void:
	_location_until = Time.get_ticks_msec() + 3800


func _draw() -> void:
	var clock := Time.get_ticks_msec()
	_status()
	if not map_expanded:
		_minimap()
		_inventory()
	if aiming and not driving:
		var center := size * 0.5
		for axis: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + axis * 5.0, center + axis * 10.0, Color("#edf0e7cc"), 1.4, true)
	if not equipped.is_empty() and not driving and not flying:
		var offset := _status_top() - 28.0
		_panel(Rect2(977, 140 + offset, 275, 47), Style.AMBER)
		_text(equipped, Vector2(991, 160 + offset), 15, Style.TEXT, true, 244)
		_text("LMB   USE  /  %s   EQUIPMENT" % GameManager.key_label("equipment_wheel"), Vector2(991, 177 + offset), 10, Style.MUTED, true)
		if not map_expanded and not aiming:
			draw_circle(size * 0.5, 3.2, Color("#111721"), false, 2.0, true)
			draw_circle(size * 0.5, 1.5, Style.TEXT, true, -1.0, true)
	if not objective.is_empty():
		_panel(Rect2(28, 28, 339, 72), Style.AMBER)
		_text("CURRENT OBJECTIVE", Vector2(43, 52), 12, Style.AMBER, true)
		_text(objective, Vector2(43, 79), 17, Style.TEXT, false, 310)
	if driving or flying:
		_speedometer()
	if (driving or flying) and RadioManager.is_playing() and not RadioManager.current_track.is_empty():
		_radio()
	if not prompt.is_empty():
		_hcenter(prompt, 538, 18, Style.AMBER)
	if not radio_tip.is_empty():
		_hcenter(radio_tip, 578, 15, Style.TEXT)
	if clock < _notice_until and not _notice.is_empty():
		_hcenter(_notice, 109, 18, Style.TEAL)
	elif clock < _location_until:
		_hcenter("MAŽEIKIAI  /  LITHUANIA", 109, 21, Style.AMBER)


func _status_top() -> float:
	return 72.0 if wanted_stars > 0 else 28.0


func _status() -> void:
	var top := _status_top()
	var tone := Color.from_string(str(character.get("outfit", "")), Style.AMBER).lightened(0.32)
	var area := Rect2(977, top, 275, 101)
	_panel(area, tone)
	draw_rect(Rect2(991, top + 16.0, 53, 47), tone.darkened(0.61))
	_text(str(character.get("initials", "MC")), Vector2(1002, top + 47.0), 22, tone, true)
	_text("CURRENT CHARACTER", Vector2(1056, top + 27.0), 11, Style.MUTED, true)
	_text(str(character.get("name", "Main Character")), Vector2(1056, top + 52.0), 19, Style.TEXT, true, 183)
	_text("€ %d" % money, Vector2(1056, top + 83.0), 20, Style.TEAL, true)
	var minutes := floori(city_time * 1440.0)
	_text("%02d:%02d" % [floori(minutes / 60.0), minutes % 60], Vector2(1190, top + 82.0), 13, Style.MUTED, true)
	if wanted_stars > 0:
		_draw_wanted()

	var meters := Rect2(28, 378, 187, 95)
	_panel(meters, Style.EDGE)
	_bar("HEALTH", health, Color("#f48a84"), Vector2(40, 397))
	_bar("STAMINA", stamina, Color("#94d9c6"), Vector2(40, 423))
	_bar("PATIENCE", patience, Color("#e5bc74"), Vector2(40, 449))


func _draw_wanted() -> void:
	var tone := Color("#ecab8b") if wanted_stars >= 4 else Color("#e2e4e3")
	var plate := Rect2(977, 28, 275, 35)
	draw_rect(plate, Color("#14181ef0"))
	draw_rect(Rect2(plate.position, Vector2(3, plate.size.y)), tone)
	_text("POLICIJA", Vector2(991, 50), 11, Color("#bec7cf"), true)
	for index in 6:
		var center := Vector2(1094 + 25 * index, 45)
		var star := PackedVector2Array()
		for corner in 10:
			var radius := 9.1 if corner % 2 == 0 else 3.9
			star.append(center + Vector2.from_angle(-PI * 0.5 + corner * TAU / 10.0) * radius)
		if index < wanted_stars:
			draw_colored_polygon(star, tone)
		else:
			star.append(star[0])
			draw_polyline(star, Color("#738191"), 1.0, true)


func _bar(title: String, amount: float, tint: Color, at: Vector2) -> void:
	_text(title, at, 10, tint, true)
	_text("%d" % roundi(amount), at + Vector2(136, 0), 10, Style.MUTED, true)
	draw_rect(Rect2(at + Vector2(0, 6), Vector2(160, 4)), Color("#424452"))
	draw_rect(Rect2(at + Vector2(0, 6), Vector2(160 * clampf(amount / 100.0, 0.0, 1.0), 4)), tint)


func _minimap() -> void:
	var area := Rect2(28, 483, 187, 187)
	_panel(area, Style.AMBER, Color("#243736"))
	var bounds := area.grow(-10.0)
	var origin := area.get_center()
	var offset := origin - Vector2(focus_position.x, focus_position.z) * MAP_SCALE
	for road: Array in nearby_roads:
		var project_a: Vector2 = road[0] * MAP_SCALE + offset
		var project_b: Vector2 = road[1] * MAP_SCALE + offset
		var width := clampf(float(road[2]) * 0.78, 1.0, 7.0)
		var visible_part := MapDiscovery.clip_line(project_a, project_b, bounds.grow(-width * 0.5))
		if visible_part.size() == 2:
			var tint := Color("#d2c1a4") if bool(road[4]) else (Color("#899d98") if bool(road[3]) else Color("#526d6b"))
			draw_line(visible_part[0], visible_part[1], Color("#172725"), width + 1.6, true)
			draw_line(visible_part[0], visible_part[1], tint, width, true)
	if discovery != null:
		var area_start: Vector2i = discovery.cell_at((bounds.position - offset) / MAP_SCALE)
		var area_end: Vector2i = discovery.cell_at((bounds.end - offset) / MAP_SCALE)
		for x in range(area_start.x, area_end.x + 1):
			for z in range(area_start.y, area_end.y + 1):
				var cell := Vector2i(x, z)
				if not discovery.is_revealed(cell):
					var block := Rect2(Vector2(cell) * MapDiscovery.CELL * MAP_SCALE + offset, Vector2.ONE * MapDiscovery.CELL * MAP_SCALE)
					draw_rect(block.intersection(bounds), Color("#0a151e"))
	if navigation != null and navigation.destination != Vector2.INF:
		var route: PackedVector2Array = navigation.route
		for index in route.size() - 1:
			var segment := MapDiscovery.clip_line(route[index] * MAP_SCALE + offset, route[index + 1] * MAP_SCALE + offset, bounds.grow(-2.0))
			if segment.size() == 2:
				draw_line(segment[0], segment[1], Style.INK, 6.0, true)
				draw_line(segment[0], segment[1], Style.GPS, 3.4, true)
		var target: Vector2 = (navigation.destination * MAP_SCALE + offset).clamp(bounds.position + Vector2.ONE * 7.0, bounds.end - Vector2.ONE * 7.0)
		draw_circle(target, 6.0, Style.INK)
		draw_circle(target, 4.2, Style.GPS, false, 2.0, true)
	for feature: Dictionary in landmarks:
		var at: Vector2 = feature.point * MAP_SCALE + offset
		if feature.get("primary", false):
			var pin := at.clamp(bounds.position + Vector2.ONE * 10.0, bounds.end - Vector2.ONE * 10.0)
			var tag := Rect2(pin - Vector2.ONE * 7.0, Vector2.ONE * 14.0)
			draw_rect(tag, Style.INK)
			draw_rect(tag, Style.AMBER, false, 1.0)
			_text("M", pin + Vector2(-4, 4), 11, Style.AMBER, true)
			continue
		if bounds.grow(-5.0).has_point(at):
			if feature.get("fuel", false):
				var badge := Rect2(at - Vector2.ONE * 6.0, Vector2.ONE * 12.0)
				var amber := Color("#ffa876")
				draw_rect(badge, Style.INK)
				draw_rect(badge, amber, false, 1.0)
				_text("F", at + Vector2(-3, 3), 9, amber, true)
				continue
			var tint := Style.TEAL if feature.home else Style.AMBER
			draw_rect(Rect2(at - Vector2.ONE * 4, Vector2.ONE * 8), Style.INK)
			draw_rect(Rect2(at - Vector2.ONE * 2, Vector2.ONE * 4), tint)
	if SessionManager.active and not SessionManager.connecting:
		var own_id := multiplayer.get_unique_id()
		for id: int in SessionManager.roster:
			var pose: Dictionary = SessionManager.poses.get(id, {})
			if id == own_id or pose.is_empty() or Time.get_ticks_msec() - int(pose.received) > 20000:
				continue
			var location: Vector3 = pose.at
			var dot := Vector2(location.x, location.z) * MAP_SCALE + offset
			if bounds.grow(-5.0).has_point(dot):
				draw_circle(dot, 5.5, Style.INK)
				draw_circle(dot, 3.5, Color("#69aafa"))
	if checkpoint != Vector3.ZERO:
		var projected := origin + Vector2(checkpoint.x - focus_position.x, checkpoint.z - focus_position.z) * MAP_SCALE
		var marker := projected.clamp(bounds.position + Vector2.ONE * 6, bounds.end - Vector2.ONE * 6)
		draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -5), marker + Vector2(5, 0), marker + Vector2(0, 5), marker + Vector2(-5, 0)]), Style.AMBER)
	var cone := PackedVector2Array()
	for point: Vector2 in [Vector2(0, -9), Vector2(6, 6), Vector2(0, 3), Vector2(-6, 6)]:
		cone.append(origin + point.rotated(-focus_heading))
	draw_colored_polygon(cone, Style.TEXT)
	_text("N", Vector2(41, 509), 14, Style.TEXT, true)
	_text(GameManager.key_label("world_map"), Vector2(190, 657), 12, Style.TEAL, true)
	_text(street_name.to_upper() if not street_name.is_empty() else "MAŽEIKIAI", Vector2(28, 689), 12, Style.TEXT, true, 187)
	_text("© OpenStreetMap contributors", Vector2(28, 706), 10, Style.MUTED, false, 188)


func _inventory() -> void:
	var start := Vector2(322, 621)
	for index in 8:
		var item: Dictionary = items[index] if index < items.size() else {}
		var active := index == slot
		var position_on_bar := start + Vector2(index * 79.0, 0)
		var rect := Rect2(position_on_bar, Vector2(75, 50))
		_panel(rect, Style.AMBER if active else Style.EDGE, Color("#363340ed") if active else Style.DARK)
		_text(str(index + 1), position_on_bar + Vector2(7, 15), 11, Style.MUTED, true)
		if item.get("texture") is Texture2D:
			Style.fitted_icon(self, item.texture, Rect2(position_on_bar + Vector2(23, 8), Vector2.ONE * 34))
		else:
			_text("—", position_on_bar + Vector2(29, 33), 17, Style.MUTED, true)
	if not items.is_empty():
		var chosen := items[slot]
		var category := str(chosen.get("category", ""))
		var tag := str(chosen.get("name", "Empty slot"))
		if CATEGORY_NAMES.has(category):
			tag += "   /   " + CATEGORY_NAMES[category]
		_hcenter(tag, 693, 13, _category_color(category), false)


func _speedometer() -> void:
	var at := Rect2(1096, 593, 156, 78)
	_panel(at, Style.TEAL)
	var tint := Style.RED if car_condition < 30 else Style.TEAL
	var heading := "ALTITUDE  %d M" % roundi(flight_height) if flying else "%s  %d%%" % [vehicle_name.to_upper(), roundi(car_condition)]
	_text(heading, Vector2(1111, 613), 10, Style.TEAL if flying else tint, true, 135)
	_text("%02d" % roundi(absf(speed) * 3.6), Vector2(1111, 655), 34, Style.TEXT, true)
	_text("KM/H", Vector2(1170, 654), 13, Style.TEAL, true)


func _radio() -> void:
	var top := _status_top() + 112.0
	var station := RadioManager.station()
	var track := RadioManager.current_track
	var tone := Color.from_string(str(station.get("color", "")), Style.AMBER)
	var duration := RadioManager.playback_duration()
	var has_timer := duration > 0.0
	var window := Rect2(977, top, 275, 113 if has_timer else 91)
	_panel(window, tone)
	var icon := Rect2(992, top + 16.0, 41, 41)
	draw_rect(icon, Color("#343c4b"))
	if station.get("texture") is Texture2D:
		Style.fitted_icon(self, station.texture, icon.grow(-2.0))
	else:
		_text(str(station.get("label", "OFF")), Vector2(997, top + 42.0), 12, tone, true, 37)
	_text(str(station.get("name", "RADIO OFF")), Vector2(1043, top + 27.0), 15, tone, true, 198)
	_text(str(track.get("title", "—")), Vector2(1043, top + 50.0), 15, Style.TEXT, false, 198)
	_text(str(track.get("artist", "")), Vector2(1043, top + 71.0), 13, Style.MUTED, false, 198)
	if has_timer:
		var elapsed := RadioManager.playback_elapsed()
		var range_bar := Rect2(992, top + 86.0, 244, 3)
		draw_rect(range_bar, Style.EDGE)
		draw_rect(Rect2(range_bar.position, Vector2(range_bar.size.x * clampf(elapsed / duration, 0.0, 1.0), 3)), tone)
		var times := "%s / %s" % [_radio_time(elapsed), _radio_time(duration)]
		var timer_width := Style.font(true).get_string_size(times, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_text(times, Vector2(1236 - timer_width, top + 104.0), 11, Style.MUTED, true)


func _radio_time(seconds: float) -> String:
	var total := floori(seconds)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


func _category_color(category: String) -> Color:
	match category:
		"banned":
			return Color("#ffe16d")
		"illegal":
			return Style.RED
		"normal":
			return Style.TEAL
		_:
			return Style.MUTED


func _panel(rect: Rect2, border: Color, fill: Color = Style.DARK) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, Style.EDGE, false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), border)


func _hcenter(value: String, baseline: float, font_size: int, tint: Color, panel := true) -> void:
	var font := Style.font(true)
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := (size.x - width) * 0.5
	if panel:
		_panel(Rect2(x - 16, baseline - font_size - 6, width + 32, font_size + 16), tint)
	_text(value, Vector2(x, baseline), font_size, tint, true)


func _text(value: String, at: Vector2, font_size: int, tint: Color, heavy := false, width := -1.0) -> void:
	draw_string(Style.font(heavy), at, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, tint)
