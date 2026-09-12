extends Area2D

## Enemy.gd - Comprehensive Bestiary with 16 Distinct Enemy Archetypes & Elite Affixes.
## Supports Directional Shield Knights, Phantoms, Drone Carriers, Snipers, Shield Frigates, and more.

enum EnemyType {
	SCOUT,
	BOMBER,
	INTERCEPTOR,
	SNIPER,
	SHIELD_FRIGATE,
	HEAVY_CRUISER,
	KNIGHT_VANGUARD,
	PHANTOM,
	DRONE_CARRIER,
	MICRO_DRONE,
	TURRET_PLATFORM,
	WARP_STALKER,
	DRAINER_LEECH,
	MISSILE_CORVETTE,
	MINE_TETHER,
	ORBITAL_REFLECTOR,
	CARGO_HAULER
}

enum EliteAffix { NONE, ARMORED, VOLATILE, SWIFT, SHIELDED }

const ProgressionModel = preload("res://scripts/ProgressionModel.gd")

enum FlightProfile {
	DIRECT_ADVANCE,   # 0: DISCIPLINED_LINE (Clean parallel firing wall)
	DEEP_SWOOP,       # 1: ARROW_WEDGE (Arrowhead banking inward)
	S_WEAVE_SLALOM,   # 2: SERPENTINE_STREAM (Sinusoidal wave slalom)
	DIAGONAL_STRAFER, # 3: PINCER_CONVERGE (Converging from upper/lower horizon toward center)
	CENTER_STREAM,    # 4: Linear rush down the center flight corridor
	FORWARD_ANCHOR    # 5: Heavy artillery siege station
}

# Canonical 2-Layer Formation Rail Aliases
const DISCIPLINED_LINE = FlightProfile.DIRECT_ADVANCE
const ARROW_WEDGE = FlightProfile.DEEP_SWOOP
const SERPENTINE_STREAM = FlightProfile.S_WEAVE_SLALOM
const PINCER_CONVERGE = FlightProfile.DIAGONAL_STRAFER

@export var enemy_type: EnemyType = EnemyType.SCOUT
@export var elite_affix: EliteAffix = EliteAffix.NONE
@export var flight_profile: FlightProfile = FlightProfile.DIRECT_ADVANCE

@export var max_health: float = 2.0
var health: float = 2.0

var speed: float = 260.0
var score_value: int = 100

# Formation / Squad tracking
var squad_id: int = -1
var spawner_ref: Node = null
var is_dying: bool = false

# Dynamic Progression Economy Drops
var drop_guaranteed: int = 1
var drop_chance: float = 0.0

# Flight behavior & Kinematic Profiles
var move_direction: Vector2 = Vector2.LEFT
var lateral_frequency: float = 2.8
var lateral_amplitude: float = 85.0
var flight_time: float = 0.0
var spawn_pos: Vector2 = Vector2.ZERO
var swoop_dir: float = 1.0
var strafe_sign: float = 1.0
var weave_sign: float = 1.0
var has_completed_cross: bool = false
var anchor_dist_target: float = 220.0
var anchor_time: float = 0.0
var anchor_max_time: float = 5.0
var is_anchored: bool = false
var juke_dir: Vector2 = Vector2.ZERO
var juke_timer: float = 0.0

# Weaponry
var fire_timer: float = 1.2
var fire_interval: float = 2.0

# Special class state
var is_shield_protected: bool = false # Buffed by nearby Shield Frigate
var shield_aura_radius: float = 140.0
var energy_shield_hp: float = 0.0 # From SHIELDED affix

# Class-specific states
var sniper_aim_timer: float = 0.0
var is_sniper_aiming: bool = false
var phantom_is_cloaked: bool = false
var phantom_timer: float = 0.0
var carrier_spawn_timer: float = 0.0
var warp_timer: float = 0.0
var is_charging: bool = false
var charge_vector: Vector2 = Vector2.ZERO

# Knight Vanguard mirror shield state
var knight_shield_max_hp: float = 8.0
var knight_shield_hp: float = 8.0
var knight_shield_cycle_timer: float = 2.4
var knight_shield_is_venting: bool = false
var knight_shield_shattered: bool = false
var knight_is_firing_salvo: bool = false

# Behavioral Mutation Traits (Procedural Variety)
var has_evasive_juke: bool = false
var juke_cooldown: float = 0.0
var has_desperation_charge: bool = false
var is_desperation_ramming: bool = false
var has_orbital_flight: bool = false
var orbital_direction: float = 1.0
var orbital_radius: float = 240.0
var has_aimed_lead: bool = false
var has_burst_spread: bool = false

# Visuals & Juice
var hit_flash_timer: float = 0.0
var main_color: Color = Color(1.0, 0.2, 0.4, 1.0)
var accent_color: Color = Color(1.0, 0.6, 0.1, 1.0)
var turret_angle: float = 0.0

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")
var crate_scene: PackedScene = preload("res://scenes/ItemCrate.tscn")

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 3
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_setup_stats()

