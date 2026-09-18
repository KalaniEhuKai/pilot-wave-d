extends Area2D

## BossCorvus.gd - Multi-part Sector 1 Boss: Super-Dreadnought Corvus with breakable wings and exposed singularity core.

signal subsystem_destroyed(name: String)
signal boss_defeated()

@export var is_miniboss: bool = false
@export var max_core_health: float = 160.0
var core_health: float = 160.0
var use_3d_model: bool = true

@export var max_wing_health: float = 60.0
var port_wing_health: float = 60.0
var starboard_wing_health: float = 60.0

var port_wing_alive: bool = true
var starboard_wing_alive: bool = true

# Movement & flight state
var flight_time: float = 0.0
var entry_done: bool = false
var target_entry_pos: Vector2
var strafe_direction: float = 1.0

# Attack timers
var turret_fire_timer: float = 1.5
var port_turret_timer: float = 1.0
var starboard_turret_timer: float = 1.8
var core_fire_timer: float = 2.0
var wing_sweep_phase: float = 0.0
var spiral_angle: float = 0.0

# Phase 2 Enraged Vortex State
var enrage_burst_active: bool = false
var enrage_burst_cooldown: float = 0.5
var enrage_pulse_timer: float = 0.0
var enrage_pulses_remaining: int = 0
var enrage_spin_dir: float = 1.0
var enrage_mid_shot_fired: bool = false
const ENRAGE_PULSES_PER_BURST: int = 18
const ENRAGE_PULSE_INTERVAL: float = 0.09
const ENRAGE_BURST_COOLDOWN: float = 1.1

# Hit flashes
var hit_flash_core: float = 0.0
var hit_flash_port: float = 0.0
var hit_flash_starboard: float = 0.0

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")
var crate_scene: PackedScene = preload("res://scenes/ItemCrate.tscn")

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 3
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if is_miniboss:
		max_core_health = 90.0
		max_wing_health = 35.0
	
	core_health = max_core_health
	port_wing_health = max_wing_health
	starboard_wing_health = max_wing_health
	
	# Initial spawn position outside screen boundary
	var vp = get_viewport_rect().size
	if GameAxis.is_vertical:
		target_entry_pos = Vector2(vp.x * 0.5, 140.0)
		global_position = Vector2(vp.x * 0.5, -120.0)
	else:
		target_entry_pos = Vector2(vp.x - 180.0, vp.y * 0.5)
		global_position = Vector2(vp.x + 140.0, vp.y * 0.5)
	
	_emit_health()
	SoundEffects.play_sfx("bonus", 0.05, -2.0)
	GameManager.request_screen_shake(12.0, 0.5)
	
	if use_3d_model:
		var stage = get_tree().get_root().find_child("Stage3D", true, false)
		if is_instance_valid(stage) and stage.has_method("register_boss"):
			stage.register_boss(self, "corvus")

func _emit_health() -> void:
	var total_hp = core_health + (port_wing_health if port_wing_alive else 0.0) + (starboard_wing_health if starboard_wing_alive else 0.0)
	var max_hp = max_core_health + max_wing_health * 2.0
	var b_name = "MINIBOSS: QUANTUM CORVUS" if is_miniboss else "SUPER-DREADNOUGHT CORVUS"
	GameManager.boss_health_updated.emit(total_hp, max_hp, b_name)

