extends SubViewportContainer

## BestiarySimulation.gd - Holographic Live Firing Diorama.
## Spawns the selected hostile from the Nexus, demonstrates authentic flight across the arena,
## fires two realistic volleys targeting a dodging player drone, despawns, and repeats.

const ShipBuilder3D = preload("res://scripts/ShipBuilder3D.gd")
const EnemyScript = preload("res://scripts/Enemy.gd")
const BulletScript = preload("res://scripts/Bullet.gd")

@onready var sub_viewport: SubViewport = $SubViewport
@onready var camera_3d: Camera3D = $SubViewport/Camera3D
@onready var entities_3d: Node3D = $SubViewport/Entities3D
@onready var canvas_2d: Node2D = $SubViewport/Canvas2D
@onready var projectiles_node: Node2D = $SubViewport/Canvas2D/Projectiles
@onready var vfx_node: Node2D = $SubViewport/Canvas2D/VFX
@onready var target_drone: Area2D = $SubViewport/Canvas2D/TargetDrone
@onready var telegraph_line: Line2D = $SubViewport/Canvas2D/TelegraphLine

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

# Arena Dimensions
const ARENA_WIDTH: float = 640.0
const ARENA_HEIGHT: float = 300.0

# Current craft state
var current_entry: Dictionary = {}
var enemy_mesh_root: Node3D = null
var player_mesh_root: Node3D = null

# Turret / Subsystem 3D nodes for animation
var turret_head_3d: Node3D = null
var wing_p_3d: Node3D = null
var wing_s_3d: Node3D = null
var bow_armor_3d: Node3D = null

# Kinematics & Lifecycle
enum State { SPAWNING, TRANSIT_1, SALVO_1, TRANSIT_2, SALVO_2, WARP_OUT, PAUSE_RESET }
var current_state: State = State.PAUSE_RESET
var state_timer: float = 0.0
var flight_time: float = 0.0

# Positions
var enemy_pos: Vector2 = Vector2(540, 150)
var enemy_rot: float = PI # Facing left
var target_prev_pos: Vector2 = Vector2(100, 150)

# Nexus Lightning & Shockwave VFX
var nexus_lightning_points: Array[Vector2] = []
var nexus_lightning_timer: float = 0.0
var shockwave_radius: float = 0.0
var shockwave_alpha: float = 0.0

# Target Drone Shield FX
var shield_hit_flash: float = 0.0
var sniper_aim_progress: float = 0.0

func _ready() -> void:
	camera_3d.position = Vector3(ARENA_WIDTH * 0.5, -ARENA_HEIGHT * 0.5, 300.0)
	camera_3d.size = ARENA_HEIGHT
	
	# Build 3D Player Drone
	_build_player_drone_3d()
	
	# Target Drone setup
	target_drone.collision_layer = 1
	target_drone.collision_mask = 8 # Detects enemy bullets
	target_drone.area_entered.connect(_on_target_drone_hit)
	
	telegraph_line.visible = false
	telegraph_line.width = 2.0
	telegraph_line.default_color = Color(1.0, 0.15, 0.25, 0.85)
	
	# Start dormant until Bestiary view is activated
	deactivate_simulation()

func activate_simulation() -> void:
	if is_instance_valid(target_drone) and not target_drone.is_in_group("player"):
		target_drone.add_to_group("player")
	set_physics_process(true)
	if not current_entry.is_empty():
		_start_nexus_spawn()

func deactivate_simulation() -> void:
	if is_instance_valid(target_drone) and target_drone.is_in_group("player"):
		target_drone.remove_from_group("player")
	set_physics_process(false)
	_clear_projectiles()
	if enemy_mesh_root and is_instance_valid(enemy_mesh_root):
		enemy_mesh_root.visible = false
	if telegraph_line:
		telegraph_line.visible = false

func _exit_tree() -> void:
	deactivate_simulation()

func load_entry(entry: Dictionary) -> void:
	current_entry = entry
	_clear_projectiles()
	_start_nexus_spawn()

