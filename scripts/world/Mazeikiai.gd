extends Node3D

signal world_progress(percent: float, message: String)
signal world_prepared
signal world_prepare_failed(message: String)
signal loading_step(message: String)

const EquipmentProfiles = preload("res://scripts/world/EquipmentProfiles.gd")
const ALTERED_SHADER = preload("res://assets/shaders/altered_view.gdshader")
const District = preload("res://scripts/world/MazeikiaiDistrict.gd")
const Geometry = preload("res://scripts/world/Geometry.gd")
const Style = preload("res://scripts/ui/Style.gd")
const PLAYER_SCENE = preload("res://scenes/player/Player.tscn")
const CAR_SCENE = preload("res://scenes/vehicles/BasicCar.tscn")
const HELICOPTER_SCENE = preload("res://scenes/vehicles/Helicopter.tscn")
const HUD_SCENE = preload("res://scenes/ui/HUD.tscn")
const RADIO_SCENE = preload("res://scenes/ui/RadioWheel.tscn")
const INVENTORY_SCENE = preload("res://scenes/ui/InventoryWheel.tscn")
const PAUSE_SCENE = preload("res://scenes/menus/PauseMenu.tscn")
const CityLife = preload("res://scripts/world/CityLife.gd")
const WantedLevel = preload("res://scripts/world/WantedLevel.gd")
const CityImpact = preload("res://scripts/world/CityImpact.gd")
const EnterablePlaces = preload("res://scripts/world/EnterablePlaces.gd")
const FuelStations = preload("res://scripts/world/FuelStations.gd")
const Discovery = preload("res://scripts/world/MapDiscovery.gd")
const CityMap = preload("res://scripts/ui/CityMap.gd")
const GearInventory = preload("res://scripts/world/GearInventory.gd")
const Collectibles = preload("res://scripts/world/Collectibles.gd")
const DroppedGoods = preload("res://scripts/world/DroppedGoods.gd")
const WeaponWheel = preload("res://scripts/ui/WeaponWheel.gd")
const PocketPanel = preload("res://scripts/ui/PocketPanel.gd")
const InteractionClips = preload("res://scripts/player/InteractionClips.gd")
const CHASE_CAMERA = preload("res://scenes/player/ChaseCamera.tscn")
const StreetOverlay = preload("res://scripts/ui/StreetOverlay.gd")
const CheatConsole = preload("res://scripts/ui/CheatConsole.gd")
const ApartmentSites = preload("res://scripts/world/ApartmentSites.gd")
const Backrooms = preload("res://scripts/world/Backrooms.gd")
const SessionAvatars = preload("res://scripts/world/SessionAvatars.gd")
const SessionChat = preload("res://scripts/ui/SessionChat.gd")
const RoadNavigation = preload("res://scripts/world/RoadNavigation.gd")
const TouchDrive = preload("res://scripts/ui/TouchDrive.gd")
const MAP_REVISION := 3
const START := Vector3(238.1, 0.05, 292.2)
const PARKED := Vector3(241.0, 0.61, 289.3)
const START_HEADING := -1.93
const DESTINATION := Vector3(423.0, 0.05, 355.0)
const CHURCH_APPROACH := Vector3(433.0, 0.05, 311.0)

var player: CharacterBody3D
var car: RigidBody3D
var driving := false
var selected_character := 0
var selected_slot := 0
var money := 0
var health := 100.0
var patience := 100.0
var stage := 0
var inventory: Array[Dictionary] = []
var prepare_during_loading := false

var _characters: Array = []
var _character_loadouts: Dictionary = {}
var _character_ready := false
var _altered_remaining := 0.0
var _altered_profile := 0
var _altered_strength := 1.0
var _altered_filter: ColorRect
var _visible_held_id := ""
var _consuming := false
var _consumption_prop := ""
var _surface_audio_timer := 0.0
var _gear := GearInventory.new()
var _collectibles: Node3D
var _dropped: Node3D
var _throwing := false
var _carried_body: CharacterBody3D
var _impact_fx: Node3D
var _hud: Control
var _radio: Control
var _inventory_picker: Control
var _weapon_picker: Control
var _pocket: Control
var _pause: Control
var _ui: Control
var _camera: Camera3D
var _camera_rig: Node3D
var _camera_arm: SpringArm3D
var _camera_car := RID()
var _visible_heading := START_HEADING
var _walk_in := ""
var _overlay: Control
var _console: Control
var _character_choice := 0
var _previous_spots: Dictionary = {}
var _destination_marker: Node3D
var _heading := 0.0
var _pitch := -0.26
var _idle_orbit := 0.0
var _in_cockpit := false
var _cockpit_look := Vector2.ZERO
var _aim := Vector3.ZERO
var _mode := ""
var _market_visited := false
var _district: Node3D
var _last_map_focus := Vector3(INF, 0, INF)
var _starter_car: RigidBody3D
var _life: Node3D
var _wanted := WantedLevel.new()
var _places: Node3D
var _fuel_stations: Node3D
var _discovery := Discovery.new()
var _large_map: Control
var _inside := ""
var _outside_at := Vector3.ZERO
var _backrooms: Node3D
var _in_backrooms := false
var _backrooms_return := Vector3.ZERO
var _backrooms_heading := 0.0
var _explored_cell := Vector2i(-9999, -9999)
var _autosave_remaining := 45.0
var _equipment_ready_at := 0
var _vehicle_action := false
var _recover_requested := false
var _recovering := false
var _throw_taps := 0
var _throw_charge_time := 0.0
var _throw_item_id := ""
var _helicopter: CharacterBody3D
var _flying := false
var _heli_entry := Vector3.ZERO
var _chat: Control
var _session_avatars: Node3D
var _passenger_driver := 0
var _passenger_exit_requested := false
var _passenger_seat_revoked := false
var _pose_interval := 0.0
var _navigation := RoadNavigation.new()
var _bank_progress := -1
var _bank_collecting := false
var _arrest_elapsed := 0.0
var _limbo: RigidBody3D
var _bank_clock := 0.0
var _completed_banks: Array = []


func _ready() -> void:
	var saved := GameManager.pending_save
	GameManager.pending_save = {}
	var current_map := int(saved.get("map_revision", 0)) >= 2
	var initial := SaveManager.read_vector(saved.get("car" if saved.get("driving", false) else "player"), START) if current_map else START
	loading_step.emit("[LOAD] mazeikiai.json / elevation.json / cadastral overlays")
	_district = District.new()
	_district.name = "District"
	_district.time_of_day = fposmod(float(saved.get("time_of_day", 0.42)), 1.0)
	var lamps: Variant = saved.get("broken_lamps", [])
	if lamps is Array:
		for key: Variant in lamps:
			if key is String and str(key).is_valid_filename():
				_district.broken_lamps[key] = true
	add_child(_district)
	_district.build_progress.connect(func(fraction: float, message: String) -> void:
		world_progress.emit(78.0 + fraction * 13.0, message)
	)
	var terrain_ready: bool = await _district.build(initial, prepare_during_loading)
	if not terrain_ready:
		world_prepare_failed.emit("Mažeikiai terrain or its ground collision could not be loaded.")
		return
	loading_step.emit("[OK] Mažeikiai geometry / starting terrain")
	world_progress.emit(91.0, "RESTORING PLAYER AND ITEMS")
	loading_step.emit("[LOAD] characters.json / items.json")
	_characters = GameManager.read_json("res://data/characters.json", [])
	if _characters.is_empty():
		_characters.append({"id": "main", "name": "Main Character", "initials": "MC"})
	_gear.load_catalog()
	_gear.restore(saved)
	loading_step.emit("[OK] items.json / %s item records" % _gear.catalog.size())
	inventory = _gear.hotbar()

	loading_step.emit("[LOAD] Player.tscn / BasicCar.tscn")
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.landed_hard.connect(_on_hard_landing)
	player.struck.connect(_on_player_struck)
	player.swim_transition.connect(_on_swim_transition)
	player.position = START
	car = CAR_SCENE.instantiate()
	car.variant = str(saved.get("car_variant", "hatchback"))
	add_child(car)
	_starter_car = car
	_impact_fx = CityImpact.new()
	add_child(_impact_fx)
	_impact_fx.restore_state(saved.get("city_damage", {}))
	world_progress.emit(93.0, "OPENING CITY SHOPS")
	if prepare_during_loading:
		await get_tree().process_frame
	_places = EnterablePlaces.new()
	add_child(_places)
	_places.groceries = _gear.items_from("maxima")
	await _places.build(_district, prepare_during_loading)
	_fuel_stations = FuelStations.new()
	_fuel_stations.name = "FuelStations"
	add_child(_fuel_stations)
	await _fuel_stations.build(_district, saved.get("fuel_jobs", []), prepare_during_loading)
	_fuel_stations.pump_exploded.connect(func(at: Vector3) -> void: _impact_fx.game_flash(at, 3.5))
	_fuel_stations.notice.connect(func(message: String) -> void: _hud.notify(message))
	_fuel_stations.robbery_committed.connect(func() -> void: _report_offence("FUEL STATION ROBBERY", 6))
	_fuel_stations.reward_paid.connect(_on_fuel_reward)
	loading_step.emit("[OK] Maxima XX / Rovana / fuel stations")
	_dropped = DroppedGoods.new()
	_dropped.district = _district
	add_child(_dropped)
	_dropped.game_bomb_burst.connect(_game_burst)
	_collectibles = Collectibles.new()
	add_child(_collectibles)
	_collectibles.build(_district, _gear.catalog, saved.get("picked_up", []))
	_camera_rig = CHASE_CAMERA.instantiate()
	add_child(_camera_rig)
	_camera_arm = _camera_rig.get_node("SpringArm3D")
	_camera_arm.add_excluded_object(player.get_rid())
	_camera = _camera_arm.get_node("Camera3D")
	_camera.make_current()
	_apply_camera_distance()
	GameManager.settings_changed.connect(_apply_camera_distance)
	_destination_marker = _build_marker(_district.point_on_ground(DESTINATION, 0.07), "ŽEMAITIJOS g.")

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(_ui)
	Style.fill(_ui)
	_altered_filter = ColorRect.new()
	_altered_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var altered_material := ShaderMaterial.new()
	altered_material.shader = ALTERED_SHADER
	_altered_filter.material = altered_material
	_ui.add_child(_altered_filter)
	Style.fill(_altered_filter)
	_altered_filter.hide()
	_hud = HUD_SCENE.instantiate()
	_ui.add_child(_hud)
	_hud.discovery = _discovery
	_hud.navigation = _navigation
	_hud.landmarks = _map_landmarks()
	_overlay = StreetOverlay.new()
	_ui.add_child(_overlay)
	Style.fill(_overlay)
	_large_map = CityMap.new()
	_large_map.position = Vector2(28, 249)
	_large_map.size = Vector2(541, 427)
	_large_map.setup(_discovery, _district, false)
	_large_map.navigation = _navigation
	_large_map.landmarks = _map_landmarks()
	_large_map.hide()
	_ui.add_child(_large_map)
	_radio = RADIO_SCENE.instantiate()
	_radio.hide()
	_ui.add_child(_radio)
	_inventory_picker = INVENTORY_SCENE.instantiate()
	_inventory_picker.hide()
	_ui.add_child(_inventory_picker)
	_weapon_picker = WeaponWheel.new()
	_weapon_picker.hide()
	_ui.add_child(_weapon_picker)
	Style.fill(_weapon_picker)

	_restore(saved, current_map)
	if SessionManager.active:
		var offset := Vector3(float(SessionManager.spawn_slot % 4) * 1.1, 0.0, float(SessionManager.spawn_slot / 4.0) + 0.8)
		if SessionManager.spawn_slot > 0:
			_relocate_player(_district.point_on_ground(START + offset, 0.12))
			car.reset_pose(_district.point_on_ground(PARKED + Vector3(0, 0, -3.0 * SessionManager.spawn_slot), PARKED.y), START_HEADING)
		_session_avatars = SessionAvatars.new()
		_session_avatars.characters = _characters
		add_child(_session_avatars)
		SessionManager.passenger_seat_changed.connect(_passenger_seat_changed)
		_chat = SessionChat.new()
		_chat.dismissed.connect(_close_chat)
		_chat.cheats_requested.connect(_open_cheats_from_chat)
		_ui.add_child(_chat)
		SessionManager.ended.connect(_session_ended)
		SessionManager.connection_notice.connect(func(message: String) -> void: _hud.notify(message, 6.0))
	if OS.has_feature("mobile"):
		var touch := TouchDrive.new()
		touch.world = self
		_ui.add_child(touch)
		Style.fill(touch)
	_discovery.restore(saved.get("explored", []))
	_discovery.revealed_all = bool(saved.get("reveal_map", false))
	world_progress.emit(96.0, "POPULATING THE CITY")
	if prepare_during_loading:
		await get_tree().process_frame
	_life = CityLife.new()
	add_child(_life)
	_life.build(_district, _map_focus())
	_life.civilian_counter_hit.connect(_on_counter_hit)
	_wanted.restore(int(saved.get("wanted_stars", 0)), float(saved.get("wanted_heat", -1.0)))
	_life.wanted = _wanted.stars
	_watch_car(car)
	world_progress.emit(98.0, "TUNING RADIO STATIONS")
	loading_step.emit("[LOAD] radio_stations.json / Radio Music")
	RadioManager.begin_session(str(saved.get("radio", "")))
	loading_step.emit("[OK] radio catalogue / %d stations" % RadioManager.library.stations.size())
	_aim = _focus() + Vector3.UP * 1.35
	_update_camera(1.0)
	_update_hud()
	_hud.show_location()
	if SessionManager.active:
		SessionManager.combat_space = self
		SessionManager.player_hit.connect(_on_player_hit)

	if prepare_during_loading:
		world_prepared.emit()
	else:
		start_playing()


