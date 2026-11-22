extends CharacterBody3D

signal landed_hard(speed_down: float)
signal struck(strength: float)
signal swim_transition(entering: bool, at: Vector3)

enum Movement { IDLE, WALK, JOG, SPRINT, AIRBORNE, VAULT, SWIM, DIVE }

@export var walk_acceleration := 11.8
@export var sprint_acceleration := 8.8
@export var braking := 16.5
@export var sprint_turn_rate := 3.2
@export var jog_speed := 4.3

@onready var _vault_probe: RayCast3D = $VaultProbe
var movement_state := Movement.IDLE
var water: Dictionary = {}
var swimming := false
var _swim_phase := 0.0
var _swim_enter := 0.0
var _splash: AudioStreamPlayer3D
var _splash_stream: AudioStream
var _vault_time := 0.0
var _vault_start := Vector3.ZERO
var _vault_end := Vector3.ZERO
var _vault_rise := 0.0
const VAULT_SECONDS := 0.54

const Geometry = preload("res://scripts/world/Geometry.gd")
const Gait = preload("res://scripts/player/Gait.gd")
const Clips = preload("res://scripts/player/InteractionClips.gd")
const Product = preload("res://scripts/world/ProductModel.gd")
const ModelBounds = preload("res://scripts/world/ModelBounds.gd")
const SuppliedMotion = preload("res://scripts/player/SuppliedMotion.gd")

var input_enabled := true
var camera_heading := 0.0
var stamina := 100.0
var walk_speed := 5.1
var run_speed := 8.7
var indoor_speed_limit := 0.0
var energy_remaining := 0.0
var ejection_grace := 0.0
var animation_phase := 0.0

var _geometry := Geometry.new()
var _visual: Node3D
var _outfit: MeshInstance3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _custom: Node3D
var _animations: AnimationPlayer
var _seated := false
var _standing_model_scale := Vector3.ONE
var _supplied_motion: RefCounted
var _gear_mesh: Node3D
var _equipment_kind := ""
var _pose_time := 0.0
var _action_pose := ""
var _landing_time := 0.0
var _step_distance := 0.0
var _footsteps: AudioStreamPlayer3D
var _walk_audio: AudioStream
var _run_audio: AudioStream
var _grass_audio: AudioStream
var grass_underfoot := false


func _ready() -> void:
	_footsteps = AudioStreamPlayer3D.new()
	_footsteps.bus = &"SFX"
	_footsteps.max_distance = 24.0
	add_child(_footsteps)
	_walk_audio = AssetShelf.sound("footstep_walk", "res://assets/audio/sfx/footstep_walk.wav")
	_run_audio = AssetShelf.sound("footstep_run", "res://assets/audio/sfx/footstep_run.wav")
	_grass_audio = AssetShelf.sound("footstep_grass", "res://assets/audio/sfx/footstep_grass.mp3", true)
	_splash = AudioStreamPlayer3D.new()
	_splash.bus = &"SFX"
	_splash.max_distance = 35.0
	add_child(_splash)
	_splash_stream = AssetShelf.sound("water_splash", "res://assets/audio/sfx/water_splash.wav")
	_splash.stream = _splash_stream

	_visual = Node3D.new()
	add_child(_visual)
	var coat := Color("#b65844")
	var skin := Color("#bf9277")
	var jeans := Color("#373f4a")
	var hair := Color("#3b322d")
	_outfit = _geometry.taper(_visual, Vector3(0, 1.17, 0), 0.59, 0.243, 0.198, coat, 12)
	_outfit.scale.z = 0.68
	_geometry.box(_visual, Vector3(0, 1.13, -0.159), Vector3(0.014, 0.49, 0.017), Color("#d2bd9d"))
	_oval(_visual, Vector3(0, 1.429, 0.045), Vector3(0.29, 0.15, 0.26), Color("#523d3d"))
	_geometry.taper(_visual, Vector3(0, 1.50, 0), 0.17, 0.075, 0.083, skin, 10)
	_oval(_visual, Vector3(0, 1.641, -0.01), Vector3(0.214, 0.287, 0.217), skin)
	_oval(_visual, Vector3(0, 1.727, 0.008), Vector3(0.229, 0.127, 0.232), hair)
	_oval(_visual, Vector3(0, 1.640, -0.119), Vector3(0.049, 0.067, 0.041), skin.lightened(0.06))
	for side: float in [-1.0, 1.0]:
		_oval(_visual, Vector3(side * 0.104, 1.636, 0.002), Vector3(0.036, 0.061, 0.053), skin)
		_oval(_visual, Vector3(side * 0.047, 1.668, -0.110), Vector3(0.025, 0.014, 0.010), Color("#3a3030"))
	_left_leg = _limb(Vector3(-0.104, 0.89, 0), Vector3(0.185, 0.72, 0.18), jeans, false)
	_right_leg = _limb(Vector3(0.104, 0.89, 0), Vector3(0.185, 0.72, 0.18), jeans, false)
	_left_arm = _limb(Vector3(-0.216, 1.38, 0), Vector3(0.143, 0.49, 0.155), coat, true)
	_right_arm = _limb(Vector3(0.216, 1.38, 0), Vector3(0.143, 0.49, 0.155), coat, true)


