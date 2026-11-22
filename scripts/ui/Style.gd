extends RefCounted

const INK := Color("#121623")
const PANEL := Color("#1b2030")
const DARK := Color("#101420eb")
const EDGE := Color("#465064")
const TEXT := Color("#f5f1ea")
const MUTED := Color("#a4adc0")
const AMBER := Color("#ffc77d")
const RED := Color("#ff777a")
const TEAL := Color("#8ee0ca")
const GPS := Color("#d2a4ff")

static var heavy_font: SystemFont
static var body_font: SystemFont


static func font(heavy: bool) -> Font:
	if heavy:
		if heavy_font == null:
			heavy_font = SystemFont.new()
			heavy_font.font_names = PackedStringArray(["Bahnschrift", "Arial", "Liberation Sans"])
			heavy_font.font_weight = 800
		return heavy_font
	if body_font == null:
		body_font = SystemFont.new()
		body_font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans"])
	return body_font


static func box(fill: Color = DARK, border: Color = EDGE, left := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = left
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func label(value: String, font_size := 18, tint := TEXT, heavy := false) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", font(heavy))
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", tint)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func button(value: String, width := 0) -> Button:
	var result := Button.new()
	result.text = value
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.custom_minimum_size = Vector2(width, 44)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_font_override("font", font(true))
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_color_override("font_hover_color", AMBER)
	result.add_theme_color_override("font_pressed_color", INK)
	result.add_theme_color_override("font_focus_color", AMBER)
	result.add_theme_color_override("font_disabled_color", Color("#747a89"))
	result.add_theme_stylebox_override("normal", box(PANEL, EDGE))
	result.add_theme_stylebox_override("hover", box(Color("#2d3141"), AMBER, 4))
	result.add_theme_stylebox_override("pressed", box(AMBER, AMBER, 4))
	result.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, AMBER, 3))
	result.add_theme_stylebox_override("disabled", box(DARK, Color("#282e3b")))
	result.mouse_entered.connect(func() -> void:
		if not result.disabled:
			result.grab_focus()
	)
	return result


static func fill(control: Control, margin := 0.0) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = -margin
	control.offset_bottom = -margin


static func rect(parent: Control, geometry: Rect2, tint: Color) -> ColorRect:
	var item := ColorRect.new()
	item.position = geometry.position
	item.size = geometry.size
	item.color = tint
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


static func layer(wash := Color("#0c1019cc")) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = wash
	fill(panel)
	return panel


static func texture(parent: Control, source: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.texture = source
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill(art)
	parent.add_child(art)
	return art


static func fitted_icon(canvas: CanvasItem, texture: Texture2D, square: Rect2) -> void:
	if texture == null:
		return
	var raw := texture.get_size()
	if raw.x <= 0.0 or raw.y <= 0.0:
		return
	var fitted := raw * minf(square.size.x / raw.x, square.size.y / raw.y)
	canvas.draw_texture_rect(texture, Rect2(square.get_center() - fitted * 0.5, fitted), false)


static func stack(parent: Control, separation := 8) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column
