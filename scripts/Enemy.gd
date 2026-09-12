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
	# Sector scaling multipliers
	var sec = GameManager.current_sector if GameManager != null else 1
	var sec_hp_mult = 1.0 + (sec - 1) * 0.95
	var sec_spd_mult = 1.0 + (sec - 1) * 0.15
	var sec_fire_mult = 1.0 + (sec - 1) * 0.25

	match enemy_type:
		EnemyType.SCOUT:
			max_health = 2.0 * sec_hp_mult
			speed = 320.0 * sec_spd_mult
			score_value = 100
			main_color = Color(1.0, 0.25, 0.45, 1.0)
			accent_color = Color(1.0, 0.7, 0.2, 1.0)
			fire_interval = 2.4 / sec_fire_mult
			fire_timer = randf_range(1.0, 2.0)
		EnemyType.BOMBER:
			max_health = 8.0 * sec_hp_mult
			speed = 160.0 * sec_spd_mult
			score_value = 250
			main_color = Color(0.95, 0.15, 0.85, 1.0)
			accent_color = Color(0.3, 0.9, 1.0, 1.0)
			fire_interval = 2.0 / sec_fire_mult
			fire_timer = 0.8
		EnemyType.INTERCEPTOR:
			max_health = 3.5 * sec_hp_mult
			speed = 420.0 * sec_spd_mult
			score_value = 150
			main_color = Color(1.0, 0.5, 0.1, 1.0)
			accent_color = Color(1.0, 0.9, 0.2, 1.0)
			fire_interval = 3.0 / sec_fire_mult
			fire_timer = 2.0
		EnemyType.SNIPER:
			max_health = 4.0 * sec_hp_mult
			speed = 110.0 * sec_spd_mult
			score_value = 300
			main_color = Color(1.0, 0.85, 0.2, 1.0)
			accent_color = Color(1.0, 0.2, 0.2, 1.0)
			fire_interval = 3.5 / sec_fire_mult
			fire_timer = 1.5
		EnemyType.SHIELD_FRIGATE:
			max_health = 14.0 * sec_hp_mult
			speed = 120.0 * sec_spd_mult
			score_value = 400
			main_color = Color(0.1, 0.8, 1.0, 1.0)
			accent_color = Color(0.3, 1.0, 0.9, 1.0)
			fire_interval = 2.8 / sec_fire_mult
			fire_timer = 1.2
		EnemyType.HEAVY_CRUISER:
			max_health = 28.0 * sec_hp_mult
			speed = 85.0 * sec_spd_mult
			score_value = 750
			main_color = Color(0.7, 0.2, 0.9, 1.0)
			accent_color = Color(1.0, 0.3, 0.5, 1.0)
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.KNIGHT_VANGUARD:
			max_health = 10.0 * sec_hp_mult
			speed = 140.0 * sec_spd_mult
			score_value = 350
			main_color = Color(0.4, 0.8, 0.9, 1.0)
			accent_color = Color(0.9, 0.9, 1.0, 1.0)
			fire_interval = 2.5 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.PHANTOM:
			max_health = 4.5 * sec_hp_mult
			speed = 280.0 * sec_spd_mult
			score_value = 320
			main_color = Color(0.5, 0.2, 0.8, 0.8)
			accent_color = Color(0.8, 0.4, 1.0, 1.0)
			fire_interval = 2.2 / sec_fire_mult
			fire_timer = 1.2
			phantom_timer = 2.0
		EnemyType.DRONE_CARRIER:
			max_health = 22.0 * sec_hp_mult
			speed = 80.0 * sec_spd_mult
			score_value = 600
			main_color = Color(0.9, 0.6, 0.1, 1.0)
			accent_color = Color(1.0, 0.8, 0.3, 1.0)
			carrier_spawn_timer = 2.5
			fire_interval = 4.0
			fire_timer = 3.0
		EnemyType.MICRO_DRONE:
			max_health = 1.0
			speed = 360.0 * sec_spd_mult
			score_value = 40
			main_color = Color(1.0, 0.9, 0.3, 1.0)
			accent_color = Color(1.0, 0.4, 0.1, 1.0)
			fire_interval = 999.0 # Kamikaze only
			fire_timer = 999.0
		EnemyType.TURRET_PLATFORM:
			max_health = 18.0 * sec_hp_mult
			speed = 20.0
			score_value = 450
			main_color = Color(0.3, 0.7, 0.5, 1.0)
			accent_color = Color(0.2, 1.0, 0.6, 1.0)
			fire_interval = 1.6 / sec_fire_mult
			fire_timer = 0.8
		EnemyType.WARP_STALKER:
			max_health = 6.0 * sec_hp_mult
			speed = 150.0
			score_value = 380
			main_color = Color(0.2, 0.4, 1.0, 1.0)
			accent_color = Color(0.6, 0.8, 1.0, 1.0)
			warp_timer = 3.0
			fire_interval = 2.5 / sec_fire_mult
			fire_timer = 1.2
		EnemyType.DRAINER_LEECH:
			max_health = 9.0 * sec_hp_mult
			speed = 160.0 * sec_spd_mult
			score_value = 340
			main_color = Color(0.8, 0.1, 0.3, 1.0)
			accent_color = Color(1.0, 0.4, 0.6, 1.0)
			fire_interval = 3.0
			fire_timer = 1.5
		EnemyType.MISSILE_CORVETTE:
			max_health = 16.0 * sec_hp_mult
			speed = 110.0 * sec_spd_mult
			score_value = 480
			main_color = Color(0.2, 0.8, 0.4, 1.0)
			accent_color = Color(0.8, 1.0, 0.3, 1.0)
			fire_interval = 3.2 / sec_fire_mult
			fire_timer = 1.5
		EnemyType.MINE_TETHER:
			max_health = 8.0 * sec_hp_mult
			speed = 40.0
			score_value = 200
			main_color = Color(1.0, 0.3, 0.7, 1.0)
			accent_color = Color(1.0, 0.8, 0.9, 1.0)
			fire_interval = 2.8 / sec_fire_mult
			fire_timer = 1.0
		EnemyType.ORBITAL_REFLECTOR:
			max_health = 12.0 * sec_hp_mult
			speed = 180.0
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
	orbital_direction = 1.0 if randf() > 0.5 else -1.0
	orbital_radius = randf_range(200.0, 320.0)
	
	var trait_chance = 0.25 + (sec - 1) * 0.15
	if randf() < trait_chance and enemy_type in [EnemyType.SCOUT, EnemyType.INTERCEPTOR, EnemyType.KNIGHT_VANGUARD]:
		has_evasive_juke = true
	if randf() < trait_chance and enemy_type in [EnemyType.SCOUT, EnemyType.BOMBER]:
		has_desperation_charge = true
	if randf() < (trait_chance * 0.7) and enemy_type in [EnemyType.SCOUT, EnemyType.SNIPER, EnemyType.DRAINER_LEECH]:
		has_orbital_flight = true
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
	var fwd = GameAxis.forward
	var lat = GameAxis.lateral

	# 1. Evasive Juking (Dodging close player bullets)
	if juke_cooldown > 0.0:
		juke_cooldown -= delta
	if has_evasive_juke and juke_cooldown <= 0.0:
		for b in get_tree().get_nodes_in_group("bullet"):
			if is_instance_valid(b) and not b.get("is_enemy"):
				if global_position.distance_to(b.global_position) <= 85.0:
					var dodge_dir = lat * (1.0 if randf() > 0.5 else -1.0)
					global_position += dodge_dir * 55.0
					juke_cooldown = 1.4
					SoundEffects.play_sfx("roll", 0.06, 5.0)
					break

	# 2. Desperation Kamikaze Charge on Low Health
	if has_desperation_charge and health <= max_health * 0.35:
		var target = _get_closest_player()
		if target != null:
			var ram_dir = (target.global_position - global_position).normalized()
			global_position += ram_dir * speed * 1.8 * delta
			rotation = ram_dir.angle()
			is_desperation_ramming = true
			return

	# 3. Dynamic Orbital Circling
	if has_orbital_flight:
		var target = _get_closest_player()
		if target != null:
			var to_player = global_position - target.global_position
			var angle = to_player.angle() + (orbital_direction * 1.6 * delta)
			global_position = target.global_position + Vector2(cos(angle), sin(angle)) * orbital_radius
			rotation = (target.global_position - global_position).angle()
			return

	match enemy_type:
		EnemyType.SCOUT:
			# Classic sine weave
			var forward_motion = fwd * speed * delta
			var lat_offset = sin(flight_time * lateral_frequency) * lateral_amplitude
			global_position = spawn_pos + (fwd * speed * flight_time) + (lat * lat_offset)
			rotation = fwd.angle()

		EnemyType.BOMBER, EnemyType.HEAVY_CRUISER, EnemyType.DRONE_CARRIER:
			# Slow forward advance with slight banking
			global_position += fwd * speed * delta
			rotation = fwd.angle()

		EnemyType.INTERCEPTOR:
			# Dives toward player position once target is spotted
			if not is_charging:
				var target = _get_closest_player()
				if target != null:
					charge_vector = (target.global_position - global_position).normalized()
					is_charging = true
				else:
					charge_vector = fwd
			global_position += charge_vector * speed * delta
			rotation = charge_vector.angle()

		EnemyType.KNIGHT_VANGUARD:
			# Slow, relentless forward march with directional shield facing forward
			global_position += fwd * speed * delta
			rotation = fwd.angle()

		EnemyType.MICRO_DRONE:
			# Swarms directly toward player
			var target = _get_closest_player()
			if target != null:
				var dir = (target.global_position - global_position).normalized()
				global_position += dir * speed * delta
				rotation = dir.angle()
			else:
				global_position += fwd * speed * delta

		EnemyType.SNIPER:
			# Slow drift, anchors at perimeter
			var vp = get_viewport_rect().size
			if global_position.y < vp.y * 0.35:
				global_position += fwd * speed * delta
			rotation = fwd.angle()

		EnemyType.PHANTOM:
			# Teleports behind player during cloak
			phantom_timer -= delta
			if phantom_timer <= 0.0:
				phantom_is_cloaked = not phantom_is_cloaked
				phantom_timer = 2.4 if phantom_is_cloaked else 3.2
				if phantom_is_cloaked:
					var target = _get_closest_player()
					if target != null:
						# Teleport behind player
						global_position = target.global_position - (fwd * 180.0) + (lat * randf_range(-100, 100))
			if not phantom_is_cloaked:
				global_position += fwd * speed * delta
			rotation = fwd.angle()

		EnemyType.WARP_STALKER:
			# Periodically teleports
			warp_timer -= delta
			if warp_timer <= 0.0:
				warp_timer = 3.0
				var vp = get_viewport_rect().size
				global_position = Vector2(randf_range(80, vp.x - 80), randf_range(60, vp.y * 0.5))
				_fire_radial_burst(4, 300.0)
			global_position += fwd * speed * delta * 0.4
			rotation = fwd.angle()

		EnemyType.TURRET_PLATFORM:
			# Anchored station; rotates its cannon toward player
			var target = _get_closest_player()
			if target != null:
				turret_angle = (target.global_position - global_position).angle()
			global_position += fwd * speed * delta

		_:
			# Default forward flight
			global_position += fwd * speed * delta
			rotation = fwd.angle()

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

	var fwd = GameAxis.forward
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
			var d = fwd.rotated(deg_to_rad(a))
			_spawn_enemy_bullet(global_position + d * 18.0, d, 1.0, 400.0)
		return

	match enemy_type:
		EnemyType.SCOUT:
			_spawn_enemy_bullet(global_position + fwd * 14.0, fwd, 1.0, 420.0)
		EnemyType.BOMBER:
			_spawn_enemy_bullet(global_position + fwd * 20.0 - lat * 12.0, fwd, 1.5, 340.0)
			_spawn_enemy_bullet(global_position + fwd * 20.0 + lat * 12.0, fwd, 1.5, 340.0)
		EnemyType.HEAVY_CRUISER:
			# 5-way sweeping fan volley
			for a in [-24.0, -12.0, 0.0, 12.0, 24.0]:
				var d = fwd.rotated(deg_to_rad(a))
				_spawn_enemy_bullet(global_position + d * 22.0, d, 1.2, 380.0)
		EnemyType.TURRET_PLATFORM:
			var d = Vector2.RIGHT.rotated(turret_angle)
			_spawn_enemy_bullet(global_position + d * 18.0, d, 1.0, 450.0)
		EnemyType.MISSILE_CORVETTE:
			_spawn_enemy_bullet(global_position - lat * 15.0, fwd.rotated(-0.25), 1.0, 280.0)
			_spawn_enemy_bullet(global_position + lat * 15.0, fwd.rotated(0.25), 1.0, 280.0)
		EnemyType.MINE_TETHER:
			_fire_radial_burst(6, 260.0)
		_:
			_spawn_enemy_bullet(global_position + fwd * 15.0, fwd, 1.0, 400.0)

func _fire_sniper_beam() -> void:
	var target = _get_closest_player()
	var dir = (target.global_position - global_position).normalized() if target != null else GameAxis.forward
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
			var dot = to_player.dot(GameAxis.forward)
			# If player is in front (positive dot along flight direction)
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
