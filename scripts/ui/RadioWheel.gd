extends "res://scripts/ui/RadialPicker.gd"


func _ready() -> void:
	visibility_changed.connect(queue_redraw)


func open() -> void:
	RadioManager.refresh_drop_folders()
	entries = RadioManager.library.stations
	var active := -1
	for index in entries.size():
		if entries[index].id == RadioManager.current_station:
			active = index
			break
	start(active)


func station_choice() -> String:
	return RadioManager.OFF if selected < 0 else str(entries[selected].id)


func _draw() -> void:
	if not visible or entries.is_empty():
		return
	var origin := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b111dd9"))
	draw_circle(origin, item_radius + 0.5, Color("#222838"), false, 31.0, true)
	draw_circle(origin, item_radius, Color("#575f74"), false, 1.0, true)
	draw_circle(origin, 171.0, Color("#313a4e"), false, 1.0, true)
	centered("RADIO", Vector2(origin.x - 200, 47), 400, 24, Style.AMBER)
	var controls := "TAP A STATION TO TUNE" if OS.has_feature("mobile") else "MOUSE / RIGHT STICK / ARROW KEYS    •    RELEASE %s / LB TO TUNE" % GameManager.key_label("radio_wheel")
	centered(controls, Vector2(origin.x - 420, size.y - 33), 840, 15, Style.MUTED)

	var station: Dictionary = {} if selected < 0 else entries[selected]
	var tone := Color.from_string(str(station.get("color", "")), Style.AMBER)
	var title := str(station.get("name", "RADIO OFF"))
	var descriptor := str(station.get("genre", "Radio audio muted"))
	var info_box := Rect2(origin - Vector2(167, 66), Vector2(334, 132))
	card(info_box, Color("#161e2d"), tone, 1.0)
	centered(title, origin + Vector2(-160, -20), 320, 25, tone)
	centered(descriptor, origin + Vector2(-160, 10), 320, 12, Style.TEXT, false)
	var info := "MOVE TO CENTRE OR PRESS X / A FOR RADIO OFF" if selected >= 0 else "RADIO OFF SELECTED"
	centered(info, origin + Vector2(-160, 43), 320, 11, Style.MUTED)

	for index in entries.size():
		var data: Dictionary = entries[index]
		var colour := Color.from_string(str(data.color), Style.AMBER)
		var slot := slot_position(index)
		var panel := Rect2(slot - Vector2.ONE * 35, Vector2.ONE * 70)
		var on_air := index == current
		var focused := index == selected
		card(panel, Color("#343e50") if focused else Color("#181e2d"), colour if (focused or on_air) else Style.EDGE, 2.5 if focused else 1.0)
		draw_rect(Rect2(panel.position, Vector2(3, panel.size.y)), colour)
		if data.texture is Texture2D:
			var artwork := Rect2(slot - Vector2.ONE * 29, Vector2.ONE * 58)
			draw_rect(artwork, Color("#111823"))
			Style.fitted_icon(self, data.texture, artwork)
		else:
			centered(str(data.label), panel.position + Vector2(2, 43), 66, 21, colour)
		if on_air:
			draw_rect(Rect2(panel.end - Vector2(8, 8), Vector2(5, 5)), colour)
