extends Area2D

## Bullet.gd - High-readability hyper-velocity projectile with Cyberpunk PBR aesthetics.
## Renders aerodynamic tapered plasma darts, mach diamonds, ionization wake streaks,
## and unstable enemy plasma containment spheres with coronal aura rings.

const ImpactFlashScript = preload("res://scripts/ImpactFlash.gd")

static var _cached_players: Array[Node] = []
static var _cached_players_frame: int = -1

static func get_active_players(tree: SceneTree) -> Array[Node]:
	if not tree:
		return []
	var cur_frame = Engine.get_physics_frames()
	if _cached_players_frame == cur_frame:
		return _cached_players
	_cached_players_frame = cur_frame
	_cached_players = tree.get_nodes_in_group("player")
	return _cached_players

static func get_active_player(tree: SceneTree) -> Node2D:
	var plist = get_active_players(tree)
	if not plist.is_empty() and is_instance_valid(plist[0]) and not plist[0].is_queued_for_deletion():
		return plist[0]
	return null

@export var is_enemy: bool = false:
	set(value):
		is_enemy = value
		_update_colors()
		queue_redraw()

@export var damage: float = 1.0
@export var speed: float = 540.0
@export var direction: Vector2 = Vector2.RIGHT

enum Pattern {
	LINEAR,
	HOMING,
	SINE_WAVE,
	CURVING_ARC,
	CLUSTER_BURST
}

@export var pattern: Pattern = Pattern.LINEAR:
	set(value):
		pattern = value
		_update_colors()
		queue_redraw()

# Pattern Parameters
var curve_delay: float = 0.32
var curve_turn_time: float = 0.55
var curve_angular_speed: float = 5.5
var curve_duration: float = 0.87
var curve_timer: float = 0.0
var max_curve_angle: float = 1.22 # ~70 degrees maximum deflection cap

var homing_strength: float = 2.4
var homing_duration: float = 1.6
var homing_timer: float = 0.0

var wave_frequency: float = 8.0
var wave_amplitude: float = 38.0
var wave_phase: float = 0.0
var base_origin: Vector2 = Vector2.ZERO
var base_direction: Vector2 = Vector2.RIGHT

var cluster_fuse: float = 2.2
var cluster_fuse_timer: float = 0.0
var cluster_count: int = 5
var has_detonated: bool = false

var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var glow_color: Color = Color(0.1, 0.94, 1.0, 1.0)
var length: float = 22.0
var radius: float = 4.5

static var active_player_bullet_count: int = 0
static var last_release_sound_frame: int = -1
static var _player_pool: Array[Node] = []
static var _enemy_pool: Array[Node] = []
static var _bullet_scene: PackedScene = null

static func _get_bullet_scene() -> PackedScene:
	if _bullet_scene == null:
		_bullet_scene = load("res://scenes/Bullet.tscn")
	return _bullet_scene

static func acquire(parent: Node, p_is_enemy: bool = false) -> Node:
	var pool = _enemy_pool if p_is_enemy else _player_pool
	while not pool.is_empty():
		var b = pool.pop_back()
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			if b.get_parent() != parent:
				if b.get_parent() != null:
					b.get_parent().remove_child(b)
				parent.add_child(b)
			b.is_enemy = p_is_enemy
			b.reset_for_pool()
			return b
	var scene = _get_bullet_scene()
	var new_b = scene.instantiate()
	new_b.is_enemy = p_is_enemy
	parent.add_child(new_b)
	return new_b

func reset_for_pool() -> void:
	traveled_distance = 0.0
	has_split = false
	is_suspended = false
	is_spectral = false
	suspension_timer = 0.0
	suspension_ship = null
	pulse_time = 0.0
	feynman_trail_timer = 0.0
	feynman_last_pos = Vector2.INF
	is_crit = false
	is_cw_dart = false
	is_casimir = false
	pierce_count = 0
	has_detonated = false
	cluster_fuse_timer = 0.0
	homing_timer = 0.0
	curve_timer = 0.0
	base_direction = Vector2.ZERO
	direction = Vector2.RIGHT
	scale = Vector2.ONE
	rotation = 0.0
	projectile_modifiers = []
	shooter = null
	visible = true
	set_physics_process(true)
	
	if not is_in_group("bullet"):
		add_to_group("bullet")
	
	# Strip lingering metadata so previous life state never bleeds over
	if has_meta("is_crit"): remove_meta("is_crit")
	if has_meta("is_cw_dart"): remove_meta("is_cw_dart")
	if has_meta("is_casimir"): remove_meta("is_casimir")
	if has_meta("has_feynman"): remove_meta("has_feynman")
	if has_meta("pierce_count"): remove_meta("pierce_count")
	if has_meta("shooter"): remove_meta("shooter")
	if has_meta("casimir_base_damage"): remove_meta("casimir_base_damage")
	if has_meta("casimir_base_scale"): remove_meta("casimir_base_scale")
	
	if not is_enemy:
		active_player_bullet_count += 1
		collision_layer = 2
		collision_mask = 0
		monitoring = false
		monitorable = true
	else:
		collision_layer = 8
		collision_mask = 1
		monitoring = true
		monitorable = true

