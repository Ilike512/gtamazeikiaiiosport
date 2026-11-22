extends RefCounted

const DOOR_WIDTH := 1.58
const DOOR_HEIGHT := 2.23
const FLOOR_OFFSET := 0.14
const THRESHOLD_Z := 4.22
const HOMES := {
	"flat_main": {"name": "Main's apartment", "resident": "BUTAS 04", "building": 399984172,
		"entrance": Vector2(206.22, 332.46), "heading": 2.7707, "color": Color("#866c56")},
	"flat_joris": {"name": "Joris's apartment", "resident": "BUTAS 07", "building": 399984174,
		"entrance": Vector2(250.35, 340.1), "heading": 2.79282, "color": Color("#627b6d")}
}


static func entrance_for(building: int) -> Dictionary:
	for site: Dictionary in HOMES.values():
		if site.building == building:
			return site
	return {}
