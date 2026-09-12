extends Area2D

## BossCorvus.gd - Multi-part Sector 1 Boss: Super-Dreadnought Corvus with breakable wings and exposed singularity core.

signal subsystem_destroyed(name: String)
signal boss_defeated()

@export var max_core_health: float = 160.0
var core_health: float = 160.0

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
var core_fire_timer: float = 2.0
var spiral_angle: float = 0.0

# Phase 2 Enraged Vortex State
var enrage_burst_active: bool = false
var enrage_burst_cooldown: float = 0.5
var enrage_pulse_timer: float = 0.0
var enrage_pulses_remaining: int = 0
var enrage_spin_dir: float = 1.0
var enrage_mid_shot_fired: bool = false
const ENRAGE_PULSES_PER_BURST: int = 12
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

func _emit_health() -> void:
	var total_hp = core_health + (port_wing_health if port_wing_alive else 0.0) + (starboard_wing_health if starboard_wing_alive else 0.0)
	var max_hp = max_core_health + max_wing_health * 2.0
	GameManager.boss_health_updated.emit(total_hp, max_hp, "SUPER-DREADNOUGHT CORVUS")

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
		# Phase 1: Turret barrages & Aimed core salvos
		turret_fire_timer -= delta
		if turret_fire_timer <= 0.0:
			turret_fire_timer = 1.6 if (port_wing_alive and starboard_wing_alive) else 0.9
			_fire_turret_barrage()
		
		core_fire_timer -= delta
		if core_fire_timer <= 0.0:
			core_fire_timer = 2.2
			_fire_core_aimed_salvo()
	else:
		# Phase 2 Enraged: Rapid rotating vortex bursts & breather plasma snipes
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
		
		# Mid-breather aimed shot from singularity core (prevents static camping)
		if not enrage_mid_shot_fired and enrage_burst_cooldown <= (ENRAGE_BURST_COOLDOWN * 0.5):
			enrage_mid_shot_fired = true
			_fire_enraged_breather_snipe()
		
		if enrage_burst_cooldown <= 0.0:
			enrage_burst_active = true
			enrage_pulses_remaining = ENRAGE_PULSES_PER_BURST
			enrage_pulse_timer = 0.0 # Trigger first pulse immediately
			SoundEffects.play_sfx("laser", 0.08, 1.0)

func _fire_turret_barrage() -> void:
	var fwd = -GameAxis.forward
	var lat = GameAxis.lateral
	
	if port_wing_alive:
		var port_pos = global_position - lat * 45.0
		for i in range(-2, 3):
			var dir = fwd.rotated(i * 0.15)
			_spawn_bullet(port_pos, dir)
	
	if starboard_wing_alive:
		var star_pos = global_position + lat * 45.0
		for i in range(-2, 3):
			var dir = fwd.rotated(i * 0.15)
			_spawn_bullet(star_pos, dir)

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

func _fire_enraged_breather_snipe() -> void:
	var fwd = -GameAxis.forward
	var players = get_tree().get_nodes_in_group("player")
	var target_dir = fwd
	if not players.is_empty() and is_instance_valid(players[0]):
		target_dir = (players[0].global_position - global_position).normalized()
	
	# Twin aimed heavy bolts
	var orth = target_dir.orthogonal()
	_spawn_bullet(global_position + orth * 14.0, target_dir)
	_spawn_bullet(global_position - orth * 14.0, target_dir)
	SoundEffects.play_sfx("laser", 0.08, -1.0)

func _fire_core_salvo(is_enraged: bool) -> void:
	if is_enraged:
		_fire_enraged_vortex_pulse()
	else:
		_fire_core_aimed_salvo()

func _spawn_bullet(pos: Vector2, dir: Vector2) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(pos, dir, true, 1.0)

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
	get_parent().add_child(exp_node)
	exp_node.global_position = pos
	exp_node.max_radius = 64.0
	SoundEffects.play_sfx("explosion", 0.05, 3.0)
	GameManager.request_screen_shake(10.0, 0.3)
	GameManager.add_score(2500)

func _die() -> void:
	GameManager.add_score(15000)
	GameManager.record_kill()
	GameManager.boss_defeated.emit("SUPER-DREADNOUGHT CORVUS")
	
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
	if area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(2)
		take_damage(4.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(2)
		take_damage(4.0)

func _draw() -> void:
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
