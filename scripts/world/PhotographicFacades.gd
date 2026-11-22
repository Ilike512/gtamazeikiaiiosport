extends RefCounted

const Geometry = preload("res://scripts/world/Geometry.gd")
const PROFILES := {
	67806216: {"address": "3", "base": Color("#c7c5ad"), "skirt": Color("#828477"), "accent": Color("#9ea28b"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 5, "balconies": 3, "glazed": true},
	543403335: {"address": "14", "base": Color("#b8ad98"), "skirt": Color("#756855"), "accent": Color("#aaa18a"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 5, "balconies": 3, "glazed": true},
	543403334: {"address": "16", "base": Color("#b7b099"), "skirt": Color("#776e60"), "accent": Color("#9b8c77"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 5, "balconies": 3, "glazed": true},
	451777919: {"address": "22", "base": Color("#a9a190"), "skirt": Color("#706a5a"), "accent": Color("#8f8371"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 9, "balconies": 3, "glazed": true},
	267468474: {"address": "41", "base": Color("#bdb09a"), "skirt": Color("#7e8072"), "accent": Color("#a98265"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 9, "balconies": 3, "glazed": true, "shops": true},
	267468472: {"address": "39", "base": Color("#c4bfb3"), "skirt": Color("#767164"), "accent": Color("#8d9484"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 5, "balconies": 3, "glazed": true},
	399984174: {"address": "32", "base": Color("#d4d4c2"), "skirt": Color("#85867c"), "accent": Color("#677669"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 5, "balconies": 3, "glazed": true, "balcony_columns": true},
	399984172: {"address": "30", "base": Color("#c0bcaa"), "skirt": Color("#7a786b"), "accent": Color("#757f70"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 5, "balconies": 3, "glazed": true, "balcony_columns": true},
	265251167: {"address": "", "base": Color("#d2cec2"), "skirt": Color("#848779"), "accent": Color("#9c9e90"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 9, "balconies": 3, "glazed": true},
	341370182: {"address": "", "base": Color("#b7b3a6"), "skirt": Color("#91866c"), "accent": Color("#d7d3c6"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 5, "balconies": 0, "striped_office": true},
	444867185: {"address": "HANZA", "base": Color("#b5cab7"), "skirt": Color("#528e77"), "accent": Color("#468975"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 2, "balconies": 0, "mint_retail": true},
	203626552: {"address": "", "base": Color("#d8d8ce"), "skirt": Color("#4c637e"), "accent": Color("#335885"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 2, "balconies": 0, "shopping_gallery": "MIEGAS"},
	203626553: {"address": "", "base": Color("#e0ded5"), "skirt": Color("#637382"), "accent": Color("#36527a"),
		"glass": Color("#657570"), "frame": Color("#e0dfd5"), "spacing": 3.00, "height": 2.89, "levels": 2, "balconies": 0, "shopping_gallery": "ŠIAULIŲ BANKAS"},
	243571674: {"address": "SODŲ G. 9", "base": Color("#d6b570"), "skirt": Color("#66635a"), "accent": Color("#a49268"),
		"glass": Color("#647a7d"), "frame": Color("#e5e2d3"), "spacing": 3.25, "height": 2.95, "levels": 5, "balconies": 2, "glazed": true},
	243571637: {"address": "SODŲ G. 11", "base": Color("#b8b7a4"), "skirt": Color("#706f67"), "accent": Color("#9a8e77"),
		"glass": Color("#636d6b"), "frame": Color("#e1dcd0"), "spacing": 3.02, "height": 2.95, "levels": 9, "balconies": 2},
	192628916: {"address": "SODŲ G. 13", "base": Color("#b6a096"), "skirt": Color("#71706d"), "accent": Color("#966e60"),
		"glass": Color("#677d80"), "frame": Color("#e8e1d4"), "spacing": 3.17, "height": 2.98, "levels": 12, "balconies": 2, "glazed": true},
	265233133: {"address": "NAFTININKŲ G. 12", "base": Color("#c3bdb0"), "skirt": Color("#3e464d"), "accent": Color("#a68b78"),
		"glass": Color("#626e71"), "frame": Color("#ece7d9"), "spacing": 3.18, "height": 2.81, "levels": 5, "balconies": 3, "glazed": true},
	341370188: {"address": "NAFTININKŲ G. 17", "base": Color("#958777"), "skirt": Color("#645b52"), "accent": Color("#aab3b8"),
		"glass": Color("#647680"), "frame": Color("#cfd4d2"), "spacing": 3.17, "height": 2.97, "levels": 2, "balconies": 0, "shops": true},
	367432739: {"address": "LAISVĖS G. 13", "base": Color("#b2a798"), "skirt": Color("#6a6a62"), "accent": Color("#657174"),
		"glass": Color("#52626c"), "frame": Color("#9a9c91"), "spacing": 3.39, "height": 3.03, "levels": 2, "balconies": 0, "shops": true},
	203378597: {"address": "MAŽEIKIAI", "base": Color("#ddd4be"), "skirt": Color("#756e62"), "accent": Color("#9b8165"),
		"glass": Color("#586265"), "frame": Color("#f0ebdc"), "spacing": 3.12, "height": 3.11, "levels": 2, "balconies": 0, "historic": "station"},
	595375414: {"address": "BIKUVA", "base": Color("#858589"), "skirt": Color("#5e5d5e"), "accent": Color("#b53237"),
		"glass": Color("#5c737a"), "frame": Color("#586166"), "spacing": 4.14, "height": 3.55, "levels": 1, "balconies": 0, "shops": true, "historic": "retail"},
	206357438: {"address": "LAISVĖS G. 8", "base": Color("#d9bf91"), "skirt": Color("#7d7c70"), "accent": Color("#eddfbf"),
		"glass": Color("#647778"), "frame": Color("#e9e6d4"), "spacing": 3.12, "height": 3.01, "levels": 3, "balconies": 0, "historic": "civic"},
	542350309: {"address": "", "base": Color("#bbb3a1"), "skirt": Color("#807565"), "accent": Color("#a68a62"), "glass": Color("#64767c"), "frame": Color("#d8d2bb"), "spacing": 3.26, "height": 2.97, "levels": 9, "balconies": 2, "glazed": true, "balcony_columns": true},
	262392300: {"address": "", "base": Color("#aa6d56"), "skirt": Color("#756450"), "accent": Color("#bca173"), "glass": Color("#61788b"), "frame": Color("#e2dbcb"), "spacing": 3.02, "height": 2.90, "levels": 5, "balconies": 2, "glazed": true, "balcony_columns": true},
	542350308: {"address": "", "base": Color("#b9b29c"), "skirt": Color("#767261"), "accent": Color("#9f7855"), "glass": Color("#647787"), "frame": Color("#d9d9c8"), "spacing": 3.11, "height": 2.91, "levels": 5, "balconies": 2, "glazed": true},
	267071242: {"address": "61", "base": Color("#c7c3aa"), "skirt": Color("#696b65"), "accent": Color("#96968a"),
		"glass": Color("#617479"), "frame": Color("#eee9dc"), "spacing": 3.08, "height": 2.89, "levels": 5, "balconies": 2},
	443726536: {"address": "23", "base": Color("#cbc1a5"), "skirt": Color("#74746e"), "accent": Color("#a9a390"),
		"glass": Color("#657373"), "frame": Color("#ede8dd"), "spacing": 3.29, "height": 2.88, "levels": 5, "balconies": 3},
	265251164: {"address": "32", "base": Color("#d2cbbc"), "skirt": Color("#77736d"), "accent": Color("#a09383"),
		"glass": Color("#687477"), "frame": Color("#f1eee1"), "spacing": 3.22, "height": 2.83, "levels": 5, "balconies": 3},
	262392298: {"address": "63", "base": Color("#bfb8a4"), "skirt": Color("#817e73"), "accent": Color("#847e78"),
		"glass": Color("#6e7777"), "frame": Color("#e5e2d6"), "spacing": 2.59, "height": 2.90, "levels": 5, "balconies": 3},
	262392299: {"address": "65", "base": Color("#d0c7ba"), "skirt": Color("#8b8277"), "accent": Color("#99908b"),
		"glass": Color("#697b79"), "frame": Color("#e9e5d7"), "spacing": 3.17, "height": 2.87, "levels": 5, "balconies": 3},
	543403337: {"address": "3", "base": Color("#bcaf9b"), "skirt": Color("#735e52"), "accent": Color("#a68d78"),
		"glass": Color("#667477"), "frame": Color("#ece9df"), "spacing": 3.08, "height": 2.87, "levels": 5, "balconies": 2},
	265233124: {"address": "1", "base": Color("#ada8a1"), "skirt": Color("#4e5659"), "accent": Color("#5b6263"),
		"glass": Color("#637e84"), "frame": Color("#59666d"), "spacing": 3.3, "height": 3.12, "levels": 2, "balconies": 0, "shops": true},
	542147693: {"address": "28", "base": Color("#c4b083"), "skirt": Color("#494f42"), "accent": Color("#466850"),
		"glass": Color("#687c80"), "frame": Color("#d3d7c5"), "spacing": 3.38, "height": 3.0, "levels": 1, "balconies": 0, "shops": true}
}

var _geo := Geometry.new()


static func model_height(profile: Dictionary, mapped: float) -> float:
	var pictured := float(profile.get("height", 0.0)) * int(profile.get("levels", 0)) + 0.14
	if profile.has("mint_retail") or profile.has("shopping_gallery") or profile.has("striped_office"):
		return pictured
	return maxf(mapped, pictured)


func decorate(tile: Node3D, mesh: RefCounted, outline: PackedVector2Array, foundation: float, profile: Dictionary) -> void:
	var main_edge := 0
	var office := bool(profile.get("striped_office", false))
	var mint := bool(profile.get("mint_retail", false))
	var gallery := str(profile.get("shopping_gallery", ""))
	for index in outline.size():
		if outline[index].distance_squared_to(outline[(index + 1) % outline.size()]) > outline[main_edge].distance_squared_to(outline[(main_edge + 1) % outline.size()]):
			main_edge = index
	for index in outline.size():
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index + 1) % outline.size()]
		var length := a.distance_to(b)
		if length < 3.0:
			continue
		var direction := a.direction_to(b)
		var outward := direction.orthogonal()
		if Geometry2D.is_point_in_polygon(a.lerp(b, 0.5) + outward * 0.08, outline):
			outward = -outward
		var forward := Vector3(outward.x, 0, outward.y)
		var start := Vector3(a.x, foundation, a.y) + forward * 0.04
		var historic := str(profile.get("historic", ""))
		var finish := Vector3(b.x, foundation, b.y) + forward * 0.04
		mesh.facade(start, finish, 0.56, profile.skirt)
		if mint:
			for band in 5:
				mesh.facade(start + Vector3.UP * (3.12 + band * 0.48), finish + Vector3.UP * (3.12 + band * 0.48), 0.056, Color("#a2b9a6"))
			for height: float in [2.66, 5.49]:
				mesh.facade(start + Vector3.UP * height, finish + Vector3.UP * height, 0.34, profile.accent)
		if office:
			mesh.facade(start + Vector3.UP * 2.91, finish + Vector3.UP * 2.91, 0.49, Color("#a4a99c"))
		if not gallery.is_empty():
			mesh.facade(start + Vector3.UP * 2.87, finish + Vector3.UP * 2.87, 0.86, profile.base.darkened(0.07))
			mesh.facade(start + Vector3.UP * 5.37, finish + Vector3.UP * 5.37, 0.53, profile.accent)
			if outward.y > 0.18:
				var canopy := Vector3(outward.x, 0, outward.y) * 1.08
				var eave := Vector3.UP * 2.78
				mesh.quad(start + eave, finish + eave, finish + eave + canopy, start + eave + canopy, profile.skirt.lightened(0.11))
		var count := maxi(1, floori(length / float(profile.spacing)))
		var step := length / count
		for level in int(profile.levels):
			var floor_y: float = foundation + level * float(profile.height)
			if level > 0 and (index % 2 == 0 or not historic.is_empty()):
				mesh.facade(Vector3(start.x, floor_y, start.z), Vector3(finish.x, floor_y, finish.z), 0.095, profile.accent)
			for column in count:
				var bay := a + direction * (0.5 + column) * step
				var balcony_count := int(profile.balconies)
				var balcony := balcony_count > 0 and level > 0 and length > 7.0 and index % 2 == 0 and column % maxi(1, balcony_count) == 0
				var storefront := (bool(profile.get("shops", false)) or mint or office or not gallery.is_empty()) and level == 0
				var wide := storefront or mint or not gallery.is_empty()
				if office and level > 0:
					var rib := Vector3(direction.x, 0, direction.y) * step * 0.25
					var column_base := Vector3(bay.x, floor_y, bay.y) + forward * 0.063 - rib
					mesh.facade(column_base, column_base + rib * 2.0, 2.90, profile.accent)
				if balcony and bool(profile.get("balcony_columns", false)):
					var half := Vector3(direction.x, 0, direction.y) * step * 0.42
					var column_base := Vector3(bay.x, floor_y, bay.y) + forward * 0.09
					mesh.facade(column_base - half, column_base + half, float(profile.height), profile.accent)
				var width := step * (0.34 if office and not storefront else (0.84 if wide else 0.62))
				_window(mesh, bay, direction, outward, floor_y, minf(width, 2.55), profile, balcony, storefront)
				if historic == "station" and not storefront:
					_arch(mesh, bay, direction, outward, floor_y + 2.27, minf(step * 0.62, 2.4), profile.frame)
		if (mint or not gallery.is_empty()) and length > 7.0 and outward.y > 0.18:
			var center := start.lerp(finish, 0.5) + Vector3.UP * (5.92 if mint else 3.36) + forward * 0.07
			_geo.signage(tile, center, "HANZA" if mint else gallery, 34, Color("#315d49") if mint else Color("#344770"), atan2(outward.x, outward.y))
		if index == main_edge and not office and not mint and gallery.is_empty() and not str(profile.address).is_empty():
			var center := start.lerp(finish, 0.5 if historic == "station" else 0.44) + Vector3.UP * 2.48 + forward * 0.24
			if historic == "retail":
				center.y += 0.95
				var across := Vector3(direction.x, 0, direction.y) * 6.30
				mesh.facade(center - across - Vector3.UP * 0.28, center + across - Vector3.UP * 0.28, 0.91, profile.accent)
				center += forward * 0.035
			elif not historic.is_empty():
				_historic_entry(tile, center - Vector3.UP * 2.48, outward, historic)
			var label := _geo.signage(tile, center, str(profile.address), 20, Color("#f1eee3"), atan2(outward.x, outward.y))
			label.outline_modulate = Color("#383932")

	if office:
		_roof_dishes(tile, outline, foundation + float(profile.height) * int(profile.levels) + 0.15)


func _roof_dishes(tile: Node3D, outline: PackedVector2Array, y: float) -> void:
	var center := Vector2.ZERO
	for point in outline:
		center += point
	center /= outline.size()
	for index in outline.size():
		var edge := outline[index].lerp(outline[(index + 1) % outline.size()], 0.35)
		var at := center.lerp(edge, 0.72)
		_geo.taper(tile, Vector3(at.x, y + 0.47, at.y), 0.92, 0.045, 0.075, Color("#6d7674"), 8)
		var dish := _geo.taper(tile, Vector3(at.x, y + 1.02, at.y), 0.14, 0.45, 0.12, Color("#c4c5b5"), 16)
		dish.rotation_degrees = Vector3(63, index * 15, -12)


func _arch(mesh: RefCounted, center: Vector2, axis: Vector2, normal: Vector2, y: float, width: float, tone: Color) -> void:
	var origin := Vector3(center.x, y, center.y) + Vector3(normal.x, 0, normal.y) * 0.084
	var across := Vector3(axis.x, 0, axis.y)
	for i in 9:
		var a := float(i) * PI / 9.0
		var b := float(i + 1) * PI / 9.0
		var left := origin + across * (cos(a) * width * 0.5) + Vector3.UP * (sin(a) * 0.26)
		var right := origin + across * (cos(b) * width * 0.5) + Vector3.UP * (sin(b) * 0.26)
		mesh.facade(left, right, 0.075, tone)


func _historic_entry(tile: Node3D, center: Vector3, direction: Vector2, style: String) -> void:
	var entry := Node3D.new()
	tile.add_child(entry)
	entry.position = center
	entry.rotation.y = atan2(direction.x, direction.y)
	var wood := Color("#5f4a37")
	var civic := style == "civic"
	_geo.box(entry, Vector3(0, 1.18, 0.02), Vector3(2.45, 2.36, 0.16), wood)
	_geo.box(entry, Vector3(0, 1.29, 0.115), Vector3(1.95, 1.82, 0.05), Color("#506062"))
	_geo.box(entry, Vector3(0, 1.29, 0.16), Vector3(0.074, 1.88, 0.08), wood)
	_geo.box(entry, Vector3(0, 0.13, 0.42), Vector3(3.3, 0.24, 1.05), Color("#aaa093"))
	if civic:
		_geo.box(entry, Vector3(0, 6.48, -0.74), Vector3(3.95, 12.96, 3.15), Color("#c9b998"))
		_geo.box(entry, Vector3(0, 12.88, -0.62), Vector3(4.55, 0.36, 3.66), Color("#756d5c"))
		for column in 4:
			var x := (column - 1.5) * 0.63
			for row in 3:
				var y := 5.38 + row * 2.16
				_geo.box(entry, Vector3(x, y, 0.83), Vector3(0.35, 1.63, 0.11), Color("#e4dbc4"))
				_geo.box(entry, Vector3(x, y, 0.91), Vector3(0.22, 1.36, 0.054), Color("#4c6164"))
		_geo.taper(entry, Vector3(0, 13.70, -0.62), 1.65, 0.036, 0.042, Color("#88857a"), 7)
		for stripe in 3:
			var colors := [Color("#eebc53"), Color("#498050"), Color("#a84945")]
			_geo.box(entry, Vector3(0.5, 14.1 - stripe * 0.14, -0.62), Vector3(0.99, 0.14, 0.034), colors[stripe])
		_geo.box(entry, Vector3(0, 2.79, 0.47), Vector3(3.52, 0.22, 1.18), Color("#696b5d"))
		for index in 3:
			var stripes := [Color("#f5bc38"), Color("#33965f"), Color("#c44949")]
			_geo.box(entry, Vector3(2.07, 2.49 - 0.19 * index, 0.44), Vector3(0.58, 0.19, 0.016), stripes[index])
	else:
		var pediment := _geo.taper(entry, Vector3(0, 6.37, -1.16), 1.44, 0.19, 5.26, Color("#7f604d"), 4)
		pediment.scale.z = 0.38
		pediment.rotation.y = PI * 0.25
		_geo.box(entry, Vector3(0, 5.59, -0.62), Vector3(9.28, 0.23, 3.66), Color("#a6957d"))
		for x: float in [-4.16, 4.16]:
			_geo.box(entry, Vector3(x, 2.65, -0.07), Vector3(0.49, 5.3, 0.54), Color("#e3d9c4"))
		_geo.box(entry, Vector3(0, 3.44, 0.52), Vector3(3.95, 0.18, 1.27), wood)
		for index in 17:
			_geo.box(entry, Vector3(-1.86 + 0.23 * index, 3.86, 1.09), Vector3(0.073, 0.73, 0.075), wood)
		for side: float in [-1.0, 1.0]:
			var brace := _geo.box(entry, Vector3(1.73 * side, 3.04, 0.53), Vector3(0.11, 0.99, 0.11), wood)
			brace.rotation.x = PI * 0.24
		_geo.box(entry, Vector3(0, 4.21, 1.09), Vector3(3.94, 0.11, 0.11), wood)
	_geo.batch_static(entry)


func _window(mesh: RefCounted, center: Vector2, axis: Vector2, normal: Vector2, floor_y: float, width: float, profile: Dictionary, balcony: bool, shop: bool) -> void:
	var glazed := balcony and bool(profile.get("glazed", false))
	var block_depth := 0.64 if glazed else (0.51 if balcony else 0.054)
	var glass_y := floor_y + (0.77 if shop else 0.98)
	var height := 1.95 if shop else (1.62 if glazed else 1.33)
	var p := center - axis * width * 0.5 + normal * block_depth
	var q := center + axis * width * 0.5 + normal * block_depth
	var a := Vector3(p.x, glass_y, p.y)
	var b := Vector3(q.x, glass_y, q.y)
	var inset := Vector3(axis.x, 0, axis.y) * 0.062
	mesh.facade(a, b, height, profile.frame)
	var offset := Vector3(normal.x, 0, normal.y) * 0.011
	mesh.facade(a + inset + Vector3.UP * 0.064 + offset, b - inset + Vector3.UP * 0.064 + offset, height - 0.128, profile.glass)
	var middle := (a + b) * 0.5 + offset * 2.0
	mesh.facade(middle - inset * 0.42, middle + inset * 0.42, height, profile.frame)
	if glazed:
		var bar := Vector3.UP * (height * 0.56) + offset * 2.5
		mesh.facade(a + bar, b + bar, 0.039, profile.frame)
	var sill := Vector3(normal.x, 0, normal.y) * 0.081
	mesh.facade(a - inset + sill - Vector3.UP * 0.085, b + inset + sill - Vector3.UP * 0.085, 0.083, profile.skirt)
	if balcony:
		var slab_y := floor_y + 0.47
		var left := Vector3(a.x, slab_y, a.z)
		var right := Vector3(b.x, slab_y, b.z)
		var wall_offset := Vector3(normal.x, 0, normal.y) * block_depth
		mesh.facade(left, right, 0.51, profile.accent)
		mesh.facade(left - wall_offset, left, height + 0.49, profile.accent)
		mesh.facade(right, right - wall_offset, height + 0.49, profile.accent)
		mesh.quad(left, right, right - wall_offset, left - wall_offset, profile.skirt)
