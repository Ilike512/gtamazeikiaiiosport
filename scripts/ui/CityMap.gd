extends Control

const Style = preload("res://scripts/ui/Style.gd")
const MapDiscovery = preload("res://scripts/world/MapDiscovery.gd")
const MapChunk = preload("res://scripts/ui/MapChunk.gd")

signal waypoint_requested(destination: Vector2)
signal waypoint_cleared

var discovery: RefCounted
var district: Node3D
var follow := true
var world_center := Vector2.ZERO
var player_point := Vector2.ZERO
var goal_point := Vector2.INF
var heading := 0.0
var label := "MAŽEIKIAI"
var landmarks: Array = []
var navigation: RefCounted
var _route_layer: Node2D
var zoom := 0.65
var _dragging := false
var _fingers: Dictionary = {}
var _viewport: Control
var _atlas: Node2D
var _overview: Node2D
var _whole := false
var _overlay: Control
var _chunks: Dictionary = {}
var _visible_cells: Dictionary = {}
var _last_range := Rect2i()
var _cell_count := -1
var _detail := false
var _pending_cells: Array[Vector2i] = []


func _ready() -> void:
	_viewport = Control.new()
	_viewport.clip_contents = true
	_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport)
	_overview = Node2D.new()
	_viewport.add_child(_overview)
	_overview.draw.connect(_draw_city_overview)
	_atlas = Node2D.new()
	_viewport.add_child(_atlas)
	_route_layer = Node2D.new()
	_viewport.add_child(_route_layer)
	_route_layer.draw.connect(_draw_route)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_draw_markers)
	resized.connect(_layout)
	visibility_changed.connect(_map_visibility_changed)
	_layout()


func _map_visibility_changed() -> void:
	_fingers.clear()
	_dragging = false
	_layout()


func _layout() -> void:
	var bounds := _map_rect()
	_viewport.position = bounds.position
	_viewport.size = bounds.size.max(Vector2.ZERO)
	if is_visible_in_tree():
		_update_atlas()
	queue_redraw()


func _update_atlas() -> void:
	if _atlas == null or discovery == null or district == null:
		return
	var half := _viewport.size * 0.5
	_atlas.position = half - world_center * zoom
	_atlas.scale = Vector2.ONE * zoom
	_overview.position = _atlas.position
	_overview.scale = _atlas.scale
	var reveal: bool = discovery.revealed_all
	if _whole != reveal:
		_overview.queue_redraw()
	_overlay.queue_redraw()
	_route_layer.queue_redraw()
	var first: Vector2i = discovery.cell_at(world_center - half / zoom)
	var last: Vector2i = discovery.cell_at(world_center + half / zoom)
	var range_now := Rect2i(first, last - first + Vector2i.ONE)
	var detail := zoom > 0.47
	if range_now == _last_range and _cell_count == discovery.cells.size() and detail == _detail and _whole == reveal:
		return
	_whole = reveal
	_atlas.visible = not reveal or detail
	_last_range = range_now
	_cell_count = discovery.cells.size()
	_detail = detail
	var shown: Dictionary = {}
	_pending_cells.clear()
	var source: Array = []
	if not reveal:
		source = discovery.cells.keys()
	elif detail:
		var visible_city: Rect2i = range_now.intersection(MapDiscovery.CITY_RECT)
		for column in range(visible_city.position.x, visible_city.end.x):
			for row in range(visible_city.position.y, visible_city.end.y):
				source.append(Vector2i(column, row))
	for cell: Vector2i in source:
		if not range_now.has_point(cell):
			continue
		if _chunks.has(cell):
			_chunks[cell].show()
			_chunks[cell].show_buildings(detail)
		else:
			_pending_cells.append(cell)
		shown[cell] = true
	for cell: Vector2i in _visible_cells:
		if not shown.has(cell) and _chunks.has(cell):
			_chunks[cell].hide()
	_visible_cells = shown
	_pending_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return discovery.cell_center(a).distance_squared_to(world_center) > discovery.cell_center(b).distance_squared_to(world_center))


func _draw_city_overview() -> void:
	if not _whole:
		return
	var bounds := Rect2(Vector2(MapDiscovery.CITY_RECT.position) * MapDiscovery.CELL,
		Vector2(MapDiscovery.CITY_RECT.size) * MapDiscovery.CELL)
	_overview.draw_rect(bounds, Color("#233430"))
	var minor := PackedVector2Array()
	var major := PackedVector2Array()
	for segment: Array in district.map_roads():
		if bool(segment[4]):
			major.append(segment[0])
			major.append(segment[1])
		else:
			minor.append(segment[0])
			minor.append(segment[1])
	if minor.size() > 1:
		_overview.draw_multiline(minor, Color("#668077"), 4.4)
	if major.size() > 1:
		_overview.draw_multiline(major, Color("#d7c2a3"), 6.25)


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _pending_cells.is_empty():
		return
	var deadline := Time.get_ticks_usec() + 2600
	var built := 0
	while not _pending_cells.is_empty() and built < 6:
		var cell: Vector2i = _pending_cells.pop_back()
		var chunk := MapChunk.new()
		_atlas.add_child(chunk)
		chunk.build(cell, district)
		chunk.show_buildings(_detail)
		_chunks[cell] = chunk
		built += 1
		if Time.get_ticks_usec() > deadline:
			break


