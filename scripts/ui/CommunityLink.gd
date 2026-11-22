extends TextureButton

const ICON := "res://assets/brand/pikihub.png"
const ADDRESS := "https://pikihub.site"


func _ready() -> void:
	texture_normal = AssetShelf.image("pikihub", ICON)
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Open PikiHub in your browser"
	accessibility_name = "Open PikiHub"
	pressed.connect(func() -> void: OS.shell_open(ADDRESS))