func _setup_stats(profile_was_preset: bool = false) -> void:
	# Sector and wave scaling multipliers
	var sec = GameManager.current_sector if GameManager != null else 1
	var wave = GameManager.current_wave if GameManager != null else 1
	var hp_mult = ProgressionModel.get_enemy_hp_multiplier(sec, wave)
	var sec_spd_mult = 1.0 + (sec - 1) * 0.10 + (wave - 1) * 0.005
	var sec_fire_mult = 1.0 + (sec - 1) * 0.20 + (wave - 1) * 0.02

	match enemy_type:
		EnemyType.SCOUT:
			max_health = 2.0 * hp_mult
			speed = 260.0 * sec_spd_mult
			score_value = 100
			main_color = Color(1.0, 0.25, 0.45, 1.0)
			accent_color = Color(1.0, 0.7, 0.2, 1.0)
			fire_interval = 2.4 / sec_fire_mult
			fire_timer = randf_range(0.8, 1.6)
		EnemyType.BOMBER:
			max_health = 8.0 * hp_mult
			speed = 135.0 * sec_spd_mult
			score_value = 250
			main_color = Color(0.95, 0.15, 0.85, 1.0)
			accent_color = Color(0.3, 0.9, 1.0, 1.0)
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.INTERCEPTOR:
			max_health = 3.5 * hp_mult
			speed = 280.0 * sec_spd_mult
			score_value = 150
			main_color = Color(1.0, 0.5, 0.1, 1.0)
			accent_color = Color(1.0, 0.9, 0.2, 1.0)
			fire_interval = 2.5 / sec_fire_mult
			fire_timer = 1.2
		EnemyType.SNIPER:
			max_health = 8.0 * hp_mult
			speed = 110.0 * sec_spd_mult
			score_value = 300
			main_color = Color(1.0, 0.85, 0.2, 1.0)
			accent_color = Color(1.0, 0.2, 0.2, 1.0)
			fire_interval = 2.8 / sec_fire_mult
			fire_timer = 1.5
		EnemyType.SHIELD_FRIGATE:
			max_health = 18.0 * hp_mult
			speed = 115.0 * sec_spd_mult
			score_value = 400
			main_color = Color(0.1, 0.8, 1.0, 1.0)
			accent_color = Color(0.3, 1.0, 0.9, 1.0)
			fire_interval = 2.5 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.HEAVY_CRUISER:
			max_health = 38.0 * hp_mult
			speed = 85.0 * sec_spd_mult
			score_value = 750
			main_color = Color(0.7, 0.2, 0.9, 1.0)
			accent_color = Color(1.0, 0.3, 0.5, 1.0)
			fire_interval = 1.8 / sec_fire_mult
			fire_timer = 0.8
		EnemyType.KNIGHT_VANGUARD:
			max_health = 16.0 * hp_mult
			speed = 125.0 * sec_spd_mult
			score_value = 350
			main_color = Color(0.4, 0.8, 0.9, 1.0)
			accent_color = Color(0.9, 0.9, 1.0, 1.0)
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 1.0
			knight_shield_max_hp = 8.0 * (1.35 if elite_affix == EliteAffix.ARMORED else 1.0)
			knight_shield_hp = knight_shield_max_hp
			knight_shield_cycle_timer = randf_range(2.0, 2.6)
			knight_shield_is_venting = false
			knight_shield_shattered = false
			knight_is_firing_salvo = false
		EnemyType.PHANTOM:
			max_health = 7.0 * hp_mult
			speed = 175.0 * sec_spd_mult
			score_value = 320
			main_color = Color(0.5, 0.2, 0.8, 0.8)
			accent_color = Color(0.8, 0.4, 1.0, 1.0)
			fire_interval = 2.0 / sec_fire_mult
			fire_timer = 1.0
			phantom_timer = 2.0
		EnemyType.DRONE_CARRIER:
			max_health = 28.0 * hp_mult
			speed = 75.0 * sec_spd_mult
			score_value = 600
			main_color = Color(0.9, 0.6, 0.1, 1.0)
			accent_color = Color(1.0, 0.8, 0.3, 1.0)
			carrier_spawn_timer = 2.4
			fire_interval = 3.2
			fire_timer = 2.0
		EnemyType.MICRO_DRONE:
			max_health = 1.0 * hp_mult
			speed = 270.0 * sec_spd_mult
			score_value = 40
			main_color = Color(1.0, 0.9, 0.3, 1.0)
			accent_color = Color(1.0, 0.4, 0.1, 1.0)
			fire_interval = 999.0
			fire_timer = 999.0
		EnemyType.TURRET_PLATFORM:
			max_health = 16.0 * hp_mult
			speed = 20.0
			score_value = 450
			main_color = Color(0.3, 0.7, 0.5, 1.0)
			accent_color = Color(0.2, 1.0, 0.6, 1.0)
			fire_interval = 1.6 / sec_fire_mult
			fire_timer = 0.8
		EnemyType.WARP_STALKER:
			max_health = 12.0 * hp_mult
			speed = 110.0
			score_value = 380
			main_color = Color(0.2, 0.4, 1.0, 1.0)
			accent_color = Color(0.6, 0.8, 1.0, 1.0)
			warp_timer = 3.0
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 1.2
		EnemyType.DRAINER_LEECH:
			max_health = 12.0 * hp_mult
			speed = 110.0 * sec_spd_mult
			score_value = 340
			main_color = Color(0.8, 0.1, 0.3, 1.0)
			accent_color = Color(1.0, 0.4, 0.6, 1.0)
			fire_interval = 2.4
			fire_timer = 1.2
		EnemyType.MISSILE_CORVETTE:
			max_health = 18.0 * hp_mult
			speed = 85.0 * sec_spd_mult
			score_value = 480
			main_color = Color(0.2, 0.8, 0.4, 1.0)
			accent_color = Color(0.8, 1.0, 0.3, 1.0)
			fire_interval = 2.5 / sec_fire_mult
			fire_timer = 1.2
		EnemyType.MINE_TETHER:
			max_health = 10.0 * hp_mult
			speed = 35.0
			score_value = 200
			main_color = Color(1.0, 0.3, 0.7, 1.0)
			accent_color = Color(1.0, 0.8, 0.9, 1.0)
			fire_interval = 2.5 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.ORBITAL_REFLECTOR:
			max_health = 16.0 * hp_mult
			speed = 130.0
			score_value = 220
			main_color = Color(0.6, 0.8, 1.0, 1.0)
			accent_color = Color(1.0, 1.0, 1.0, 1.0)
			fire_interval = 999.0
			fire_timer = 999.0
		EnemyType.CARGO_HAULER:
			max_health = 10.0 * hp_mult
			speed = 100.0 * sec_spd_mult
			score_value = 600
			main_color = Color(1.0, 0.8, 0.2, 1.0)
			accent_color = Color(0.2, 1.0, 0.9, 1.0)
			fire_interval = 3.0 / sec_fire_mult
			fire_timer = 1.5

	# Apply Elite Affix modifiers
	match elite_affix:
		EliteAffix.ARMORED:
			var armor_mult = 1.45 if sec == 1 else 1.85
			max_health *= armor_mult
			speed *= 0.85
			score_value *= 3
			main_color = Color(1.0, 0.85, 0.2, 1.0)
			accent_color = Color(1.0, 0.95, 0.5, 1.0)
		EliteAffix.VOLATILE:
			max_health *= 1.3
			score_value *= 2
			main_color = Color(1.0, 0.35, 0.05, 1.0)
			accent_color = Color(1.0, 0.8, 0.1, 1.0)
		EliteAffix.SWIFT:
			max_health *= 1.1
			speed *= 1.5
			score_value *= 2
			main_color = Color(0.2, 1.0, 0.7, 1.0)
			accent_color = Color(0.7, 1.0, 0.9, 1.0)
		EliteAffix.SHIELDED:
			max_health *= 1.2
			energy_shield_hp = max_health * 0.5

	# Procedural Behavioral Mutation Traits & Flight Profile Assignment
	lateral_frequency = randf_range(2.0, 3.4)
	lateral_amplitude = randf_range(50.0, 95.0)
	has_evasive_juke = (randf() < 0.28 and enemy_type in [EnemyType.SCOUT, EnemyType.INTERCEPTOR])
	has_orbital_flight = false
	has_desperation_charge = (randf() < 0.35 and enemy_type in [EnemyType.SCOUT, EnemyType.INTERCEPTOR])
	has_aimed_lead = false
	has_burst_spread = false

	# Dynamic Flight Profile assignment only if not explicitly preset by wave/spawner
	if not profile_was_preset:
		match enemy_type:
			EnemyType.BOMBER, EnemyType.HEAVY_CRUISER, EnemyType.TURRET_PLATFORM, EnemyType.SHIELD_FRIGATE, EnemyType.MINE_TETHER:
				flight_profile = FlightProfile.FORWARD_ANCHOR
			_:
				flight_profile = FlightProfile.DIRECT_ADVANCE

	_initialize_inward_direction()

	if sec > 1 or wave >= 4:
		var trait_chance = 0.22 if wave == 4 else (0.38 + (sec - 1) * 0.12)
		if randf() < trait_chance:
			has_aimed_lead = true
		if randf() < (trait_chance * 0.55) and enemy_type in [EnemyType.SCOUT, EnemyType.BOMBER, EnemyType.MISSILE_CORVETTE]:
			has_burst_spread = true

	if elite_affix in [EliteAffix.SWIFT, EliteAffix.ARMORED] and (sec > 1 or wave >= 4):
		has_aimed_lead = true

	health = max_health

