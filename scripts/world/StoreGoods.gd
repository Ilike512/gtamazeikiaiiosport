extends Node3D

const Product = preload("res://scripts/world/ProductModel.gd")

var _stock: Dictionary = {}


func stock_shelves(items: Array[Dictionary], centers: Array[Vector2]) -> void:
	for index in items.size():
		var row := index % centers.size()
		var seat := index / centers.size()
		var level := seat / 14
		var faced := seat % 14
		var side := -1.0 if faced < 7 else 1.0
		var item := items[index]
		var facing := Node3D.new()
		var x := centers[row].x + side * 0.66
		facing.position = Vector3(x, 0.18 + level * 0.39, centers[row].y - 4.05 + (faced % 7) * 1.18)
		facing.rotation.y = side * PI * 0.5
		add_child(facing)
		for display_index in 2:
			var product := Product.new()
			facing.add_child(product)
			var dimensions := product.build(item, 0.26)
			product.position = Vector3((display_index - 0.5) * 0.27, dimensions.y * 0.5, 0.055)
		_stock[item.id] = facing


func find_product(at: Vector3, forward: Vector3) -> String:
	var point := at + Vector3.UP * 0.96
	var best := 1.76
	var selected := ""
	for id: String in _stock:
		var center: Vector3 = _stock[id].global_position - point
		var distance := center.length()
		if distance <= 1.85 and distance > 0.01:
			var weight := distance - center.normalized().dot(forward) * 0.72
			if weight < best:
				best = weight
				selected = id
	return selected


func take_product(id: String) -> void:
	if _stock.has(id):
		_stock[id].queue_free()
		_stock.erase(id)
