extends RefCounted

const STATS := {
	"fists": [2.10, 4.7, false, 480],
	"baton": [2.55, 6.7, false, 510],
	"pulse": [16.0, 9.2, true, 430],
	"sport_pistol": [36.0, 11.0, true, 360],
	"field_carbine": [63.0, 14.0, true, 300],
	"foam_hammer": [2.35, 7.4, false, 490],
	"crowbar": [2.6, 7.8, false, 490],
	"trainer_blade": [2.05, 6.5, false, 490],
	"yoyo": [2.8, 4.5, false, 450],
	"cheat_rpg": [92.0, 24.0, true, 1340],
	"field_blade": [2.30, 13.5, false, 535],
	"stun_wand": [12.0, 8.2, true, 410],
	"old_revolver": [37.0, 12.0, true, 410],
	"compact_smg": [43.0, 9.5, true, 190],
	"pump_scattergun": [27.0, 16.0, true, 760],
	"service_pistol": [43.0, 13.0, true, 290],
	"patrol_carbine": [66.0, 13.5, true, 255],
	"short_scattergun": [24.0, 17.5, true, 690],
	"practice_bat": [2.62, 7.1, false, 535],
	"longwatch_rifle": [110.0, 20.0, true, 980],
	"sidewinder": [31.0, 8.0, true, 145],
	"street_maul": [2.48, 12.6, false, 770],
}
const FIREARMS := ["sport_pistol", "field_carbine", "old_revolver", "compact_smg", "sidewinder", "pump_scattergun", "service_pistol", "patrol_carbine", "short_scattergun", "cheat_rpg", "longwatch_rifle"]
const LONG := ["field_carbine", "pump_scattergun", "patrol_carbine", "short_scattergun", "cheat_rpg", "longwatch_rifle"]

static func is_firearm(kind: String) -> bool:
	return kind in FIREARMS

static func is_ranged(kind: String) -> bool:
	return bool(STATS.get(kind, [0.0, 0.0, false])[2])