func start_playing() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	RadioManager.set_audible(driving or _flying)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_update_charged_throw(delta)
	if _bank_progress >= 0:
		_bank_clock -= delta
		if _bank_clock <= 0.0:
			_finish_bank_job(false)
	_altered_remaining = maxf(_altered_remaining - delta, 0.0)
	if is_instance_valid(_altered_filter):
		_altered_filter.visible = _altered_remaining > 0.0
		if _altered_remaining > 0.0:
			var material := _altered_filter.material as ShaderMaterial
			material.set_shader_parameter("strength", smoothstep(0.0, 5.0, _altered_remaining) * _altered_strength)
			material.set_shader_parameter("profile", _altered_profile)
	if _in_backrooms:
		if player.global_position.y < _backrooms.global_position.y - 2.0:
			_relocate_player(_backrooms.to_global(Backrooms.ENTRY))
		if _mode.is_empty():
			_update_camera(delta)
		_update_hud()
		return
	_places.update_store_doors(player.position, driving or not _inside.is_empty())
	var current_shop: String = "" if driving or _flying or not _inside.is_empty() else _places.walk_in_at(player.position)
	if _walk_in != current_shop:
		_walk_in = current_shop
		if not _walk_in.is_empty() and _mode.is_empty():
			_hud.notify(_places.name_of(_walk_in).to_upper(), 1.9)
	if _inside.is_empty():
		var enclosed: bool = not _walk_in.is_empty() or not _places.home_at(player.position).is_empty()
		player.indoor_speed_limit = 2.8 if not driving and enclosed else 0.0
	if _mode.is_empty():
		_update_camera(delta)
		_autosave_remaining -= delta
		if _autosave_remaining <= 0.0 and not _vehicle_action and (driving or player.is_on_floor()):
			_autosave()
	if not _inside.is_empty() and player.global_position.y < 208.0:
		_relocate_player(_places.enter(_inside))
	elif _inside.is_empty() and not driving and player.global_position.y < -48.0:
		_relocate_player(_district.point_on_ground(START, 0.12))
	var location := _map_focus()
	_fuel_stations.update_job(delta, location)
	if _inside.is_empty() and _navigation.update(Vector2(location.x, location.z)):
		_hud.notify("GPS   /   DESTINATION REACHED")
	_district.stream_at(location)
	var camera_water: Dictionary = _district.water_sample(_camera.global_position)
	_district.set_underwater_view(not camera_water.is_empty() and _camera.global_position.y < float(camera_water.level) - 0.08)
	_district.update_day(delta, _focus(), not _store_id().is_empty() or not _places.home_at(player.position).is_empty())
	_life.update_focus(location, car, not driving and not _flying and _inside.is_empty())
	if _wanted.stars > 0:
		var sheltered: bool = not _store_id().is_empty() or not _places.home_at(player.position).is_empty()
		if _wanted.update(delta, not sheltered and _life.patrol_near(location)):
			_life.wanted = _wanted.stars
			if _wanted.stars == 0:
				_hud.notify("POLICE LOST")
	_update_arrest(delta, location)
	var cell := _discovery.cell_at(Vector2(location.x, location.z))
	if cell != _explored_cell:
		_explored_cell = cell
		_discovery.visit(Vector2(location.x, location.z))
	_update_hud()