func recycle() -> void:
	if is_queued_for_deletion():
		return
	visible = false
	set_physics_process(false)
	monitoring = false
	monitorable = false
	global_position = Vector2(-9999, -9999)
	if is_in_group("bullet"):
		remove_from_group("bullet")
	if is_enemy:
		_enemy_pool.append(self)
	else:
		active_player_bullet_count = max(0, active_player_bullet_count - 1)
		_player_pool.append(self)

# Synergy & ballistic variables
var traveled_distance: float = 0.0
var has_split: bool = false
var is_suspended: bool = false
var is_spectral: bool = false
var suspension_timer: float = 0.0
var suspension_ship: CharacterBody2D = null
var pulse_time: float = 0.0

var shooter: Node2D = null
var projectile_modifiers: Array = []
var has_feynman: bool = false
var feynman_last_pos: Vector2 = Vector2.INF
var feynman_trail_timer: float = 0.0
var is_crit: bool = false
var is_cw_dart: bool = false
var is_casimir: bool = false
var pierce_count: int = 0

func _ready() -> void:
	add_to_group("bullet")
	_update_colors()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	if not is_enemy:
		active_player_bullet_count += 1
		monitoring = false
		monitorable = not is_suspended

func _exit_tree() -> void:
	if not is_enemy:
		active_player_bullet_count = max(0, active_player_bullet_count - 1)

func _update_colors() -> void:
	if is_enemy:
		collision_layer = 8
		collision_mask = 1
		monitoring = true
		monitorable = true
		match pattern:
			Pattern.HOMING:
				core_color = Color(1.0, 0.98, 0.9, 1.0)
				glow_color = Color(1.0, 0.55, 0.1, 1.0) # Amber rocket fire
				speed = 400.0
				length = 18.0
				radius = 5.0
			Pattern.SINE_WAVE:
				core_color = Color(0.98, 0.95, 1.0, 1.0)
				glow_color = Color(0.72, 0.25, 1.0, 1.0) # Ethereal Quantum Violet
				speed = 370.0
				length = 16.0
				radius = 6.0
			Pattern.CURVING_ARC:
				core_color = Color(1.0, 1.0, 0.9, 1.0)
				glow_color = Color(1.0, 0.48, 0.05, 1.0) # Saturated Solar Flare Orange
				speed = 380.0
				length = 22.0
				radius = 6.2
			Pattern.CLUSTER_BURST:
				core_color = Color(0.95, 1.0, 0.95, 1.0)
				glow_color = Color(0.2, 1.0, 0.45, 1.0) # Radiant Emerald
				speed = 340.0
				length = 20.0
				radius = 8.5
			_:
				core_color = Color(1.0, 0.95, 0.98, 1.0)
				glow_color = Color(1.0, 0.08, 0.55, 0.95) # Cyberpunk Hot Magenta / Laser Crimson
				speed = 420.0
				length = 16.0
				radius = 5.5
	else:
		core_color = Color(0.92, 1.0, 1.0, 1.0)
		glow_color = Color(0.0, 0.94, 1.0, 0.95) # Hyper-luminous Cyan
		speed = 540.0
		length = 16.0
		radius = 2.8
		collision_layer = 2
		collision_mask = 0
		monitoring = false
		monitorable = not is_suspended

func setup(p_pos: Vector2, p_dir: Vector2, p_is_enemy: bool = false, p_dmg: float = 1.0) -> void:
	global_position = p_pos
	base_origin = p_pos
	direction = p_dir.normalized()
	base_direction = direction
	is_enemy = p_is_enemy
	damage = p_dmg
	rotation = direction.angle()
	traveled_distance = 0.0
	has_split = false
	_update_colors()
	queue_redraw()

