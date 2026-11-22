extends Control

signal closed
signal bought(id: String)
signal spawn_requested(id: String, on_ground: bool)
signal item_used(id: String)
signal item_pinned(id: String)
signal contact_selected(index: int)
signal map_requested(anchor: Control)

const Style = preload("res://scripts/ui/Style.gd")
const CommunityLink = preload("res://scripts/ui/CommunityLink.gd")
const PHONE_FRAME := "res://assets/brand/phone_frame.png"
const GUGU := [
	["MAXIMA XX", "Žemaitijos g. 20-2", "Use the map to find the marked Maxima entrance. The shop has a walk-in lobby and several working checkouts."],
	["PUTINAS", "Naftininkų g. 38-2", "Grūstė occupies the corner of the shopping centre. Walk in to browse the shelves and use a checkout."],
	["RIMI", "Žemaitijos g. 38", "Find Rimi near the Mažeikiai town centre."],
	["EIFELIS", "Senkelio g. 14A", "The shopping centre is near the small wooden Eiffel tower."],
	["JUODPELKIO PARKAS", "Juodpelkio pond", "Walk to the overlook on the eastern shore."]
]

var _page: VBoxContainer
var _header: Label
var _message: Label
var _store := ""
var _cash := 0
var _items: Array[Dictionary] = []
var _owned: Dictionary = {}
var _people: Array = []
var _objective := ""
var _back: Button


func open_phone(items: Array[Dictionary], quantities: Dictionary, people: Array, objective: String) -> void:
	_items = items
	_owned = quantities
	_people = people
	_objective = objective
	_build_frame(Rect2(922, 33, 308, 650), true)
	_show_home()


func open_spawn_menu(items: Array[Dictionary]) -> void:
	_items = items
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name).nocasecmp_to(str(b.name)) < 0)
	_build_frame(Rect2(285, 78, 710, 560), false)
	_reset_page("ITEM CATALOG")
	var query := LineEdit.new()
	query.placeholder_text = "Find an item by name"
	_page.add_child(query)
	var list := _scroll_list()
	query.text_changed.connect(func(term: String) -> void: _spawn_results(list, term))
	_spawn_results(list, "")
	query.grab_focus()


func _spawn_results(list: VBoxContainer, term: String) -> void:
	for row: Node in list.get_children():
		list.remove_child(row)
		row.queue_free()
	var lowered := term.strip_edges().to_lower()
	for item: Dictionary in _items:
		if not str(item.name).to_lower().contains(lowered):
			continue
		var row := _item_row(list, item, str(item.get("category", "")).capitalize())
		_button(row, "TAKE", spawn_requested.emit.bind(item.id, false))
		_button(row, "SPAWN", spawn_requested.emit.bind(item.id, true))


func open_store(title: String, items: Array[Dictionary], quantities: Dictionary, cash: int) -> void:
	_store = title
	_items = items
	_owned = quantities
	_cash = cash
	_build_frame(Rect2(305, 86, 670, 548), false)
	_show_store()


func _build_frame(bounds: Rect2, phone: bool) -> void:
	var wash := Style.layer(Color("#0c12196d"))
	add_child(wash)
	var chassis := Panel.new()
	var edge := Style.box(Color("#191c22"), Color("#95a5a3"))
	edge.set_corner_radius_all(24 if phone else 5)
	edge.set_border_width_all(2)
	chassis.add_theme_stylebox_override("panel", edge)
	chassis.position = bounds.position
	chassis.size = bounds.size
	add_child(chassis)
	if phone:
		var image := TextureRect.new()
		image.texture = AssetShelf.image("phone_frame", PHONE_FRAME)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.size = bounds.size
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chassis.add_child(image)
		var display := Panel.new()
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		display.add_theme_stylebox_override("panel", Style.box(Color("#142029"), Color("#2d424b"), 1))
		display.position = Vector2(21, 92)
		display.size = Vector2(267, 468)
		chassis.add_child(display)
	var frame := VBoxContainer.new()
	frame.position = Vector2(29, 103) if phone else Vector2(14, 14)
	frame.size = Vector2(250, 445) if phone else bounds.size - Vector2(28, 28)
	frame.add_theme_constant_override("separation", 8)
	chassis.add_child(frame)
	_header = Style.label("", 23, Style.TEAL, true)
	frame.add_child(_header)
	_page = Style.stack(frame, 7)
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message = Style.label("", 12, Style.AMBER, true)
	frame.add_child(_message)
	_back = Style.button("HOME" if phone else "CLOSE")
	_back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if phone:
		_back.text = ""
		_back.tooltip_text = "Home"
		_back.flat = true
		_back.custom_minimum_size = Vector2.ZERO
		_back.position = Vector2(126, 573)
		_back.size = Vector2(57, 57)
		chassis.add_child(_back)
		_back.pressed.connect(func() -> void:
			if _header.text == "RYŠYS":
				closed.emit()
			else:
				_show_home()
		)
	else:
		frame.add_child(_back)
		_back.pressed.connect(func() -> void: closed.emit())