func _physics_process(delta: float) -> void:
	if _passenger_driver != 0:
		_update_passenger(delta)
	if _recover_requested:
		_recover_requested = false
		if can_recover_car():
			_recover_car()
	_surface_audio_timer -= delta
	if _surface_audio_timer <= 0.0:
		_surface_audio_timer = 0.18
		player.grass_underfoot = (not driving and not _flying and not _in_backrooms and _store_id().is_empty()
			and _places.home_at(player.position).is_empty() and _district.footstep_uses_grass(player.position))
	if _flying:
		_helicopter.controls_enabled = _mode.is_empty()
	if is_instance_valid(_carried_body):
		_carried_body.carry_toward(player.global_position + Vector3.UP * 1.22 - player.global_basis.z * 0.95)
	if SessionManager.active:
		_pose_interval -= delta
		if _pose_interval <= 0.0:
			_pose_interval = 0.055
			var pace := Vector2(player.velocity.x, player.velocity.z).length()
			var vehicle := "helicopter" if _flying else (str(car.variant) if driving else "")
			var orientation := Quaternion.IDENTITY
			if _flying:
				orientation = _helicopter.global_basis.get_rotation_quaternion()
			elif driving:
				orientation = car.global_basis.get_rotation_quaternion()
				pace = car.linear_velocity.length()
			elif _passenger_driver != 0:
				orientation = player.global_basis.get_rotation_quaternion()
			SessionManager.publish_pose(_focus(), player.rotation.y, pace, selected_character, vehicle, orientation)
	if driving:
		player.global_transform = car.driver_avatar_transform()
		player.update_driver_pose(car._steering / 0.55, delta)
	player.camera_heading = _heading
	player.water = {} if driving or _passenger_driver != 0 or _flying or _in_backrooms or not _store_id().is_empty() else _district.water_sample(player.position)
	if driving and stage >= 2 and stage < 3 and _distance(car.global_position, DESTINATION) < 8.0:
		stage = 3
		money += 20
		_hud.notify("ŽEMAITIJOS g. CHECKPOINT   /   +€20", 3.6)
		_autosave()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_hud):
		return
	if _mode == "chat":
		if event.is_action_pressed("pause", false):
			_close_chat()
			get_viewport().set_input_as_handled()
		return
	if _mode.is_empty() and SessionManager.active and event.is_action_pressed("chat", false) and not _vehicle_action:
		_open_chat()
		get_viewport().set_input_as_handled()
		return
	if _mode == "cheats":
		if event.is_action_pressed("pause", false):
			_close_cheats()
			get_viewport().set_input_as_handled()
		return
	if _mode == "character_pick":
		_character_input(event)
		return
	if _mode in ["transition", "down"]:
		return
	if event.is_action_released("world_map"):
		_set_large_map(false)
		return
	if event.is_action_pressed("world_map") and _mode.is_empty():
		_set_large_map(true)
		get_viewport().set_input_as_handled()
		return
	if _mode == "radio":
		if event.is_action_released("radio_wheel"):
			var choice: String = _radio.station_choice()
			_close_picker()
			RadioManager.set_station(choice)
			if choice != RadioManager.OFF and stage == 1:
				stage = 2
				_hud.notify("RADIO TUNED   /   FOLLOW ŽEMAITIJOS g.")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			_close_picker()
			_pause_game()
			get_viewport().set_input_as_handled()
		elif _radio.handle_event(event):
			get_viewport().set_input_as_handled()
		return
	if _mode == "inventory":
		if event.is_action_released("inventory_wheel"):
			_select_hotbar(maxi(_inventory_picker.selected, 0))
			_close_picker()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			_close_picker()
			_pause_game()
			get_viewport().set_input_as_handled()
		elif _inventory_picker.handle_event(event):
			get_viewport().set_input_as_handled()
		return
	if _mode == "equipment":
		if event.is_action_released("equipment_wheel"):
			_gear.equipment = _weapon_picker.choice()
			_refresh_held_item()
			_close_picker()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			_close_picker()
			_pause_game()
			get_viewport().set_input_as_handled()
		elif _weapon_picker.handle_event(event):
			get_viewport().set_input_as_handled()
		return
	if _mode in ["phone", "shop", "spawn_catalog"]:
		if event.is_action_pressed("pause") or (_mode == "phone" and event.is_action_pressed("phone", false)):
			_close_pocket()
			get_viewport().set_input_as_handled()
		return
	if not _mode.is_empty():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.device != InputEvent.DEVICE_ID_EMULATION:
		var sensitivity := float(GameManager.settings.sensitivity)
		_orbit(event.screen_relative * sensitivity * 0.0027)
	elif event.is_action_pressed("pause"):
		_pause_game()
		get_viewport().set_input_as_handled()
	elif _vehicle_action:
		return
	elif _passenger_driver != 0:
		if event.is_action_pressed("rob", false):
			_passenger_exit_requested = true
			get_viewport().set_input_as_handled()
	elif _flying:
		if event.is_action_pressed("radio_wheel"):
			_open_picker("radio")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("rob", false):
			_leave_helicopter()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cheats", false):
		_open_cheats()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character_picker", false):
		_open_character_picker()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_select_hotbar(posmod(selected_slot + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 8))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact", false):
		if driving:
			car.honk()
		elif _helicopter_near_player():
			_board_helicopter()
		else:
			var driver_id := nearby_passenger_driver()
			if driver_id != 0:
				SessionManager.seat_request(driver_id)
			else:
				_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("vehicle_camera", false) and driving:
		_in_cockpit = not _in_cockpit
		_cockpit_look = Vector2.ZERO
		_heading = car.heading()
		_hud.notify("COCKPIT" if _in_cockpit else "CHASE CAMERA", 1.1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rob", false):
		if driving:
			_exit_vehicle()
		elif _places.is_bank(_inside):
			_start_bank_job()
		elif _places.stock_for(_walk_in) != null:
			_pick_shelf(true)
		elif _store_id().is_empty() and not _fuel_stations.begin_at(player.position, EquipmentProfiles.is_firearm(_equipment_kind())):
			_rob_nearby()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("radio_wheel") and driving:
		_open_picker("radio")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory_wheel"):
		_open_picker("inventory")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("equipment_wheel") and not driving:
		_open_picker("equipment")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("phone", false):
		_open_phone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_item", false) and not driving:
		_use_item(str(_gear.slots[selected_slot]))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop_item", false) and not driving:
		_drop_held()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_checkpoint", false) and not driving:
		if EquipmentProfiles.is_firearm(_equipment_kind()):
			_begin_defeat("CHECKPOINT RESTART")
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("throw_item", false) and not driving:
		_charge_throw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("equipment_use") and not driving and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _gear.equipment.is_empty() and _can_use_item(_held_id()):
			_use_item(_held_id())
		else:
			_use_equipment()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character", false):
		_switch_character((selected_character + 1) % _characters.size())
	elif event.is_action_pressed("recover", false) and can_recover_car():
		_recover_requested = true
		get_viewport().set_input_as_handled()
	else:
		for index in range(8):
			if event.is_action_pressed("slot_%d" % (index + 1)):
				_select_hotbar(index)
				get_viewport().set_input_as_handled()
				break


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_instance_valid(_large_map):
			_set_large_map(false)
		if _mode in ["radio", "inventory", "equipment"]:
			_close_picker()
		elif _mode == "character_pick":
			_close_character_picker()


func _set_large_map(value: bool) -> void:
	_large_map.visible = value
	_hud.map_expanded = value
	if value:
		_large_map.update_map(_map_focus(), _hud.focus_heading, _hud.checkpoint, _hud.street_name)


func _open_picker(kind: String) -> void:
	_mode = kind
	_set_large_map(false)
	Engine.time_scale = 0.18
	player.input_enabled = false
	car.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.modulate.a = 0.24
	if kind == "radio":
		_radio.open()
	elif kind == "equipment":
		_weapon_picker.open(_gear.available(true), _gear.equipment)
	else:
		_inventory_picker.open(inventory, selected_slot)


func _close_picker() -> void:
	_mode = ""
	Engine.time_scale = 1.0
	_radio.hide()
	_inventory_picker.hide()
	_weapon_picker.hide()
	_hud.modulate.a = 1.0
	player.input_enabled = true
	car.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_chat() -> void:
	_mode = "chat"
	_set_large_map(false)
	player.input_enabled = false
	car.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_chat.open_editor()


func _close_chat() -> void:
	_chat.close_editor()
	_mode = ""
	player.input_enabled = true
	car.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _session_ended(reason: String) -> void:
	if _mode == "chat":
		_close_chat()
	if is_instance_valid(_chat):
		_chat.queue_free()
	_passenger_exit_requested = _passenger_driver != 0
	_hud.notify(reason, 7.0)


func _update_arrest(delta: float, at: Vector3) -> void:
	if _wanted.stars == 0 or not _mode.is_empty() or driving or _flying or _passenger_driver != 0 \
			or not _inside.is_empty() or not _walk_in.is_empty() or not _life.patrol_near(at, 8.2):
		_arrest_elapsed = 0.0
		return
	_arrest_elapsed += delta
	if _arrest_elapsed >= 3.0:
		_arrest_elapsed = 0.0
		_begin_defeat("BUSTED")


func _pause_game(show_whole := false) -> void:
	_mode = "pause"
	if SessionManager.active:
		player.input_enabled = false
		car.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause = PAUSE_SCENE.instantiate()
	_ui.add_child(_pause)
	_set_large_map(false)
	var pause_map := CityMap.new()
	pause_map.setup(_discovery, _district, true)
	pause_map.navigation = _navigation
	pause_map.waypoint_requested.connect(_set_waypoint.bind(pause_map))
	pause_map.waypoint_cleared.connect(_clear_waypoint.bind(pause_map))
	pause_map.world_center = Vector2(_map_focus().x, _map_focus().z)
	if show_whole:
		pause_map.world_center = Vector2(0, -700)
	pause_map.zoom = 0.14 if show_whole else 0.78
	pause_map.landmarks = _map_landmarks()
	pause_map.update_map(_map_focus(), _hud.focus_heading, _hud.checkpoint, _hud.street_name)
	_pause.attach_map(pause_map)
	_pause.resume_requested.connect(_resume_game)
	_pause.save_requested.connect(func() -> void: _pause.show_save_result(_save()))
	RadioManager.set_paused(true)
	get_tree().paused = not SessionManager.active


func _set_waypoint(destination: Vector2, map: Control) -> void:
	var at := _map_focus()
	var routed := _navigation.select(Vector2(at.x, at.z), destination, _district.map_roads())
	map.update_map(at, _hud.focus_heading, _hud.checkpoint,
		"GPS WAYPOINT SET" if routed else "NO CONNECTED ROAD NEAR THAT POINT")


func _clear_waypoint(map: Control) -> void:
	_navigation.clear()
	map.update_map(_map_focus(), _hud.focus_heading, _hud.checkpoint, "GPS WAYPOINT CLEARED")


func _resume_game() -> void:
	_pause.queue_free()
	_mode = ""
	if SessionManager.active:
		player.input_enabled = true
		car.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	RadioManager.set_paused(false)


func _interact() -> void:
	if _in_backrooms:
		if _backrooms.near_exit(player.global_position):
			_leave_backrooms()
		elif _backrooms.near_bottle(player.global_position):
			if _gear.add("beer"):
				_backrooms.take_bottle()
				inventory = _gear.hotbar()
				player.interaction_pose()
				_hud.notify("BEER ADDED TO INVENTORY")
			else:
				_hud.notify("INVENTORY FULL")
		return
	if driving:
		car.honk()
		return
	if _fuel_stations.collect_at(player.position):
		player.interaction_pose()
		return
	if _open_fuel_shop():
		return
	if _release_carried_body(false):
		return
	var dropped: RigidBody3D = _dropped.nearest(player.position)
	if dropped != null and _gear.add(str(dropped.get_meta("product"))):
		_dropped.take(dropped)
		inventory = _gear.hotbar()
		player.interaction_pose()
		return
	if not _inside.is_empty():
		if _places.room_exit_near(_inside, player.position):
			var job_active := _bank_progress >= 0
			if job_active:
				_finish_bank_job(_bank_progress == 3)
			var label: String = _places.name_of(_inside)
			_inside = ""
			_life.set_physics_process(true)
			_camera.far = SettingsManager.view_distance()
			player.indoor_speed_limit = 0.0
			_relocate_player(_outside_at)
			if not job_active:
				_hud.notify("LEFT " + label.to_upper())
		elif _places.is_bank(_inside):
			_collect_bank_token()
		elif _places.checkout_near(_inside, player.position):
			_open_shop()
		return
	if not _walk_in.is_empty():
		if _places.checkout_near(_walk_in, player.position):
			_open_shop()
		elif _places.stock_for(_walk_in) != null:
			_pick_shelf(false)
		return
	var body: CharacterBody3D = _life.nearby_body(player.position)
	if body != null:
		_carried_body = body
		player.interaction_pose()
		return
	var apartment: Node3D = _places.home_door_at(player.position)
	if apartment != null:
		if apartment.toggle_door(player.position):
			player.interaction_pose()
		else:
			_hud.notify("STEP CLEAR OF THE DOOR")
		return
	var place: String = _places.gate_at(player.position)
	if not place.is_empty():
		_inside = place
		_outside_at = _places.outside_point(place)
		_life.set_physics_process(false)
		_camera.far = 125.0
		player.indoor_speed_limit = 0.0
		_heading = 0.0
		_pitch = -0.18
		player.rotation.y = 0.0
		_relocate_player(_places.enter(place))
		_hud.notify(_places.name_of(place).to_upper())
		return
	var pickup: String = _collectibles.nearby(player.global_position)
	if not pickup.is_empty() and _gear.add(pickup):
		_collectibles.take(pickup)
		inventory = _gear.hotbar()
		_hud.notify("PICKED UP   /   " + str(_gear.catalog[pickup].name))
		_autosave()
		return
	if _can_use_item(_held_id()) and _nearby_vehicle() == null:
		_use_item(_held_id())
		return
	var target := _nearby_vehicle()
	if target != null:
		_enter_vehicle(target)
	elif _distance(player.position, CHURCH_APPROACH) < 5.0:
		if not _market_visited:
			_market_visited = true
			_hud.notify("ŠV. PRANCIŠKAUS ASYŽIEČIO BAŽNYČIA", 4.0)
		else:
			_hud.notify("NAFTININKŲ g.  /  MAŽEIKIAI")


func _start_bank_job() -> void:
	if _bank_progress >= 0 or _completed_banks.has(_inside):
		return
	_bank_progress = 0
	_bank_clock = 40.0
	_places.set_bank_progress(_inside, 0)
	_hud.notify("BANK JOB   /   COLLECT THREE MARKERS AND REACH THE EXIT", 4.0)


func _collect_bank_token() -> void:
	if _bank_collecting or not _places.bank_target_near(_inside, player.position, _bank_progress):
		return
	var job := _inside
	var slot := _bank_progress
	_bank_collecting = true
	var towards: Vector3 = _places.bank_target_position(job, slot) - player.global_position
	if towards.slide(Vector3.UP).length_squared() > 0.08:
		player.rotation.y = atan2(-towards.x, -towards.z)
	player.action_clip("grab_cash", 0.95)
	_places.animate_bank_pickup(job, slot, player.global_position)
	await get_tree().create_timer(0.74, false, true).timeout
	_bank_collecting = false
	if _inside != job or _bank_progress != slot or _mode == "down":
		return
	_bank_progress += 1
	_places.set_bank_progress(_inside, _bank_progress)
	_hud.notify("REACH THE EXIT" if _bank_progress == 3 else "CHECKPOINT %d / 3" % _bank_progress)


func _finish_bank_job(completed: bool) -> void:
	_bank_progress = -1
	_places.set_bank_progress(_inside, -1)
	if completed:
		var reward := 420 if _inside == "swedbank" else 340
		_completed_banks.append(_inside)
		money += reward
		_report_offence("BANK ROBBERY", 12)
		_hud.notify("BANK JOB COMPLETE   /   +€%d" % reward, 4.5)
	else:
		_hud.notify("BANK JOB FAILED")


func _relocate_player(at: Vector3) -> void:
	player.global_position = at
	player.ejection_grace = 0.0
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	_aim = at + Vector3.UP * 1.52
	_update_camera(1.0)


func _nearby_vehicle() -> RigidBody3D:
	var candidate: RigidBody3D = _life.nearest_car(player.position)
	var nearest := 4.7 ** 2 if candidate == null else candidate.global_position.distance_squared_to(player.position)
	for owned: RigidBody3D in [_starter_car, car, _limbo]:
		if not is_instance_valid(owned):
			continue
		var distance := owned.global_position.distance_squared_to(player.position)
		if distance <= nearest:
			candidate = owned
			nearest = distance
	return candidate


func _watch_car(target: RigidBody3D) -> void:
	var callback := _on_car_wrecked.bind(target)
	if not target.wreck_created.is_connected(callback):
		target.wreck_created.connect(callback)
	if not target.incident.is_connected(_report_offence):
		target.incident.connect(_report_offence)
	var damage := _on_occupant_impact.bind(target)
	if not target.occupant_impact.is_connected(damage):
		target.occupant_impact.connect(damage)


func _on_fuel_reward(amount: int, armed: bool) -> void:
	money += amount
	var message := "CLERK HANDED OVER CASH" if armed else "FUEL STATION JOB COMPLETE"
	_hud.notify("%s   /   +€%d" % [message, amount], 4.5)
	_autosave()


func _map_landmarks() -> Array:
	return _places.map_pins() + _fuel_stations.map_pins() + _district.settlement_pins()


func _report_offence(description: String, severity: int) -> void:
	_wanted.report(severity, description)
	InterfaceAudio.play_wanted()
	_life.wanted = _wanted.stars
	_hud.notify("%s   /   WANTED %d" % [description, _wanted.stars])


func _on_car_wrecked(target: RigidBody3D) -> void:
	if target == car and driving:
		_hud.notify("ENGINE FAILED  /  EXIT THE WRECK", 4.8)


func _enter_vehicle(target: RigidBody3D) -> void:
	if target.wrecked or target.linear_velocity.length() > 3.2:
		_hud.notify("ENGINE FAILED" if target.wrecked else "WAIT FOR THE CAR TO STOP")
		return
	if not await _play_door_action(target, false):
		return
	var stolen: bool = _life.take_car(target)
	car = target
	_watch_car(car)
	driving = true
	player.set_seated(true)
	car.set_driver(true, false)
	_heading = car.heading()
	_pitch = -0.19
	_idle_orbit = 0.0
	RadioManager.set_audible(true)
	if stolen:
		_report_offence("VEHICLE THEFT", 2 if target.variant == "police" else 1)
	if stage == 0:
		stage = 2 if RadioManager.current_station != RadioManager.OFF else 1


func _play_door_action(target: RigidBody3D, search: bool) -> bool:
	if _vehicle_action or not is_instance_valid(target):
		return false
	var side: Vector3 = _district.point_on_ground(target.driver_side_point(), 0.055)
	var yaw: float = target.heading()
	var frame := Basis(Vector3.UP, yaw)
	var relative := frame.inverse() * (player.global_position - target.global_position)
	var route: Array[Vector3] = []
	if relative.x > 0.2:
		var end := 2.85 if relative.z >= 0.0 else -2.90
		for x: float in [1.40, -1.44]:
			route.append(_district.point_on_ground(target.global_position + frame * Vector3(x, 0, end), 0.055))
	route.append(side)
	var from := player.global_position
	for point: Vector3 in route:
		var test := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.62, point + Vector3.UP * 0.62, 1 | 4, [target.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(test).is_empty():
			_hud.notify("MOVE TO THE DRIVER'S DOOR")
			return false
		from = point
	_vehicle_action = true
	target.parking_interaction = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.action_clip("walk", 0.25)
	for point: Vector3 in route:
		var distance := player.global_position.distance_to(point)
		if distance < 0.10:
			continue
		var direction := player.global_position.direction_to(point)
		var walk := create_tween().set_parallel(true)
		walk.tween_property(player, "global_position", point, distance / 3.8)
		var facing := atan2(-direction.x, -direction.z)
		walk.tween_property(player, "rotation:y", player.rotation.y + angle_difference(player.rotation.y, facing), minf(0.22, distance / 3.8))
		await walk.finished
	if not is_instance_valid(target):
		_vehicle_action = false
		player.set_seated(false)
		return false
	var face_yaw := player.rotation.y + angle_difference(player.rotation.y, yaw - PI * 0.5)
	var pose := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	pose.tween_property(player, "rotation:y", face_yaw, 0.22)
	target.animate_driver_door(true)
	var duration := InteractionClips.SEARCH_LENGTH if search else InteractionClips.ENTRY_LENGTH
	player.action_clip("search_car" if search else "car_entry", duration)
	var lean := side + frame.x * (0.18 if search else 0.64)
	pose.tween_property(player, "global_position", lean, duration * 0.63).set_ease(Tween.EASE_IN_OUT)
	if search:
		pose.chain().tween_property(player, "global_position", side, duration * 0.37)
	else:
		pose.tween_interval(duration)
	await pose.finished
	_vehicle_action = false
	if not is_instance_valid(target):
		player.set_seated(false)
		return false
	target.parking_interaction = false
	target.animate_driver_door(false)
	player.set_seated(not search)
	return true


func _rob_nearby() -> void:
	var target := _nearby_vehicle()
	var civilian: CharacterBody3D = _life.nearest_person(player.position)
	var cash := 0
	var from_car: bool = target != null and target.wallet > 0 and target.linear_velocity.length() <= 3.0
	if from_car:
		if not await _play_door_action(target, true):
			return
		cash = target.take_glovebox()
	elif civilian != null:
		player.interaction_pose()
		cash = civilian.steal_wallet()
	if cash > 0:
		money += cash
		_report_offence(("GLOVEBOX CASH" if from_car else "WALLET TAKEN") + "   /   +€%d" % cash, 1)
	elif target != null or civilian != null:
		_hud.notify("NO CASH TO TAKE")


func _open_phone() -> void:
	_create_pocket("phone")
	_pocket.open_phone(_gear.available(), _gear.owned, _characters, _hud.objective)
	_pocket.item_used.connect(_use_item)
	_pocket.item_pinned.connect(func(id: String) -> void:
		_gear.pin(id, selected_slot)
		inventory = _gear.hotbar()
		_select_hotbar(selected_slot)
		_pocket.feedback("Pinned to slot %d" % (selected_slot + 1), money)
	)
	_pocket.contact_selected.connect(func(index: int) -> void:
		if driving:
			_pocket.feedback("Exit the car to switch characters.", money)
		else:
			_select_character(index)
			_close_pocket()
			_hud.notify("PLAYING AS " + str(_characters[index].name).to_upper())
	)
	_pocket.map_requested.connect(func(anchor: Control) -> void:
		var pocket_map := CityMap.new()
		pocket_map.custom_minimum_size = Vector2(0, 380)
		pocket_map.setup(_discovery, _district, true)
		pocket_map.world_center = Vector2(_map_focus().x, _map_focus().z)
		pocket_map.zoom = 0.78
		pocket_map.landmarks = _map_landmarks()
		pocket_map.update_map(_map_focus(), _hud.focus_heading, _hud.checkpoint, _hud.street_name)
		anchor.add_child(pocket_map)
	)


func _shelf_product() -> String:
	var stock: Node3D = _places.stock_for(_walk_in)
	return stock.find_product(player.position, -_camera.global_basis.z) if stock != null else ""


func _pick_shelf(steal: bool) -> void:
	var id := _shelf_product()
	if id.is_empty():
		return
	var item: Dictionary = _gear.catalog[id]
	if not steal and money < int(item.price):
		_hud.notify("NOT ENOUGH CASH")
		return
	if not _gear.add(id):
		return
	_places.stock_for(_walk_in).take_product(id)
	if not steal:
		money -= int(item.price)
	player.interaction_pose()
	inventory = _gear.hotbar()
	if steal:
		_report_offence("SHOPLIFTING   /   " + str(item.name).to_upper(), 1)
	else:
		_hud.notify("PURCHASED   /   " + str(item.name).to_upper())
	_autosave()


func _drop_held() -> void:
	if _release_carried_body(false):
		return
	var id := _held_id()
	var item: Dictionary = _gear.catalog.get(id, {})
	if item.is_empty():
		return
	var forward := -player.global_basis.z
	var origin := player.position + Vector3.UP * 0.82
	var target := origin + forward * 0.73
	var ray := PhysicsRayQueryParameters3D.create(origin, target, 1 | 4, [player.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty() or not _gear.consume(id):
		return
	_dropped.drop(item, target, forward)
	inventory = _gear.hotbar()
	_refresh_held_item()
	_hud.notify("DROPPED  /  " + str(item.name))


func _release_carried_body(throw_it: bool) -> bool:
	if not is_instance_valid(_carried_body):
		return false
	var launch := -_camera.global_basis.z * 8.6 + Vector3.UP * 2.3 if throw_it else Vector3.ZERO
	_carried_body.release_body(launch)
	_carried_body = null
	if throw_it:
		player.interaction_pose()
	return true


func _charge_throw() -> void:
	if is_instance_valid(_carried_body):
		_throw_selected()
		return
	var id := _held_id()
	if _throwing or id.is_empty() or not _gear.owned.has(id):
		return
	if _throw_item_id != id:
		_throw_taps = 0
	_throw_item_id = id
	_throw_taps = mini(_throw_taps + 1, 5)
	_throw_charge_time = 0.29 if _throw_taps < 5 else 0.0


func _update_charged_throw(delta: float) -> void:
	if _throw_taps == 0:
		return
	if driving or _vehicle_action or not _mode.is_empty() or _held_id() != _throw_item_id:
		_throw_taps = 0
		return
	_throw_charge_time -= delta
	if _throw_charge_time <= 0.0:
		var power := 1.0 + float(_throw_taps - 1) * 0.31
		_throw_taps = 0
		_throw_selected(power)


func _throw_selected(power := 1.0) -> void:
	if _release_carried_body(true):
		return
	var id := _held_id()
	var item: Dictionary = _gear.catalog.get(id, {})
	if _throwing or item.is_empty() or not _gear.owned.has(id):
		return
	_throwing = true
	var thrower := selected_character
	player.action_clip("throw_item", InteractionClips.THROW_LENGTH)
	await get_tree().create_timer(0.21, false, true).timeout
	_throwing = false
	if driving or _vehicle_action or not _mode.is_empty() or selected_character != thrower or _held_id() != id or not _gear.consume(id):
		return
	var direction := -_camera.global_basis.z
	var origin := player.position + Vector3.UP * 1.29 + direction * 0.55
	_dropped.throw(item, origin, direction, power)
	inventory = _gear.hotbar()
	_refresh_held_item()


func _store_id() -> String:
	return _walk_in if _inside.is_empty() else _inside


func _open_shop() -> void:
	var shop := _store_id()
	var source: String = shop if shop in ["burger", "rovana", "senukai"] else "maxima"
	_open_store(_places.name_of(shop), source)


func _open_fuel_shop() -> bool:
	var title: String = _fuel_stations.shop_near(player.position)
	if title.is_empty():
		return false
	_open_store(title, "fuel")
	return true


func _open_store(title: String, source: String) -> void:
	_create_pocket("shop")
	_pocket.open_store(title, _gear.items_from(source), _gear.owned, money)
	_pocket.bought.connect(_buy_item.bind(source))


func _create_pocket(mode: String) -> void:
	_mode = mode
	_set_large_map(false)
	Engine.time_scale = 0.25
	player.input_enabled = false
	car.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.modulate.a = 0.38
	_pocket = PocketPanel.new()
	_ui.add_child(_pocket)
	Style.fill(_pocket)
	_pocket.closed.connect(_close_pocket)


func _close_pocket() -> void:
	if is_instance_valid(_pocket):
		_pocket.queue_free()
		_pocket = null
	_close_picker()


func _buy_item(id: String, source: String) -> void:
	var item: Dictionary = _gear.catalog.get(id, {})
	if item.get("source") != source or not item.has("price"):
		return
	var price := int(item.price)
	if money < price or not _gear.add(id):
		_pocket.feedback("Cannot buy this item.", money)
		return
	money -= price
	inventory = _gear.hotbar()
	_pocket.feedback("Purchased %s" % item.name, money)
	_autosave()


func _can_use_item(id: String) -> bool:
	if not _gear.owned.has(id):
		return false
	var item: Dictionary = _gear.catalog.get(id, {})
	return item.get("consume", "") in ["eat", "drink"] or item.has("health") or item.has("stamina") or item.get("effect") == "altered"


func _use_item(id: String) -> void:
	if _consuming or driving or _passenger_driver != 0 or _flying or player.swimming or not _can_use_item(id):
		return
	var item: Dictionary = _gear.catalog[id]
	var altered: bool = item.get("effect") == "altered"
	if _mode == "phone" or _mode == "shop":
		_close_pocket()
	var use_animation := str(item.get("consume", "consume"))
	var character := selected_character
	_consuming = true
	_consumption_prop = id
	_refresh_held_item()
	player.action_clip(use_animation, 0.85)
	await get_tree().create_timer(0.24, false, true).timeout
	if _mode.is_empty() and not driving and not _flying and selected_character == character:
		if use_animation == "drink":
			InterfaceAudio.play_drink()
		elif use_animation == "eat":
			InterfaceAudio.play_eat()
	await get_tree().create_timer(0.34, false, true).timeout
	_consuming = false
	_consumption_prop = ""
	if not _mode.is_empty() or driving or _flying or selected_character != character or not _gear.consume(id):
		_refresh_held_item()
		return
	health = minf(health + float(item.get("health", 0)), 100.0)
	player.stamina = minf(player.stamina + float(item.get("stamina", 0)), 100.0)
	if altered:
		_altered_remaining = float(item.get("seconds", 90.0))
		_altered_profile = int(item.get("visual_profile", 0))
		_altered_strength = clampf(float(item.get("visual_strength", 1.0)), 0.0, 1.8)
	if item.has("boost_seconds"):
		player.energy_remaining = maxf(player.energy_remaining, float(item.boost_seconds))
	inventory = _gear.hotbar()
	_refresh_held_item()
	if is_instance_valid(_pocket):
		_pocket.feedback("Used %s" % item.name, money)
	else:
		var verb := "DRANK" if use_animation == "drink" else ("ATE" if use_animation == "eat" else "USED")
		_hud.notify("%s   /   %s%s" % [verb, item.name, "   /   +22% MOVEMENT" if item.has("boost_seconds") else ""])


func _use_equipment() -> void:
	var now := Time.get_ticks_msec()
	if now < _equipment_ready_at or not player.input_enabled or player.swimming or _consuming:
		return
	var kind := _equipment_kind()
	if kind == "cheat_bomb":
		_throw_selected()
		return
	var profile: Array = EquipmentProfiles.STATS.get(kind, [])
	var ranged := EquipmentProfiles.is_ranged(kind)
	var melee := not ranged and not profile.is_empty()
	_equipment_ready_at = now + (int(profile[3]) if not profile.is_empty() else 480)
	var forward := -_camera.global_basis.z
	if absf(forward.y) < 0.95:
		player.rotation.y = atan2(-forward.x, -forward.z)
	if melee or ranged:
		var clip := "punch" if melee else ("rifle_fire" if kind in EquipmentProfiles.LONG else "fire")
		player.action_clip(clip, 0.47 if melee else 0.32)
	else:
		player.interaction_pose()
	var contact_delay := 0.19 if melee else (0.10 if ranged else 0.0)
	if contact_delay > 0.0:
		await get_tree().create_timer(contact_delay, false, true).timeout
		if not _mode.is_empty() or driving or player.swimming:
			return
	var from := player.global_position + Vector3.UP * 1.31
	var distance: float = float(profile[0]) if not profile.is_empty() else 16.0
	var space := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var camera_origin := _camera.project_ray_origin(screen_center)
	var screen_direction := _camera.project_ray_normal(screen_center)
	var aim_ray := PhysicsRayQueryParameters3D.create(camera_origin, camera_origin + screen_direction * (distance + 12.0), 1 | 4 | 8 | 16, [player.get_rid()])
	var aim := space.intersect_ray(aim_ray)
	var target_point: Vector3 = aim.get("position", aim_ray.to)
	var direction := forward.slide(Vector3.UP).normalized() if melee and kind != "field_blade" else from.direction_to(target_point)
	if direction.is_zero_approx():
		return
	var ray := PhysicsRayQueryParameters3D.create(from, from + direction * distance, 1 | 4 | 8 | 16, [player.get_rid()])
	var hit := space.intersect_ray(ray)
	if melee and hit.is_empty():
		var reach := SphereShape3D.new()
		reach.radius = 0.53
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = reach
		query.transform.origin = from + direction * (distance - 0.51)
		query.collision_mask = 8
		for candidate: Dictionary in space.intersect_shape(query, 8):
			var victim := candidate.collider as Node3D
			if victim != null and victim.has_method("receive_attack"):
				var at := victim.global_position + Vector3.UP * 0.94
				var line := PhysicsRayQueryParameters3D.create(from, at, 1 | 4, [player.get_rid()])
				if space.intersect_ray(line).is_empty():
					hit = {"collider": victim, "position": at, "normal": -direction}
					break
	if not melee and (kind != "marker" or not hit.is_empty()):
		_impact_fx.equipment_effect(kind, from, hit.get("position", ray.to), hit.get("normal", Vector3.UP))
	SessionManager.attack_players(kind, from, direction)
	if kind == "cheat_rpg" and not hit.is_empty():
		_game_burst(hit.position + hit.normal * 0.19)
		return
	if EquipmentProfiles.is_firearm(kind):
		_report_offence("SHOTS FIRED", 2)
	if hit.is_empty():
		return
	var target: Node3D = hit.collider
	if target is PhysicalBone3D:
		target = target.get_meta("pedestrian_actor", null)
		if not is_instance_valid(target):
			return
	var impact: float = float(profile[1]) if not profile.is_empty() else 0.0
	if impact > 0.0 and target.has_method("receive_attack"):
		target.receive_attack(impact, direction, player, hit.position, ranged, kind)
		if not EquipmentProfiles.is_firearm(kind):
			_report_offence("DISTURBANCE", 1)
	elif impact > 8.0 and target.has_method("apply_impact"):
		target.apply_impact(impact * 0.69, hit.position, forward)


func _game_burst(at: Vector3) -> void:
	_impact_fx.game_flash(at)
	_report_offence("EXPLOSION", 3)
	for civilian: CharacterBody3D in _life.civilians:
		if not is_instance_valid(civilian):
			continue
		var hit_at := civilian.global_position + Vector3.UP * 0.71
		var distance := at.distance_to(hit_at)
		if distance >= 5.9:
			continue
		var cover := PhysicsRayQueryParameters3D.create(at, hit_at, 1 | 4)
		if get_world_3d().direct_space_state.intersect_ray(cover).is_empty():
			civilian.vehicle_impact((1.0 - distance / 5.9) * 26.0, at.direction_to(hit_at))


func _on_counter_hit(strength: float) -> void:
	if not driving and _mode.is_empty():
		_take_damage(strength, "COUNTERATTACK")


func _on_hard_landing(speed_down: float) -> void:
	var damage := clampf((speed_down - 9.5) * 5.3, 0.0, 100.0)
	if damage <= 0.0:
		return
	_impact_fx.injury(player.global_position + Vector3.UP * 0.09, Vector3.ZERO, damage * 0.29)
	_take_damage(damage, "HARD LANDING")


func _on_swim_transition(entering: bool, at: Vector3) -> void:
	if at.y < -80.0 or not _mode.is_empty():
		return
	var ripple := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.71
	ring.outer_radius = 0.79
	ring.rings = 24
	ring.ring_segments = 6
	var tint := StandardMaterial3D.new()
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.albedo_color = Color("#b5e2e2b2")
	ripple.mesh = ring
	ripple.material_override = tint
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ripple.position = at
	ripple.scale = Vector3(0.36, 0.17, 0.36)
	add_child(ripple)
	var wash := create_tween().set_parallel()
	wash.tween_property(ripple, "scale", Vector3(1.82, 0.12, 1.82) if entering else Vector3(1.26, 0.12, 1.26), 0.72)
	wash.tween_property(tint, "albedo_color:a", 0.0, 0.72)
	wash.chain().tween_callback(ripple.queue_free)


func _on_player_struck(strength: float) -> void:
	_take_damage(maxf(0.0, strength - 3.0) * 6.0, "VEHICLE IMPACT")


func _on_occupant_impact(strength: float, target: RigidBody3D) -> void:
	if driving and car == target:
		_take_damage(clampf((strength - 16.5) * 1.28, 0.0, 40.0), "CRASH")


func _on_player_hit(damage: float, attacker: String) -> void:
	if not driving and not _flying and _inside.is_empty():
		_take_damage(damage, "HIT BY " + attacker.to_upper())
		player.action_clip("hit_react", 0.33)


func _take_damage(damage: float, cause: String) -> void:
	if damage <= 0.0 or _mode == "down" or _mode == "transition":
		return
	health = maxf(0.0, health - damage)
	if health <= 0.0:
		_begin_defeat()
	else:
		_hud.notify("%s   /   −%d HEALTH" % [cause, roundi(damage)])


func nearby_passenger_driver() -> int:
	if not SessionManager.supports_passengers() or not is_instance_valid(_session_avatars) or driving or _flying \
			or _passenger_driver != 0 or _in_backrooms or not _inside.is_empty() or not _walk_in.is_empty() or player.swimming:
		return 0
	return _session_avatars.closest_passenger_car(player.global_position)


func _passenger_seat_changed(driver: int, reason: String) -> void:
	if not reason.is_empty():
		_hud.notify(reason)
		return
	if driver == 0:
		if _passenger_driver != 0:
			_passenger_exit_requested = true
			_passenger_seat_revoked = true
		return
	if driving or _flying or not _mode.is_empty() or not is_instance_valid(_session_avatars.car_for(driver)):
		SessionManager.seat_request(0)
		return
	_passenger_driver = driver
	_passenger_exit_requested = false
	_passenger_seat_revoked = false
	player.set_seated(true)
	_hud.notify("RIDING WITH " + str(SessionManager.roster.get(driver, "PLAYER")).to_upper())


func _update_passenger(delta: float) -> void:
	var vehicle: RigidBody3D = _session_avatars.car_for(_passenger_driver)
	var driver_present := is_instance_valid(vehicle) and SessionManager.roster.has(_passenger_driver)
	if driver_present and not _passenger_exit_requested:
		player.global_transform = vehicle.passenger_avatar_transform()
		player.update_driver_pose(0.0, delta)
		return
	_passenger_exit_requested = false
	var origin := player.global_position
	var transform_on_road := Transform3D(Basis(Vector3.UP, vehicle.heading()), vehicle.global_position) if driver_present else player.global_transform
	var landing := Vector3.INF
	for offset: Vector3 in [Vector3.RIGHT * 2.05, Vector3.LEFT * 2.05, Vector3.BACK * 3.7, Vector3.FORWARD * 3.7]:
		var at := transform_on_road * offset
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at - Vector3.UP * 3.5, 1)
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not floor_hit.is_empty() and floor_hit.normal.y >= 0.66 and _vehicle_exit_clear(car, floor_hit.position + Vector3.UP * 0.075):
			landing = floor_hit.position + Vector3.UP * 0.075
			break
	if landing == Vector3.INF and driver_present and not _passenger_seat_revoked:
		_hud.notify("NO CLEAR GROUND BESIDE THE CAR")
		return
	_passenger_driver = 0
	_passenger_seat_revoked = false
	SessionManager.seat_request(0)
	player.set_seated(false)
	_relocate_player(landing if landing != Vector3.INF else origin + Vector3.UP * 0.3)
	player.ejection_grace = 0.65


func _exit_vehicle() -> void:
	var vehicle := car
	var motion: Vector3 = vehicle.linear_velocity
	if motion.slide(Vector3.UP).length() > 4.2 or motion.y < -5.0:
		var launch := _clear_launch_point(vehicle, 2.25)
		if launch == Vector3.INF:
			_hud.notify("NO SPACE TO BAIL OUT")
			return
		_end_drive()
		_launch_from_vehicle(vehicle, launch, motion)
		return
	var pose := Transform3D(Basis(Vector3.UP, vehicle.heading()), vehicle.global_position)
	for offset: Vector3 in [Vector3(-1.94, 0.0, 0.34), Vector3(1.94, 0.0, 0.34),
		Vector3(0, 0, 3.09), Vector3(-2.42, 0.0, 0.0), Vector3(2.42, 0.0, 0.0),
		Vector3(0, 0, -3.35), Vector3(-2.65, 0, 1.85), Vector3(2.65, 0, 1.85)]:
		var at := pose * offset
		var base: Vector3 = _district.point_on_ground(at, 0.0)
		var centre := Vector3(at.x, maxf(at.y, base.y), at.z)
		var landing := PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 1.5, centre - Vector3.UP * 2.6, 1, [vehicle.get_rid()])
		var ground := get_world_3d().direct_space_state.intersect_ray(landing)
		if ground.is_empty() or ground.normal.y < 0.66:
			continue
		var feet: Vector3 = ground.position + Vector3.UP * 0.075
		if not _vehicle_exit_clear(vehicle, feet):
			continue
		_end_drive()
		player.rotation = Vector3(0.0, vehicle.heading(), 0.0)
		_relocate_player(feet)
		player.ejection_grace = 0.65
		return
	_hud.notify("NO CLEAR GROUND BESIDE THE CAR")


func _end_drive() -> void:
	driving = false
	_in_cockpit = false
	car.set_driver(false)
	player.set_seated(false)
	RadioManager.set_audible(false)


func _vehicle_exit_clear(vehicle: PhysicsBody3D, feet: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.66
	capsule.radius = 0.32
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = capsule
	room.collision_mask = 1 | 4
	room.transform.origin = feet + Vector3.UP * 0.88
	if not space.intersect_shape(room, 1).is_empty():
		return false
	var from := Vector3(vehicle.global_position.x, room.transform.origin.y, vehicle.global_position.z)
	var across := PhysicsRayQueryParameters3D.create(from, room.transform.origin, 1 | 4, [vehicle.get_rid()])
	return space.intersect_ray(across).is_empty()


func _clear_launch_point(vehicle: PhysicsBody3D, clearance: float) -> Vector3:
	var side := vehicle.global_basis.x.slide(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	var height := Vector3.UP * 0.16
	if vehicle.global_basis.y.y < 0.35:
		height = Vector3.UP * 0.6
	for sign_value: float in [-1.0, 1.0]:
		var at := vehicle.global_position + height + side * sign_value * clearance
		if _vehicle_exit_clear(vehicle, at):
			return at
	return Vector3.INF


func _launch_from_vehicle(vehicle: PhysicsBody3D, at: Vector3, motion: Vector3) -> void:
	var away := (at - vehicle.global_position).slide(Vector3.UP).normalized()
	_relocate_player(at)
	player.velocity = motion.limit_length(27.0) + away * 4.6 + Vector3.UP * 2.4
	player.ejection_grace = 1.55
	player.action_clip("hit_react", 0.58)
	player.add_collision_exception_with(vehicle)
	get_tree().create_timer(1.35, false, true).timeout.connect(func() -> void:
		if is_instance_valid(vehicle):
			player.remove_collision_exception_with(vehicle)
	)


func can_recover_car() -> bool:
	return driving and is_instance_valid(car) and not car.wrecked and not _recovering and car.global_basis.y.y < 0.52


func _recover_car() -> void:
	var vehicle := car
	var yaw: float = vehicle.heading()
	var pose := Transform3D(Basis(Vector3.UP, yaw), vehicle.global_position)
	var space := get_world_3d().direct_space_state
	var chassis := vehicle.get_node("ChassisCollision") as CollisionShape3D
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = chassis.shape
	room.collision_mask = 1 | 2 | 4 | 8
	room.exclude = [vehicle.get_rid(), player.get_rid()]
	for offset: Vector3 in [Vector3.ZERO, Vector3.LEFT * 2.8, Vector3.RIGHT * 2.8,
			Vector3.FORWARD * 4.8, Vector3.BACK * 4.8, Vector3(-3.5, 0, -3.5), Vector3(3.5, 0, 3.5)]:
		var at := pose * offset
		var terrain: Vector3 = _district.point_on_ground(at)
		at.y = maxf(terrain.y, at.y)
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.4, at - Vector3.UP * 3.8, 1, room.exclude)
		var ground := space.intersect_ray(ray)
		if ground.is_empty() or ground.normal.y < 0.87:
			continue
		var water: Dictionary = _district.water_sample(ground.position)
		if not water.is_empty() and ground.position.y < float(water.level) + 0.08:
			continue
		pose.origin = ground.position + Vector3.UP * 0.75
		room.transform = pose * chassis.transform
		if not space.intersect_shape(room, 1).is_empty():
			pose.origin = vehicle.global_position
			continue
		_recovering = true
		vehicle.request_recovery(pose)
		_heading = yaw
		await get_tree().create_timer(0.55, false, true).timeout
		_recovering = false
		if driving and car == vehicle and is_instance_valid(vehicle):
			_hud.notify("CAR RECOVERED" if vehicle.global_basis.y.y > 0.78 else "CAR COULD NOT SETTLE UPRIGHT")
		return
	_hud.notify("NO CLEAR GROUND TO RIGHT THE CAR")


func _orbit(amount: Vector2) -> void:
	if driving and _in_cockpit:
		_cockpit_look -= amount
		_cockpit_look = _cockpit_look.clamp(Vector2(-1.24, -0.63), Vector2(1.24, 0.33))
		return
	_heading -= amount.x
	_pitch = clampf(_pitch - amount.y, -0.94, 0.21)
	_idle_orbit = 0.0


func _apply_camera_distance() -> void:
	if is_instance_valid(_camera) and _inside.is_empty() and not _in_backrooms:
		_camera.far = SettingsManager.view_distance()


func _update_camera(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var axis := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y))
		if axis.length() > 0.25:
			_orbit(axis * delta * 2.4 * float(GameManager.settings.controller_look))
	if driving:
		player.visible = not _in_cockpit
	if driving and _in_cockpit:
		_camera.near = 0.028
		_camera_arm.collision_mask = 0
		_camera_arm.spring_length = 0.0
		_camera.position = Vector3.ZERO
		_camera_rig.global_transform = car.cockpit_transform(_cockpit_look.x, _cockpit_look.y - 0.13)
		_camera.fov = lerpf(_camera.fov, 73.0, minf(delta * 9.0, 1.0))
		return
	_camera.near = 0.075
	_camera_arm.collision_mask = 1 | 4
	var followed: RID = _helicopter.get_rid() if _flying else (car.get_rid() if driving else RID())
	if followed != _camera_car:
		if _camera_car.is_valid():
			_camera_arm.remove_excluded_object(_camera_car)
		if followed.is_valid():
			_camera_arm.add_excluded_object(followed)
		_camera_car = followed
	_idle_orbit += delta
	if _idle_orbit > 0.85:
		if _flying and _helicopter.velocity.length() > 3.0:
			_heading = lerp_angle(_heading, _helicopter.rotation.y, 1.0 - exp(-delta * 1.65))
		elif driving and absf(car.speed) > 3.0:
			_heading = lerp_angle(_heading, car.heading(), 1.0 - exp(-delta * 1.55))
		elif not driving and player.velocity.length() > 1.1 and Input.get_action_strength("move_forward") > 0.25:
			_heading = lerp_angle(_heading, player.rotation.y, 1.0 - exp(-delta * 0.86))
	var height := 2.34 if _flying else (1.62 if driving or _passenger_driver != 0 else 1.52)
	var aiming := not driving and _passenger_driver == 0 and not _flying and EquipmentProfiles.is_ranged(_equipment_kind())
	var target := _focus() + Vector3.UP * height
	_visible_heading = lerp_angle(_visible_heading, _heading, 1.0 - exp(-delta * (6.0 if driving else 8.0)))
	if aiming:
		var shoulder := Basis(Vector3.UP, _visible_heading).x * 0.74
		var query := PhysicsRayQueryParameters3D.create(target, target + shoulder, 1 | 4, [player.get_rid()])
		var wall := get_world_3d().direct_space_state.intersect_ray(query)
		if not wall.is_empty():
			shoulder = shoulder.normalized() * maxf(0.0, target.distance_to(wall.position) - 0.12)
		target += shoulder
	_aim = _aim.lerp(target, 1.0 - exp(-delta * (6.0 if driving else 8.5)))
	_camera_rig.global_transform = Transform3D(Basis(Vector3.UP, _visible_heading) * Basis(Vector3.RIGHT, _pitch), _aim)
	var distance := 11.0 if _flying else (2.7 if _in_backrooms else (7.15 if driving else 4.5))
	if _in_backrooms:
		player.set_camera_occluded(_camera_arm.get_hit_length() < 0.78)
	var home_id: String = "" if driving or _flying else _places.home_at(player.position)
	var at_home := not home_id.is_empty()
	if at_home:
		distance = _places.home_camera_distance(home_id, player.position)
	elif not _store_id().is_empty():
		distance = 3.05
	_camera_arm.spring_length = minf(distance, 3.6) if aiming else distance
	if not driving:
		var clear_camera := _camera_arm.get_hit_length() >= 0.92
		player.visible = not _flying and (clear_camera or (not aiming and _store_id().is_empty() and not at_home))
	_camera.fov = lerpf(_camera.fov, 66.0 + minf(absf(car.speed) * 0.47, 12.0) if driving else 67.0, minf(delta * 3.8, 1.0))


func _update_hud() -> void:
	if _visible_held_id != (_held_id() if _consumption_prop.is_empty() else _consumption_prop):
		_refresh_held_item()
	_hud.focus_position = _map_focus()
	_hud.focus_heading = _helicopter.rotation.y if _flying else (car.heading() if driving else player.rotation.y)
	if _last_map_focus.distance_to(_hud.focus_position) >= 5.0:
		_last_map_focus = _hud.focus_position
		_hud.nearby_roads = _district.map_segments(_last_map_focus, 128.0)
		_hud.street_name = _district.street_at(_last_map_focus, _hud.nearby_roads)
	_hud.checkpoint = DESTINATION if not _in_backrooms and stage in [1, 2] else Vector3.ZERO
	_destination_marker.visible = stage in [1, 2]
	_hud.character = _characters[selected_character]
	_hud.items = inventory
	var selected_gear: Dictionary = _gear.catalog.get(_held_id(), {})
	_hud.equipped = str(selected_gear.get("name", ""))
	_hud.aiming = not _flying and _passenger_driver == 0 and EquipmentProfiles.is_ranged(str(selected_gear.get("equipment", ""))) and _mode.is_empty()
	_hud.slot = selected_slot
	_hud.money = money
	_hud.wanted_stars = _wanted.stars
	_hud.city_time = _district.time_of_day
	_hud.health = health
	_hud.stamina = player.stamina
	_hud.patience = patience
	_hud.driving = driving
	_hud.speed = car.speed
	_hud.car_condition = car.condition
	_hud.vehicle_name = car.vehicle_name
	_hud.flying = _flying
	if _flying:
		_hud.speed = _helicopter.velocity.slide(Vector3.UP).length()
		_hud.flight_height = maxf(0.0, _helicopter.position.y - _district.elevation.height_at(Vector2(_helicopter.position.x, _helicopter.position.z)))
	_hud.map_expanded = _large_map.visible
	_large_map.update_map(_map_focus(), _hud.focus_heading, _hud.checkpoint, _hud.street_name)
	_hud.objective = "Explore the Backrooms, Level 0." if _in_backrooms else [
		"Enter the teal hatchback.",
		"Tune to a station with the radio picker.",
		"Follow Žemaitijos g. to the checkpoint.",
		"Explore the streets of Mažeikiai."
	][stage]
	var fuel_objective: String = _fuel_stations.objective()
	if not fuel_objective.is_empty():
		_hud.objective = fuel_objective
	_hud.prompt = ""
	_hud.radio_tip = ""
	var key := GameManager.key_label("interact")
	if _flying:
		_hud.radio_tip = "HOLD %s / LB   RADIO" % GameManager.key_label("radio_wheel")
		_hud.prompt = "%s CLIMB   /   %s DESCEND   /   %s EXIT OR JUMP" % [
			GameManager.key_label("jump_brake"), GameManager.key_label("dive"), GameManager.key_label("rob")]
	elif driving:
		if stage < 3:
			_hud.radio_tip = "HOLD %s / LB   RADIO" % GameManager.key_label("radio_wheel")
		if car.wrecked:
			_hud.prompt = "%s   EXIT WRECK" % GameManager.key_label("rob")
		elif _recovering:
			_hud.prompt = "RIGHTING CAR…"
		elif can_recover_car():
			_hud.prompt = "%s   RECOVER CAR" % GameManager.key_label("recover")
		elif car.linear_velocity.length() < 0.65:
			_hud.prompt = "%s  EXIT   /   %s  HORN" % [GameManager.key_label("rob"), key]
		else:
			_hud.prompt = "%s   BAIL OUT" % GameManager.key_label("rob")
	elif _passenger_driver != 0:
		_hud.prompt = "%s   LEAVE PASSENGER SEAT" % GameManager.key_label("rob")
	else:
		_foot_prompt(key)
		if player.swimming:
			_hud.radio_tip = "%s SURFACE   /   %s DIVE" % [GameManager.key_label("jump_brake"), GameManager.key_label("dive")]


func _foot_prompt(key: String) -> void:
	if nearby_passenger_driver() != 0:
		_hud.prompt = "%s   RIDE AS PASSENGER" % key
		return
	if _in_backrooms:
		if _backrooms.near_exit(player.global_position):
			_hud.prompt = "%s   RETURN TO MAŽEIKIAI" % key
		elif _backrooms.near_bottle(player.global_position):
			_hud.prompt = "%s   PICK UP BEER" % key
		return
	if _vehicle_action:
		return
	if _helicopter_near_player():
		_hud.prompt = "%s   BOARD HELICOPTER" % key
		return
	var dropped: RigidBody3D = _dropped.nearest(player.position)
	if dropped != null:
		_hud.prompt = "%s   PICK UP %s" % [key, str(_gear.catalog[dropped.get_meta("product")].name).to_upper()]
		return
	if not _inside.is_empty():
		if _places.room_exit_near(_inside, player.position):
			_hud.prompt = "%s   EXIT %s" % [key, _places.name_of(_inside).to_upper()]
		elif _places.is_bank(_inside):
			if _bank_progress >= 0:
				_hud.radio_tip = "BANK JOB   /   %02d SEC" % ceili(_bank_clock)
				if _places.bank_target_near(_inside, player.position, _bank_progress):
					_hud.prompt = "%s   COLLECT MARKER" % key
			elif not _completed_banks.has(_inside):
				_hud.prompt = "%s   START BANK JOB" % GameManager.key_label("rob")
		elif _places.checkout_near(_inside, player.position):
			_hud.prompt = "%s   OPEN CHECKOUT" % key
		return
	if not _walk_in.is_empty():
		if _places.checkout_near(_walk_in, player.position):
			_hud.prompt = "%s   OPEN CHECKOUT" % key
		else:
			var id := _shelf_product()
			if not id.is_empty():
				var item: Dictionary = _gear.catalog[id]
				_hud.prompt = "%s   BUY %s   €%d" % [key, str(item.name).to_upper(), int(item.price)]
				_hud.radio_tip = "%s   TAKE FROM SHELF" % GameManager.key_label("rob")
		return
	if is_instance_valid(_carried_body):
		_hud.prompt = "%s THROW BODY   /   %s DROP" % [GameManager.key_label("throw_item"), GameManager.key_label("drop_item")]
		return
	if _life.nearby_body(player.position) != null:
		_hud.prompt = "%s   CARRY BODY" % key
		return
	var station_prompt: String = _fuel_stations.prompt(player.position, key, GameManager.key_label("rob"), EquipmentProfiles.is_firearm(_equipment_kind()))
	if not station_prompt.is_empty():
		_hud.prompt = station_prompt
		return
	var automatic_door: String = _places.walk_in_prompt(player.position)
	if not automatic_door.is_empty():
		_hud.prompt = "%s   /   WALK THROUGH THE DOORS" % automatic_door.to_upper()
		return
	var apartment: Node3D = _places.home_door_at(player.position)
	if apartment != null:
		_hud.prompt = "%s   %s" % [key, apartment.door_label(player.position)]
		return
	var place: String = _places.gate_at(player.position)
	var pickup: String = _collectibles.nearby(player.global_position)
	var vehicle := _nearby_vehicle() if _life != null else null
	if not place.is_empty():
		_hud.prompt = "%s   ENTER %s" % [key, _places.name_of(place).to_upper()]
	elif not pickup.is_empty():
		_hud.prompt = "%s   PICK UP %s" % [key, str(_gear.catalog[pickup].name).to_upper()]
	elif vehicle != null:
		if not vehicle.wrecked:
			_hud.prompt = "%s   TAKE CAR" % key if vehicle.autopilot else "%s   ENTER CAR" % key
		if vehicle.wallet > 0:
			_hud.radio_tip = "%s   SEARCH GLOVEBOX" % GameManager.key_label("rob")
	elif _life != null and _life.nearest_person(player.position) != null:
		_hud.prompt = "%s   TAKE WALLET" % GameManager.key_label("rob")
	elif _distance(player.position, CHURCH_APPROACH) < 5.0:
		_hud.prompt = "%s   INSPECT CHURCH" % key
	elif _can_use_item(_held_id()) and not player.swimming:
		_hud.prompt = "%s   USE %s" % [GameManager.key_label("use_item"), str(_gear.catalog[_held_id()].name).to_upper()]


func _focus() -> Vector3:
	if _flying:
		return _helicopter.global_position
	return car.global_position if driving else player.global_position


func _map_focus() -> Vector3:
	if _in_backrooms:
		return _backrooms_return
	return _focus() if _inside.is_empty() else _outside_at


func _distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x - to.x, from.z - to.z).length()


func _build_marker(at: Vector3, title: String) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var geo := Geometry.new()
	var diamond := geo.box(root, Vector3(0, 2.0, 0), Vector3(0.46, 0.46, 0.46), Style.AMBER)
	diamond.rotation.z = PI * 0.25
	geo.taper(root, Vector3(0, 0.086, 0), 0.042, 2.5, 2.5, Color("#ffc77d36"), 24)
	var label := geo.signage(root, Vector3(0, 3, 0), title, 28, Color("#ffdf9d"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.outline_modulate = Color("#30263b")
	return root


func _select_character(index: int) -> void:
	if _character_ready and selected_character != index:
		_store_character_loadout()
	if not _character_ready or selected_character != index:
		var stored: Variant = _character_loadouts.get(str(_characters[index].id), {})
		var state: Dictionary = stored if stored is Dictionary else {}
		_gear.restore(state)
		money = maxi(int(state.get("money", 0)), 0)
		selected_slot = clampi(int(state.get("slot", 0)), 0, 7)
		player.energy_remaining = clampf(float(state.get("energy_remaining", 0.0)), 0.0, 60.0)
		inventory = _gear.hotbar()
	selected_character = index
	_character_ready = true
	player.apply_character(_characters[index])
	_refresh_held_item()


func _store_character_loadout() -> void:
	var id := str(_characters[selected_character].id)
	_character_loadouts[id] = {"money": money, "items": _gear.slots.duplicate(),
		"owned_items": _gear.owned.duplicate(), "equipment": _gear.equipment, "slot": selected_slot, "energy_remaining": player.energy_remaining}


func _select_hotbar(index: int) -> void:
	selected_slot = index
	var id := str(_gear.slots[index])
	_gear.equipment = id if _gear.catalog.get(id, {}).has("equipment") else ""
	_refresh_held_item()


func _held_id() -> String:
	return _gear.equipment if not _gear.equipment.is_empty() else str(_gear.slots[selected_slot])


func _equipment_kind() -> String:
	return str(_gear.catalog.get(_held_id(), {}).get("equipment", "fists"))


func _refresh_held_item() -> void:
	_visible_held_id = _held_id() if _consumption_prop.is_empty() else _consumption_prop
	var item: Dictionary = _gear.catalog.get(_visible_held_id, {})
	if item.has("equipment"):
		player.show_equipment(str(item.equipment), item)
	else:
		player.show_product(item)


func _autosave() -> void:
	_autosave_remaining = 45.0
	if GameManager.settings.autosave and not SessionManager.active:
		_save(true)


func _save(automatic := false) -> bool:
	if SessionManager.active:
		return false
	_store_character_loadout()
	return SaveManager.save_game({
		"character_loadouts": _character_loadouts, "altered_remaining": _altered_remaining,
		"altered_profile": _altered_profile, "altered_strength": _altered_strength,
		"completed_banks": _completed_banks, "fuel_jobs": _fuel_stations.completed, "city_damage": _impact_fx.save_state(),
		"map": "mazeikiai", "map_revision": MAP_REVISION, "character": _characters[selected_character].id,
		"player": SaveManager.vector_data(_heli_entry if _flying else (_map_focus() if not driving else player.position)),
		"heading": _backrooms_heading if _in_backrooms else player.rotation.y,
		"walk_in_home": _places.home_at(player.position) if _inside.is_empty() and not driving and not _in_backrooms else "",
		"walk_in_shop": _walk_in if not driving else "", "reveal_map": _discovery.revealed_all,
		"character_spots": _previous_spots,
		"time_of_day": _district.time_of_day, "broken_lamps": _district.broken_lamps.keys(),
		"wanted_stars": _wanted.stars, "wanted_heat": _wanted.heat,
		"car": SaveManager.vector_data(car.position), "car_heading": car.heading(), "car_variant": car.variant,
		"driving": driving, "money": money, "health": health, "stamina": player.stamina,
		"patience": patience, "radio": RadioManager.current_station, "stage": stage,
		"items": _gear.slots, "owned_items": _gear.owned, "equipment": _gear.equipment,
		"picked_up": _collectibles.collected.keys(), "slot": selected_slot, "market_visited": _market_visited,
		"explored": _discovery.export_cells(), "car_condition": car.condition
	}, automatic)


func _restore(saved: Dictionary, current_map: bool) -> void:
	var character_index := 0
	for index in _characters.size():
		if _characters[index].id == saved.get("character", ""):
			character_index = index
			break
	var loadouts: Variant = saved.get("character_loadouts", {})
	if loadouts is Dictionary:
		_character_loadouts = loadouts.duplicate(true)
	var character_id := str(_characters[character_index].id)
	if not _character_loadouts.has(character_id):
		var legacy := {}
		for key: String in ["money", "items", "owned_items", "equipment", "slot"]:
			if saved.has(key):
				legacy[key] = saved[key]
		_character_loadouts[character_id] = legacy
	_select_character(character_index)
	var bank_jobs: Variant = saved.get("completed_banks", [])
	if bank_jobs is Array:
		_completed_banks = bank_jobs
	_altered_remaining = clampf(float(saved.get("altered_remaining", 0.0)), 0.0, 120.0)
	_altered_profile = clampi(int(saved.get("altered_profile", 0)), 0, 3)
	_altered_strength = clampf(float(saved.get("altered_strength", 1.0)), 0.0, 1.8)
	stage = clampi(int(saved.get("stage", 0)), 0, 3) if current_map else 0
	var spots: Variant = saved.get("character_spots", {})
	if spots is Dictionary:
		_previous_spots = spots
	health = clampf(float(saved.get("health", 100.0)), 0, 100)
	patience = clampf(float(saved.get("patience", 100.0)), 0, 100)
	player.stamina = clampf(float(saved.get("stamina", 100.0)), 0, 100)
	_market_visited = bool(saved.get("market_visited", false)) and current_map
	var last_player := SaveManager.read_vector(saved.get("player"), START) if current_map else START
	var saved_home: String = str(saved.get("walk_in_home", ""))
	var saved_shop := str(saved.get("walk_in_shop", ""))
	var valid_shop: bool = not saved_shop.is_empty() and _places.walk_in_at(last_player) == saved_shop
	var valid_home: bool = not saved_home.is_empty() and _places.home_at(last_player) == saved_home
	player.position = last_player if valid_home else (_places.shop_ground(saved_shop, last_player)
		if valid_shop else _district.point_on_ground(last_player, 0.065))
	_walk_in = saved_shop if valid_shop else ""
	var last_car := SaveManager.read_vector(saved.get("car"), PARKED) if current_map else PARKED
	var parked: Vector3 = _district.point_on_ground(last_car, PARKED.y)
	player.rotation.y = float(saved.get("heading", START_HEADING)) if current_map else START_HEADING
	car.reset_pose(parked, float(saved.get("car_heading", START_HEADING)) if current_map else START_HEADING)
	car.restore_condition(float(saved.get("car_condition", 100.0)))
	driving = bool(saved.get("driving", false)) and current_map
	_heading = car.heading() if driving else player.rotation.y
	_visible_heading = _heading
	player.set_seated(driving)
	car.set_driver(driving, false)

func _open_cheats_from_chat() -> void:
	_close_chat()
	_open_cheats()


func _open_cheats() -> void:
	if not SessionManager.cheats_allowed():
		_hud.notify("CHEATS ARE RESTRICTED IN THIS ROOM")
		return
	_mode = "cheats"
	_set_large_map(false)
	player.input_enabled = false
	car.input_enabled = false
	Engine.time_scale = 0.18
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_console = CheatConsole.new()
	_ui.add_child(_console)
	Style.fill(_console)
	_console.closed.connect(_close_cheats)
	_console.entered.connect(_submit_cheat)


func _submit_cheat(code: String) -> void:
	if not SessionManager.cheats_allowed():
		_close_cheats()
		_hud.notify("CHEATS ARE RESTRICTED IN THIS ROOM")
		return
	if code == "limbo":
		_close_cheats()
		_spawn_limbo()
		return
	if code in SessionManager.ANNOUNCED_CODES:
		SessionManager.announce_cheat(code)
	if code == "helli":
		_close_cheats()
		_spawn_helicopter()
		return
	if code == "givemeeverything":
		_close_cheats()
		_open_spawn_menu()
		return
	if code == "ihopeidontfall":
		_close_cheats()
		if _in_backrooms:
			_leave_backrooms()
		else:
			_enter_backrooms()
		return
	if code == "advert":
		_close_cheats()
		var enabled: bool = RadioManager.toggle_interludes()
		_hud.notify("RADIO DJ AND ADVERTS ENABLED" if enabled else "RADIO DJ AND ADVERTS DISABLED")
		return
	if code == "skipad":
		_close_cheats()
		var changed: bool = RadioManager.skip_to_interlude()
		_hud.notify("PLAYING DJ OR ADVERT" if changed else "NO PLAYABLE DJ OR ADVERT ON THIS STATION")
		return
	if code == "skip":
		_close_cheats()
		var changed := RadioManager.skip_track()
		_hud.notify("RADIO TRACK SKIPPED" if changed else "NO ACTIVE RADIO TRACK")
		return
	if code != "map":
		_console.reject()
		return
	_discovery.revealed_all = true
	_close_cheats()
	_hud.notify("ENTIRE CITY MAP REVEALED")
	_autosave()
	_pause_game(true)


func _spawn_limbo() -> void:
	if is_instance_valid(_limbo) and driving and car == _limbo:
		_hud.notify("YOU ARE ALREADY DRIVING THE LIMBO")
		return
	var anchor := _focus()
	var space := get_world_3d().direct_space_state
	var clearance := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 1.1, 4.9)
	clearance.shape = shape
	clearance.collision_mask = 1 | 2 | 4 | 8
	var heading := Basis(Vector3.UP, _heading)
	for offset: Vector3 in [Vector3.FORWARD * 5.2, Vector3.RIGHT * 5.2, Vector3.LEFT * 5.2, Vector3.BACK * 5.2]:
		var at := anchor + heading * offset
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.5, at - Vector3.UP * 4.0, 1)
		var ground := space.intersect_ray(ray)
		if ground.is_empty() or ground.normal.y < 0.88:
			continue
		at = ground.position + Vector3.UP * 0.92
		clearance.transform = Transform3D(heading, at)
		if not space.intersect_shape(clearance, 1).is_empty():
			continue
		if is_instance_valid(_limbo):
			_limbo.queue_free()
		_limbo = CAR_SCENE.instantiate()
		_limbo.variant = "limbo"
		_limbo.position = at
		_limbo.rotation.y = _heading
		add_child(_limbo)
		_hud.notify("LIMBO  /  200 KM/H")
		return
	_hud.notify("FIND CLEAR GROUND TO SPAWN THE LIMBO")


func _helicopter_near_player() -> bool:
	return (is_instance_valid(_helicopter) and not _helicopter.crashing and not _flying and not player.swimming
		and player.global_position.distance_to(_helicopter.global_position) <= 4.5)


func _spawn_helicopter() -> void:
	if (driving or _flying or _in_backrooms or not _inside.is_empty() or not _walk_in.is_empty()
		or not _places.home_at(player.position).is_empty() or player.swimming):
		_hud.notify("GO OUTSIDE ON FOOT TO SPAWN A HELICOPTER")
		return
	var scope := SphereShape3D.new()
	scope.radius = 2.4
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = scope
	clearance.collision_mask = 1 | 4
	var world := get_world_3d().direct_space_state
	var front := Vector3(-sin(_heading), 0, -cos(_heading))
	for offset: float in [0.0, 0.77, -0.77, 1.58, -1.58, PI]:
		var target := player.global_position + front.rotated(Vector3.UP, offset) * 7.8
		var ray := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 1.7, target - Vector3.UP * 2.7, 1)
		var ground := world.intersect_ray(ray)
		if ground.is_empty() or ground.normal.y < 0.94 or not _district.water_sample(target).is_empty():
			continue
		var at: Vector3 = ground.position + Vector3.UP * 0.13
		clearance.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 2.55)
		if not world.intersect_shape(clearance, 1).is_empty():
			continue
		if is_instance_valid(_helicopter):
			_helicopter.queue_free()
		_helicopter = HELICOPTER_SCENE.instantiate()
		_helicopter.position = at
		_helicopter.rotation.y = _heading
		_helicopter.pad_height = at.y
		add_child(_helicopter)
		_hud.notify("HELICOPTER NEARBY   /   %s TO BOARD" % GameManager.key_label("interact"))
		return
	_hud.notify("FIND FLAT, OPEN GROUND FOR A HELICOPTER")