func setup(state: RefCounted, map_district: Node3D, interactive: bool) -> void:
	discovery = state
	district = map_district
	follow = not interactive
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if interactive and OS.has_feature("mobile"):
		var controls := VBoxContainer.new()
		add_child(controls)
		controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		controls.position += Vector2(-60, 58)
		for factor: float in [1.25, 0.8]:
			var button := Style.button("+" if factor > 1.0 else "−", 44)
			controls.add_child(button)
			button.pressed.connect(func() -> void:
				_zoom_at(_map_rect().get_center(), _map_rect().get_center(), factor)
				_refresh_position()
			)


func update_map(at: Vector3, yaw: float, waypoint: Vector3, street: String) -> void:
	player_point = Vector2(at.x, at.z)
	heading = yaw
	goal_point = Vector2(waypoint.x, waypoint.z) if waypoint != Vector3.ZERO else Vector2.INF
	label = street if not street.is_empty() else "MAŽEIKIAI"
	if follow:
		world_center = player_point
	if is_visible_in_tree():
		_update_atlas()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if follow:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _map_rect().has_point(event.position):
			if _fingers.is_empty() and event.double_tap:
				waypoint_requested.emit(world_center + (event.position - _map_rect().get_center()) / zoom)
			_fingers[event.index] = event.position
		elif not event.pressed:
			_fingers.erase(event.index)
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		var previous: Vector2 = _fingers[event.index]
		_fingers[event.index] = event.position
		if _fingers.size() == 1:
			world_center -= (event.position - previous) / zoom
		elif _fingers.size() == 2:
			var other_id: int = _fingers.keys()[0] if _fingers.keys()[0] != event.index else _fingers.keys()[1]
			var other: Vector2 = _fingers[other_id]
			var factor: float = event.position.distance_to(other) / maxf(previous.distance_to(other), 1.0)
			_zoom_at(previous.lerp(other, 0.5), event.position.lerp(other, 0.5), factor)
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION and OS.has_feature("mobile"):
		return
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed and _map_rect().has_point(event.position)
			if event.pressed and event.double_click and _dragging:
				_dragging = false
				waypoint_requested.emit(world_center + (event.position - _map_rect().get_center()) / zoom)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _map_rect().has_point(event.position):
			waypoint_cleared.emit()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(event.position, event.position, 1.20 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.83)
		else:
			return
	elif event is InputEventMouseMotion and _dragging:
		world_center -= event.relative / zoom
	else:
		return
	_refresh_position()
	accept_event()


func _zoom_at(from: Vector2, to: Vector2, factor: float) -> void:
	var center := _map_rect().get_center()
	var anchor := world_center + (from - center) / zoom
	zoom = clampf(zoom * factor, 0.14, 1.7)
	world_center = anchor - (to - center) / zoom


func _refresh_position() -> void:
	var bounds := MapDiscovery.CITY_RECT
	world_center = world_center.clamp(Vector2(bounds.position) * MapDiscovery.CELL, Vector2(bounds.end) * MapDiscovery.CELL)
	_update_atlas()


func _draw() -> void:
	if discovery == null or district == null:
		return
	var viewport := _map_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101821"))
	draw_rect(Rect2(Vector2.ZERO, size), Style.EDGE, false, 1.0)
	draw_rect(Rect2(0, 0, 3, size.y), Style.AMBER)
	var show_distance: bool = not follow and navigation != null and navigation.destination != Vector2.INF
	var header_width := size.x - (174.0 if show_distance else 100.0)
	draw_string(Style.font(true), Vector2(18, 28), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, header_width, 18, Style.TEXT)
	if show_distance:
		var remaining: float = navigation.remaining_distance(player_point)
		var distance := "%.1f KM" % (remaining / 1000.0) if remaining >= 1000.0 else "%d M" % roundi(remaining)
		draw_string(Style.font(true), Vector2(size.x - 146, 28), "GPS  " + distance, HORIZONTAL_ALIGNMENT_LEFT, 108, 14, Style.GPS)
	draw_string(Style.font(true), Vector2(size.x - 30, 28), "N", HORIZONTAL_ALIGNMENT_LEFT, 20, 16, Style.AMBER)
	draw_rect(viewport, Color("#0b151e"))
	var caption := "Double-click to set GPS   ·   Right-click to clear   ·   Drag to pan   ·   Scroll to zoom   ·   Dark areas are unexplored"
	if OS.has_feature("mobile") and not follow:
		caption = "Double-tap to set GPS   ·   Drag to pan   ·   Pinch or use + / − to zoom"
	if follow:
		caption = "Release %s to close   ·   © OpenStreetMap contributors" % GameManager.key_label("world_map")
	draw_string(Style.font(false), Vector2(17, size.y - 12), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 33, 11, Style.MUTED)