func _physics_process(delta: float) -> void:
	pulse_time += delta
	
	if is_suspended:
		suspension_timer += delta
		var should_release = false
		if is_instance_valid(suspension_ship):
			if not suspension_ship.is_firing or suspension_timer >= 2.0:
				should_release = true
		else:
			should_release = true
		
		if should_release:
			is_suspended = false
			monitoring = false
			monitorable = true
			speed *= 1.45
			if SoundEffects != null and Engine.get_physics_frames() != last_release_sound_frame:
				last_release_sound_frame = Engine.get_physics_frames()
				SoundEffects.play_sfx("laser", 0.15, -2.0)
			queue_redraw()
		else:
			if (Engine.get_physics_frames() % 4) == (get_instance_id() % 4):
				queue_redraw()
			return
	
	# Projectile modifier hooks (e.g. Gravitational Lensing, Birefringence Prism, Feynman Propagator)
	if not is_enemy:
		if projectile_modifiers.is_empty():
			if is_instance_valid(shooter) and "active_projectile_modifiers" in shooter:
				projectile_modifiers = shooter.active_projectile_modifiers
			elif is_instance_valid(shooter) and "active_modifiers" in shooter:
				projectile_modifiers = shooter.active_modifiers
			else:
				var player = get_active_player(get_tree())
				if is_instance_valid(player):
					if "active_projectile_modifiers" in player:
						projectile_modifiers = player.active_projectile_modifiers
					elif "active_modifiers" in player:
						projectile_modifiers = player.active_modifiers
		
		for mod in projectile_modifiers:
			if mod.id == "birefringence_prism" and has_split:
				continue
			mod.on_projectile_tick(self, delta)
	
	# Ballistic Kinematics by Pattern
	if is_enemy:
		match pattern:
			Pattern.HOMING:
				homing_timer += delta
				# Eject outward from missile tube before thrusters lock on
				if homing_timer >= 0.20 and homing_timer < homing_duration:
					var target = _get_closest_player()
					if target != null and is_instance_valid(target):
						var desired_dir = (target.global_position - global_position).normalized()
						direction = direction.slerp(desired_dir, homing_strength * delta).normalized()
						rotation = direction.angle()
				var step = speed * delta
				global_position += direction * step
				traveled_distance += step
				queue_redraw()
			
			Pattern.SINE_WAVE:
				traveled_distance += speed * delta
				var perp = Vector2(-base_direction.y, base_direction.x)
				var lateral_offset = sin(pulse_time * wave_frequency + wave_phase) * wave_amplitude
				global_position = base_origin + base_direction * traveled_distance + perp * lateral_offset
				var tangent = (base_direction * speed + perp * (wave_frequency * wave_amplitude * cos(pulse_time * wave_frequency + wave_phase))).normalized()
				rotation = tangent.angle()
			
			Pattern.CURVING_ARC:
				curve_timer += delta
				if base_direction == Vector2.ZERO:
					base_direction = direction
				# Phase 1: Fly outward and away from player along initial wide angle
				# Phase 2: Active re-aiming curve towards the player
				if curve_timer >= curve_delay and curve_timer < (curve_delay + curve_turn_time):
					var vp_rect = GameAxis.get_viewport_rect() if GameAxis != null else Rect2(0, 0, 1280, 720)
					var is_offscreen = not vp_rect.grow(16.0).has_point(global_position)
					# Off-Screen Curve Prohibition: Do not curve while outside visible playfield
					if not is_offscreen:
						var target = _get_closest_player()
						if target != null and is_instance_valid(target):
							var desired_dir = (target.global_position - global_position).normalized()
							direction = direction.slerp(desired_dir, curve_angular_speed * delta).normalized()
							# Maximum Deflection Cap: Prevent bullet from turning more than max_curve_angle from base_direction
							var angle_diff = base_direction.angle_to(direction)
							if absf(angle_diff) > max_curve_angle:
								direction = base_direction.rotated(signf(angle_diff) * max_curve_angle)
							rotation = direction.angle()
						else:
							direction = direction.rotated(curve_angular_speed * delta)
							var angle_diff = base_direction.angle_to(direction)
							if absf(angle_diff) > max_curve_angle:
								direction = base_direction.rotated(signf(angle_diff) * max_curve_angle)
							rotation = direction.angle()
				# Phase 3: Fly locked on the re-aimed trajectory straight into the player's airspace
				var step = speed * delta
				global_position += direction * step
				traveled_distance += step
			
			Pattern.CLUSTER_BURST:
				cluster_fuse_timer += delta
				var decel_factor = clampf(1.0 - (cluster_fuse_timer / cluster_fuse) * 0.35, 0.65, 1.0)
				var step = speed * decel_factor * delta
				global_position += direction * step
				traveled_distance += step
				
				var should_detonate = false
				# Proximity airburst: if armed (flew past 0.35s) and within 140px of player
				if cluster_fuse_timer >= 0.35:
					var target = _get_closest_player()
					if target != null and is_instance_valid(target):
						if global_position.distance_to(target.global_position) <= 140.0:
							should_detonate = true
				
				# Maximum fuse timeout fallback (travels deep into player sector)
				if cluster_fuse_timer >= cluster_fuse:
					should_detonate = true
				
				if should_detonate and not has_detonated:
					_detonate_cluster()
					return
			
			_:
				var step = speed * delta
				global_position += direction * step
				traveled_distance += step
	else:
		var step = speed * delta
		global_position += direction * step
		traveled_distance += step
	
	if GameAxis != null and GameAxis.is_out_of_bounds(global_position, 60.0):
		recycle()