func _build_player_drone_3d() -> void:
	if player_mesh_root and is_instance_valid(player_mesh_root):
		player_mesh_root.queue_free()
	
	player_mesh_root = ShipBuilder3D.build_player_ship(1)
	entities_3d.add_child(player_mesh_root)
	player_mesh_root.scale = Vector3(0.85, 0.85, 0.85)

func _start_nexus_spawn() -> void:
	_clear_projectiles()
	telegraph_line.visible = false
	
	# Initial spawn position at right horizon
	var is_boss = (current_entry.get("boss_id", "") != "")
	var spawn_y = (ARENA_HEIGHT * 0.5) if is_boss else randf_range(110.0, 190.0)
	var spawn_x = (ARENA_WIDTH - 45.0) if is_boss else (ARENA_WIDTH - 55.0)
	enemy_pos = Vector2(spawn_x, spawn_y)
	enemy_rot = PI
	flight_time = 0.0
	state_timer = 0.0
	current_state = State.SPAWNING
	
	# Rebuild 3D Enemy Mesh
	if enemy_mesh_root and is_instance_valid(enemy_mesh_root):
		enemy_mesh_root.queue_free()
		enemy_mesh_root = null
	
	var enemy_type = current_entry.get("enemy_type", 0)
	var boss_id = current_entry.get("boss_id", "")
	
	if boss_id != "":
		enemy_mesh_root = ShipBuilder3D.build_boss_ship(boss_id)
		enemy_mesh_root.scale = Vector3(0.55, 0.55, 0.55) # Scale boss to fit diorama
	else:
		enemy_mesh_root = ShipBuilder3D.build_enemy_ship(enemy_type, 0)
		enemy_mesh_root.scale = Vector3(0.9, 0.9, 0.9)
	
	entities_3d.add_child(enemy_mesh_root)
	enemy_mesh_root.visible = false
	
	# Cache dynamic parts
	turret_head_3d = enemy_mesh_root.find_child("TurretHead", true, false)
	wing_p_3d = enemy_mesh_root.find_child("Wing_Port", true, false)
	wing_s_3d = enemy_mesh_root.find_child("Wing_Starboard", true, false)
	bow_armor_3d = enemy_mesh_root.find_child("BowArmor", true, false)
	
	# Trigger Nexus Lightning & Shockwave VFX
	_trigger_nexus_lightning(enemy_pos)
	SoundEffects.play_sfx("laser", 0.08, 5.0)

func _trigger_nexus_lightning(target_pos: Vector2) -> void:
	nexus_lightning_points.clear()
	var start = Vector2(ARENA_WIDTH + 20.0, randf_range(60.0, ARENA_HEIGHT - 60.0))
	nexus_lightning_points.append(start)
	
	var steps = 6
	var curr = start
	for i in range(steps):
		var t = float(i + 1) / float(steps)
		var base = start.lerp(target_pos, t)
		var jitter = Vector2(randf_range(-18, 18), randf_range(-22, 22)) if i < steps - 1 else Vector2.ZERO
		curr = base + jitter
		nexus_lightning_points.append(curr)
	
	nexus_lightning_timer = 0.28
	shockwave_radius = 4.0
	shockwave_alpha = 1.0

var player_flight_time: float = 0.0

func _physics_process(delta: float) -> void:
	flight_time += delta
	player_flight_time += delta
	state_timer += delta
	
	# 1. Update Player Drone Movement (Dodging / Slalom flight)
	_update_target_drone(delta)
	
	# 2. Update VFX (Nexus Lightning, Shockwave, Shield Ripples)
	_update_vfx(delta)
	
	# 3. Process Enemy State Machine
	_process_enemy_lifecycle(delta)
	
	# 4. Sync 3D Meshes with 2D positions
	_sync_3d_meshes(delta)
	
	# 5. Cull out-of-bounds projectiles
	_cull_projectiles()
	
	canvas_2d.queue_redraw()

