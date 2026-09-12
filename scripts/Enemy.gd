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
	ORBITAL_REFLECTOR
}

enum EliteAffix { NONE, ARMORED, VOLATILE, SWIFT, SHIELDED }

@export var enemy_type: EnemyType = EnemyType.SCOUT
@export var elite_affix: EliteAffix = EliteAffix.NONE

@export var max_health: float = 2.0
var health: float = 2.0

var speed: float = 260.0
var score_value: int = 100

# Formation / Squad tracking
var squad_id: int = -1
var spawner_ref: Node = null

# Flight behavior
var move_direction: Vector2 = Vector2.LEFT
var lateral_frequency: float = 2.5
var lateral_amplitude: float = 80.0
var flight_time: float = 0.0
var spawn_pos: Vector2 = Vector2.ZERO

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

func _setup_stats() -> void:
	# Sector and wave scaling multipliers
	var sec = GameManager.current_sector if GameManager != null else 1
	var wave = GameManager.current_wave if GameManager != null else 1
	var wave_hp_mult = 1.0 + (wave - 1) * 0.08
	var sec_hp_mult = 1.0 + (sec - 1) * 0.95
	var hp_mult = wave_hp_mult * sec_hp_mult
	var sec_spd_mult = 1.0 + (sec - 1) * 0.12 + (wave - 1) * 0.008
	var sec_fire_mult = 1.0 + (sec - 1) * 0.25 + (wave - 1) * 0.035

	match enemy_type:
		EnemyType.SCOUT:
			max_health = 6.0 * hp_mult
			speed = 280.0 * sec_spd_mult
			score_value = 100
			main_color = Color(1.0, 0.25, 0.45, 1.0)
			accent_color = Color(1.0, 0.7, 0.2, 1.0)
			fire_interval = 1.4 / sec_fire_mult
			fire_timer = randf_range(0.4, 1.0)
		EnemyType.BOMBER:
			max_health = 26.0 * hp_mult
			speed = 140.0 * sec_spd_mult
			score_value = 250
			main_color = Color(0.95, 0.15, 0.85, 1.0)
			accent_color = Color(0.3, 0.9, 1.0, 1.0)
			fire_interval = 1.3 / sec_fire_mult
			fire_timer = 0.6
		EnemyType.INTERCEPTOR:
			max_health = 12.0 * hp_mult
			speed = 380.0 * sec_spd_mult
			score_value = 150
			main_color = Color(1.0, 0.5, 0.1, 1.0)
			accent_color = Color(1.0, 0.9, 0.2, 1.0)
			fire_interval = 2.0 / sec_fire_mult
			fire_timer = 1.2
		EnemyType.SNIPER:
			max_health = 18.0 * hp_mult
			speed = 100.0 * sec_spd_mult
			score_value = 300
			main_color = Color(1.0, 0.85, 0.2, 1.0)
			accent_color = Color(1.0, 0.2, 0.2, 1.0)
			fire_interval = 2.4 / sec_fire_mult
			fire_timer = 1.2
		EnemyType.SHIELD_FRIGATE:
			max_health = 42.0 * hp_mult
			speed = 110.0 * sec_spd_mult
			score_value = 400
			main_color = Color(0.1, 0.8, 1.0, 1.0)
			accent_color = Color(0.3, 1.0, 0.9, 1.0)
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 0.8
		EnemyType.HEAVY_CRUISER:
			max_health = 75.0 * hp_mult
			speed = 80.0 * sec_spd_mult
			score_value = 750
			main_color = Color(0.7, 0.2, 0.9, 1.0)
			accent_color = Color(1.0, 0.3, 0.5, 1.0)
			fire_interval = 1.6 / sec_fire_mult
			fire_timer = 0.7
		EnemyType.KNIGHT_VANGUARD:
			max_health = 48.0 * hp_mult
			speed = 130.0 * sec_spd_mult
			score_value = 350
			main_color = Color(0.4, 0.8, 0.9, 1.0)
			accent_color = Color(0.9, 0.9, 1.0, 1.0)
			fire_interval = 2.0 / sec_fire_mult
			fire_timer = 0.8
		EnemyType.PHANTOM:
			max_health = 14.0 * hp_mult
			speed = 260.0 * sec_spd_mult
			score_value = 320
			main_color = Color(0.5, 0.2, 0.8, 0.8)
			accent_color = Color(0.8, 0.4, 1.0, 1.0)
			fire_interval = 1.8 / sec_fire_mult
			fire_timer = 0.8
			phantom_timer = 2.0
		EnemyType.DRONE_CARRIER:
			max_health = 60.0 * hp_mult
			speed = 75.0 * sec_spd_mult
			score_value = 600
			main_color = Color(0.9, 0.6, 0.1, 1.0)
			accent_color = Color(1.0, 0.8, 0.3, 1.0)
			carrier_spawn_timer = 2.0
			fire_interval = 3.0
			fire_timer = 2.0
		EnemyType.MICRO_DRONE:
			max_health = 3.0 * hp_mult
			speed = 340.0 * sec_spd_mult
			score_value = 40
			main_color = Color(1.0, 0.9, 0.3, 1.0)
			accent_color = Color(1.0, 0.4, 0.1, 1.0)
			fire_interval = 999.0 # Kamikaze only
			fire_timer = 999.0
		EnemyType.TURRET_PLATFORM:
			max_health = 45.0 * hp_mult
			speed = 20.0
			score_value = 450
			main_color = Color(0.3, 0.7, 0.5, 1.0)
			accent_color = Color(0.2, 1.0, 0.6, 1.0)
			fire_interval = 1.2 / sec_fire_mult
			fire_timer = 0.6
		EnemyType.WARP_STALKER:
			max_health = 22.0 * hp_mult
			speed = 140.0
			score_value = 380
			main_color = Color(0.2, 0.4, 1.0, 1.0)
			accent_color = Color(0.6, 0.8, 1.0, 1.0)
			warp_timer = 2.8
			fire_interval = 2.0 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.DRAINER_LEECH:
			max_health = 24.0 * hp_mult
			speed = 150.0 * sec_spd_mult
			score_value = 340
			main_color = Color(0.8, 0.1, 0.3, 1.0)
			accent_color = Color(1.0, 0.4, 0.6, 1.0)
			fire_interval = 2.2
			fire_timer = 1.0
		EnemyType.MISSILE_CORVETTE:
			max_health = 45.0 * hp_mult
			speed = 100.0 * sec_spd_mult
			score_value = 480
			main_color = Color(0.2, 0.8, 0.4, 1.0)
			accent_color = Color(0.8, 1.0, 0.3, 1.0)
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.MINE_TETHER:
			max_health = 25.0 * hp_mult
			speed = 40.0
			score_value = 200
			main_color = Color(1.0, 0.3, 0.7, 1.0)
			accent_color = Color(1.0, 0.8, 0.9, 1.0)
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 0.8
		EnemyType.ORBITAL_REFLECTOR:
			max_health = 32.0 * hp_mult
			speed = 170.0
			score_value = 220
			main_color = Color(0.6, 0.8, 1.0, 1.0)
			accent_color = Color(1.0, 1.0, 1.0, 1.0)
			fire_interval = 999.0
			fire_timer = 999.0

	# Apply Elite Affix modifiers
	match elite_affix:
		EliteAffix.ARMORED:
			max_health *= 2.5
			speed *= 0.85
			score_value *= 3
			main_color = Color(1.0, 0.85, 0.2, 1.0)
			accent_color = Color(1.0, 0.95, 0.5, 1.0)
		EliteAffix.VOLATILE:
			max_health *= 1.4
			score_value *= 2
			main_color = Color(1.0, 0.35, 0.05, 1.0)
			accent_color = Color(1.0, 0.8, 0.1, 1.0)
		EliteAffix.SWIFT:
			max_health *= 1.1
			speed *= 1.7
			score_value *= 2
			main_color = Color(0.2, 1.0, 0.7, 1.0)
			accent_color = Color(0.7, 1.0, 0.9, 1.0)
		EliteAffix.SHIELDED:
			max_health *= 1.3
			energy_shield_hp = max_health * 0.6
	# Procedural Behavioral Mutation Traits
	lateral_frequency = randf_range(1.8, 3.6)
	lateral_amplitude = randf_range(50.0, 110.0)
	has_evasive_juke = false
	has_orbital_flight = false
	
	var trait_chance = 0.25 + (sec - 1) * 0.15
	if randf() < trait_chance and enemy_type in [EnemyType.SCOUT, EnemyType.INTERCEPTOR]:
		has_desperation_charge = true
	if randf() < trait_chance:
		has_aimed_lead = true
	if randf() < (trait_chance * 0.6) and enemy_type in [EnemyType.SCOUT, EnemyType.BOMBER, EnemyType.MISSILE_CORVETTE]:
		has_burst_spread = true

	health = max_health