func setup(p_type: EnemyType, p_pos: Vector2, p_squad_id: int, p_spawner: Node, p_affix: EliteAffix = EliteAffix.NONE, p_profile: int = -1, p_drop_profile: Dictionary = {}) -> void:
	enemy_type = p_type
	elite_affix = p_affix
	global_position = p_pos
	spawn_pos = p_pos
	squad_id = p_squad_id
	spawner_ref = p_spawner
	if p_profile >= 0:
		flight_profile = p_profile as FlightProfile
	
	if not p_drop_profile.is_empty():
		drop_guaranteed = p_drop_profile.get("guaranteed", 1)
		drop_chance = p_drop_profile.get("chance", 0.0)
	else:
		var def_prof = ProgressionModel.get_default_drop_profile(p_type)
		drop_guaranteed = def_prof.get("guaranteed", 1)
		drop_chance = def_prof.get("chance", 0.0)

	_setup_stats(p_profile >= 0)
	_initialize_inward_direction()
	if elite_affix != EliteAffix.NONE:
		scale = Vector2(1.22, 1.22)
	queue_redraw()

func _physics_process(delta: float) -> void:
	flight_time += delta

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		queue_redraw()

	if juke_cooldown > 0.0:
		juke_cooldown -= delta

	_check_shield_frigate_buffs()
	_handle_flight_movement(delta)
	_handle_combat_abilities(delta)

	# Boundary check / Despawn when escaping past the player through the rear horizon
	var vp = get_viewport_rect().size
	if GameAxis != null and GameAxis.is_vertical:
		if global_position.y > vp.y + 100 or global_position.y < -200 or global_position.x < -160 or global_position.x > vp.x + 160:
			_escape_squad()
	else:
		if global_position.x < -100 or global_position.x > vp.x + 200 or global_position.y < -160 or global_position.y > vp.y + 160:
			_escape_squad()

func _check_shield_frigate_buffs() -> void:
	if enemy_type == EnemyType.SHIELD_FRIGATE:
		is_shield_protected = false
		return

	is_shield_protected = false
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e != self and e.get("enemy_type") == EnemyType.SHIELD_FRIGATE:
			var aura = e.get("shield_aura_radius")
			if aura != null and global_position.distance_to(e.global_position) <= aura:
				is_shield_protected = true
				break

func _initialize_inward_direction() -> void:
	var vp_rect = GameAxis.get_viewport_rect() if GameAxis != null else Rect2(0, 0, 1280, 720)
	var is_vert = GameAxis.is_vertical if GameAxis != null else false
	var center_lat = (vp_rect.position.x + vp_rect.size.x * 0.5) if is_vert else (vp_rect.position.y + vp_rect.size.y * 0.5)
	var cur_lat = spawn_pos.x if is_vert else spawn_pos.y
	if spawn_pos == Vector2.ZERO:
		cur_lat = global_position.x if is_vert else global_position.y

	if cur_lat < center_lat:
		strafe_sign = 1.0   # Upper/Left half -> steer inward toward center (+lat)
		swoop_dir = 1.0     # Swoop downward/rightward toward center
		weave_sign = 1.0
	else:
		strafe_sign = -1.0  # Lower/Right half -> steer inward toward center (-lat)
		swoop_dir = -1.0    # Swoop upward/leftward toward center
		weave_sign = -1.0

func _enforce_lateral_bounds() -> void:
	var rect = GameAxis.get_viewport_rect() if GameAxis != null else Rect2(0, 0, 1280, 720)
	var margin = 38.0

	if GameAxis != null and GameAxis.is_vertical:
		var min_x = rect.position.x + margin
		var max_x = rect.position.x + rect.size.x - margin
		if global_position.x < min_x:
			global_position.x = min_x
			if flight_profile == FlightProfile.DIAGONAL_STRAFER:
				has_completed_cross = true
			if is_charging or is_desperation_ramming:
				charge_vector.x = absf(charge_vector.x)
				rotation = charge_vector.angle()
		elif global_position.x > max_x:
			global_position.x = max_x
			if flight_profile == FlightProfile.DIAGONAL_STRAFER:
				has_completed_cross = true
			if is_charging or is_desperation_ramming:
				charge_vector.x = -absf(charge_vector.x)
				rotation = charge_vector.angle()
	else:
		var min_y = rect.position.y + margin
		var max_y = rect.position.y + rect.size.y - margin
		if global_position.y < min_y:
			global_position.y = min_y
			if flight_profile == FlightProfile.DIAGONAL_STRAFER:
				has_completed_cross = true
			if is_charging or is_desperation_ramming:
				charge_vector.y = absf(charge_vector.y)
				rotation = charge_vector.angle()
		elif global_position.y > max_y:
			global_position.y = max_y
			if flight_profile == FlightProfile.DIAGONAL_STRAFER:
				has_completed_cross = true
			if is_charging or is_desperation_ramming:
				charge_vector.y = -absf(charge_vector.y)
				rotation = charge_vector.angle()