func _update_target_drone(delta: float) -> void:
	target_prev_pos = target_drone.position
	
	# Organic continuous dodging slalom: vertical sinusoidal weave + subtle forward/back strafing
	var t = player_flight_time * 1.8
	var target_y = (ARENA_HEIGHT * 0.5) + sin(t) * (ARENA_HEIGHT * 0.35)
	var target_x = 95.0 + cos(t * 0.55) * 28.0
	
	target_drone.position = Vector2(target_x, target_y)
	
	# Compute current velocity for lead calculation
	if delta > 0.0:
		var vel = (target_drone.position - target_prev_pos) / delta
		target_drone.set("current_velocity", vel)
	
	# Target drone bank tilt
	var bank = clampf((target_drone.position.y - target_prev_pos.y) * 0.08, -0.4, 0.4)
	target_drone.rotation = bank

func _update_vfx(delta: float) -> void:
	if nexus_lightning_timer > 0.0:
		nexus_lightning_timer -= delta
	
	if shockwave_alpha > 0.0:
		shockwave_radius += 140.0 * delta
		shockwave_alpha = maxf(0.0, shockwave_alpha - delta * 3.2)
	
	if shield_hit_flash > 0.0:
		shield_hit_flash = maxf(0.0, shield_hit_flash - delta * 4.0)

func _process_enemy_lifecycle(delta: float) -> void:
	var base_speed = current_entry.get("speed", 120.0)
	var flight_style = current_entry.get("flight_style", "DIRECT_ADVANCE")
	
	match current_state:
		State.SPAWNING:
			if state_timer >= 0.25:
				if enemy_mesh_root:
					enemy_mesh_root.visible = true
					var base_scale = 0.55 if (current_entry.get("boss_id", "") != "") else 0.9
					enemy_mesh_root.scale = Vector3(base_scale, base_scale, base_scale)
				current_state = State.TRANSIT_1
				state_timer = 0.0
		
		State.TRANSIT_1:
			_apply_flight_movement(delta, base_speed, flight_style)
			
			# Sniper telegraph aiming
			if current_entry.get("enemy_type", -1) == EnemyScript.EnemyType.SNIPER:
				_update_sniper_telegraph(state_timer / 1.1)
			
			if state_timer >= 1.0:
				current_state = State.SALVO_1
				state_timer = 0.0
				_execute_salvo(1)
		
		State.SALVO_1:
			_apply_flight_movement(delta, base_speed * 0.85, flight_style)
			if state_timer >= 0.5:
				current_state = State.TRANSIT_2
				state_timer = 0.0
		
		State.TRANSIT_2:
			_apply_flight_movement(delta, base_speed, flight_style)
			
			if current_entry.get("enemy_type", -1) == EnemyScript.EnemyType.SNIPER:
				_update_sniper_telegraph(state_timer / 1.1)
			
			if state_timer >= 1.3:
				current_state = State.SALVO_2
				state_timer = 0.0
				_execute_salvo(2)
		
		State.SALVO_2:
			_apply_flight_movement(delta, base_speed * 0.85, flight_style)
			if state_timer >= 0.8:
				current_state = State.WARP_OUT
				state_timer = 0.0
		
		State.WARP_OUT:
			var is_anchored_or_boss = (flight_style in ["FORWARD_ANCHOR", "STANDOFF_SENTRY", "FLAGSHIP_CAPITAL"])
			if not is_anchored_or_boss:
				_apply_flight_movement(delta, base_speed * 1.2, flight_style)
			else:
				_apply_flight_movement(delta, 0.0, flight_style)
			if enemy_mesh_root:
				var alpha_scale = maxf(0.0, 1.0 - state_timer * 2.5)
				var base_scale = 0.55 if (current_entry.get("boss_id", "") != "") else 0.9
				enemy_mesh_root.scale = Vector3(alpha_scale, alpha_scale, alpha_scale) * base_scale
			if state_timer >= 0.4:
				if enemy_mesh_root:
					enemy_mesh_root.visible = false
				current_state = State.PAUSE_RESET
				state_timer = 0.0
		
		State.PAUSE_RESET:
			if state_timer >= 0.55:
				_start_nexus_spawn()