func _show_home() -> void:
	_reset_page("RYŠYS")
	_page.add_child(Style.label("Mažeikiai   ·   Local network", 13, Style.MUTED))
	_button(_page, "MESSENGER", _show_messages)
	_button(_page, "GUGU", _show_gugu)
	_button(_page, "MAP", func() -> void:
		_reset_page("MAP")
		map_requested.emit(_page)
	)
	_button(_page, "BACKPACK", _show_bag)
	_button(_page, "CONTACTS", _show_contacts)
	var link := CommunityLink.new()
	link.custom_minimum_size = Vector2(54, 54)
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_page.add_child(link)
	_button(_page, "OBJECTIVES", func() -> void:
		_reset_page("OBJECTIVES")
		var note := Style.label(_objective, 17)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_page.add_child(note)
	)
	_message.text = "%s   Close phone" % GameManager.key_label("phone")


func _show_bag() -> void:
	_reset_page("BACKPACK")
	var list := _scroll_list()
	for item: Dictionary in _items:
		if int(_owned.get(item.id, 0)) <= 0:
			continue
		var row := _item_row(list, item, "×%s" % _owned[item.id])
		if item.get("consume", "") in ["eat", "drink"] or item.has("health") or item.has("stamina") or item.get("effect") == "altered":
			_button(row, "USE", item_used.emit.bind(item.id))
		_button(row, "PIN", item_pinned.emit.bind(item.id))


func _show_messages() -> void:
	_reset_page("MESSENGER")
	for person: Dictionary in _people:
		_button(_page, str(person.name), _show_message_thread.bind(str(person.name)))


func _show_message_thread(person: String) -> void:
	_reset_page(person)
	var note := Style.label("Meet me near Žemaitijos g. Maxima XX is beside the marked parking area.", 15, Style.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(note)
	_button(_page, "THREADS", _show_messages)


func _show_gugu() -> void:
	_reset_page("GUGU")
	var query := LineEdit.new()
	query.placeholder_text = "Search Mažeikiai"
	_page.add_child(query)
	var results := _scroll_list()
	query.text_changed.connect(func(term: String) -> void: _gugu_results(results, term))
	_gugu_results(results, "")
	query.grab_focus()


func _gugu_results(results: VBoxContainer, term: String) -> void:
	for child: Node in results.get_children():
		results.remove_child(child)
		child.queue_free()
	for listing: Array in GUGU:
		var combined: String = "%s %s" % [listing[0], listing[1]]
		if not combined.to_lower().contains(term.strip_edges().to_lower()):
			continue
		_button(results, str(listing[0]), _show_gugu_page.bind(listing))


func _show_gugu_page(listing: Array) -> void:
	_reset_page(str(listing[0]))
	_page.add_child(Style.label(str(listing[1]), 14, Style.AMBER))
	var body := Style.label(str(listing[2]), 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(body)
	_button(_page, "SEARCH", _show_gugu)


func _show_contacts() -> void:
	_reset_page("CONTACTS")
	for index in _people.size():
		_button(_page, str(_people[index].name).to_upper(), contact_selected.emit.bind(index))


func _show_store() -> void:
	_reset_page(_store.to_upper())
	_page.add_child(Style.label("AVAILABLE CASH   € %d" % _cash, 15, Style.AMBER, true))
	var list := _scroll_list()
	for item: Dictionary in _items:
		var row := _item_row(list, item, "€ %d" % int(item.price))
		var button := _button(row, "BUY", bought.emit.bind(item.id))
		button.disabled = int(item.price) > _cash


func feedback(message: String, cash: int) -> void:
	if not _store.is_empty() and cash != _cash:
		_cash = cash
		_show_store()
	elif _header.text == "BACKPACK":
		_show_bag()
	_message.text = message


func _reset_page(title: String) -> void:
	_header.text = title
	_message.text = ""
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()


func _scroll_list() -> VBoxContainer:
	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.add_child(scroller)
	var list := Style.stack(scroller, 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return list


func _item_row(list: VBoxContainer, item: Dictionary, aside: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	list.add_child(row)
	var icon := TextureRect.new()
	icon.texture = item.get("texture")
	icon.custom_minimum_size = Vector2.ONE * (24 if _store.is_empty() else 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Style.label(str(item.name), 13, Style.TEXT, true)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(Style.label(aside, 12, Style.MUTED))
	return row


func _button(parent: Control, title: String, callback: Callable) -> Button:
	var button := Style.button(title)
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size.y = 35
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