func _handle_flight_movement(delta: float) -> void:
	var oncoming = -GameAxis.forward
	var lat = GameAxis.lateral
	var base_angle = oncoming.angle()

	# 0. Reactive Evasive Juke handling
	if juke_timer > 0.0:
		juke_timer -= delta
		global_position += juke_dir * speed * 2.0 * delta
		_enforce_lateral_bounds()
		return

	# 1. Desperation Kamikaze Charge on Low Health
	if has_desperation_charge and health <= max_health * 0.35:
		if not is_desperation_ramming:
			var target = _get_closest_player()
			if target != null:
				var to_player = (target.global_position - global_position).normalized()
				if to_player.dot(oncoming) > 0.15:
					charge_vector = (oncoming * 0.75 + to_player * 0.65).normalized()
				else:
					charge_vector = oncoming
			else:
				charge_vector = oncoming
			is_desperation_ramming = true
			SoundEffects.play_sfx("laser", 0.15, -2.0)

		global_position += charge_vector * speed * 1.8 * delta
		rotation = charge_vector.angle()
		_enforce_lateral_bounds()
		return

	# 2. Bespoke Phase Mechanics for specialized archetypes
	if enemy_type == EnemyType.PHANTOM:
		phantom_timer -= delta
		if phantom_timer <= 0.0:
			phantom_is_cloaked = not phantom_is_cloaked
			phantom_timer = 2.4 if phantom_is_cloaked else 3.2
			if not phantom_is_cloaked:
				var target = _get_closest_player()
				if target != null:
					global_position = target.global_position + (oncoming * randf_range(200.0, 320.0)) + (lat * randf_range(-140.0, 140.0))
		global_position += oncoming * speed * (1.2 if phantom_is_cloaked else 0.8) * delta
		rotation = base_angle
		_enforce_lateral_bounds()
		return

	elif enemy_type == EnemyType.WARP_STALKER:
		warp_timer -= delta
		if warp_timer <= 0.0:
			warp_timer = 3.2
			var vp = get_viewport_rect().size
			if GameAxis.is_vertical:
				global_position = Vector2(randf_range(80, vp.x - 80), randf_range(60, vp.y * 0.32))
			else:
				global_position = Vector2(randf_range(vp.x * 0.68, vp.x - 60), randf_range(80, vp.y - 80))
			_fire_radial_burst(4, 280.0)
		global_position += oncoming * speed * delta * 0.35
		rotation = base_angle
		_enforce_lateral_bounds()
		return

	# 3. LAYER 2: Heavy Siege Stations (Bomber, Frigate, Heavy Cruiser, Turret Platform, Mine Tether)
	var is_heavy_station = (enemy_type in [EnemyType.BOMBER, EnemyType.HEAVY_CRUISER, EnemyType.SHIELD_FRIGATE, EnemyType.TURRET_PLATFORM, EnemyType.MINE_TETHER])
	if is_heavy_station or flight_profile == FlightProfile.FORWARD_ANCHOR:
		var dist = spawn_pos.distance_to(global_position)
		if not is_anchored and dist < anchor_dist_target:
			global_position += oncoming * speed * delta
			rotation = base_angle
			_enforce_lateral_bounds()
			return
		elif not is_anchored and dist >= anchor_dist_target:
			is_anchored = true
			anchor_time = 0.0
		elif is_anchored:
			anchor_time += delta
			global_position += lat * sin(flight_time * 1.5) * 22.0 * delta
			rotation = base_angle
			if enemy_type == EnemyType.TURRET_PLATFORM:
				var target = _get_closest_player()
				if target != null:
					turret_angle = (target.global_position - global_position).angle()
			if anchor_time >= anchor_max_time:
				is_anchored = false
				anchor_dist_target = 99999.0
			_enforce_lateral_bounds()
			return

	# 4. LAYER 2: Backline Sentries (Sniper)
	if enemy_type == EnemyType.SNIPER:
		var vp = get_viewport_rect().size
		var in_station = (global_position.y >= vp.y * 0.22) if GameAxis.is_vertical else (global_position.x <= vp.x * 0.78)
		if not in_station:
			global_position += oncoming * speed * delta
		rotation = base_angle
		_enforce_lateral_bounds()
		return

	# 5. LAYER 2: Breakout Dive-Bombers (Interceptor)
	if enemy_type == EnemyType.INTERCEPTOR:
		if flight_time < 0.9:
			# Initial formation entry along rail
			pass
		elif flight_time < 2.2:
			# Screeching dive-bomb into player lane!
			if not is_charging:
				var target = _get_closest_player()
				if target != null:
					var to_p = (target.global_position - global_position).normalized()
					charge_vector = (oncoming * 0.78 + to_p * 0.48).normalized()
				else:
					charge_vector = (oncoming * 0.85 + lat * strafe_sign * 0.35).normalized()
				is_charging = true
				fire_timer = minf(fire_timer, 0.15)
				SoundEffects.play_sfx("laser", 0.08, -1.0)
			var dive_vel = charge_vector * speed * 1.45 * delta
			global_position += dive_vel
			rotation = charge_vector.angle()
			_enforce_lateral_bounds()
			return
		else:
			# Breakout completed -> bank forward downfield along player corridor
			var peel_lat = strafe_sign * 0.25
			var peel_vel = (oncoming * 1.15 + lat * peel_lat).normalized() * speed * 1.25 * delta
			global_position += peel_vel
			rotation = base_angle
			_enforce_lateral_bounds()
			return

	# 6. LAYER 1: Formation Macro-Rails (Scouts, Drones, and other followers)
	var vel: Vector2 = Vector2.ZERO
	match flight_profile:
		FlightProfile.DEEP_SWOOP: # ARROW_WEDGE
			var bank = lat * swoop_dir * sin(flight_time * 1.6) * speed * 0.32
			vel = oncoming * speed * 1.05 + bank

		FlightProfile.S_WEAVE_SLALOM: # SERPENTINE_STREAM
			var wave_lateral = lat * weave_sign * cos(flight_time * lateral_frequency) * lateral_amplitude * 0.75
			vel = oncoming * speed * 1.05 + wave_lateral

		FlightProfile.DIAGONAL_STRAFER: # PINCER_CONVERGE
			if not has_completed_cross:
				var vp_rect = GameAxis.get_viewport_rect() if GameAxis != null else Rect2(0, 0, 1280, 720)
				var center_lat = (vp_rect.position.x + vp_rect.size.x * 0.5) if (GameAxis != null and GameAxis.is_vertical) else (vp_rect.position.y + vp_rect.size.y * 0.5)
				var cur_lat = global_position.x if (GameAxis != null and GameAxis.is_vertical) else global_position.y
				if absf(cur_lat - center_lat) < 60.0 or flight_time > 1.8:
					has_completed_cross = true
				vel = (oncoming * 0.90 + lat * strafe_sign * 0.42).normalized() * speed * 1.15
			else:
				vel = oncoming * speed * 1.10

		FlightProfile.CENTER_STREAM:
			vel = oncoming * speed * 1.15

		_: # DIRECT_ADVANCE (DISCIPLINED_LINE) and fallback
			vel = oncoming * speed

	# Archetype modifier for Drainer Leech (lateral homing slip)
	if enemy_type == EnemyType.DRAINER_LEECH:
		var target = _get_closest_player()
		if target != null and global_position.distance_to(target.global_position) < 380.0:
			var to_target = target.global_position - global_position
			var lat_sign = 1.0 if to_target.dot(lat) > 0 else -1.0
			vel += lat * lat_sign * speed * 0.35

	global_position += vel * delta
	rotation = vel.angle() if absf(vel.dot(oncoming)) < vel.length() * 0.98 else base_angle
	_enforce_lateral_bounds()

