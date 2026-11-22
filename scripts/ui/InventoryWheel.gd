extends "res://scripts/ui/RadialPicker.gd"

const CATEGORY_NAMES := {"normal": "NORMAL ITEMS", "banned": "BANNED ITEMS", "illegal": "ILLEGAL ITEMS"}


func _ready() -> void:
	item_radius = 169.0
	center_option = false


func open(items: Array[Dictionary], active: int) -> void:
	entries = items
	start(active)


func _draw() -> void:
	if not visible or entries.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#10151cdd"))
	var origin := size * 0.5
	centered("INVENTORY", Vector2(origin.x - 180, 87), 360, 30, Style.TEXT)
	draw_circle(origin, item_radius, Style.EDGE, false, 2.0, true)
	for index in entries.size():
		var item := entries[index]
		var position_on_wheel := slot_position(index)
		var panel := Rect2(position_on_wheel - Vector2(41, 27), Vector2(82, 54))
		var tone := _category_color(str(item.get("category", "")))
		card(panel, Style.PANEL, tone if selected == index else Style.EDGE, 2.0 if selected == index else 1.0)
		if item.get("texture") is Texture2D:
			Style.fitted_icon(self, item.texture, Rect2(panel.get_center() - Vector2.ONE * 18, Vector2.ONE * 36))
		else:
			centered("—", panel.position + Vector2(0, 32), 82, 21, tone)
		draw_string(Style.font(true), panel.position + Vector2(6, 15), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, 20, 11, Style.MUTED)
	var item := entries[maxi(selected, 0)]
	var category := str(item.get("category", ""))
	var info := Rect2(origin - Vector2(116, 46), Vector2(232, 92))
	card(info, Style.INK, _category_color(category))
	centered(str(item.get("name", "Empty slot")), info.position + Vector2(6, 40), 220, 17, Style.TEXT)
	centered(CATEGORY_NAMES.get(category, ""), info.position + Vector2(6, 67), 220, 13, _category_color(category))
	centered("RELEASE %s / RB TO SELECT" % GameManager.key_label("inventory_wheel"), Vector2(origin.x - 230, size.y - 62), 460, 15, Style.MUTED)


func _category_color(category: String) -> Color:
	match category:
		"illegal":
			return Style.RED
		"banned":
			return Color("#ffe16d")
		_:
			return Style.TEAL