func apply_character(character: Dictionary) -> void:
	walk_speed = minf(maxf(float(character.get("walk_speed", 5.1)), 1.0), 2.70)
	run_speed = maxf(float(character.get("run_speed", 8.7)), walk_speed)
	if is_instance_valid(_custom):
		_custom.queue_free()
	_custom = null
	_animations = null
	_supplied_motion = null
	_gear_mesh = null
	var path := str(character.get("model", ""))
	var model_ready := not path.is_empty() and ResourceLoader.exists(path, "PackedScene")
	if not model_ready:
		path = str(character.get("fallback_model", ""))
	_visual.show()
	if not path.is_empty() and ResourceLoader.exists(path, "PackedScene"):
		var scene := load(path) as PackedScene
		var actor := scene.instantiate()
		if actor is Node3D:
			_custom = actor
			add_child(_custom)
			var yaw := float(character.get("model_yaw_degrees", 0.0)) if model_ready else float(character.get("fallback_yaw_degrees", 180.0))
			_custom.rotation.y += deg_to_rad(yaw)
			if model_ready and character.has("model_height"):
				ModelBounds.fit_to_height(_custom, float(character.model_height))
				_custom.position.y += float(character.get("model_floor_offset", 0.0))
			if model_ready and bool(character.get("procedural_motion", false)):
				_supplied_motion = SuppliedMotion.new(_custom, _skeleton())
			for controller: AnimationPlayer in _custom.find_children("*", "AnimationPlayer", true, false):
				_install_overrides(controller, character.get("animation_library", ""), character.get("animation_aliases", {}))
				if controller.has_animation("idle") and controller.has_animation("walk"):
					_animations = controller
					for name_on_model: String in ["idle", "walk", "run", "swim", "swim_dive", "tread"]:
						if controller.has_animation(name_on_model):
							controller.get_animation(name_on_model).loop_mode = Animation.LOOP_LINEAR
					Gait.install_run(controller, _skeleton())
					Gait.install_jump(controller)
					Gait.install_vault(controller)
					Gait.install_swim(controller, _skeleton())
					Clips.install(controller)
					controller.play("idle")
					break
			if bool(character.get("tint_model", false)):
				_tint_model(Color.from_string(str(character.get("outfit", "")), Color.WHITE))
			_visual.hide()
			show_equipment(_equipment_kind)
			return
		actor.free()
	var outfit := _geometry.material(Color.from_string(str(character.get("outfit", "")), Color("#b65844")))
	_outfit.material_override = outfit
	(_left_arm.get_child(0) as MeshInstance3D).material_override = outfit
	(_right_arm.get_child(0) as MeshInstance3D).material_override = outfit
	show_equipment(_equipment_kind)