func _handle_combat_abilities(delta: float) -> void:
	# Carrier drone spawning
	if enemy_type == EnemyType.DRONE_CARRIER:
		carrier_spawn_timer -= delta
		if carrier_spawn_timer <= 0.0:
			carrier_spawn_timer = 3.5
			_launch_drone_swarm(3)

	# Knight Vanguard shield cycling & attack telegraphing
	if enemy_type == EnemyType.KNIGHT_VANGUARD and not knight_shield_shattered:
		knight_shield_cycle_timer -= delta
		if knight_shield_is_venting:
			if knight_shield_cycle_timer <= 0.0:
				knight_shield_is_venting = false
				knight_shield_cycle_timer = 2.4
				queue_redraw()
		else:
			if knight_shield_cycle_timer <= 0.0:
				knight_shield_is_venting = true
				knight_shield_cycle_timer = 1.3
				queue_redraw()
		
		# Pre-attack telegraph: unmask cannons 0.35s before firing
		if fire_timer <= 0.35 and not knight_is_firing_salvo:
			knight_is_firing_salvo = true
			queue_redraw()

	# Sniper aim telegraphing
	if enemy_type == EnemyType.SNIPER:
		sniper_aim_timer += delta
		if sniper_aim_timer >= fire_interval - 1.2 and sniper_aim_timer < fire_interval:
			is_sniper_aiming = true
			queue_redraw()
		elif sniper_aim_timer >= fire_interval:
			is_sniper_aiming = false
			sniper_aim_timer = 0.0
			_fire_sniper_beam()
			queue_redraw()
		return

	# Standard firing cycle
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_interval
		_execute_attack()

func calculate_lead_target_vector(origin: Vector2, target: Node2D, proj_speed: float, max_lead_time: float = 1.0) -> Vector2:
	if target == null or not is_instance_valid(target):
		return -GameAxis.forward
	
	var oncoming = -GameAxis.forward
	var p_pos = target.global_position
	var p_vel = Vector2.ZERO
	if target.get("current_velocity") != null:
		p_vel = target.current_velocity
	
	var d = p_pos - origin
	if p_vel.length_squared() < 25.0:
		var direct = d.normalized()
		return direct if direct.dot(oncoming) > 0.05 else oncoming
	
	var sec_num = GameManager.current_sector if GameManager != null else 1
	var wave_num = GameManager.current_wave if GameManager != null else 1
	# Smooth early lead scaling: Sector 1 introduces moderate lead; Sector 2 delivers full lead
	var lead_factor = 1.0 if sec_num > 1 else clampf(0.45 + (wave_num - 3) * 0.15, 0.45, 0.85)
	var effective_vel = p_vel * lead_factor
	
	# Quadratic intercept: || d + effective_vel * t ||^2 = (proj_speed * t)^2
	# a * t^2 + b * t + c = 0
	var a = effective_vel.length_squared() - proj_speed * proj_speed
	var b = 2.0 * d.dot(effective_vel)
	var c = d.length_squared()
	var disc = b * b - 4.0 * a * c
	
	var t = -1.0
	if disc >= 0.0 and absf(a) > 0.001:
		var sqrt_disc = sqrt(disc)
		var t1 = (-b - sqrt_disc) / (2.0 * a)
		var t2 = (-b + sqrt_disc) / (2.0 * a)
		if t1 > 0.0 and t2 > 0.0:
			t = minf(t1, t2)
		elif t1 > 0.0:
			t = t1
		elif t2 > 0.0:
			t = t2
	
	if t > 0.0:
		t = minf(t, max_lead_time)
		var predicted = p_pos + effective_vel * t
		var lead_dir = (predicted - origin).normalized()
		if lead_dir.dot(oncoming) > 0.05:
			return lead_dir
	
	# First-order fallback if quadratic has no valid forward root
	var fallback_t = minf(d.length() / maxf(100.0, proj_speed), max_lead_time)
	var fallback_pred = p_pos + effective_vel * fallback_t * 0.75
	var fallback_dir = (fallback_pred - origin).normalized()
	if fallback_dir.dot(oncoming) > 0.05:
		return fallback_dir
	
	var default_dir = d.normalized()
	return default_dir if default_dir.dot(oncoming) > 0.05 else oncoming

func _get_aim_vector(target: Node2D, fallback: Vector2) -> Vector2:
	if target == null or not is_instance_valid(target):
		return fallback
	var d = (target.global_position - global_position).normalized()
	return d if d.dot(-GameAxis.forward) > 0.05 else fallback