func _draw() -> void:
	if is_enemy:
		match pattern:
			Pattern.HOMING:
				_draw_homing_missile()
			Pattern.SINE_WAVE:
				_draw_quantum_wavepacket()
			Pattern.CURVING_ARC:
				_draw_crescent_arc()
			Pattern.CLUSTER_BURST:
				_draw_cluster_mortar()
			_:
				_draw_enemy_plasma_orb()
	else:
		_draw_player_needle_dart()
		if is_suspended:
			_draw_suspension_field()

func _draw_suspension_field() -> void:
	# High-tech magnetic stasis containment bottle holding the primed dart
	var pulse = 1.0 + sin(suspension_timer * 16.0) * 0.22
	var stasis_r = maxf(length * 0.75, radius * 3.4) * pulse
	
	# 1. Outer Translucent Antimatter Stasis Bubble
	draw_circle(Vector2.ZERO, stasis_r, Color(1.0, 0.2, 0.55, 0.2))
	draw_circle(Vector2.ZERO, stasis_r * 0.55, Color(1.0, 0.35, 0.7, 0.28))
	
	# 2. Counter-Rotating Magnetic Flux Brackets
	var rot_a = suspension_timer * 9.0
	var arc_r = length * 0.62 * (1.0 + sin(suspension_timer * 24.0) * 0.08)
	draw_arc(Vector2.ZERO, arc_r, rot_a, rot_a + PI * 0.55, 12, Color(1.0, 0.45, 0.8, 0.8), 1.8, true)
	draw_arc(Vector2.ZERO, arc_r, rot_a + PI, rot_a + PI * 1.55, 12, Color(1.0, 0.45, 0.8, 0.8), 1.8, true)
	draw_arc(Vector2.ZERO, arc_r * 0.82, -rot_a * 1.3, -rot_a * 1.3 + PI * 0.4, 10, Color(1.0, 0.8, 0.95, 0.65), 1.2, true)
	draw_arc(Vector2.ZERO, arc_r * 0.82, -rot_a * 1.3 + PI, -rot_a * 1.3 + PI * 1.4, 10, Color(1.0, 0.8, 0.95, 0.65), 1.2, true)