func _install_overrides(controller: AnimationPlayer, library_path: String, aliases: Dictionary) -> void:
	if not library_path.is_empty() and ResourceLoader.exists(library_path, "AnimationLibrary"):
		controller.add_animation_library("custom", load(library_path) as AnimationLibrary)
	if aliases.is_empty():
		return
	if not controller.has_animation_library(""):
		controller.add_animation_library("", AnimationLibrary.new())
	var gameplay := controller.get_animation_library("")
	for action: String in aliases:
		var source := StringName(aliases[action])
		if source == StringName(action) or not controller.has_animation(source):
			continue
		var clip := controller.get_animation(source).duplicate() as Animation
		if gameplay.has_animation(action):
			gameplay.remove_animation(action)
		gameplay.add_animation(action, clip)


func _skeleton() -> Skeleton3D:
	if _custom == null:
		return null
	var nodes := _custom.find_children("*", "Skeleton3D", true, false)
	return nodes[0] if not nodes.is_empty() else null


func show_product(item: Dictionary) -> void:
	_equipment_kind = ""
	var mount := _held_mount()
	if item.is_empty():
		if is_instance_valid(_gear_mesh):
			_gear_mesh.queue_free()
		_gear_mesh = null
		return
	var product := Product.new()
	mount.add_child(product)
	var model_type := str(item.get("model", ""))
	var span := 0.57 if model_type in ["carbine", "scattergun", "hammer", "crowbar"] else 0.23
	product.rotation.z = 0.12
	product.build(item, span)


func _held_mount() -> Node3D:
	if is_instance_valid(_gear_mesh):
		_gear_mesh.queue_free()
		_gear_mesh = null
	var skeleton := _skeleton()
	var pivot: Node3D = self if _supplied_motion != null else _right_arm
	if skeleton != null:
		var hand := _right_hand_on(skeleton)
		if not hand.is_empty():
			var grip := BoneAttachment3D.new()
			grip.bone_name = hand
			skeleton.add_child(grip)
			pivot = grip
	var device := Node3D.new()
	pivot.add_child(device)
	_gear_mesh = pivot if pivot is BoneAttachment3D else device
	if pivot == self:
		device.position = Vector3(0.22, 1.02, -0.27)
	else:
		device.position = Vector3(0, -0.06 if pivot is BoneAttachment3D else -0.49, 0.02)
	return device


func show_equipment(kind: String, item: Dictionary = {}) -> void:
	if kind.is_empty():
		show_product({})
		return
	var device := _held_mount()
	_equipment_kind = kind
	if not item.is_empty() and kind not in ["baton", "marker", "pulse", "flare"]:
		var product := Product.new()
		device.add_child(product)
		product.rotation.y = PI * 0.5
		product.build(item, 0.56 if str(item.get("model", "")) in ["carbine", "scattergun", "hammer", "crowbar"] else 0.27)
		return
	if kind in ["sport_pistol", "field_carbine"]:
		var firearm := Product.new()
		device.add_child(firearm)
		firearm.rotation.y = PI * 0.5
		firearm.build({"id": kind, "model": "carbine" if kind == "field_carbine" else "replica"},
			0.61 if kind == "field_carbine" else 0.26)
		return
	var tone := {"baton": Color("#657081"), "marker": Color("#f39575"), "pulse": Color("#71a7bf"), "flare": Color("#db724c")}
	if kind == "baton":
		_geometry.taper(device, Vector3(0, -0.18, 0), 0.49, 0.046, 0.034, tone[kind], 10)
	else:
		_geometry.box(device, Vector3(0, -0.08, 0.03), Vector3(0.075, 0.25, 0.078), tone.get(kind, Color.SLATE_GRAY))
	_geometry.taper(device, Vector3(0, -0.02, 0), 0.111, 0.038, 0.038, Color("#232a30"), 9)


func _right_hand_on(skeleton: Skeleton3D) -> String:
	for name_on_rig: String in ["hand_R", "RightHand", "mixamorig_RightHand", "mixamorig:RightHand", "Base HumanRArmPalm"]:
		if skeleton.find_bone(name_on_rig) >= 0:
			return name_on_rig
	return ""