func _execute_attack() -> void:
	if phantom_is_cloaked or enemy_type == EnemyType.MICRO_DRONE or enemy_type == EnemyType.SNIPER:
		return

	var oncoming = -GameAxis.forward
	var lat = GameAxis.lateral
	var sec_num = GameManager.current_sector if GameManager != null else 1
	var wave_num = GameManager.current_wave if GameManager != null else 1
	var base_bullet_spd = 320.0 * (1.0 + (wave_num - 1) * 0.025 + (sec_num - 1) * 0.20)

	# Procedural Attack Trait: Burst Spread (gated to wave 4+)
	if has_burst_spread and enemy_type in [EnemyType.SCOUT, EnemyType.BOMBER, EnemyType.MISSILE_CORVETTE]:
		var target = _get_closest_player()
		var center_d = calculate_lead_target_vector(global_position, target, base_bullet_spd) if (has_aimed_lead and target != null) else _get_aim_vector(target, oncoming)
		for a in [-14.0, 0.0, 14.0]:
			var d = center_d.rotated(deg_to_rad(a))
			_spawn_enemy_bullet(global_position + d * 18.0, d, 1.0, base_bullet_spd)
		return

	match enemy_type:
		EnemyType.SCOUT:
			var target = _get_closest_player()
			var shot_dir = calculate_lead_target_vector(global_position, target, base_bullet_spd) if (has_aimed_lead and target != null) else _get_aim_vector(target, oncoming)
			_spawn_enemy_bullet(global_position + shot_dir * 14.0, shot_dir, 1.0, base_bullet_spd)
			get_tree().create_timer(0.12).timeout.connect(func():
				if is_instance_valid(self) and not is_queued_for_deletion():
					var t2 = _get_closest_player()
					var dir2 = calculate_lead_target_vector(global_position, t2, base_bullet_spd) if (has_aimed_lead and t2 != null) else _get_aim_vector(t2, oncoming)
					_spawn_enemy_bullet(global_position + dir2 * 14.0, dir2, 1.0, base_bullet_spd)
			)
		EnemyType.INTERCEPTOR:
			var target = _get_closest_player()
			var int_spd = base_bullet_spd * 1.15
			var shot_dir = calculate_lead_target_vector(global_position, target, int_spd) if (has_aimed_lead or (wave_num >= 5 and elite_affix != EliteAffix.NONE)) else _get_aim_vector(target, oncoming)
			var burst_count = 3 if (wave_num >= 4 or sec_num > 1) else 2
			for i in range(burst_count):
				get_tree().create_timer(i * 0.09).timeout.connect(func():
					if is_instance_valid(self) and not is_queued_for_deletion():
						var t_cur = _get_closest_player()
						var d_cur = calculate_lead_target_vector(global_position, t_cur, int_spd) if (has_aimed_lead or (wave_num >= 5 and elite_affix != EliteAffix.NONE)) else _get_aim_vector(t_cur, oncoming)
						_spawn_enemy_bullet(global_position + d_cur * 16.0, d_cur, 1.0, int_spd)
				)
		EnemyType.BOMBER:
			var target = _get_closest_player()
			var b_spd = base_bullet_spd * 0.95
			var center_dir = calculate_lead_target_vector(global_position, target, b_spd) if (has_aimed_lead and target != null) else _get_aim_vector(target, oncoming)
			var angles = [-15.0, 0.0, 15.0]
			if wave_num >= 5 or sec_num > 1:
				angles = [-24.0, -12.0, 0.0, 12.0, 24.0]
			for a in angles:
				var d = center_dir.rotated(deg_to_rad(a))
				_spawn_enemy_bullet(global_position + d * 20.0, d, 1.0, b_spd)
		EnemyType.HEAVY_CRUISER:
			var target = _get_closest_player()
			var c_spd = base_bullet_spd * 1.05
			var center_dir = _get_aim_vector(target, oncoming)
			for a in [-24.0, -12.0, 0.0, 12.0, 24.0]:
				var d = center_dir.rotated(deg_to_rad(a))
				_spawn_enemy_bullet(global_position + d * 22.0, d, 1.0, c_spd)
		EnemyType.KNIGHT_VANGUARD:
			knight_is_firing_salvo = true
			queue_redraw()
			var target = _get_closest_player()
			var kv_spd = base_bullet_spd * 1.05
			var kv_dir = calculate_lead_target_vector(global_position, target, kv_spd) if (has_aimed_lead and target != null) else _get_aim_vector(target, oncoming)
			_spawn_enemy_bullet(global_position + kv_dir * 18.0, kv_dir, 1.0, kv_spd)
			get_tree().create_timer(0.14).timeout.connect(func():
				if is_instance_valid(self) and not is_queued_for_deletion():
					var t2 = _get_closest_player()
					var d2 = calculate_lead_target_vector(global_position, t2, kv_spd) if (has_aimed_lead and t2 != null) else _get_aim_vector(t2, oncoming)
					_spawn_enemy_bullet(global_position + d2 * 18.0, d2, 1.0, kv_spd)
			)
			get_tree().create_timer(0.55).timeout.connect(func():
				if is_instance_valid(self) and not is_queued_for_deletion():
					knight_is_firing_salvo = false
					queue_redraw()
			)
		EnemyType.SHIELD_FRIGATE:
			_fire_radial_burst(6, base_bullet_spd * 0.85)
		EnemyType.TURRET_PLATFORM:
			for i in range(4):
				get_tree().create_timer(i * 0.09).timeout.connect(func():
					if is_instance_valid(self) and not is_queued_for_deletion():
						var t_cur = _get_closest_player()
						if t_cur != null:
							turret_angle = (t_cur.global_position - global_position).angle()
						var d = Vector2.RIGHT.rotated(turret_angle)
						_spawn_enemy_bullet(global_position + d * 18.0, d, 1.0, base_bullet_spd * 1.08)
				)
		EnemyType.MISSILE_CORVETTE:
			var target = _get_closest_player()
			var aim_base = _get_aim_vector(target, oncoming)
			_spawn_enemy_bullet(global_position - lat * 14.0, aim_base.rotated(-0.16), 1.0, base_bullet_spd * 0.95)
			_spawn_enemy_bullet(global_position + lat * 14.0, aim_base.rotated(0.16), 1.0, base_bullet_spd * 0.95)
		EnemyType.DRAINER_LEECH:
			var target = _get_closest_player()
			var l_dir = _get_aim_vector(target, oncoming)
			_spawn_enemy_bullet(global_position + l_dir * 14.0, l_dir, 1.0, base_bullet_spd * 1.1)
		EnemyType.MINE_TETHER:
			_fire_radial_burst(6, base_bullet_spd * 0.85)
		_:
			var target = _get_closest_player()
			var gen_dir = _get_aim_vector(target, oncoming)
			_spawn_enemy_bullet(global_position + gen_dir * 15.0, gen_dir, 1.0, base_bullet_spd)

func _fire_sniper_beam() -> void:
	var target = _get_closest_player()
	var sniper_spd = 950.0
	var sec_num = GameManager.current_sector if GameManager != null else 1
	var dir = calculate_lead_target_vector(global_position, target, sniper_spd) if (sec_num > 1 or has_aimed_lead or elite_affix != EliteAffix.NONE) else _get_aim_vector(target, -GameAxis.forward)
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(global_position + dir * 25.0, dir, true, 2.5)
	b.speed = sniper_spd # High-speed rail slug
	b.glow_color = Color(1.0, 0.1, 0.1, 1.0)
	b.scale = Vector2(2.2, 1.2)
	SoundEffects.play_sfx("laser", 0.15, 3.0)

func _fire_radial_burst(count: int, b_speed: float) -> void:
	for i in range(count):
		var angle = (float(i) / count) * TAU
		var d = Vector2(cos(angle), sin(angle))
		_spawn_enemy_bullet(global_position + d * 16.0, d, 1.0, b_speed)

func _launch_drone_swarm(count: int) -> void:
	for i in range(count):
		var drone = load("res://scenes/Enemy.tscn").instantiate()
		get_parent().add_child(drone)
		drone.setup(EnemyType.MICRO_DRONE, global_position + Vector2(randf_range(-25, 25), randf_range(10, 30)), squad_id, spawner_ref, EliteAffix.NONE)
	SoundEffects.play_sfx("laser", 0.08, 6.0)

func _spawn_enemy_bullet(pos: Vector2, dir: Vector2, dmg: float, b_speed: float) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(pos, dir, true, dmg)
	b.speed = b_speed
	SoundEffects.play_sfx("laser", 0.06, -3.0)

func _get_closest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	var closest: Node2D = null
	var min_d: float = INF
	for p in players:
		if is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d < min_d:
				min_d = d
				closest = p
	return closest