func setup(p_type: EnemyType, p_pos: Vector2, p_squad_id: int, p_spawner: Node, p_affix: EliteAffix = EliteAffix.NONE) -> void:
	enemy_type = p_type
	elite_affix = p_affix
	global_position = p_pos
	spawn_pos = p_pos
	squad_id = p_squad_id
	spawner_ref = p_spawner
	_setup_stats()
	queue_redraw()

func _physics_process(delta: float) -> void:
	flight_time += delta

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		queue_redraw()

	_check_shield_frigate_buffs()
	_handle_flight_movement(delta)
	_handle_combat_abilities(delta)

	# Boundary check / Despawn if completely off screen
	var vp = get_viewport_rect().size
	if global_position.x < -160 or global_position.x > vp.x + 160 or global_position.y < -160 or global_position.y > vp.y + 160:
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

func _handle_flight_movement(delta: float) -> void:
	var oncoming = -GameAxis.forward
	var lat = GameAxis.lateral
	var base_angle = oncoming.angle()

	# 1. Desperation Kamikaze Charge on Low Health
	# Commits to a single focused high-speed charge downfield through player position, then exits screen
	if has_desperation_charge and health <= max_health * 0.35:
		if not is_desperation_ramming:
			var target = _get_closest_player()
			if target != null:
				var to_player = (target.global_position - global_position).normalized()
				if to_player.dot(oncoming) > 0.05:
					charge_vector = to_player
				else:
					charge_vector = oncoming
			else:
				charge_vector = oncoming
			is_desperation_ramming = true
			SoundEffects.play_sfx("laser", 0.15, -2.0)

		global_position += charge_vector * speed * 1.8 * delta
		rotation = charge_vector.angle()
		return

	match enemy_type:
		EnemyType.SCOUT:
			# Classic smooth sine weave advancing downfield
			var forward_step = oncoming * speed * delta
			var lat_step = lat * cos(flight_time * lateral_frequency) * lateral_amplitude * delta
			global_position += forward_step + lat_step
			rotation = base_angle

		EnemyType.BOMBER, EnemyType.HEAVY_CRUISER, EnemyType.DRONE_CARRIER, EnemyType.SHIELD_FRIGATE, EnemyType.DRAINER_LEECH, EnemyType.ORBITAL_REFLECTOR:
			# Steady forward advance downfield into the combat arena
			global_position += oncoming * speed * delta
			rotation = base_angle

		EnemyType.INTERCEPTOR:
			# High-speed strike craft: advances downfield, locks dive vector downfield when player is sighted, streaks through off-screen
			if not is_charging:
				var target = _get_closest_player()
				if target != null:
					var to_player = (target.global_position - global_position).normalized()
					if to_player.dot(oncoming) > 0.1:
						charge_vector = to_player
						is_charging = true
					else:
						charge_vector = oncoming
				else:
					charge_vector = oncoming
			global_position += charge_vector * (speed * 1.4 if is_charging else speed) * delta
			rotation = charge_vector.angle()

		EnemyType.KNIGHT_VANGUARD:
			# Relentless forward march with forward-facing mirror shield
			global_position += oncoming * speed * delta
			rotation = base_angle

		EnemyType.MICRO_DRONE:
			# Fast forward swarm: high forward velocity with gentle lateral drift toward player corridor
			var target = _get_closest_player()
			var lat_drift = Vector2.ZERO
			if target != null:
				var lat_diff = (target.global_position - global_position).dot(lat)
				lat_drift = lat * clampf(lat_diff * 1.4, -speed * 0.35, speed * 0.35)
			var swarm_vel = oncoming * speed + lat_drift
			global_position += swarm_vel * delta
			rotation = swarm_vel.angle()

		EnemyType.SNIPER:
			# Advances from spawn horizon, then anchors in forward perimeter to snipe
			var vp = get_viewport_rect().size
			var in_station = false
			if GameAxis.is_vertical:
				in_station = (global_position.y >= vp.y * 0.26)
			else:
				in_station = (global_position.x <= vp.x * 0.74)

			if not in_station:
				global_position += oncoming * speed * delta
			rotation = base_angle

		EnemyType.PHANTOM:
			# Cloaks and drifts downfield unseen, decloaks in the forward sector ahead of the player
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

		EnemyType.WARP_STALKER:
			# Quantum phase-shifter: warps strictly within forward staging sector
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

		EnemyType.TURRET_PLATFORM:
			# Heavy anchored fortress; slowly drifts while its cannon traverses to target player
			var target = _get_closest_player()
			if target != null:
				turret_angle = (target.global_position - global_position).angle()
			global_position += oncoming * speed * delta * 0.4
			rotation = base_angle

		_:
			# Default downfield forward flight
			global_position += oncoming * speed * delta
			rotation = base_angle