func _physics_process(delta: float) -> void:
	flight_time += delta
	
	if hit_flash_core > 0.0: hit_flash_core -= delta
	if hit_flash_port > 0.0: hit_flash_port -= delta
	if hit_flash_starboard > 0.0: hit_flash_starboard -= delta
	
	# Entry warp sequence
	if not entry_done:
		global_position = global_position.lerp(target_entry_pos, 1.0 - exp(-delta / 0.8))
		if global_position.distance_to(target_entry_pos) < 6.0:
			entry_done = true
		queue_redraw()
		return
	
	# Strafing patrol along lateral axis
	var strafe_speed = 90.0 if (port_wing_alive or starboard_wing_alive) else 140.0
	var lat_move = GameAxis.lateral * strafe_direction * strafe_speed * delta
	global_position += lat_move
	
	# Bounce off screen bounds
	var rect = get_viewport_rect()
	var margin = 110.0
	if GameAxis.is_vertical:
		if global_position.x < rect.position.x + margin: strafe_direction = 1.0
		elif global_position.x > rect.position.x + rect.size.x - margin: strafe_direction = -1.0
	else:
		if global_position.y < rect.position.y + margin: strafe_direction = 1.0
		elif global_position.y > rect.position.y + rect.size.y - margin: strafe_direction = -1.0
	
	rotation = (-GameAxis.forward).angle()
	
	# Handle weapon salvos
	_handle_attacks(delta)
	queue_redraw()

func _handle_attacks(delta: float) -> void:
	var is_enraged = not port_wing_alive and not starboard_wing_alive
	
	if not is_enraged:
		# Phase 1: Alternating & Sweeping Turret barrages + Aimed core salvos
		wing_sweep_phase += delta * 2.2
		var base_interval = 1.6 if (port_wing_alive and starboard_wing_alive) else 0.95
		
		if port_wing_alive:
			port_turret_timer -= delta
			if port_turret_timer <= 0.0:
				port_turret_timer = base_interval
				_fire_wing_barrage(true)
		
		if starboard_wing_alive:
			starboard_turret_timer -= delta
			if starboard_turret_timer <= 0.0:
				starboard_turret_timer = base_interval
				_fire_wing_barrage(false)
		
		core_fire_timer -= delta
		if core_fire_timer <= 0.0:
			core_fire_timer = 2.2
			_fire_core_aimed_salvo()
	else:
		# Phase 2 Enraged: Rapid rotating vortex bursts & dorsal homing missiles
		_handle_enraged_attacks(delta)

func _handle_enraged_attacks(delta: float) -> void:
	if enrage_burst_active:
		enrage_pulse_timer -= delta
		if enrage_pulse_timer <= 0.0:
			enrage_pulse_timer = ENRAGE_PULSE_INTERVAL
			_fire_enraged_vortex_pulse()
			enrage_pulses_remaining -= 1
			if enrage_pulses_remaining <= 0:
				enrage_burst_active = false
				enrage_burst_cooldown = ENRAGE_BURST_COOLDOWN
				enrage_spin_dir = -enrage_spin_dir # Alternate spin direction
				enrage_mid_shot_fired = false
	else:
		enrage_burst_cooldown -= delta
		
		# Mid-breather dorsal homing missiles from singularity core (forces player to maneuver/roll)
		if not enrage_mid_shot_fired and enrage_burst_cooldown <= (ENRAGE_BURST_COOLDOWN * 0.5):
			enrage_mid_shot_fired = true
			_fire_enraged_breather_missiles()
		
		if enrage_burst_cooldown <= 0.0:
			enrage_burst_active = true
			enrage_pulses_remaining = ENRAGE_PULSES_PER_BURST
			enrage_pulse_timer = 0.0 # Trigger first pulse immediately
			SoundEffects.play_sfx("laser", 0.08, 1.0)

func _fire_wing_barrage(is_port: bool) -> void:
	var fwd = -GameAxis.forward
	var lat = GameAxis.lateral
	var wing_pos = global_position + lat * (-45.0 if is_port else 45.0)
	var sweep_offset = sin(wing_sweep_phase) * 0.12 # Sweeping angular variation
	
	for i in range(-2, 3):
		var spread_angle = (i * 0.14) + sweep_offset
		var dir = fwd.rotated(spread_angle)
		var b = _spawn_bullet(wing_pos, dir, 0, 1.0) # High-velocity linear plasma bolts
		if b != null:
			b.speed = 420.0
	
	SoundEffects.play_sfx("laser", 0.07, -1.5)

func _fire_turret_barrage() -> void:
	if port_wing_alive:
		_fire_wing_barrage(true)
	if starboard_wing_alive:
		_fire_wing_barrage(false)

