extends RefCounted

const MAX_STARS := 6
const SEARCH_SECONDS := 21.0
const THRESHOLDS := [1.0, 5.0, 12.0, 24.0, 46.0, 88.0]

var stars := 0
var heat := 0.0
var _cooldown := 0.0
var _last_reports: Dictionary = {}


func report(severity: int, description := "") -> void:
	if severity <= 0:
		return
	var now := Time.get_ticks_msec()
	var previous := int(_last_reports.get(description, -10000))
	if not description.is_empty() and now - previous < 3500:
		_cooldown = maxf(_cooldown, SEARCH_SECONDS * 0.75)
		return
	_last_reports[description] = now
	heat = clampf(heat + float(severity) * (1.15 if severity > 1 else 1.0), 0.0, 100.0)
	_update_stars()
	_cooldown = SEARCH_SECONDS + stars * 2.5


func _update_stars() -> void:
	stars = 0
	for threshold: float in THRESHOLDS:
		if heat >= threshold:
			stars += 1


func update(delta: float, near_patrol: bool) -> bool:
	if stars == 0:
		heat = 0.0
		return false
	if near_patrol:
		_cooldown = maxf(_cooldown, 5.5)
	else:
		_cooldown -= delta
	if _cooldown > 0.0:
		return false
	var previous := stars
	heat = maxf(float(THRESHOLDS[stars - 1]) - 0.1, 0.0)
	_update_stars()
	_cooldown = 8.0 + stars * 2.0
	return previous != stars


func restore(value: int, saved_heat := -1.0) -> void:
	var level := clampi(value, 0, MAX_STARS)
	heat = 0.0 if level == 0 else float(THRESHOLDS[level - 1])
	if saved_heat >= 0.0:
		heat = clampf(saved_heat, 0.0, 100.0)
	_update_stars()
	_cooldown = SEARCH_SECONDS + stars * 2.5
	_last_reports.clear()