func _handle_combat_abilities(delta: float) -> void:
	# Carrier drone spawning
	if enemy_type == EnemyType.DRONE_CARRIER:
		carrier_spawn_timer -= delta
		if carrier_spawn_timer <= 0.0:
			carrier_spawn_timer = 3.5
			_launch_drone_swarm(3)

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

func _execute_attack() -> void:
	if phantom_is_cloaked or enemy_type == EnemyType.MICRO_DRONE or enemy_type == EnemyType.SNIPER:
		return

	var oncoming = -GameAxis.forward
	var lat = GameAxis.lateral

	# Procedural Attack Trait: Aimed Lead Prediction
	if has_aimed_lead and enemy_type in [EnemyType.SCOUT, EnemyType.INTERCEPTOR, EnemyType.KNIGHT_VANGUARD]:
		var target = _get_closest_player()
		if target != null:
			var target_vel = target.get("current_velocity")
			var lead_offset = (target_vel * 0.28) if target_vel != null else Vector2.ZERO
			var lead_dir = ((target.global_position + lead_offset) - global_position).normalized()
			_spawn_enemy_bullet(global_position + lead_dir * 18.0, lead_dir, 1.0, 440.0)
			return

	# Procedural Attack Trait: Burst Spread
	if has_burst_spread and enemy_type in [EnemyType.SCOUT, EnemyType.BOMBER, EnemyType.MISSILE_CORVETTE]:
		for a in [-16.0, 0.0, 16.0]:
			var d = oncoming.rotated(deg_to_rad(a))
			_spawn_enemy_bullet(global_position + d * 18.0, d, 1.0, 400.0)
		return

	match enemy_type:
		EnemyType.SCOUT:
			var wave_num = GameManager.current_wave if GameManager != null else 1
			if wave_num >= 16:
				for a in [-15.0, 0.0, 15.0]:
					var d = oncoming.rotated(deg_to_rad(a))
					_spawn_enemy_bullet(global_position + d * 14.0, d, 1.0, 460.0)
			elif wave_num >= 6:
				_spawn_enemy_bullet(global_position + oncoming.rotated(-0.14) * 14.0, oncoming.rotated(-0.14), 1.0, 440.0)
				_spawn_enemy_bullet(global_position + oncoming.rotated(0.14) * 14.0, oncoming.rotated(0.14), 1.0, 440.0)
			else:
				_spawn_enemy_bullet(global_position + oncoming * 14.0, oncoming, 1.0, 420.0)
		EnemyType.BOMBER:
			_spawn_enemy_bullet(global_position + oncoming * 20.0 - lat * 14.0, oncoming, 1.5, 380.0)
			_spawn_enemy_bullet(global_position + oncoming * 20.0, oncoming, 1.5, 410.0)
			_spawn_enemy_bullet(global_position + oncoming * 20.0 + lat * 14.0, oncoming, 1.5, 380.0)
		EnemyType.HEAVY_CRUISER:
			# 5-way sweeping fan volley
			for a in [-26.0, -13.0, 0.0, 13.0, 26.0]:
				var d = oncoming.rotated(deg_to_rad(a))
				_spawn_enemy_bullet(global_position + d * 22.0, d, 1.2, 420.0)
		EnemyType.TURRET_PLATFORM:
			var d = Vector2.RIGHT.rotated(turret_angle)
			_spawn_enemy_bullet(global_position + d * 18.0, d, 1.0, 480.0)
		EnemyType.MISSILE_CORVETTE:
			_spawn_enemy_bullet(global_position - lat * 15.0, oncoming.rotated(-0.25), 1.0, 320.0)
			_spawn_enemy_bullet(global_position + lat * 15.0, oncoming.rotated(0.25), 1.0, 320.0)
		EnemyType.MINE_TETHER:
			_fire_radial_burst(8, 280.0)
		_:
			_spawn_enemy_bullet(global_position + oncoming * 15.0, oncoming, 1.0, 420.0)

