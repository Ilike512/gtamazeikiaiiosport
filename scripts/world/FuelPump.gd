extends StaticBody3D

signal ignited(at: Vector3)

const Fire = preload("res://scripts/vehicles/VehicleFire.gd")
var _collider: CollisionShape3D
var _burning := false


func build() -> void:
	name = "FuelPump"
	var box := BoxShape3D.new()
	box.size = Vector3(0.72, 1.66, 0.58)
	_collider = CollisionShape3D.new()
	_collider.shape = box
	_collider.position = Vector3(0, 0.92, 0.42)
	add_child(_collider)


func receive_vehicle_hit(strength: float, _travel: Vector3) -> bool:
	if _burning or strength < 6.0:
		return false
	_burning = true
	_collider.set_deferred("disabled", true)
	for child: Node in get_children():
		if child is MeshInstance3D or child is Label3D:
			child.hide()
	var fire := Fire.new()
	fire.position = Vector3(0, 0.38, 0.42)
	fire.scale = Vector3.ONE * 2.25
	add_child(fire)
	ignited.emit(global_position + Vector3(0, 0.72, 0.42))
	get_tree().create_timer(13.0, false).timeout.connect(fire.queue_free)
	return true
