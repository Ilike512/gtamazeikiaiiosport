extends "res://scripts/ui/RadialPicker.gd"


func _ready() -> void:
	item_radius = 173.0


func open(items: Array[Dictionary], equipped: String) -> void:
	entries = items
	var active := -1
	for index in entries.size():
		if entries[index].id == equipped:
			active = index
			break
	start(active)


func choice() -> String:
	return str(entries[selected].id) if selected >= 0 else ""


func _draw() -> void:
	if not visible:
		return
	var origin := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color("#111a20dc"))
	centered("EQUIPMENT", Vector2(origin.x - 230, 92), 460, 31, Style.AMBER)
	draw_circle(origin, item_radius, Style.EDGE, false, 2.0, true)
	for index in entries.size():
		var at := slot_position(index)
		var selected_now := selected == index
		card(Rect2(at - Vector2.ONE * 42, Vector2.ONE * 84), Style.PANEL if selected_now else Style.INK,
			Style.AMBER if selected_now else Style.EDGE, 3.0 if selected_now else 1.0)
		Style.fitted_icon(self, entries[index].get("texture"), Rect2(at - Vector2.ONE * 28, Vector2.ONE * 56))
	var detail := Rect2(origin - Vector2(137, 54), Vector2(274, 108))
	card(detail, Style.INK, Style.AMBER)
	centered(str(entries[selected].name) if selected >= 0 else "EMPTY HANDS", detail.position + Vector2(5, 45), 264, 23, Style.TEXT)
	centered("Move to centre for empty hands", detail.position + Vector2(5, 72), 264, 13, Style.MUTED, false)
	centered("RELEASE %s TO EQUIP   •   LEFT CLICK TO USE" % GameManager.key_label("equipment_wheel"), Vector2(origin.x - 305, 639), 610, 15, Style.MUTED)