func _apply_flight_movement(delta: float, spd: float, style: String) -> void:
	var move_x = -spd * delta
	var move_y = 0.0
	
	match style:
		"FLAGSHIP_CAPITAL":
			var station_x = 490.0
			if enemy_pos.x > station_x:
				move_x = -spd * delta
			else:
				move_x = 0.0
			move_y = sin(flight_time * 0.9) * 45.0 * delta
		
		"STANDOFF_SENTRY":
			var station_x = 480.0
			if enemy_pos.x > station_x:
				move_x = -spd * delta
			else:
				move_x = 0.0
			move_y = sin(flight_time * 1.2) * 35.0 * delta
		
		"FORWARD_ANCHOR":
			var station_x = 410.0
			if enemy_pos.x > station_x:
				move_x = -spd * delta
			else:
				move_x = 0.0
			move_y = sin(flight_time * 1.2) * 30.0 * delta
		
		"SERPENTINE_SWARM":
			move_y = sin(flight_time * 3.8) * 85.0 * delta
		
		"DIVE_BOMB":
			if flight_time > 0.8 and flight_time < 2.2:
				move_y = (target_drone.position.y - enemy_pos.y) * 1.5 * delta
				move_x *= 1.3
		
		"LATERAL_HOMING":
			move_y = (target_drone.position.y - enemy_pos.y) * 1.2 * delta
		
		"QUANTUM_BLINK":
			if fmod(flight_time, 2.0) < delta:
				enemy_pos.y = randf_range(80.0, ARENA_HEIGHT - 80.0)
				_trigger_nexus_lightning(enemy_pos)
		
		_:
			move_y = sin(flight_time * 1.2) * 15.0 * delta
	
	enemy_pos.x += move_x
	enemy_pos.y = clampf(enemy_pos.y + move_y, 40.0, ARENA_HEIGHT - 40.0)
	
	# Heading orientation: craft always face downfield toward the player (left = PI)
	# with smooth aerodynamic banking (never snapping 90° up or down!)
	if move_x < -2.0:
		var bank_angle = clampf(atan2(move_y, absf(move_x)), -0.45, 0.45)
		enemy_rot = PI + bank_angle
	else:
		var idle_bank = clampf(sin(flight_time * 1.8) * 0.05, -0.05, 0.05)
		enemy_rot = PI + idle_bank

func _update_sniper_telegraph(progress: float) -> void:
	telegraph_line.visible = true
	telegraph_line.clear_points()
	telegraph_line.add_point(enemy_pos)
	
	var aim_dir = _calculate_lead_vector(enemy_pos, 950.0)
	telegraph_line.add_point(enemy_pos + aim_dir * 600.0)
	
	var col = Color(1.0, 0.15, 0.25, clampf(progress * 0.9, 0.1, 0.95))
	telegraph_line.default_color = col
	telegraph_line.width = 1.0 + progress * 2.0