func _fire_sniper_beam() -> void:
	var target = _get_closest_player()
	var dir = (target.global_position - global_position).normalized() if target != null else -GameAxis.forward
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(global_position + dir * 25.0, dir, true, 2.5)
	b.speed = 850.0 # High-speed rail slug
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
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]):
			var to_player = (players[0].global_position - global_position).normalized()
			var dot = to_player.dot(-GameAxis.forward)
			# If player is in front (positive dot along oncoming direction)
			if dot > 0.2:
				SoundEffects.play_sfx("hit", 0.1, 7.0)
				# Sparks/deflected
				hit_flash_timer = 0.08
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

	if health <= 0.0:
		_die()
	else:
		queue_redraw()

func _die() -> void:
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

	GameManager.add_score(score_value)
	GameManager.record_kill()
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	# Scrap drop
	var count = 1
	if elite_affix != EliteAffix.NONE or enemy_type == EnemyType.HEAVY_CRUISER:
		count = 4
	for i in range(count):
		var scrap = scrap_scene.instantiate()
		get_parent().add_child(scrap)
		scrap.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))

	# Guaranteed item crate drop for Elite Champions
	if elite_affix != EliteAffix.NONE or enemy_type == EnemyType.DRONE_CARRIER:
		var crate = crate_scene.instantiate()
		get_parent().add_child(crate)
		crate.global_position = global_position

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
			var local_target = to_local(target.global_position)
			draw_line(Vector2.ZERO, local_target, Color(1.0, 0.1, 0.1, 0.75), 1.5)

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
			# Front mirror shield arc
			draw_arc(Vector2(8, 0), 16.0, -PI * 0.45, PI * 0.45, 12, Color(0.4, 0.9, 1.0, 1.0), 3.5)
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
		EnemyType.MICRO_DRONE:
			var pts = PackedVector2Array([Vector2(8, 0), Vector2(-6, -5), Vector2(-6, 5)])
			draw_colored_polygon(pts, col)
		_:
			# Default craft polygon
			var pts = PackedVector2Array([Vector2(16, 0), Vector2(-10, -10), Vector2(-6, 0), Vector2(-10, 10)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([Vector2(16, 0)]), accent_color, 1.5)