func action_clip(clip: String, duration: float) -> void:
	_pose_time = duration
	_action_pose = clip
	if _animations != null and _animations.has_animation(clip):
		var animation := _animations.get_animation(clip)
		_animations.speed_scale = 1.32 if animation.loop_mode != Animation.LOOP_NONE else clampf(animation.length / maxf(duration, 0.05), 0.55, 3.8)
		_animations.play(clip, 0.12 if clip == "walk" else 0.09)
	elif _animations == null and _supplied_motion == null:
		var motion := create_tween().set_trans(Tween.TRANS_SINE)
		motion.tween_property(_visual, "rotation:x", 0.26, duration * 0.45)
		motion.tween_property(_visual, "rotation:x", 0.0, duration * 0.55)


func interaction_pose() -> void:
	if _animations == null or not _animations.has_animation("wave"):
		return
	_pose_time = 0.44
	_action_pose = "wave"
	_animations.speed_scale = 1.25
	_animations.play("wave", 0.08, 1.65)


func _tint_model(tint: Color) -> void:
	for mesh: MeshInstance3D in _custom.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original != null:
				var material := original.duplicate() as StandardMaterial3D
				material.albedo_color = material.albedo_color * tint.lightened(0.62)
				mesh.set_surface_override_material(surface, material)


func set_camera_occluded(occluded: bool) -> void:
	if is_instance_valid(_custom):
		_custom.visible = not occluded
	else:
		_visual.visible = not occluded


func stop_footsteps() -> void:
	if _footsteps != null:
		_footsteps.stop()


func set_seated(seated: bool) -> void:
	_vault_time = 0.0
	if seated:
		stop_footsteps()
	if seated:
		swimming = false
	if seated != _seated:
		var model := _custom if is_instance_valid(_custom) else _visual
		if seated:
			_standing_model_scale = model.scale
			model.scale = model.scale * 0.53
		else:
			model.scale = _standing_model_scale
		_seated = seated
	visible = true
	set_physics_process(not seated)
	collision_layer = 0 if seated else 2
	collision_mask = 0 if seated else (1 | 4)
	velocity = Vector3.ZERO


func update_driver_pose(amount: float, delta: float) -> void:
	if _supplied_motion != null:
		_supplied_motion.seat(amount, delta)
	elif _animations != null and _animations.has_animation("idle"):
		if _animations.current_animation != "idle":
			_animations.play("idle", 0.18)
	else:
		_left_leg.rotation.x = -1.13
		_right_leg.rotation.x = -1.13
		_left_arm.rotation.x = -0.77
		_right_arm.rotation.x = -0.77


func _limb(at: Vector3, dimensions: Vector3, tint: Color, arm: bool) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = at
	_visual.add_child(hinge)
	var long_part := _geometry.taper(hinge, Vector3.DOWN * dimensions.y * 0.5, dimensions.y,
		dimensions.x * 0.60, dimensions.x * 0.38, tint, 10)
	long_part.scale.z = dimensions.z / dimensions.x
	_oval(hinge, Vector3(0, -dimensions.y - 0.04, 0 if arm else -0.058),
		Vector3(dimensions.x * 0.78, 0.108, dimensions.z if arm else 0.275),
		Color("#bf9277") if arm else Color("#303331"))
	return hinge