func take_damage(amount: float) -> void:
	# Shield Frigate invulnerability protection
	if is_shield_protected:
		SoundEffects.play_sfx("hit", 0.05, 5.0)
		return

	# Phantom cloaking intangibility
	if phantom_is_cloaked:
		return

	# Directional shield: Knight Vanguard deflects shots from the front
	if enemy_type == EnemyType.KNIGHT_VANGUARD:
		var shield_is_up = not knight_shield_shattered and not knight_shield_is_venting and not knight_is_firing_salvo
		if shield_is_up:
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty() and is_instance_valid(players[0]):
				var to_player = (players[0].global_position - global_position).normalized()
				var dot = to_player.dot(-GameAxis.forward)
				# If player is in front (positive dot along oncoming direction)
				if dot > 0.2:
					knight_shield_hp -= amount
					hit_flash_timer = 0.08
					if knight_shield_hp <= 0.0:
						knight_shield_shattered = true
						knight_shield_hp = 0.0
						SoundEffects.play_sfx("explosion", 0.12, 4.0)
						GameManager.request_screen_shake(4.0, 0.18)
					else:
						SoundEffects.play_sfx("hit", 0.1, 7.0)
					queue_redraw()
					return

	# Energy Shield depletion from SHIELDED affix
	if energy_shield_hp > 0.0:
		energy_shield_hp -= amount
		SoundEffects.play_sfx("hit", 0.08, 3.0)
		hit_flash_timer = 0.08
		queue_redraw()
		return

	health -= amount
	hit_flash_timer = 0.08
	SoundEffects.play_sfx("hit", 0.12, randf_range(0.0, 2.0))

	# Reactive Evasive Juke check on agile craft
	if has_evasive_juke and juke_cooldown <= 0.0 and health > 0.0:
		juke_cooldown = 1.5
		juke_timer = 0.18
		var lat = GameAxis.lateral
		var vp_rect = GameAxis.get_viewport_rect() if GameAxis != null else Rect2(0, 0, 1280, 720)
		var is_vert = GameAxis.is_vertical if GameAxis != null else false
		var cur_lat = global_position.x if is_vert else global_position.y
		var center_lat = (vp_rect.position.x + vp_rect.size.x * 0.5) if is_vert else (vp_rect.position.y + vp_rect.size.y * 0.5)
		var juke_sign = 1.0 if cur_lat < center_lat else -1.0
		# If within 30% of center, allow random dodge direction; if near boundary, dodge inward
		if absf(cur_lat - center_lat) < (vp_rect.size.y * 0.3 if not is_vert else vp_rect.size.x * 0.3):
			juke_sign = 1.0 if randf() > 0.5 else -1.0
		juke_dir = lat * juke_sign
		SoundEffects.play_sfx("laser", 0.06, 5.0)

	if health <= 0.0:
		_die()
	else:
		queue_redraw()

func _die() -> void:
	if is_dying:
		return
	is_dying = true

	var ex = explosion_scene.instantiate()
	get_parent().add_child(ex)
	ex.global_position = global_position
	ex.scale = Vector2(1.5, 1.5) if enemy_type == EnemyType.HEAVY_CRUISER or enemy_type == EnemyType.DRONE_CARRIER else Vector2.ONE

	# Volatile elite explodes in bullet nova
	if elite_affix == EliteAffix.VOLATILE:
		_fire_radial_burst(8, 320.0)

	# Notify squads and award score
	if spawner_ref and spawner_ref.has_method("notify_kill"):
		spawner_ref.notify_kill(squad_id)

	# Trigger player kill hooks
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.has_method("trigger_kill_hooks"):
			p.trigger_kill_hooks(self, global_position)

	GameManager.add_score(score_value)
	GameManager.record_kill()
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	# Quantum Cargo Hauler drops guaranteed Item Choice Crate
	if enemy_type == EnemyType.CARGO_HAULER:
		var crate = crate_scene.instantiate()
		get_parent().add_child(crate)
		crate.global_position = global_position

	# Elite Champions drop Golden Plasma Bounty (replaces loose scrap pellets)
	if elite_affix != EliteAffix.NONE:
		_award_elite_plasma_bounty()
	else:
		# Check for Heavy craft bounty bonus
		if enemy_type == EnemyType.HEAVY_CRUISER or enemy_type == EnemyType.DRONE_CARRIER:
			for p in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and "elite_bounty_bonus" in p and p.elite_bounty_bonus > 0:
					if GameManager != null:
						GameManager.add_joules(p.elite_bounty_bonus)
						SoundEffects.play_sfx("bonus", 0.06, 2.5)
					break
		
		# Dynamic target-driven scrap drop calibrated against wave composition
		var count = drop_guaranteed + (1 if randf() < drop_chance else 0)
		for i in range(count):
			var scrap = scrap_scene.instantiate()
			get_parent().add_child(scrap)
			scrap.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))

func _award_elite_plasma_bounty() -> void:
	var sec = GameManager.current_sector if GameManager != null else 1
	var bounty_joules = 10
	if sec == 2:
		bounty_joules = 15
	elif sec >= 3:
		bounty_joules = 20
	
	var bonus_bounty = 0
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and "elite_bounty_bonus" in p and p.elite_bounty_bonus > 0:
			bonus_bounty += p.elite_bounty_bonus
			break
	bounty_joules += bonus_bounty

	if GameManager != null:
		GameManager.add_joules(bounty_joules)
	
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			if p.has_method("recharge_shields_full"):
				p.recharge_shields_full()
			elif "shields" in p and "max_shields" in p:
				p.shields = p.max_shields
				if p.has_method("_emit_health"):
					p._emit_health()
	
	SoundEffects.play_sfx("bonus", 0.05, 2.0)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_banner"):
		hud._show_banner("[ +%d J ELITE BOUNTY | SHIELDS RESTORED ]" % bounty_joules, Color(1.0, 0.85, 0.2, 1.0))

func _escape_squad() -> void:
	if spawner_ref and spawner_ref.has_method("notify_escape"):
		spawner_ref.notify_escape(squad_id)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and not area.get("is_enemy"):
		var dmg = area.get("damage")
		take_damage(dmg if dmg != null else 1.0)
		if not area.has_meta("pierce_count") or area.get_meta("pierce_count") <= 0:
			area.queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(1)
		take_damage(5.0)