func _draw_player_needle_dart() -> void:
	var half_len = length * 0.5
	var tip = Vector2(half_len + 4.0, 0.0)
	var shoulder_x = half_len * 0.3
	var r = radius
	var has_pierce = is_spectral or (has_meta("pierce_count") and get_meta("pierce_count") > 0)
	
	# 0. Quantum Phase Shroud (Spectral Wavepacket Resonance Envelope)
	if has_pierce:
		var phase_poly = PackedVector2Array([
			tip + Vector2(7.0, 0.0),
			Vector2(shoulder_x, -r * 3.0),
			Vector2(-half_len * 1.0, -r * 1.6),
			Vector2(-half_len * 2.5, 0.0),
			Vector2(-half_len * 1.0, r * 1.6),
			Vector2(shoulder_x, r * 3.0)
		])
		var phase_col = Color(0.78, 0.35, 1.0, 0.28)
		draw_colored_polygon(phase_poly, phase_col)
		
		# Twin phase-interference resonance streaks along the flanks
		var flank_phase = Color(0.85, 0.5, 1.0, 0.65)
		draw_line(Vector2(shoulder_x + 1.0, -r * 2.2), Vector2(-half_len * 1.4, -r * 1.0), flank_phase, 1.4, true)
		draw_line(Vector2(shoulder_x + 1.0, r * 2.2), Vector2(-half_len * 1.4, r * 1.0), flank_phase, 1.4, true)
	
	# 0B. Feynman Propagator Ionization Envelope & Path Integral Filament (∿)
	if has_meta("has_feynman") and get_meta("has_feynman"):
		var feynman_halo = Color(1.0, 0.35, 0.85, 0.30)
		var feynman_poly = PackedVector2Array([
			tip + Vector2(6.0, 0.0),
			Vector2(shoulder_x + 1.0, -r * 2.7),
			Vector2(-half_len * 1.1, -r * 1.6),
			Vector2(-half_len * 3.0, 0.0),
			Vector2(-half_len * 1.1, r * 1.6),
			Vector2(shoulder_x + 1.0, r * 2.7)
		])
		draw_colored_polygon(feynman_poly, feynman_halo)
		
		# Propagator Wiggle Filament along the bullet flanks
		var f_phase = pulse_time * 26.0
		var f_pts = PackedVector2Array()
		for fi in range(6):
			var fx = lerpf(-half_len * 2.2, tip.x, float(fi) / 5.0)
			var fy = sin(fx * 0.28 + f_phase) * (r * 0.75)
			f_pts.append(Vector2(fx, fy))
		draw_polyline(f_pts, Color(1.0, 0.85, 1.0, 0.75), 1.5, true)
	
	# 1. Outer Translucent Ionization Shroud (Shock Cone)
	var outer_poly = PackedVector2Array([
		tip + Vector2(5.0, 0.0),
		Vector2(shoulder_x, -r * 2.2),
		Vector2(-half_len * 0.8, -r * 1.1),
		Vector2(-half_len * 2.2, 0.0),
		Vector2(-half_len * 0.8, r * 1.1),
		Vector2(shoulder_x, r * 2.2)
	])
	var shroud_col = glow_color
	shroud_col.a = 0.38
	draw_colored_polygon(outer_poly, shroud_col)
	
	# 2. Saturated Energetic Dart Body
	var body_poly = PackedVector2Array([
		tip,
		Vector2(shoulder_x, -r * 1.3),
		Vector2(-half_len * 0.6, -r * 0.6),
		Vector2(-half_len * 1.4, 0.0),
		Vector2(-half_len * 0.6, r * 0.6),
		Vector2(shoulder_x, r * 1.3)
	])
	draw_colored_polygon(body_poly, glow_color)
	
	# 3. Incandescent White-Hot Needle Core
	var core_poly = PackedVector2Array([
		tip - Vector2(1.0, 0.0),
		Vector2(shoulder_x + 2.0, -r * 0.5),
		Vector2(-half_len * 0.2, 0.0),
		Vector2(shoulder_x + 2.0, r * 0.5)
	])
	draw_colored_polygon(core_poly, core_color)
	
	# 4. Supersonic Mach Diamonds (2 compression nodes along tail)
	var d1_x = -half_len * 0.2
	var d2_x = -half_len * 0.7
	var d_pulse = 1.0 + sin(pulse_time * 30.0) * 0.2
	
	var diamond_col = glow_color.lightened(0.6)
	diamond_col.a = 0.85
	
	var d1 = PackedVector2Array([
		Vector2(d1_x - 3.0, 0.0), Vector2(d1_x, -r * 0.9 * d_pulse),
		Vector2(d1_x + 3.0, 0.0), Vector2(d1_x, r * 0.9 * d_pulse)
	])
	draw_colored_polygon(d1, diamond_col)
	
	var d2 = PackedVector2Array([
		Vector2(d2_x - 2.5, 0.0), Vector2(d2_x, -r * 0.7),
		Vector2(d2_x + 2.5, 0.0), Vector2(d2_x, r * 0.7)
	])
	draw_colored_polygon(d2, diamond_col)
	
	# 5. Dissipation Velocity Wake Streak
	var wake_col = glow_color
	wake_col.a = 0.35
	draw_line(Vector2(-half_len * 0.8, 0.0), Vector2(-half_len * 2.8, 0.0), wake_col, 1.8, true)

func _draw_enemy_plasma_orb() -> void:
	var r = radius
	
	# 1. Trailing Comet Plasma Wake
	var wake_pts = PackedVector2Array([
		Vector2(r * 0.8, 0.0),
		Vector2(-r * 0.6, -r * 1.3),
		Vector2(-r * 3.4, 0.0),
		Vector2(-r * 0.6, r * 1.3)
	])
	var wake_col = glow_color
	wake_col.a = 0.42
	draw_colored_polygon(wake_pts, wake_col)
	
	# 2. Outer Containment Corona
	var halo_col = glow_color
	halo_col.a = 0.32
	draw_circle(Vector2.ZERO, r * 2.4, halo_col)
	
	# 3. Rotating Magnetic Corona Arcs
	var rot_a = pulse_time * 12.0
	draw_arc(Vector2.ZERO, r * 1.8, rot_a, rot_a + PI * 0.85, 12, glow_color, 2.2, true)
	draw_arc(Vector2.ZERO, r * 1.8, rot_a + PI, rot_a + PI * 1.85, 12, glow_color, 2.2, true)
	
	# 4. Dense Saturated Body
	draw_circle(Vector2.ZERO, r * 1.2, glow_color)
	
	# 5. Incandescent White-Hot Core
	draw_circle(Vector2.ZERO, r * 0.65, core_color)

