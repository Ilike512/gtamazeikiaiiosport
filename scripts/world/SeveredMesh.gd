extends RefCounted
## Rebuilds only the index buffer. Each surviving triangle stays mapped to one
## side of the cut, so its skin weights cannot stretch between separated bones.

static var _variants: Dictionary = {}


static func apply(model: Node3D, skeleton: Skeleton3D, root_bone: int) -> bool:
	var changed := false
	for instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var source := instance.mesh as ArrayMesh
		if source == null or instance.skin == null:
			continue
		var key := Vector2i(source.get_instance_id(), root_bone)
		if not _variants.has(key):
			_variants[key] = _rebuild(source, instance.skin, skeleton, root_bone)
		var result := _variants[key] as ArrayMesh
		if result == null:
			continue
		var overrides: Array[Material] = []
		for surface in source.get_surface_count():
			overrides.append(instance.get_surface_override_material(surface))
		instance.mesh = result
		for surface in overrides.size():
			instance.set_surface_override_material(surface, overrides[surface])
		changed = true
	return changed


static func _rebuild(source: ArrayMesh, skin: Skin, skeleton: Skeleton3D, root_bone: int) -> ArrayMesh:
	var separated := PackedByteArray()
	separated.resize(skin.get_bind_count())
	for bind in separated.size():
		var bone := skin.get_bind_bone(bind)
		if not skin.get_bind_name(bind).is_empty():
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		while bone >= 0 and bone != root_bone:
			bone = skeleton.get_bone_parent(bone)
		separated[bind] = int(bone == root_bone)
	var copy := ArrayMesh.new()
	var revised := false
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var primitive := source.surface_get_primitive_type(surface)
		var flags := source.surface_get_format(surface)
		if primitive == Mesh.PRIMITIVE_TRIANGLES and bones != null and weights != null and indices != null:
			var count: int = bones.size() / vertices.size()
			var section := PackedByteArray()
			section.resize(vertices.size())
			for vertex in vertices.size():
				var start := vertex * count
				var mass := 0.0
				for slot in range(start, start + count):
					mass += float(weights[slot]) * float(separated[bones[slot]])
				section[vertex] = int(mass >= 0.5)
				var remaining := 0.0
				for slot in range(start, start + count):
					if separated[bones[slot]] != section[vertex]:
						weights[slot] = 0.0
					remaining += weights[slot]
				for slot in range(start, start + count):
					weights[slot] /= maxf(remaining, 0.0001)
			var triangles := PackedInt32Array()
			for triangle in range(0, indices.size(), 3):
				var a: int = indices[triangle]
				var b: int = indices[triangle + 1]
				var c: int = indices[triangle + 2]
				if section[a] == section[b] and section[a] == section[c]:
					triangles.append(a)
					triangles.append(b)
					triangles.append(c)
			if not triangles.is_empty():
				revised = revised or triangles.size() != indices.size()
				arrays[Mesh.ARRAY_INDEX] = triangles
				arrays[Mesh.ARRAY_WEIGHTS] = weights
		copy.add_surface_from_arrays(primitive, arrays, [], {}, flags & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		copy.surface_set_material(surface, source.surface_get_material(surface))
	return copy if revised else null