func _execute_salvo(volley_num: int) -> void:
	telegraph_line.visible = false
	var enemy_type = current_entry.get("enemy_type", -1)
	var boss_id = current_entry.get("boss_id", "")
	
	var base_spd = 340.0
	var oncoming = Vector2.LEFT
	
	if boss_id != "":
		_fire_boss_weapons(boss_id, volley_num)
		return
	
	match enemy_type:
		EnemyScript.EnemyType.SCOUT:
			var aim = _calculate_lead_vector(enemy_pos, base_spd)
			_spawn_bullet(enemy_pos + aim * 14.0, aim, base_spd)
			get_tree().create_timer(0.12).timeout.connect(func():
				if is_instance_valid(self):
					var a2 = _calculate_lead_vector(enemy_pos, base_spd)
					_spawn_bullet(enemy_pos + a2 * 14.0, a2, base_spd)
			)
			SoundEffects.play_sfx("laser", 0.06, -2.0)
		
		EnemyScript.EnemyType.INTERCEPTOR:
			var int_spd = base_spd * 1.15
			var direct = (target_drone.position - enemy_pos).normalized()
			var left_arc = direct.rotated(-0.91)
			var right_arc = direct.rotated(0.91)
			_spawn_curving_bullet(enemy_pos + Vector2(0, -12), left_arc, 5.5, int_spd)
			_spawn_curving_bullet(enemy_pos + Vector2(0, 12), right_arc, 5.5, int_spd)
			if volley_num == 2:
				get_tree().create_timer(0.14).timeout.connect(func():
					if is_instance_valid(self):
						_spawn_bullet(enemy_pos, direct, int_spd * 1.08)
				)
			SoundEffects.play_sfx("laser", 0.06, -1.0)
		
		EnemyScript.EnemyType.BOMBER:
			var direct = (target_drone.position - enemy_pos).normalized()
			if volley_num == 1:
				# 3-Way Purple Fan Spread
				for angle in [-15.0, 0.0, 15.0]:
					var d = direct.rotated(deg_to_rad(angle))
					_spawn_bullet(enemy_pos + d * 18.0, d, base_spd * 0.92)
				SoundEffects.play_sfx("laser", 0.08, -3.0)
			else:
				# Solo Emerald Proximity Cluster Mortar
				_spawn_cluster_mortar(enemy_pos + direct * 20.0, direct, base_spd * 0.9)
				SoundEffects.play_sfx("laser", 0.12, -4.0)
		
		EnemyScript.EnemyType.SNIPER:
			var aim = _calculate_lead_vector(enemy_pos, 950.0)
			_spawn_sniper_slug(enemy_pos + aim * 24.0, aim)
			SoundEffects.play_sfx("laser", 0.15, 3.0)
		
		EnemyScript.EnemyType.SHIELD_FRIGATE:
			_spawn_radial_burst(6, base_spd * 0.8)
			SoundEffects.play_sfx("bonus", 0.08, -2.0)
		
		EnemyScript.EnemyType.HEAVY_CRUISER:
			var direct = (target_drone.position - enemy_pos).normalized()
			for angle in [-24.0, -12.0, 0.0, 12.0, 24.0]:
				var d = direct.rotated(deg_to_rad(angle))
				_spawn_bullet(enemy_pos + d * 22.0, d, base_spd * 1.05)
			SoundEffects.play_sfx("laser", 0.1, -4.0)
		
		EnemyScript.EnemyType.KNIGHT_VANGUARD:
			var aim = _calculate_lead_vector(enemy_pos, base_spd * 1.05)
			_spawn_bullet(enemy_pos + Vector2(0, -10), aim, base_spd * 1.05)
			_spawn_bullet(enemy_pos + Vector2(0, 10), aim, base_spd * 1.05)
			SoundEffects.play_sfx("laser", 0.08, -1.0)
		
		EnemyScript.EnemyType.PHANTOM:
			var direct = (target_drone.position - enemy_pos).normalized()
			_spawn_wave_bullet(enemy_pos, direct, 0.0, base_spd)
			SoundEffects.play_sfx("laser", 0.07, 1.5)
		
		EnemyScript.EnemyType.DRONE_CARRIER:
			for i in range(2):
				var off_y = -18.0 if i == 0 else 18.0
				var d = Vector2.LEFT.rotated(randf_range(-0.25, 0.25))
				_spawn_wave_bullet(enemy_pos + Vector2(-15, off_y), d, randf_range(0, TAU), base_spd * 0.85)
			SoundEffects.play_sfx("laser", 0.08, 4.0)
		
		EnemyScript.EnemyType.TURRET_PLATFORM:
			var direct = (target_drone.position - enemy_pos).normalized()
			for i in range(3):
				get_tree().create_timer(i * 0.09).timeout.connect(func():
					if is_instance_valid(self):
						var d = (target_drone.position - enemy_pos).normalized()
						_spawn_bullet(enemy_pos + d * 16.0, d, base_spd * 1.1)
				)
			SoundEffects.play_sfx("laser", 0.06, 0.0)
		
		EnemyScript.EnemyType.WARP_STALKER:
			var direct = (target_drone.position - enemy_pos).normalized()
			_spawn_wave_bullet(enemy_pos + Vector2(0, -10), direct, 0.0, base_spd * 0.95)
			_spawn_wave_bullet(enemy_pos + Vector2(0, 10), direct, PI, base_spd * 0.95)
			SoundEffects.play_sfx("laser", 0.07, 2.0)
		
		EnemyScript.EnemyType.DRAINER_LEECH:
			var direct = (target_drone.position - enemy_pos).normalized()
			_spawn_bullet(enemy_pos + direct * 14.0, direct, base_spd * 1.12)
			SoundEffects.play_sfx("laser", 0.06, -2.0)
		
		EnemyScript.EnemyType.MISSILE_CORVETTE:
			var direct = (target_drone.position - enemy_pos).normalized()
			_spawn_homing_missile(enemy_pos + Vector2(0, -14), direct.rotated(-0.75), base_spd * 0.9)
			_spawn_homing_missile(enemy_pos + Vector2(0, 14), direct.rotated(0.75), base_spd * 0.9)
			SoundEffects.play_sfx("laser", 0.08, -1.0)
		
		EnemyScript.EnemyType.MINE_TETHER:
			_spawn_radial_burst(6, base_spd * 0.85)
			SoundEffects.play_sfx("laser", 0.08, -3.0)
		
		EnemyScript.EnemyType.CARGO_HAULER:
			_spawn_bullet(enemy_pos + Vector2(-15, 0), Vector2.LEFT, base_spd * 0.85)
			SoundEffects.play_sfx("laser", 0.07, -3.0)
		
		_:
			var direct = (target_drone.position - enemy_pos).normalized()
			_spawn_bullet(enemy_pos + direct * 14.0, direct, base_spd)
			SoundEffects.play_sfx("laser", 0.06, -2.0)