func _draw_homing_missile() -> void:
	var half_len = length * 0.5
	var r = radius
	var is_burned_out = homing_timer >= homing_duration
	
	if not is_burned_out:
		# 1. Active Rocket Thruster Exhaust Flame
		var flame_flicker = 1.0 + sin(pulse_time * 45.0) * 0.28
		var flame_len = half_len * 1.6 * flame_flicker
		var flame_pts = PackedVector2Array([
			Vector2(-half_len * 0.7, -r * 0.6),
			Vector2(-half_len * 0.7 - flame_len, 0.0),
			Vector2(-half_len * 0.7, r * 0.6)
		])
		var flame_col = Color(1.0, 0.45, 0.05, 0.85)
		draw_colored_polygon(flame_pts, flame_col)
		
		# Inner white-hot thruster core
		var inner_flame = PackedVector2Array([
			Vector2(-half_len * 0.7, -r * 0.3),
			Vector2(-half_len * 0.7 - flame_len * 0.5, 0.0),
			Vector2(-half_len * 0.7, r * 0.3)
		])
		draw_colored_polygon(inner_flame, Color(1.0, 0.95, 0.6, 0.9))
	else:
		# 1. BURNOUT INDICATOR: Rocket flame extinguished! Sputtering smoke puff wake
		var smoke_flicker = sin(pulse_time * 22.0) * 0.12
		var puff_1 = Color(0.55, 0.58, 0.65, 0.45 + smoke_flicker)
		var puff_2 = Color(0.40, 0.42, 0.48, 0.30)
		var puff_3 = Color(0.30, 0.32, 0.36, 0.18)
		draw_circle(Vector2(-half_len * 0.9, 0.0), r * 0.85, puff_1)
		draw_circle(Vector2(-half_len * 1.5, 0.0), r * 1.25, puff_2)
		draw_circle(Vector2(-half_len * 2.3, 0.0), r * 1.65, puff_3)
		# Cold inert nozzle ring
		draw_line(Vector2(-half_len * 0.7, -r * 0.55), Vector2(-half_len * 0.7, r * 0.55), Color(0.3, 0.3, 0.35, 0.9), 1.8)
	
	# 2. Stabilizing Tail Fins
	var fin_top = PackedVector2Array([
		Vector2(-half_len * 0.3, -r * 0.8),
		Vector2(-half_len * 0.9, -r * 2.2),
		Vector2(-half_len * 0.7, -r * 0.8)
	])
	var fin_col = glow_color.darkened(0.5 if is_burned_out else 0.2)
	draw_colored_polygon(fin_top, fin_col)
	
	var fin_bot = PackedVector2Array([
		Vector2(-half_len * 0.3, r * 0.8),
		Vector2(-half_len * 0.9, r * 2.2),
		Vector2(-half_len * 0.7, r * 0.8)
	])
	draw_colored_polygon(fin_bot, fin_col)
	
	# 3. Cylindrical Missile Fuselage
	var body_pts = PackedVector2Array([
		Vector2(half_len + 3.0, 0.0),
		Vector2(half_len * 0.3, -r * 1.0),
		Vector2(-half_len * 0.7, -r * 0.9),
		Vector2(-half_len * 0.7, r * 0.9),
		Vector2(half_len * 0.3, r * 1.0)
	])
	var body_col = glow_color.darkened(0.35) if is_burned_out else glow_color
	draw_colored_polygon(body_pts, body_col)
	
	# 4. Seeker Nose Sensor & Spine
	var nose_pts = PackedVector2Array([
		Vector2(half_len + 3.0, 0.0),
		Vector2(half_len * 0.4, -r * 0.45),
		Vector2(half_len * 0.4, r * 0.45)
	])
	if not is_burned_out:
		draw_colored_polygon(nose_pts, core_color)
		draw_line(Vector2(half_len * 0.4, 0.0), Vector2(-half_len * 0.4, 0.0), core_color, 1.4, true)
		
		# 5. Soft Ionization Halo
		var halo_col = glow_color
		halo_col.a = 0.25
		draw_circle(Vector2.ZERO, r * 2.2, halo_col)
	else:
		# Burned-out / lost-lock indicator: seeker eye blinks red/gray warning
		var sensor_offline_col = Color(0.9, 0.2, 0.2, 0.85) if fmod(pulse_time * 8.0, 1.0) > 0.4 else Color(0.35, 0.35, 0.4, 0.85)
		draw_colored_polygon(nose_pts, sensor_offline_col)
		draw_line(Vector2(half_len * 0.4, 0.0), Vector2(-half_len * 0.4, 0.0), Color(0.35, 0.35, 0.4, 0.7), 1.2, true)
		# Faint inertial trajectory tick ahead
		draw_line(Vector2(half_len + 3.0, 0.0), Vector2(half_len + 12.0, 0.0), Color(0.85, 0.25, 0.25, 0.35), 1.0)