func _oval(parent: Node3D, at: Vector3, proportions: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 7
	var model := MeshInstance3D.new()
	model.position = at
	model.scale = proportions
	model.mesh = mesh
	model.material_override = _geometry.material(tint)
	parent.add_child(model)
	return model


func _physics_process(delta: float) -> void:
	energy_remaining = maxf(energy_remaining - delta, 0.0)
	ejection_grace = maxf(ejection_grace - delta, 0.0)
	if _handle_water(delta):
		return
	if _vault_time > 0.0:
		_advance_vault(delta)
		return
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	var held := movement.length()
	var direction := Vector3(movement.x, 0, movement.y).rotated(Vector3.UP, camera_heading).normalized()
	var indoor := indoor_speed_limit > 0.0
	var sprint := input_enabled and not indoor and Input.is_action_pressed("sprint") and stamina > 1.0 and held > 0.28
	var jogging := held > 0.74 and not indoor
	var boost := 1.22 if energy_remaining > 0.0 else 1.0
	var desired_speed := (run_speed if sprint else (jog_speed if jogging else walk_speed * held)) * boost
	if indoor:
		desired_speed = minf(walk_speed * held * boost, indoor_speed_limit)
	stamina = clampf(stamina + (-18.0 if sprint else 13.5) * delta, 0.0, 100.0)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var grounded := is_on_floor()
	if ejection_grace > 0.0 and not grounded:
		horizontal *= exp(-0.35 * delta)
	elif held < 0.06:
		horizontal = horizontal.move_toward(Vector3.ZERO, braking * (1.0 if grounded else 0.27) * delta)
	else:
		var speed := horizontal.length()
		var turn := sprint_turn_rate if speed > jog_speed + 0.8 else 9.8
		var blended := direction
		if speed > 0.15:
			var current_yaw := atan2(-horizontal.x, -horizontal.z)
			var target_yaw := atan2(-direction.x, -direction.z)
			blended = Vector3.FORWARD.rotated(Vector3.UP, rotate_toward(current_yaw, target_yaw, turn * delta))
		var aligned := clampf(direction.dot(blended), -1.0, 1.0)
		var goal := desired_speed * lerpf(0.33, 1.0, (aligned + 1.0) * 0.5)
		var rate := braking if speed > goal else (sprint_acceleration if sprint else walk_acceleration)
		horizontal = blended * move_toward(speed, goal, rate * (1.0 if grounded else 0.35) * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not grounded:
		velocity.y -= 19.0 * delta
	elif input_enabled and Input.is_action_just_pressed("jump_brake"):
		if held > 0.45 and _try_vault(direction):
			return
		velocity.y = 6.0
	var impact_speed := -velocity.y
	move_and_slide()
	if not grounded and is_on_floor():
		if impact_speed > 9.5 and ejection_grace <= 0.0:
			landed_hard.emit(impact_speed)
		if impact_speed > 3.8:
			_landing_time = 0.25
	var pace := Vector2(velocity.x, velocity.z).length()
	if pace > 0.20:
		var heading := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, heading, 1.0 - exp(-delta * (7.0 if sprint else 13.0)))
	movement_state = Movement.IDLE
	if not is_on_floor():
		movement_state = Movement.AIRBORNE
	elif pace > (jog_speed + 0.45) * boost:
		movement_state = Movement.SPRINT
	elif pace > (walk_speed + 0.16) * boost:
		movement_state = Movement.JOG
	elif pace > 0.22:
		movement_state = Movement.WALK
	_update_footsteps(pace, delta, movement_state == Movement.SPRINT)
	_animate_stride(pace, delta, not is_on_floor())


func update_network_pose(pace: float, delta: float) -> void:
	movement_state = Movement.SPRINT if pace > 7.0 else (Movement.WALK if pace > 0.22 else Movement.IDLE)
	_animate_stride(pace, delta, false)


func _animate_stride(pace: float, delta: float, airborne: bool) -> void:
	if _animations != null:
		_update_motion_clip(pace, delta)
		return
	if _supplied_motion != null:
		_update_supplied_pose(delta, pace, airborne, false)
		return
	animation_phase += delta * (6.0 + pace * 1.15)
	var stride := sin(animation_phase) * minf(pace / 7.0, 1.0) if not airborne else 0.15
	_left_leg.rotation.x = stride
	_right_leg.rotation.x = -stride
	_left_arm.rotation.x = -stride * 0.73
	_right_arm.rotation.x = stride * 0.73
	_visual.position.y = absf(stride) * 0.023 - 0.006


func _handle_water(delta: float) -> bool:
	var level := float(water.get("level", -INF))
	var deep := not water.is_empty() and level - float(water.bed) > (0.52 if swimming else 0.80)
	var in_water := deep and global_position.y < level - (0.10 if swimming else 0.45)
	if in_water != swimming:
		swimming = in_water
		var y := level if not water.is_empty() else global_position.y
		swim_transition.emit(swimming, Vector3(global_position.x, y + 0.03, global_position.z))
		_play_splash(-7.0 if swimming else -13.0)
		var transition := "swim_enter" if swimming else "swim_exit"
		if _animations == null or not _animations.has_animation(transition):
			transition = "leap" if swimming else "land"
		action_clip(transition, 0.38)
		_swim_enter = 0.39
	if not swimming:
		return false
	_vault_time = 0.0
	_swim_enter = maxf(0.0, _swim_enter - delta)
	var controls := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO
	var lane := Vector3(controls.x, 0, controls.y).rotated(Vector3.UP, camera_heading)
	var dive := input_enabled and Input.is_action_pressed("dive")
	var rise := input_enabled and Input.is_action_pressed("jump_brake")
	var depth := level - global_position.y
	var submerged := depth > 1.67
	var steady := clampf((depth - 1.10) * 2.8, -1.6, 1.95)
	if dive:
		steady = -1.75
	elif rise:
		steady = clampf((depth - 0.68) * 4.2, -0.55, 2.8)
	var current: Vector2 = water.flow
	var wish := lane * (2.27 if submerged else 2.65) + Vector3(current.x, 0, current.y)
	velocity.x = move_toward(velocity.x, wish.x, delta * 5.8)
	velocity.z = move_toward(velocity.z, wish.z, delta * 5.8)
	velocity.y = move_toward(velocity.y, steady, delta * (12.5 if rise else 7.5))
	move_and_slide()
	if lane.length_squared() > 0.12:
		rotation.y = lerp_angle(rotation.y, atan2(-lane.x, -lane.z), 1.0 - exp(-4.8 * delta))
	movement_state = Movement.DIVE if submerged else Movement.SWIM
	if _animations != null and _swim_enter <= 0.0:
		var clip := "swim_dive" if submerged else ("swim" if lane.length_squared() > 0.035 else "tread")
		if _animations.current_animation != clip and _animations.has_animation(clip):
			_animations.speed_scale = 1.0
			_animations.play(clip, 0.24)
		_custom.rotation.x = lerpf(_custom.rotation.x, -0.29 if submerged else -0.17, minf(5.0 * delta, 1.0))
	if _supplied_motion != null:
		_update_supplied_pose(delta, lane.length() * 4.0, false, true)
	if not submerged and lane.length_squared() > 0.17:
		_swim_phase += delta
		if _swim_phase >= 0.65:
			_swim_phase = 0.0
			_play_splash(-22.0)
	return true


func _update_supplied_pose(delta: float, pace: float, airborne: bool, in_water: bool) -> void:
	_pose_time = maxf(_pose_time - delta, 0.0)
	_supplied_motion.update(delta, pace, airborne, _action_pose if _pose_time > 0.0 else "", in_water)


func _play_splash(volume: float) -> void:
	if _splash_stream != null:
		_splash.volume_db = volume
		_splash.pitch_scale = randf_range(0.86, 1.15)
		_splash.play()


func _update_motion_clip(pace: float, delta: float) -> void:
	_pose_time = maxf(_pose_time - delta, 0.0)
	_landing_time = maxf(_landing_time - delta, 0.0)
	_custom.rotation.x = lerpf(_custom.rotation.x, 0.12 if movement_state == Movement.SPRINT else 0.0, minf(delta * 8.0, 1.0))
	if _pose_time > 0.0 and (pace < 0.45 or _action_pose in ["punch", "fire", "rifle_fire", "swim_exit"]):
		return
	var motion := "idle"
	var speed_scale := 1.0
	match movement_state:
		Movement.WALK:
			motion = "walk"
			speed_scale = clampf(pace / 2.50, 0.60, 1.15)
		Movement.JOG, Movement.SPRINT:
			motion = "run"
			speed_scale = clampf(pace / 5.2, 0.68, 1.57)
		Movement.AIRBORNE:
			motion = "leap"
	if _landing_time > 0.0 and is_on_floor():
		motion = "land"
	if _animations.current_animation != motion and _animations.has_animation(motion):
		_animations.play(motion, 0.12 if motion in ["leap", "land"] else 0.23)
	_animations.speed_scale = speed_scale


func _try_vault(direction: Vector3) -> bool:
	var pose := global_transform
	pose.basis = Basis.looking_at(direction)
	_vault_probe.target_position = global_basis.inverse() * direction * 1.07
	_vault_probe.force_raycast_update()
	if not _vault_probe.is_colliding() or absf(_vault_probe.get_collision_normal().y) > 0.47:
		return false
	var hit := _vault_probe.get_collision_point()
	var space := get_world_3d().direct_space_state
	var top_point := hit + direction * 0.12
	var surface := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_point + Vector3.UP * 0.83, top_point - Vector3.UP * 0.09, 1))
	if surface.is_empty() or surface.normal.y < 0.75:
		return false
	var obstacle_height: float = surface.position.y - global_position.y
	if obstacle_height < 0.48 or obstacle_height > 1.08:
		return false
	var reach := hit + direction * 1.24
	var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(reach + Vector3.UP * 0.95, reach - Vector3.UP * 1.48, 1))
	if floor.is_empty() or floor.normal.y < 0.72 or floor.position.y > global_position.y + 0.32:
		return false
	var step := obstacle_height + 0.16
	var landing: Vector3 = floor.position + Vector3.UP * 0.045
	if test_move(pose, Vector3.UP * step, null, 0.004):
		return false
	pose.origin += Vector3.UP * step
	var crossing := (landing - pose.origin).slide(Vector3.UP)
	if test_move(pose, crossing, null, 0.004):
		return false
	_vault_start = global_position
	_vault_end = landing
	_vault_rise = step
	_vault_time = VAULT_SECONDS
	movement_state = Movement.VAULT
	rotation.y = atan2(-direction.x, -direction.z)
	velocity = Vector3.ZERO
	action_clip("vault", VAULT_SECONDS)
	return true