func _fire_boss_weapons(boss_id: String, volley_num: int) -> void:
	var direct = (target_drone.position - enemy_pos).normalized()
	var base_spd = 350.0
	
	if "corvus" in boss_id:
		# Dual Heavy Bow Railguns + Wing Sweeps
		_spawn_bullet(enemy_pos + Vector2(-20, -18), direct, base_spd * 1.15)
		_spawn_bullet(enemy_pos + Vector2(-20, 18), direct, base_spd * 1.15)
		if volley_num == 2:
			for a in [-20.0, 0.0, 20.0]:
				_spawn_bullet(enemy_pos, direct.rotated(deg_to_rad(a)), base_spd)
		SoundEffects.play_sfx("laser", 0.12, -2.0)
	
	elif "goliath" in boss_id:
		# Heavy Carrier Flak + Seeker Rockets
		_spawn_homing_missile(enemy_pos + Vector2(-15, -22), direct.rotated(-0.6), base_spd * 0.88)
		_spawn_homing_missile(enemy_pos + Vector2(-15, 22), direct.rotated(0.6), base_spd * 0.88)
		SoundEffects.play_sfx("laser", 0.1, -3.0)
	
	else: # Ouroboros
		# Bullet Vortex Arc
		for a in [-32.0, -16.0, 0.0, 16.0, 32.0]:
			var d = direct.rotated(deg_to_rad(a))
			_spawn_wave_bullet(enemy_pos, d, deg_to_rad(a * 2.0), base_spd * 0.95)
		SoundEffects.play_sfx("laser", 0.12, 1.0)

# --- Ballistic Spawn Helpers ---

func _calculate_lead_vector(origin: Vector2, proj_speed: float) -> Vector2:
	var target_pos = target_drone.position
	var target_vel = target_drone.get("current_velocity")
	if target_vel == null:
		target_vel = Vector2.ZERO
	
	var d = target_pos - origin
	var t = clampf(d.length() / maxf(100.0, proj_speed), 0.1, 0.8)
	var predicted = target_pos + target_vel * t * 0.8
	var lead_dir = (predicted - origin).normalized()
	return lead_dir if lead_dir.x < 0.1 else Vector2.LEFT

func _spawn_bullet(pos: Vector2, dir: Vector2, spd: float) -> void:
	var b = bullet_scene.instantiate()
	projectiles_node.add_child(b)
	b.setup(pos, dir, true, 1.0)
	b.speed = spd