func _draw_quantum_wavepacket() -> void:
	var r = radius
	var pulse = 1.0 + sin(pulse_time * 16.0) * 0.15
	
	# 1. Ethereal Phase Resonance Shroud
	var shroud_col = glow_color
	shroud_col.a = 0.26
	draw_circle(Vector2.ZERO, r * 2.6 * pulse, shroud_col)
	
	# 2. Dual Orbital Probability Nodes (counter-rotating)
	var rot_a = pulse_time * 9.0
	var offset_dist = r * 1.15
	var lobe1 = Vector2(cos(rot_a), sin(rot_a)) * offset_dist
	var lobe2 = -lobe1
	
	var lobe_col = Color(0.2, 0.85, 1.0, 0.5)
	draw_circle(lobe1, r * 0.65, lobe_col)
	draw_circle(lobe2, r * 0.65, lobe_col)
	
	# Twin braided interference arcs
	draw_arc(Vector2.ZERO, r * 1.7, rot_a, rot_a + PI * 0.7, 12, glow_color, 2.0, true)
	draw_arc(Vector2.ZERO, r * 1.7, rot_a + PI, rot_a + PI * 1.7, 12, glow_color, 2.0, true)
	
	# 3. Dense Superposition Body
	draw_circle(Vector2.ZERO, r * 1.1, glow_color)
	
	# 4. White-Hot Quantum Singularity Core (signals 2-damage threat)
	draw_circle(Vector2.ZERO, r * 0.55, core_color)
	
	# 5. Transverse Pilot Wave Halo Streak
	var wake_col = glow_color
	wake_col.a = 0.35
	draw_line(Vector2(-r * 1.2, 0.0), Vector2(-r * 3.5, 0.0), wake_col, 2.2, true)

func _draw_crescent_arc() -> void:
	var half_len = length * 0.5
	var r = radius
	
	# 1. Outer curved plasma sweep (swept curved wing profile)
	var sweep_pts = PackedVector2Array([
		Vector2(half_len + 5.0, 0.0),
		Vector2(half_len * 0.3, -r * 2.6),
		Vector2(-half_len * 1.0, -r * 1.8),
		Vector2(-half_len * 0.3, 0.0),
		Vector2(-half_len * 1.0, r * 1.8),
		Vector2(half_len * 0.3, r * 2.6)
	])
	var sweep_col = glow_color
	sweep_col.a = 0.38
	draw_colored_polygon(sweep_pts, sweep_col)
	
	# 2. Dense Curved Sickle Blade
	var blade_pts = PackedVector2Array([
		Vector2(half_len + 3.0, 0.0),
		Vector2(half_len * 0.4, -r * 1.7),
		Vector2(-half_len * 0.6, -r * 1.0),
		Vector2(-half_len * 0.1, 0.0),
		Vector2(-half_len * 0.6, r * 1.0),
		Vector2(half_len * 0.4, r * 1.7)
	])
	draw_colored_polygon(blade_pts, glow_color)
	
	# 3. Incandescent Cutting Blade Edge
	var edge_pts = PackedVector2Array([
		Vector2(half_len + 3.0, 0.0),
		Vector2(half_len * 0.5, -r * 0.7),
		Vector2(half_len * 0.15, 0.0),
		Vector2(half_len * 0.5, r * 0.7)
	])
	draw_colored_polygon(edge_pts, core_color)
	
	# 4. Fiery Solar Flare Ionization Trail
	var trail_col = glow_color
	trail_col.a = 0.5
	draw_line(Vector2(-half_len * 0.1, 0.0), Vector2(-half_len * 2.8, 0.0), trail_col, 2.4, true)
	draw_line(Vector2(-half_len * 0.5, -r * 0.8), Vector2(-half_len * 2.0, -r * 1.2), trail_col, 1.4, true)
	draw_line(Vector2(-half_len * 0.5, r * 0.8), Vector2(-half_len * 2.0, r * 1.2), trail_col, 1.4, true)