func _draw() -> void:
	var col = Color.WHITE if hit_flash_timer > 0.0 else main_color
	if phantom_is_cloaked:
		col.a = 0.15

	# Draw Shield Frigate protection aura
	if is_shield_protected:
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 16, Color(0.2, 0.8, 1.0, 0.8), 2.0)

	# Draw Energy Shield bubble if SHIELDED affix
	if energy_shield_hp > 0.0:
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 16, Color(0.4, 0.7, 1.0, 0.9), 2.5)

	# Draw Shield Frigate aura perimeter
	if enemy_type == EnemyType.SHIELD_FRIGATE:
		draw_arc(Vector2.ZERO, shield_aura_radius, 0, TAU, 32, Color(0.1, 0.8, 1.0, 0.35), 1.5)

	# Draw Sniper aiming laser line
	if is_sniper_aiming:
		var target = _get_closest_player()
		if target != null:
			var sec_num = GameManager.current_sector if GameManager != null else 1
			var sniper_spd = 950.0
			var lead_v = calculate_lead_target_vector(global_position, target, sniper_spd) if (sec_num > 1 or has_aimed_lead or elite_affix != EliteAffix.NONE) else _get_aim_vector(target, -GameAxis.forward)
			var local_endpoint = to_local(global_position + lead_v * 1200.0)
			draw_line(Vector2.ZERO, local_endpoint, Color(1.0, 0.15, 0.15, 0.8), 1.5)

	# Vector draw per enemy archetype
	match enemy_type:
		EnemyType.SCOUT:
			var pts = PackedVector2Array([Vector2(16, 0), Vector2(-12, -10), Vector2(-6, 0), Vector2(-12, 10)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(16, 0)]), accent_color, 1.5)
		EnemyType.BOMBER:
			var pts = PackedVector2Array([Vector2(20, 0), Vector2(6, -18), Vector2(-18, -14), Vector2(-12, 0), Vector2(-18, 14), Vector2(6, 18)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(20, 0)]), accent_color, 2.0)
		EnemyType.INTERCEPTOR:
			var pts = PackedVector2Array([Vector2(22, 0), Vector2(-14, -8), Vector2(-8, 0), Vector2(-14, 8)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(22, 0)]), accent_color, 2.0)
			# Afterburner flame
			draw_line(Vector2(-8, 0), Vector2(-18, 0), Color(1.0, 0.8, 0.1, 0.9), 3.0)
		EnemyType.SNIPER:
			# Long needle hull
			var pts = PackedVector2Array([Vector2(28, 0), Vector2(-16, -6), Vector2(-12, 0), Vector2(-16, 6)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(28, 0)]), accent_color, 1.5)
		EnemyType.SHIELD_FRIGATE:
			var pts = PackedVector2Array([Vector2(18, 0), Vector2(8, -16), Vector2(-16, -12), Vector2(-16, 12), Vector2(8, 16)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(18, 0)]), accent_color, 2.0)
			draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.9, 1.0, 0.9))
		EnemyType.HEAVY_CRUISER:
			var pts = PackedVector2Array([Vector2(32, 0), Vector2(16, -26), Vector2(-28, -20), Vector2(-20, 0), Vector2(-28, 20), Vector2(16, 26)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(32, 0)]), accent_color, 2.5)
			draw_rect(Rect2(-10, -6, 20, 12), Color.WHITE, false, 1.5)
		EnemyType.KNIGHT_VANGUARD:
			var pts = PackedVector2Array([Vector2(18, 0), Vector2(-12, -12), Vector2(-8, 0), Vector2(-12, 12)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(18, 0)]), accent_color, 1.5)
			
			# Dynamic Mirror Shield rendering
			if not knight_shield_shattered:
				if knight_is_firing_salvo:
					# Split parted shield arc exposing forward cannons
					draw_arc(Vector2(8, 0), 16.0, -PI * 0.45, -PI * 0.15, 6, Color(1.0, 0.8, 0.2, 0.9), 3.0)
					draw_arc(Vector2(8, 0), 16.0, PI * 0.15, PI * 0.45, 6, Color(1.0, 0.8, 0.2, 0.9), 3.0)
					# Cannon muzzle spark
					draw_circle(Vector2(18, 0), 3.5, Color(1.0, 0.9, 0.3, 0.95))
				elif knight_shield_is_venting:
					# Flickering amber/orange warning arc (overheating / vulnerable)
					var vent_alpha = 0.35 + 0.25 * sin(flight_time * 18.0)
					draw_arc(Vector2(8, 0), 16.0, -PI * 0.45, PI * 0.45, 12, Color(1.0, 0.45, 0.15, vent_alpha), 2.5)
				else:
					# Intact shield: color degrades as HP depletes (Cyan -> Amber -> Danger Red)
					var s_ratio = clampf(knight_shield_hp / maxf(1.0, knight_shield_max_hp), 0.0, 1.0)
					var s_color = Color(0.4, 0.9, 1.0, 1.0)
					if s_ratio < 0.35:
						s_color = Color(1.0, 0.25, 0.35, 0.95)
					elif s_ratio < 0.65:
						s_color = Color(1.0, 0.85, 0.25, 0.95)
					
					if hit_flash_timer > 0.0:
						s_color = Color.WHITE
					draw_arc(Vector2(8, 0), 16.0, -PI * 0.45, PI * 0.45, 12, s_color, 3.5)
		EnemyType.TURRET_PLATFORM:
			# Hexagonal bunker
			var hex = PackedVector2Array()
			for i in range(6):
				var a = (float(i) / 6.0) * TAU
				hex.append(Vector2(cos(a) * 20.0, sin(a) * 20.0))
			draw_colored_polygon(hex, col)
			draw_polyline(hex + PackedVector2Array([hex[0]]), accent_color, 2.0)
			# Rotating cannon barrel
			var barrel_dir = Vector2.RIGHT.rotated(turret_angle)
			draw_line(Vector2.ZERO, barrel_dir * 22.0, Color.WHITE, 3.0)
		EnemyType.CARGO_HAULER:
			# Sturdy armored freight hull with twin glowing cargo pods
			var pts = PackedVector2Array([
				Vector2(20, 0), Vector2(10, -12), Vector2(-16, -14),
				Vector2(-20, -8), Vector2(-20, 8), Vector2(-16, 14), Vector2(10, 12)
			])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(20, 0)]), accent_color, 2.0)
			# Twin holographic relic cargo pods on upper/lower dorsal
			draw_rect(Rect2(-12, -18, 14, 6), Color(0.2, 1.0, 0.9, 0.85), true)
			draw_rect(Rect2(-12, 12, 14, 6), Color(0.2, 1.0, 0.9, 0.85), true)
			draw_rect(Rect2(-12, -18, 14, 6), Color.WHITE, false, 1.0)
			draw_rect(Rect2(-12, 12, 14, 6), Color.WHITE, false, 1.0)
			# Central quantum core pulse
			draw_circle(Vector2(-2, 0), 4.5, Color(1.0, 0.9, 0.2, 0.95))
		EnemyType.MICRO_DRONE:
			var pts = PackedVector2Array([Vector2(8, 0), Vector2(-6, -5), Vector2(-6, 5)])
			draw_colored_polygon(pts, col)
		_:
			# Default craft polygon
			var pts = PackedVector2Array([Vector2(16, 0), Vector2(-10, -10), Vector2(-6, 0), Vector2(-10, 10)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(16, 0)]), accent_color, 1.5)
