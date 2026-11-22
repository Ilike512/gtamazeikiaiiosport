extends RefCounted

const MAXIMA_FOOTPRINT := [
	203626568, 9.5, 2, [[-56.5, 202.7], [-25.7, 230.1], [-54.0, 262.0], [-109.4, 212.6],
	[-89.1, 189.7], [-74.2, 202.9], [-66.3, 194.0]], "Maxima XX", 0
]

const MAXIMA := {
	"id": "maxima", "name": "Maxima XX", "building": 203626568, "address": "Žemaitijos g. 20-2",
	"entrance": Vector2(-34.45, 240.10), "heading": 0.846, "door_width": 3.02, "floor_height": 0.72,
	"hall_height": 4.75, "threshold_depth": 1.46, "color": Color("#9e3b41")
}
const RIMI := {
	"id": "rimi", "name": "Rimi", "building": 599382149, "address": "Žemaitijos g. 38",
	"entrance": Vector2(459.4, 466.04), "heading": 2.775, "door_width": 3.18, "floor_height": 0.23,
	"room_offset": Vector3(0, 0.23, -9.92), "span": 20.0, "depth": 20.0, "aisles": 3, "color": Color("#a23e45")
}
const GRUSTE := {
	"id": "gruste", "name": "Grūstė · Putinas", "building": 265251169, "address": "Naftininkų g. 38-2",
	"entrance": Vector2(338.57, 295.42), "heading": -0.3485, "door_width": 3.15, "floor_height": 0.17,
	"hall_height": 4.68, "threshold_depth": 0.44, "color": Color("#315644")
}
const MAXIMA_DAUKSOS := {
	"id": "maxima_dauksos", "name": "Maxima X", "building": 399989258, "address": "M. Daukšos g. 26",
	"entrance": Vector2(1030.6, 304.98), "heading": 1.43, "door_width": 4.1, "floor_height": 0.11,
	"hall_height": 4.85, "threshold_depth": 0.78, "color": Color("#a6373d")
}
const LIDL := {
	"id": "lidl", "name": "Lidl", "building": 420910825, "address": "Daukšos g. 24",
	"entrance": Vector2(1069.4, 203.4), "heading": 0.594, "door_width": 4.0, "floor_height": 0.10,
	"hall_height": 4.65, "threshold_depth": 0.67, "color": Color("#24578b")
}
const SENUKAI := {
	"id": "senukai", "name": "Senukai", "building": 206359030, "address": "Tirkšlių g. 5E",
	"entrance": Vector2(1259.35, 112.10), "heading": 2.752, "door_width": 4.2, "floor_height": 0.11,
	"hall_height": 6.1, "threshold_depth": 0.72, "color": Color("#45563c")
}
const BURGER := {
	"name": "Burger Stotis", "address": "Eifelis, Senkelio g. 14A",
	"entrance": Vector2(1370.93, 840.1), "heading": 1.425, "span": 36.0, "depth": 32.0,
	"door_width": 4.20, "floor_height": 0.15, "color": Color("#af5634")
}
const ROVANA := {
	"id": "rovana", "name": "Rovana", "building": 367417475, "address": "Naftininkų g. 5",
	"entrance": Vector2(497.43, -156.35), "heading": -0.164, "door_width": 1.82, "floor_height": 0.32,
	"room_offset": Vector3(0, 0.32, -3.65), "span": 8.7, "depth": 7.4, "aisles": 0, "color": Color("#314947")
}


static func burger_footprint() -> PackedVector2Array:
	var points := PackedVector2Array()
	var front := Vector2(sin(BURGER.heading), cos(BURGER.heading))
	var right := Vector2(front.y, -front.x)
	for corner: Vector2 in [Vector2(-17.86, 0.05), Vector2(17.86, 0.05),
		Vector2(17.86, -31.9), Vector2(-17.86, -31.9)]:
		points.append(BURGER.entrance + right * corner.x + front * corner.y)
	return points


static func for_building(id: int) -> Dictionary:
	if id == MAXIMA.building:
		return MAXIMA
	if id == RIMI.building:
		return RIMI
	if id == GRUSTE.building:
		return GRUSTE
	if id == ROVANA.building:
		return ROVANA
	if id == MAXIMA_DAUKSOS.building:
		return MAXIMA_DAUKSOS
	if id == LIDL.building:
		return LIDL
	if id == SENUKAI.building:
		return SENUKAI
	return {}
