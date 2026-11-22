extends RefCounted

const SLOT_COUNT := 8
const DEFAULT_SLOTS := ["", "", "", "", "", "", "", ""]

var catalog: Dictionary = {}
var owned: Dictionary = {}
var slots: Array = []
var equipment := ""


func load_catalog() -> void:
	for item: Dictionary in GameManager.read_json("res://data/items/items.json", []):
		var id := str(item.id)
		item.texture = AssetShelf.image("items/" + id, str(item.icon))
		catalog[id] = item


func restore(saved: Dictionary) -> void:
	slots = DEFAULT_SLOTS.duplicate()
	if saved.get("items") is Array:
		slots = saved.items.duplicate()
		slots.resize(SLOT_COUNT)
	owned.clear()
	if saved.get("owned_items") is Dictionary:
		for id: String in saved.owned_items:
			if catalog.has(id):
				var count := clampi(int(saved.owned_items[id]), 0, 999)
				if count > 0:
					owned[id] = count
	else:
		for value: Variant in slots:
			if catalog.has(value):
				owned[value] = int(owned.get(value, 0)) + 1
	for index in slots.size():
		if not owned.has(slots[index]):
			slots[index] = ""
	equipment = str(saved.get("equipment", ""))
	if not owned.has(equipment) or not catalog[equipment].has("equipment"):
		equipment = ""


func hotbar() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: Variant in slots:
		result.append(catalog.get(id, {}))
	return result


func items_from(source: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in catalog.values():
		if item.source == source:
			result.append(item)
	return result


func available(weapons_only := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in catalog:
		var item: Dictionary = catalog[id]
		if owned.has(id) and (not weapons_only or item.has("equipment")):
			result.append(item)
	return result


func add(id: String) -> bool:
	if not catalog.has(id) or int(owned.get(id, 0)) >= 999:
		return false
	owned[id] = int(owned.get(id, 0)) + 1
	if not slots.has(id):
		var empty := slots.find("")
		if empty >= 0:
			slots[empty] = id
	return true


func consume(id: String) -> bool:
	if not owned.has(id):
		return false
	var count := int(owned[id]) - 1
	if count > 0:
		owned[id] = count
	else:
		owned.erase(id)
		if equipment == id:
			equipment = ""
		for index in slots.size():
			if slots[index] == id:
				slots[index] = ""
	return true


func pin(id: String, slot: int) -> void:
	if owned.has(id) and slot >= 0 and slot < SLOT_COUNT:
		var old := slots.find(id)
		if old >= 0:
			slots[old] = ""
		slots[slot] = id