func _fire_core_aimed_salvo() -> void:
	var fwd = -GameAxis.forward
	var players = get_tree().get_nodes_in_group("player")
	var target_dir = fwd
	if not players.is_empty() and is_instance_valid(players[0]):
		target_dir = (players[0].global_position - global_position).normalized()
	
	_spawn_bullet(global_position, target_dir)
	_spawn_bullet(global_position + target_dir.orthogonal() * 16.0, target_dir)
	_spawn_bullet(global_position - target_dir.orthogonal() * 16.0, target_dir)
	SoundEffects.play_sfx("laser", 0.08, -1.0)

func _fire_enraged_vortex_pulse() -> void:
	for i in range(4):
		var angle = spiral_angle + (i * PI * 0.5)
		var dir = Vector2(cos(angle), sin(angle))
		_spawn_bullet(global_position, dir)
	spiral_angle += 0.22 * enrage_spin_dir
	if enrage_pulses_remaining % 3 == 0:
		SoundEffects.play_sfx("laser", 0.03, 3.5)

func _fire_enraged_breather_missiles() -> void:
	var fwd = -GameAxis.forward
	var lat = GameAxis.lateral
	var players = get_tree().get_nodes_in_group("player")
	var target_dir = fwd
	if not players.is_empty() and is_instance_valid(players[0]):
		target_dir = (players[0].global_position - global_position).normalized()
	
	# Twin dorsal homing seeker missiles launched outward that curve in
	for side in [-1.0, 1.0]:
		var spawn_pos = global_position + lat * (side * 28.0) - fwd * 15.0
		var eject_dir = target_dir.rotated(side * 0.42)
		var m = _spawn_bullet(spawn_pos, eject_dir, 1, 1.0) # Pattern.HOMING
		if m != null:
			m.speed = 400.0 # Faster homing speed
			m.homing_strength = 2.9
			m.homing_duration = 1.9
	
	SoundEffects.play_sfx("laser", 0.09, -3.0)

func _fire_enraged_breather_snipe() -> void:
	_fire_enraged_breather_missiles()

func _fire_core_salvo(is_enraged: bool) -> void:
	if is_enraged:
		_fire_enraged_vortex_pulse()
	else:
		_fire_core_aimed_salvo()

func _spawn_bullet(pos: Vector2, dir: Vector2, p_pattern: int = 0, p_dmg: float = 1.0) -> Area2D:
	var b = bullet_scene.instantiate()
	b.pattern = p_pattern
	if get_parent():
		get_parent().add_child(b)
	else:
		add_child(b)
	b.setup(pos, dir, true, p_dmg)
	return b

func take_damage(amount: float) -> void:
	# Distribute damage: wings take hits first, then core
	if port_wing_alive:
		port_wing_health -= amount
		hit_flash_port = 0.08
		if port_wing_health <= 0.0:
			port_wing_alive = false
			_explode_subsystem(global_position - GameAxis.lateral * 45.0)
	elif starboard_wing_alive:
		starboard_wing_health -= amount
		hit_flash_starboard = 0.08
		if starboard_wing_health <= 0.0:
			starboard_wing_alive = false
			_explode_subsystem(global_position + GameAxis.lateral * 45.0)
	else:
		core_health -= amount
		hit_flash_core = 0.08
		if core_health <= 0.0:
			_die()
			return
	
	_emit_health()

func _explode_subsystem(pos: Vector2) -> void:
	var exp_node = explosion_scene.instantiate()
	if get_parent():
		get_parent().add_child(exp_node)
	else:
		add_child(exp_node)
	exp_node.global_position = pos
	exp_node.max_radius = 64.0
	SoundEffects.play_sfx("explosion", 0.05, 3.0)
	var dir = (pos - global_position).normalized()
	GameManager.request_directional_shake(dir if dir != Vector2.ZERO else Vector2.UP, 14.0, 0.3)
	GameManager.trigger_hit_stop(0.045)
	GameManager.add_score(2500)
	
	# Wing fracture retaliation: release a cluster flak barrage (Cluster Mortars)
	var fwd = -GameAxis.forward
	for angle_offset in [-0.35, 0.0, 0.35]:
		var flak_dir = fwd.rotated(angle_offset)
		var b = _spawn_bullet(pos, flak_dir, 4, 2.0) # Pattern.CLUSTER_BURST
		if b != null:
			b.cluster_fuse = 1.1
			b.speed = 320.0