func _advance_vault(delta: float) -> void:
	_vault_time = maxf(0.0, _vault_time - delta)
	var t := 1.0 - _vault_time / VAULT_SECONDS
	var across := smoothstep(0.26, 0.78, t)
	var arc := smoothstep(0.0, 0.27, t) * (1.0 - smoothstep(0.78, 1.0, t))
	var at := _vault_start.lerp(_vault_end, across) + Vector3.UP * _vault_rise * arc
	if move_and_collide(at - global_position, false, 0.004) != null:
		_vault_time = 0.0


func vehicle_impact(strength: float, direction: Vector3) -> void:
	if ejection_grace > 0.0:
		return
	velocity += direction * minf(strength * 0.35, 7.0)
	struck.emit(strength)


func _update_footsteps(speed: float, delta: float, running: bool) -> void:
	if not is_on_floor() or speed < 0.45 or swimming:
		_step_distance = 0.0
		if _grass_audio != null and _footsteps.stream == _grass_audio:
			_footsteps.stop()
		return
	if grass_underfoot and _grass_audio != null:
		_step_distance = 0.0
		if _footsteps.stream != _grass_audio:
			_footsteps.stream = _grass_audio
		_footsteps.volume_db = -9.0 if running else -15.0
		_footsteps.pitch_scale = lerpf(0.74, 1.17, smoothstep(1.25, 7.0, speed))
		if not _footsteps.playing:
			_footsteps.play()
		return
	if _grass_audio != null and _footsteps.stream == _grass_audio and _footsteps.playing:
		_footsteps.stop()
	_step_distance += speed * delta
	var step_length := clampf(speed * (0.275 if running else 0.41), 0.46, 2.15)
	if _step_distance < step_length:
		return
	_step_distance = fmod(_step_distance, step_length)
	_footsteps.stream = _run_audio if running else _walk_audio
	_footsteps.volume_db = -6.5 if running else -12.0
	_footsteps.pitch_scale = randf_range(0.91, 1.09)
	if _footsteps.stream != null:
		_footsteps.play()