func _board_helicopter() -> void:
	_release_carried_body(false)
	_heli_entry = player.global_position
	_flying = true
	_helicopter.occupied = true
	RadioManager.set_audible(true)
	player.set_seated(true)
	player.input_enabled = false
	player.hide()
	_heading = _helicopter.rotation.y
	_idle_orbit = 0.0


func _leave_helicopter() -> void:
	var at := _helicopter.global_position
	var surface: Dictionary = _helicopter.ground_below(at + Vector3.UP * 0.2, 1.0)
	if surface.is_empty() or _helicopter.velocity.length() > 1.25:
		var launch := _clear_launch_point(_helicopter, 2.75)
		if launch == Vector3.INF:
			_hud.notify("NO SPACE TO JUMP CLEAR")
			return
		var motion: Vector3 = _helicopter.velocity
		_end_flight()
		_helicopter.start_crash(motion)
		_launch_from_vehicle(_helicopter, launch, motion)
		return
	var world := get_world_3d().direct_space_state
	for side: float in [-1.0, 1.0]:
		var next := at + _helicopter.global_basis.x * side * 2.03
		var landing: Dictionary = _helicopter.ground_below(next + Vector3.UP, 2.6)
		if landing.is_empty() or landing.normal.y < 0.72:
			continue
		var floor_at: Vector3 = landing.position
		var path := PhysicsRayQueryParameters3D.create(at + Vector3.UP, floor_at + Vector3.UP,
			1 | 4, [_helicopter.get_rid()])
		if not world.intersect_ray(path).is_empty():
			continue
		_end_flight()
		_relocate_player(floor_at + Vector3.UP * 0.07)
		player.ejection_grace = 0.65
		return
	_hud.notify("NO SPACE TO EXIT ON EITHER SIDE")