func _die() -> void:
	GameManager.add_score(15000)
	GameManager.record_kill()
	var b_name = "MINIBOSS: QUANTUM CORVUS" if is_miniboss else "SUPER-DREADNOUGHT CORVUS"
	GameManager.boss_defeated.emit(b_name)
	boss_defeated.emit()
	
	# Chain of 6 massive explosions
	for i in range(6):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			var exp_node = explosion_scene.instantiate()
			get_parent().add_child(exp_node)
			var offset = Vector2(randf_range(-50, 50), randf_range(-40, 40))
			exp_node.global_position = global_position + offset
			exp_node.max_radius = 85.0
			GameManager.request_screen_shake(14.0, 0.3)
		)
	
	# Drop bounty of 10 scrap pellets & Guaranteed Relic Crate
	for i in range(10):
		var sc = scrap_scene.instantiate()
		get_parent().add_child(sc)
		sc.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	
	var crate = crate_scene.instantiate()
	get_parent().add_child(crate)
	crate.global_position = global_position
	
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("_handle_hit"):
		area._handle_hit(self)
	elif area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(2)
		take_damage(4.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(2)
		take_damage(4.0)

func _draw() -> void:
	if use_3d_model:
		return
		
	var hull_color = Color(0.12, 0.05, 0.16, 0.95)
	var outline_color = Color(1.0, 0.2, 0.5, 1.0)
	
	# Dreadnought heavy hull (drawn facing Vector2.RIGHT / 0 radians)
	var nose = Vector2(48, 0)
	var bow_top = Vector2(28, -26)
	var wing_port = Vector2(-24, -68)
	var engine_port = Vector2(-48, -42)
	var stern = Vector2(-54, 0)
	var engine_star = Vector2(-48, 42)
	var wing_star = Vector2(-24, 68)
	var bow_bot = Vector2(28, 26)
	
	var hull_poly = PackedVector2Array([
		nose, bow_top, wing_port, engine_port, stern, engine_star, wing_star, bow_bot
	])
	
	draw_colored_polygon(hull_poly, hull_color)
	draw_polyline(hull_poly + PackedVector2Array([nose]), outline_color, 3.2, true)
	
	# Port Wing Battery
	if port_wing_alive:
		var port_col = Color.WHITE if hit_flash_port > 0.0 else Color(1.0, 0.3, 0.2, 1.0)
		draw_circle(Vector2(-20, -45), 14.0, port_col)
		draw_line(Vector2(-20, -45), Vector2(10, -45), Color(1.0, 0.8, 0.2), 3.0)
	
	# Starboard Wing Battery
	if starboard_wing_alive:
		var star_col = Color.WHITE if hit_flash_starboard > 0.0 else Color(1.0, 0.3, 0.2, 1.0)
		draw_circle(Vector2(-20, 45), 14.0, star_col)
		draw_line(Vector2(-20, 45), Vector2(10, 45), Color(1.0, 0.8, 0.2), 3.0)
	
	# Central Plasma Singularity Core
	var core_col = Color.WHITE if hit_flash_core > 0.0 else (Color(1.0, 0.1, 0.3, 1.0) if not port_wing_alive and not starboard_wing_alive else Color(0.2, 0.9, 1.0, 1.0))
	var core_radius = 18.0 + sin(flight_time * 8.0) * 3.0
	draw_circle(Vector2(4, 0), core_radius, core_col)
	draw_arc(Vector2(4, 0), core_radius * 1.5, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)