func _draw_route() -> void:
	if navigation == null or navigation.route.size() < 2:
		return
	var route := PackedVector2Array()
	for at: Vector2 in navigation.route:
		route.append(_project(at) - _viewport.position)
	_route_layer.draw_polyline(route, Style.INK, 7.0, true)
	_route_layer.draw_polyline(route, Style.GPS, 4.5, true)


func _draw_markers() -> void:
	if district == null:
		return
	var viewport := _map_rect()
	_overlay.draw_rect(viewport, Color("#3e545b"), false, 1.0)
	var labels: Array[Rect2] = []
	var pin_rects: Array[Rect2] = []
	for landmark: Dictionary in landmarks:
		pin_rects.append(Rect2(_project(landmark.point) - Vector2.ONE * 9.0, Vector2.ONE * 18.0))
	for landmark: Dictionary in landmarks:
		var at := _project(landmark.point)
		if viewport.grow(-11.0).has_point(at):
			var school := bool(landmark.get("school", false))
			var fuel := bool(landmark.get("fuel", false))
			var park := bool(landmark.get("park", false))
			var tint := Color("#98c791") if park else (Color("#7ccbe6") if landmark.get("water", false) else (Color("#acc1e7") if school else (Style.TEAL if landmark.home else Style.AMBER)))
			if fuel:
				tint = Color("#ffa876")
			var badge := Rect2(at - Vector2.ONE * 7.0, Vector2.ONE * 14.0)
			_overlay.draw_rect(badge, Style.INK)
			_overlay.draw_rect(badge, tint, false, 1.0)
			var symbol := "M" if landmark.get("primary", false) else ("P" if park else ("S" if school else ("H" if landmark.home else "•")))
			if fuel:
				symbol = "F"
			_overlay.draw_string(Style.font(true), at + Vector2(-4, 4), symbol, HORIZONTAL_ALIGNMENT_LEFT, 9, 11, tint)
			var text_width := Style.font(true).get_string_size(landmark.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 9.0
			for offset: Vector2 in [Vector2(10, -8), Vector2(-text_width - 10, -8), Vector2(10, 10)]:
				var chip := Rect2(at + offset, Vector2(text_width, 17))
				if not viewport.encloses(chip) or pin_rects.any(func(pin: Rect2) -> bool: return pin.intersects(chip)) or labels.any(func(label_rect: Rect2) -> bool: return label_rect.intersects(chip)):
					continue
				labels.append(chip)
				_overlay.draw_rect(chip, Style.DARK)
				_overlay.draw_string(Style.font(true), chip.position + Vector2(4, 12), landmark.name, HORIZONTAL_ALIGNMENT_LEFT, text_width - 4, 11, Style.TEXT)
				break
	if SessionManager.active and not SessionManager.connecting:
		var own_id := multiplayer.get_unique_id()
		for id: int in SessionManager.roster:
			var pose: Dictionary = SessionManager.poses.get(id, {})
			if id == own_id or pose.is_empty() or Time.get_ticks_msec() - int(pose.received) > 20000:
				continue
			var location: Vector3 = pose.at
			var remote := _project(Vector2(location.x, location.z))
			if viewport.grow(-10.0).has_point(remote):
				_overlay.draw_circle(remote, 7.0, Style.INK)
				_overlay.draw_circle(remote, 4.5, Color("#69aafa"))
				if not follow:
					var username := str(SessionManager.roster[id])
					var width := minf(150.0, viewport.end.x - remote.x - 13.0)
					if width > 30.0:
						_overlay.draw_string(Style.font(true), remote + Vector2(10, -6), username, HORIZONTAL_ALIGNMENT_LEFT, width, 14, Style.TEXT)
	var marker := _project(player_point)
	if viewport.grow(-9.0).has_point(marker):
		var arrow := PackedVector2Array()
		for point: Vector2 in [Vector2(0, -10), Vector2(7, 7), Vector2(0, 4), Vector2(-7, 7)]:
			arrow.append(marker + point.rotated(-heading))
		_overlay.draw_colored_polygon(arrow, Style.TEAL)
	if navigation != null and navigation.destination != Vector2.INF:
		var destination := _project(navigation.destination)
		if viewport.grow(-12.0).has_point(destination):
			_overlay.draw_circle(destination, 10.0, Style.INK)
			_overlay.draw_circle(destination, 8.0, Style.GPS, false, 2.5, true)
	if goal_point != Vector2.INF:
		var here := _project(goal_point).clamp(viewport.position + Vector2.ONE * 8.0, viewport.end - Vector2.ONE * 8.0)
		_overlay.draw_circle(here, 4.0, Style.AMBER)
		_overlay.draw_circle(here, 7.0, Style.AMBER, false, 1.0, true)


func _map_rect() -> Rect2:
	return Rect2(Vector2(13, 39), size - Vector2(26, 68))


func _project(point: Vector2) -> Vector2:
	return _map_rect().get_center() + (point - world_center) * zoom