func _end_flight() -> void:
	_flying = false
	RadioManager.set_audible(false)
	_helicopter.occupied = false
	_helicopter.velocity = Vector3.ZERO
	player.set_seated(false)
	player.input_enabled = true


func _open_spawn_menu() -> void:
	_create_pocket("spawn_catalog")
	var all_items: Array[Dictionary] = []
	all_items.assign(_gear.catalog.values())
	_pocket.open_spawn_menu(all_items)
	_pocket.spawn_requested.connect(_spawn_catalog_item)


func _spawn_catalog_item(id: String, on_ground: bool) -> void:
	var item: Dictionary = _gear.catalog.get(id, {})
	if item.is_empty():
		return
	if on_ground:
		var forward := -_camera.global_basis.z
		var at := _focus() + Vector3.UP * 0.72
		var ray := PhysicsRayQueryParameters3D.create(at, at + forward * 1.1, 1 | 4, [player.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			_pocket.feedback("Clear some space in front of you.", money)
			return
		_dropped.drop(item, at + forward * 1.05, forward)
		_pocket.feedback("Spawned %s." % str(item.name), money)
	elif _gear.add(id):
		_gear.pin(id, selected_slot)
		inventory = _gear.hotbar()
		_select_hotbar(selected_slot)
		_pocket.feedback("Added %s." % str(item.name), money)
	else:
		_pocket.feedback("You already carry the maximum.", money)


func _enter_backrooms() -> void:
	if driving or _vehicle_action or not _inside.is_empty() or not _walk_in.is_empty() or not _places.home_at(player.position).is_empty() or player.swimming:
		_hud.notify("GO OUTSIDE ON FOOT TO ENTER THE BACKROOMS")
		return
	_fuel_stations.cancel()
	_release_carried_body(false)
	_backrooms_return = player.global_position
	_backrooms_heading = player.rotation.y
	if not is_instance_valid(_backrooms):
		_backrooms = Backrooms.new()
		_backrooms.name = "Backrooms"
		_backrooms.position = Vector3(START.x, -122.0, START.z)
		add_child(_backrooms)
		_backrooms.build()
	_in_backrooms = true
	_life.set_physics_process(false)
	_camera.environment = _backrooms.view_environment
	_camera.far = 100.0
	player.indoor_speed_limit = 2.8
	_heading = 0.0
	_visible_heading = 0.0
	_pitch = -0.10
	player.rotation.y = 0.0
	_relocate_player(_backrooms.to_global(Backrooms.ENTRY))
	_hud.notify("THE BACKROOMS   /   LEVEL 0", 4.0)


func _leave_backrooms() -> void:
	_in_backrooms = false
	_camera.environment = null
	_camera.far = SettingsManager.view_distance()
	_life.set_physics_process(true)
	player.set_camera_occluded(false)
	player.indoor_speed_limit = 0.0
	player.rotation.y = _backrooms_heading
	_heading = _backrooms_heading
	_visible_heading = _backrooms_heading
	_relocate_player(_backrooms_return)
	_hud.notify("RETURNED TO MAŽEIKIAI", 3.0)


func _close_cheats() -> void:
	if is_instance_valid(_console):
		_console.queue_free()
		_console = null
	_mode = ""
	Engine.time_scale = 1.0
	player.input_enabled = true
	car.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_character_picker() -> void:
	if _in_backrooms:
		_hud.notify("RETURN TO THE SURFACE TO SWITCH CHARACTERS")
		return
	_mode = "character_pick"
	_character_choice = selected_character
	_set_large_map(false)
	player.input_enabled = false
	car.input_enabled = false
	Engine.time_scale = 0.24
	_overlay.picker(_characters, _character_choice)
	InterfaceAudio.play_selector(true)


func _character_input(event: InputEvent) -> void:
	if event.is_action_released("character_picker"):
		var choice := _character_choice
		_close_character_picker()
		if choice != selected_character:
			_switch_character(choice)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause", false):
		_close_character_picker()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left", false) or event.is_action_pressed("ui_right", false) or (
		event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		_character_choice = (_character_choice + 1) % _characters.size()
		_overlay.picker(_characters, _character_choice)
		get_viewport().set_input_as_handled()


func _close_character_picker() -> void:
	InterfaceAudio.play_selector(false)
	_overlay.hide()
	Engine.time_scale = 1.0
	player.input_enabled = true
	car.input_enabled = true
	_mode = ""


func _switch_character(next: int) -> void:
	if next == selected_character or _vehicle_action or not _mode.is_empty():
		return
	if driving:
		_exit_vehicle()
		if driving:
			return
	var origin := player.global_position if _inside.is_empty() else _outside_at
	var current_id := str(_characters[selected_character].id)
	var next_id := str(_characters[next].id)
	_previous_spots[current_id] = {"point": SaveManager.vector_data(origin), "yaw": player.rotation.y}
	var previous: Dictionary = _previous_spots.get(next_id, {})
	var default: Vector3 = _district.point_on_ground(START, 0.065)
	if next_id == "joris":
		var entry: Vector2 = ApartmentSites.HOMES.flat_joris.entrance
		var side := Vector2(sin(ApartmentSites.HOMES.flat_joris.heading), cos(ApartmentSites.HOMES.flat_joris.heading))
		default = _district.elevation.point_at(entry + side * 4.0, 0.08)
	var landing := SaveManager.read_vector(previous.get("point"), default)
	var landing_yaw := float(previous.get("yaw", START_HEADING))
	var tint := Color("#8cb5fc") if next_id == "joris" else Color("#b9bdc2")
	_mode = "transition"
	player.input_enabled = false
	player.set_physics_process(false)
	_hud.hide()
	var origin_view := _camera.global_position
	_overlay.transition(tint, "", "", 0.12)
	var rise: Tween = _overlay.animate_grade(1.0, 1.0, 0.76)
	rise.tween_method(_crane.bind(origin_view, origin + Vector3.UP * 1.2), 0.0, 1.0, 0.76)
	await rise.finished
	if _bank_progress >= 0:
		_finish_bank_job(false)
	_fuel_stations.cancel()
	_release_carried_body(false)
	_inside = ""
	_walk_in = ""
	_camera.far = SettingsManager.view_distance()
	_life.set_physics_process(true)
	_select_character(next)
	player.global_position = landing
	player.reset_physics_interpolation()
	player.rotation.y = landing_yaw
	player.velocity = Vector3.ZERO
	_heading = landing_yaw
	_visible_heading = landing_yaw
	_aim = landing + Vector3.UP * 1.52
	_district.stream_at(landing, true)
	var view_direction := Basis(Vector3.UP, _heading) * Basis(Vector3.RIGHT, _pitch) * Vector3.BACK
	var landing_view := _aim + view_direction * 4.4
	_crane(1.0, landing_view, _aim)
	var settle: Tween = _overlay.animate_grade(0.0, 0.0, 1.02)
	settle.tween_method(_crane.bind(landing_view, _aim), 1.0, 0.0, 1.02)
	await settle.finished
	player.set_seated(false)
	player.input_enabled = true
	_overlay.hide()
	_hud.show()
	_mode = ""
	_hud.notify("PLAYING AS %s" % str(_characters[next].name).to_upper())
	_autosave()


func _crane(progress: float, base: Vector3, subject: Vector3) -> void:
	_camera_arm.collision_mask = 0
	_camera_arm.spring_length = 0.0
	_camera.position = Vector3.ZERO
	var side := (base - subject).slide(Vector3.UP).normalized().rotated(Vector3.UP, 0.47 * progress)
	_camera_rig.global_position = base.lerp(subject + Vector3.UP * 38.0 + side * 15.0, progress)
	if _camera_rig.global_position.distance_squared_to(subject) > 0.1:
		_camera_rig.look_at(subject, Vector3.UP)


func _begin_defeat(title := "YOU DIED") -> void:
	if _mode == "down":
		return
	if _flying:
		_end_flight()
	if _bank_progress >= 0:
		_finish_bank_job(false)
	_fuel_stations.cancel()
	_release_carried_body(false)
	_mode = "down"
	_set_large_map(false)
	InterfaceAudio.play_selector(false)
	player.input_enabled = false
	player.set_physics_process(false)
	player.stop_footsteps()
	car.parking_interaction = driving
	_hud.hide()
	RadioManager.set_audible(false)
	var audio := InterfaceAudio.play_defeat()
	_overlay.defeat()
	var rise: Tween = _overlay.animate_grade(0.96, 0.0, 1.4)
	rise.tween_property(_camera_rig, "rotation:z", -0.115, 1.4)
	var started := Time.get_ticks_msec()
	var duration := audio.stream.get_length() if audio.stream != null else 3.4
	var reveal_at := minf(2.0, maxf(0.0, duration - 0.28))
	var shown := false
	var closing := false
	while true:
		var elapsed := float(Time.get_ticks_msec() - started) * 0.001
		var playhead := audio.get_playback_position() if audio.playing else elapsed
		if not shown and playhead >= reveal_at:
			shown = true
			_overlay.reveal_defeat(title, maxf(0.24, duration - reveal_at))
		if not closing and playhead >= duration - 0.38:
			closing = true
			_overlay.fade_defeat_to_black(0.38)
		if not audio.playing and elapsed >= (reveal_at if audio.stream != null else duration):
			break
		await get_tree().process_frame
	_overlay.clear_defeat_fog()
	if driving:
		car.parking_interaction = false
		car.set_driver(false, false)
		driving = false
	_in_cockpit = false
	_inside = ""
	_walk_in = ""
	_in_backrooms = false
	_camera.environment = null
	_camera.far = SettingsManager.view_distance()
	_life.set_physics_process(true)
	player.set_camera_occluded(false)
	_wanted.restore(0)
	_life.wanted = 0
	player.set_seated(false)
	player.input_enabled = false
	_heading = START_HEADING
	_visible_heading = START_HEADING
	_passenger_driver = 0
	_passenger_exit_requested = false
	SessionManager.seat_request(0)
	_camera_rig.rotation = Vector3.ZERO
	player.global_basis = Basis(Vector3.UP, START_HEADING)
	player.up_direction = Vector3.UP
	_district.stream_at(START, true)
	_relocate_player(_district.point_on_ground(START, 0.12))
	_camera_rig.reset_physics_interpolation()
	health = 100.0
	_altered_remaining = 0.0
	player.energy_remaining = 0.0
	player.stamina = 100.0
	await _overlay.animate_grade(0.0, 0.0, 0.46).finished
	_overlay.hide()
	_hud.show()
	player.input_enabled = true
	_mode = ""
	_hud.notify("RECOVERED AT ŽEMAITIJOS g.")
	_autosave()
