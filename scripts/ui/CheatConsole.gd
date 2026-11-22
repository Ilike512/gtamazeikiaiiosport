extends Control

signal entered(code: String)
signal closed

const Style = preload("res://scripts/ui/Style.gd")
var _entry: LineEdit
var _feedback: Label


func _ready() -> void:
	add_child(Style.layer(Color("#141822b0")))
	var middle := CenterContainer.new()
	add_child(middle)
	Style.fill(middle)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", Style.box(Style.INK, Style.TEAL, 3))
	middle.add_child(panel)
	var form := Style.stack(panel, 9)
	form.add_child(Style.label("ENTER CODE", 26, Style.TEXT, true))
	_entry = LineEdit.new()
	_entry.placeholder_text = "Code"
	_entry.max_length = 32
	_entry.custom_minimum_size.y = 38
	_entry.text_submitted.connect(_submit)
	form.add_child(_entry)
	_feedback = Style.label("", 14, Style.MUTED)
	form.add_child(_feedback)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	form.add_child(buttons)
	var apply := Style.button("APPLY", 113)
	buttons.add_child(apply)
	apply.pressed.connect(func() -> void: _submit(_entry.text))
	var cancel := Style.button("CLOSE", 113)
	buttons.add_child(cancel)
	cancel.pressed.connect(func() -> void: closed.emit())
	_entry.grab_focus()


func _submit(code: String) -> void:
	entered.emit(code.strip_edges().to_lower())


func reject() -> void:
	_feedback.text = "Unknown code"
	_entry.select_all()
	_entry.grab_focus()
