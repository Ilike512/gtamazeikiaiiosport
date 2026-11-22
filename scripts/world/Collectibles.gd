extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const LOCATIONS := {
	"wallet": Vector2(235.3, 296.0), "house_keys": Vector2(205.5, 329.6),
	"cassette": Vector2(246.7, 336.4), "toolbox": Vector2(-32.0, 245.4),
	"wireless_pad": Vector2(428.0, 218.8), "bus_ticket": Vector2(229.5, 292.8),
	"street_map": Vector2(435.7, 310.3), "paint_marker": Vector2(242.5, 298.4),
	"weed": Vector2(242.2, 297.1), "moon_drops": Vector2(253.0, 304.5),
	"violet_patch": Vector2(396.0, 301.5), "dream_caps": Vector2(-95.6, 117.1), "pulse_tag": Vector2(135.5, 283.0), "flare_wand": Vector2(1379.1, 840.5)
}

var collected: Dictionary = {}
var _markers: Dictionary = {}


func build(district: Node3D, catalog: Dictionary, saved: Variant) -> void:
	if saved is Array:
		for id: Variant in saved:
			if LOCATIONS.has(id):
				collected[id] = true
	var geo := Geometry.new()
	for id: String in LOCATIONS:
		if collected.has(id) or not catalog.has(id):
			continue
		var root := Node3D.new()
		root.position = district.elevation.point_at(LOCATIONS[id], 0.05)
		add_child(root)
		var base := geo.box(root, Vector3.UP * 0.08, Vector3(0.34, 0.135, 0.34), Color("#384953"))
		base.rotation.y = PI * 0.25
		var hint := Sprite3D.new()
		hint.texture = catalog[id].get("texture")
		hint.pixel_size = 0.012
		hint.position.y = 0.47
		hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		hint.shaded = false
		hint.visibility_range_end = 26.0
		root.add_child(hint)
		_markers[id] = root


func nearby(at: Vector3) -> String:
	var best := 2.05 ** 2
	var result := ""
	for id: String in _markers:
		var node: Node3D = _markers[id]
		var distance := node.global_position.distance_squared_to(at)
		if distance < best:
			best = distance
			result = id
	return result


func take(id: String) -> void:
	collected[id] = true
	_markers[id].queue_free()
	_markers.erase(id)