func _spawn_curving_bullet(pos: Vector2, dir: Vector2, ang_spd: float, spd: float) -> void:
	var b = bullet_scene.instantiate()
	projectiles_node.add_child(b)
	b.pattern = BulletScript.Pattern.CURVING_ARC
	b.curve_angular_speed = ang_spd
	b.curve_delay = 0.28
	b.curve_turn_time = 0.60
	b.setup(pos, dir, true, 1.0)
	b.speed = spd

func _spawn_cluster_mortar(pos: Vector2, dir: Vector2, spd: float) -> void:
	var b = bullet_scene.instantiate()
	projectiles_node.add_child(b)
	b.pattern = BulletScript.Pattern.CLUSTER_BURST
	b.cluster_fuse = 1.4
	b.setup(pos, dir, true, 2.0)
	b.speed = spd

func _spawn_homing_missile(pos: Vector2, dir: Vector2, spd: float) -> void:
	var b = bullet_scene.instantiate()
	projectiles_node.add_child(b)
	b.pattern = BulletScript.Pattern.HOMING
	b.homing_strength = 3.2
	b.homing_duration = 1.8
	b.setup(pos, dir, true, 1.0)
	b.speed = spd

func _spawn_wave_bullet(pos: Vector2, dir: Vector2, phase: float, spd: float) -> void:
	var b = bullet_scene.instantiate()
	projectiles_node.add_child(b)
	b.pattern = BulletScript.Pattern.SINE_WAVE
	b.wave_phase = phase
	b.wave_frequency = 9.0
	b.wave_amplitude = 30.0
	b.setup(pos, dir, true, 2.0)
	b.speed = spd

func _spawn_sniper_slug(pos: Vector2, dir: Vector2) -> void:
	var b = bullet_scene.instantiate()
	projectiles_node.add_child(b)
	b.setup(pos, dir, true, 2.5)
	b.speed = 950.0
	b.glow_color = Color(1.0, 0.1, 0.2, 1.0)
	b.scale = Vector2(2.4, 1.2)

func _spawn_radial_burst(count: int, spd: float) -> void:
	for i in range(count):
		var angle = (float(i) / count) * TAU
		var d = Vector2(cos(angle), sin(angle))
		_spawn_bullet(enemy_pos + d * 14.0, d, spd)

func _on_target_drone_hit(area: Area2D) -> void:
	if area and is_instance_valid(area) and area.is_in_group("bullet"):
		shield_hit_flash = 1.0
		SoundEffects.play_sfx("bonus", 0.04, 6.0)
		if area.has_method("recycle"):
			area.recycle()
		else:
			area.queue_free()

func _cull_projectiles() -> void:
	for child in projectiles_node.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		var p = child.position
		if p.x < -40.0 or p.x > ARENA_WIDTH + 40.0 or p.y < -40.0 or p.y > ARENA_HEIGHT + 40.0:
			if child.has_method("recycle"):
				child.recycle()
			else:
				child.queue_free()

func _clear_projectiles() -> void:
	for child in projectiles_node.get_children():
		if is_instance_valid(child):
			child.queue_free()

func _sync_3d_meshes(delta: float) -> void:
	# 1. Sync Player Drone 3D Mesh
	if player_mesh_root and is_instance_valid(player_mesh_root):
		var p_pos = target_drone.position
		player_mesh_root.position = Vector3(p_pos.x, -p_pos.y, 0.0)
		var bank_tilt = target_drone.rotation
		player_mesh_root.transform.basis = ShipBuilder3D.compute_tilted_basis(0.0, -bank_tilt * 0.8, 0.0)
	
	# 2. Sync Enemy 3D Mesh
	if enemy_mesh_root and is_instance_valid(enemy_mesh_root) and enemy_mesh_root.visible:
		enemy_mesh_root.position = Vector3(enemy_pos.x, -enemy_pos.y, 0.0)
		enemy_mesh_root.transform.basis = ShipBuilder3D.compute_tilted_basis(-enemy_rot, 0.0, 0.0)
		
		# Articulate Turret head toward target drone
		if turret_head_3d and is_instance_valid(turret_head_3d):
			var to_target = target_drone.position - enemy_pos
			var target_angle = to_target.angle() - enemy_rot
			turret_head_3d.rotation.y = -target_angle