func _draw_cluster_mortar() -> void:
	var r = radius
	var fuse_ratio = clampf(cluster_fuse_timer / cluster_fuse, 0.0, 1.0)
	var fuse_pulse = 1.0 + sin(pulse_time * (12.0 + fuse_ratio * 25.0)) * (0.12 + fuse_ratio * 0.25)
	
	# 1. Unstable Volatile Hazard Halo (emerald shifting to amber warning)
	var halo_col = glow_color.lerp(Color(1.0, 0.6, 0.1, 1.0), fuse_ratio * 0.75)
	halo_col.a = 0.28 + fuse_ratio * 0.25
	draw_circle(Vector2.ZERO, r * 2.2 * fuse_pulse, halo_col)
	
	# 2. Quad Magnetic Containment Calipers
	var rot_a = pulse_time * 6.0
	for i in range(4):
		var a = rot_a + (float(i) * PI * 0.5)
		draw_arc(Vector2.ZERO, r * 1.5, a - 0.25, a + 0.25, 6, glow_color, 2.4, true)
	
	# 3. Dense Superheated Shell Core
	var core_pulse_r = r * (0.95 + fuse_ratio * 0.35)
	draw_circle(Vector2.ZERO, core_pulse_r, glow_color)
	
	# 4. White-Hot Critical Mass Singularity
	draw_circle(Vector2.ZERO, r * 0.52, core_color)
	
	# 5. Heavy Combustion Trailing Wake
	var wake_pts = PackedVector2Array([
		Vector2(r * 0.6, 0.0),
		Vector2(-r * 0.8, -r * 1.2),
		Vector2(-r * 3.2, 0.0),
		Vector2(-r * 0.8, r * 1.2)
	])
	var wake_col = glow_color
	wake_col.a = 0.35
	draw_colored_polygon(wake_pts, wake_col)

func _detonate_cluster() -> void:
	has_detonated = true
	var parent_node = get_parent()
	if parent_node:
		for i in range(cluster_count):
			var angle = (float(i) / float(cluster_count)) * TAU + rotation
			var sub_dir = Vector2(cos(angle), sin(angle))
			var sub_b = acquire(parent_node, true)
			sub_b.setup(global_position + sub_dir * 14.0, sub_dir, true, 1.0)
			sub_b.speed = 320.0
			sub_b.glow_color = Color(0.25, 1.0, 0.5, 1.0) # Radiant Emerald Shrapnel
		
		var flash = ImpactFlashScript.acquire(parent_node)
		flash.setup(global_position, 30.0, Color(0.3, 1.0, 0.5, 1.0))
		
		SoundEffects.play_sfx("hit", 0.08, 1.8)
	
	queue_free()

func _get_closest_player() -> Node2D:
	var tree = get_tree()
	if not tree:
		return null
	var players = get_active_players(tree)
	var closest: Node2D = null
	var min_dist_sq = INF
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			var d_sq = global_position.distance_squared_to(p.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				closest = p
	return closest

func _on_area_entered(area: Area2D) -> void:
	_handle_hit(area)

func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)

func _handle_hit(target: Node2D) -> void:
	if is_enemy:
		if target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(damage)
			recycle()
	else:
		if not target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(damage)
			var is_crit_hit = is_crit or (has_meta("is_crit") and get_meta("is_crit"))
			
			# Dynamic acoustic snap: crits snap higher, heavy hits have deeper body thud
			var hit_pitch = 1.0
			if is_crit_hit:
				hit_pitch = 1.22
			elif damage >= 2.0:
				hit_pitch = clampf(1.0 - (damage - 1.0) * 0.08, 0.65, 0.95)
			SoundEffects.play_sfx("hit", 0.08, -3.5, hit_pitch)
			
			# Spawn lightweight vector impact flash shock-ring (throttled)
			_spawn_impact_shockwave(is_crit_hit)
			
			var p_count = pierce_count if pierce_count > 0 else (get_meta("pierce_count") if has_meta("pierce_count") else 0)
			if p_count > 0:
				pierce_count = p_count - 1
				set_meta("pierce_count", pierce_count)
			else:
				recycle()

func _spawn_impact_shockwave(is_crit: bool) -> void:
	if ImpactFlashScript.active_count >= ImpactFlashScript.MAX_ACTIVE_FLASHES and not is_crit:
		return
	var parent_node = get_parent()
	if parent_node:
		var flash = ImpactFlashScript.acquire(parent_node)
		var flash_col = Color(1.0, 0.92, 0.25, 1.0) if is_crit else glow_color
		var ring_radius = clampf(7.0 + sqrt(maxf(1.0, damage)) * 5.5, 7.0, 24.0)
		if is_crit:
			ring_radius *= 1.25
		flash.setup(global_position, ring_radius, flash_col)
