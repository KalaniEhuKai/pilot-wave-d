extends Area2D

## BossGoliath.gd - Asymmetric Sector 1 Boss: Armored Behemoth Goliath.
## A heavy fortress carrier with sweeping railgun targeting lasers, breakable bow armor, and fighter hangar bays.

signal subsystem_destroyed(subsystem_name: String)

@export var is_miniboss: bool = false
@export var max_core_health: float = 280.0
var core_health: float = 280.0

@export var max_railgun_health: float = 25.0
var port_railgun_health: float = 25.0
var star_railgun_health: float = 25.0

@export var max_armor_health: float = 120.0
var bow_armor_health: float = 120.0

var port_railgun_alive: bool = true
var star_railgun_alive: bool = true
var bow_armor_alive: bool = true

var entry_done: bool = false
var target_entry_pos: Vector2
var strafe_direction: float = 1.0
var flight_time: float = 0.0

const EnemyScript = preload("res://scripts/Enemy.gd")

# Attack states
var railgun_timer: float = 2.0
var is_charging_railgun: bool = false
var charge_elapsed: float = 0.0
var charge_duration: float = 0.75
var railgun_aim_dir: Vector2 = Vector2.DOWN
var railgun_locked: bool = false

var drone_launch_timer: float = 4.0
var frontal_turret_timer: float = 1.8
var core_overdrive_timer: float = 1.0
var core_radial_timer: float = 3.2

# Hit flashes
var hit_flash_core: float = 0.0
var hit_flash_port: float = 0.0
var hit_flash_star: float = 0.0
var hit_flash_armor: float = 0.0

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
var drone_scene: PackedScene = preload("res://scenes/Enemy.tscn")
var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")
var crate_scene: PackedScene = preload("res://scenes/ItemCrate.tscn")

func _ready() -> void:
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 3
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if is_miniboss:
		max_core_health = 90.0
		max_railgun_health = 20.0
		port_railgun_alive = true
		star_railgun_alive = true
		max_armor_health = 50.0
		charge_duration = 0.85
		railgun_timer = 1.8
		drone_launch_timer = 3.2
	
	core_health = max_core_health
	port_railgun_health = max_railgun_health
	star_railgun_health = max_railgun_health
	bow_armor_health = max_armor_health
	
	var vp = get_viewport_rect().size
	if GameAxis.is_vertical:
		target_entry_pos = Vector2(vp.x * 0.5, 145.0)
		global_position = Vector2(vp.x * 0.5, -130.0)
	else:
		target_entry_pos = Vector2(vp.x - 190.0, vp.y * 0.5)
		global_position = Vector2(vp.x + 150.0, vp.y * 0.5)
	
	_emit_health()

func _emit_health() -> void:
	var total = maxf(0.0, core_health) + maxf(0.0, port_railgun_health) + maxf(0.0, star_railgun_health) + maxf(0.0, bow_armor_health)
	var max_total = max_core_health + max_railgun_health * 2.0 + max_armor_health
	var b_name = "MINIBOSS: SIEGE GOLIATH" if is_miniboss else "ARMORED BEHEMOTH GOLIATH"
	GameManager.boss_health_updated.emit(maxf(0.0, total), max_total, b_name)

func _physics_process(delta: float) -> void:
	flight_time += delta
	
	if hit_flash_core > 0.0: hit_flash_core -= delta
	if hit_flash_port > 0.0: hit_flash_port -= delta
	if hit_flash_star > 0.0: hit_flash_star -= delta
	if hit_flash_armor > 0.0: hit_flash_armor -= delta
	
	if not entry_done:
		global_position = global_position.lerp(target_entry_pos, 1.0 - exp(-delta / 0.8))
		if global_position.distance_to(target_entry_pos) < 6.0:
			entry_done = true
		queue_redraw()
		return
	
	# Lateral combat patrol
	var lat = GameAxis.lateral
	var strafe_speed = 85.0 if bow_armor_alive else 125.0
	global_position += lat * strafe_direction * strafe_speed * delta
	
	var rect = get_viewport_rect()
	var margin = 120.0
	if GameAxis.is_vertical:
		if global_position.x < rect.position.x + margin: strafe_direction = 1.0
		elif global_position.x > rect.position.x + rect.size.x - margin: strafe_direction = -1.0
	else:
		if global_position.y < rect.position.y + margin: strafe_direction = 1.0
		elif global_position.y > rect.position.y + rect.size.y - margin: strafe_direction = -1.0
	
	rotation = (-GameAxis.forward).angle()
	_handle_attacks(delta)
	queue_redraw()

func _handle_attacks(delta: float) -> void:
	# 1. Fighter Drone Hangar Launch (Interceptors on flanks)
	drone_launch_timer -= delta
	if drone_launch_timer <= 0.0:
		drone_launch_timer = 3.5 if bow_armor_alive else 2.6
		_launch_fighters(2)
	
	# 2. Frontal Weapons: Kinetic Autocannon (Bow intact) OR Fusion Overdrive (Bow broken)
	if bow_armor_alive:
		frontal_turret_timer -= delta
		if frontal_turret_timer <= 0.0:
			frontal_turret_timer = 1.8
			_fire_frontal_cannon()
	else:
		core_overdrive_timer -= delta
		if core_overdrive_timer <= 0.0:
			core_overdrive_timer = 1.4
			_fire_core_overdrive_burst()
		
		core_radial_timer -= delta
		if core_radial_timer <= 0.0:
			core_radial_timer = 3.8
			_fire_core_radial_pulse()
	
	# 3. Tracking Railgun Battery Charging & Salvo
	if not is_charging_railgun:
		railgun_timer -= delta
		if railgun_timer <= 0.0:
			if port_railgun_alive or star_railgun_alive:
				is_charging_railgun = true
				charge_elapsed = 0.0
				railgun_locked = false
				railgun_aim_dir = -GameAxis.forward
				SoundEffects.play_sfx("laser", 0.05, 5.0)
	else:
		charge_elapsed += delta
		var lock_threshold = charge_duration * 0.75
		if charge_elapsed < lock_threshold:
			var players = get_tree().get_nodes_in_group("player")
			if not players.is_empty() and is_instance_valid(players[0]):
				railgun_aim_dir = (players[0].global_position - global_position).normalized()
		else:
			if not railgun_locked:
				railgun_locked = true
				SoundEffects.play_sfx("hit", 0.04, 5.5)
		
		if charge_elapsed >= charge_duration:
			is_charging_railgun = false
			railgun_locked = false
			railgun_timer = 2.4 if is_miniboss else 2.2
			_fire_railguns()

func _fire_frontal_cannon() -> void:
	var fwd = -GameAxis.forward
	var nose_pos = global_position + fwd * 40.0
	for i in range(-2, 3):
		var dir = fwd.rotated(i * 0.16)
		var b = bullet_scene.instantiate()
		get_parent().add_child(b)
		b.setup(nose_pos, dir, true, 1.0)
	SoundEffects.play_sfx("laser", 0.08, -1.5)

func _fire_core_overdrive_burst() -> void:
	var fwd = -GameAxis.forward
	var players = get_tree().get_nodes_in_group("player")
	var target_dir = fwd
	if not players.is_empty() and is_instance_valid(players[0]):
		target_dir = (players[0].global_position - global_position).normalized()
	
	for i in range(-1, 2):
		var dir = target_dir.rotated(i * 0.15)
		var b = bullet_scene.instantiate()
		get_parent().add_child(b)
		b.setup(global_position, dir, true, 1.0)
	SoundEffects.play_sfx("laser", 0.08, 0.5)

func _fire_core_radial_pulse() -> void:
	var count = 8
	for i in range(count):
		var angle = (float(i) / count) * TAU + flight_time
		var dir = Vector2(cos(angle), sin(angle))
		var b = bullet_scene.instantiate()
		get_parent().add_child(b)
		b.setup(global_position, dir, true, 1.0)
	SoundEffects.play_sfx("bonus", 0.08, 3.0)
	GameManager.request_screen_shake(4.0, 0.2)

func _fire_railguns() -> void:
	var lat = GameAxis.lateral
	var aim = railgun_aim_dir
	
	for salvo in range(2):
		get_tree().create_timer(salvo * 0.09).timeout.connect(func():
			if not is_instance_valid(self): return
			if port_railgun_alive:
				var port_pos = global_position - lat * 48.0
				_spawn_heavy_beam(port_pos, aim)
			if star_railgun_alive:
				var star_pos = global_position + lat * 48.0
				_spawn_heavy_beam(star_pos, aim)
		)

func _spawn_heavy_beam(pos: Vector2, dir: Vector2) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(pos, dir, true, 2.0)
	b.scale = Vector2(2.2, 1.8)
	b.speed = 480.0
	b.glow_color = Color(1.0, 0.4, 0.1, 1.0)
	SoundEffects.play_sfx("laser", 0.1, -1.0)
	GameManager.request_screen_shake(8.0, 0.25)

func _launch_fighters(count: int = 1) -> void:
	var parent = get_parent()
	if not parent:
		return
	
	for i in range(count):
		var drone = drone_scene.instantiate()
		parent.add_child(drone)
		var side = -1.0 if i == 0 else 1.0
		var offset = GameAxis.lateral * (side * 85.0) - GameAxis.forward * 15.0
		var drone_type = EnemyScript.EnemyType.INTERCEPTOR if is_miniboss else EnemyScript.EnemyType.SCOUT
		drone.setup(drone_type, global_position + offset, 999, null, 0)
	SoundEffects.play_sfx("roll", 0.05, 2.5)

func take_damage(amount: float) -> void:
	# Subsystem defense hierarchy: Bow Armor -> Railguns -> Core
	if bow_armor_alive:
		bow_armor_health -= amount
		hit_flash_armor = 0.08
		if bow_armor_health <= 0.0:
			bow_armor_alive = false
			_explode_subsystem(global_position - (-GameAxis.forward) * 35.0, "BOW ARMOR PLATING")
	elif port_railgun_alive:
		port_railgun_health -= amount
		hit_flash_port = 0.08
		if port_railgun_health <= 0.0:
			port_railgun_alive = false
			_explode_subsystem(global_position - GameAxis.lateral * 48.0, "PORT RAILGUN BATTERY")
	elif star_railgun_alive:
		star_railgun_health -= amount
		hit_flash_star = 0.08
		if star_railgun_health <= 0.0:
			star_railgun_alive = false
			_explode_subsystem(global_position + GameAxis.lateral * 48.0, "STARBOARD RAILGUN BATTERY")
	else:
		core_health -= amount
		hit_flash_core = 0.08
		if core_health <= 0.0:
			_die()
			return
	
	_emit_health()

func _explode_subsystem(pos: Vector2, s_name: String) -> void:
	var exp_node = explosion_scene.instantiate()
	get_parent().add_child(exp_node)
	exp_node.global_position = pos
	exp_node.max_radius = 65.0
	SoundEffects.play_sfx("explosion", 0.05, 3.0)
	GameManager.request_screen_shake(10.0, 0.3)
	GameManager.add_score(2500)
	subsystem_destroyed.emit(s_name)

func _die() -> void:
	GameManager.add_score(15000)
	GameManager.record_kill()
	var b_name = "MINIBOSS: SIEGE GOLIATH" if is_miniboss else "ARMORED BEHEMOTH GOLIATH"
	GameManager.boss_defeated.emit(b_name)
	
	# Massive chain explosions
	for i in range(7):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			var exp_node = explosion_scene.instantiate()
			get_parent().add_child(exp_node)
			var offset = Vector2(randf_range(-55, 55), randf_range(-45, 45))
			exp_node.global_position = global_position + offset
			exp_node.max_radius = 90.0
			GameManager.request_screen_shake(14.0, 0.3)
		)
	
	# 10 scrap pellets & Guaranteed Item Crate
	for i in range(10):
		var sc = scrap_scene.instantiate()
		get_parent().add_child(sc)
		sc.global_position = global_position + Vector2(randf_range(-35, 35), randf_range(-35, 35))
	
	var crate = crate_scene.instantiate()
	get_parent().add_child(crate)
	crate.global_position = global_position
	
	queue_free()

func _draw() -> void:
	var fwd = Vector2.RIGHT # Local forward
	var lat = Vector2.DOWN  # Local lateral
	
	# Telegraphing laser targeting lines when charging
	if is_charging_railgun:
		var charge_ratio = clampf(charge_elapsed / charge_duration, 0.0, 1.0)
		var local_aim = to_local(global_position + railgun_aim_dir).normalized()
		var laser_col = Color(1.0, 0.9, 0.25, 0.95) if railgun_locked else Color(1.0, 0.3, 0.1, 0.35 + charge_ratio * 0.45)
		var laser_w = 4.5 if railgun_locked else (1.5 + charge_ratio * 2.5)
		if port_railgun_alive:
			draw_line(-lat * 48.0, -lat * 48.0 + local_aim * 850.0, laser_col, laser_w)
		if star_railgun_alive:
			draw_line(lat * 48.0, lat * 48.0 + local_aim * 850.0, laser_col, laser_w)
	
	# Draw Goliath Fortress Hull
	var hull_col = Color(0.12, 0.14, 0.22, 1.0)
	var line_col = Color(0.3, 0.8, 1.0, 0.9)
	
	if hit_flash_core > 0.0:
		hull_col = Color.WHITE
	
	# Main Fortress Body
	var body_pts = PackedVector2Array([
		Vector2(-50, -35),
		Vector2(45, -35),
		Vector2(65, 0),
		Vector2(45, 35),
		Vector2(-50, 35),
		Vector2(-60, 0)
	])
	draw_colored_polygon(body_pts, hull_col)
	draw_polyline(body_pts + PackedVector2Array([Vector2(-50, -35)]), line_col, 2.0)
	
	# Heavy Bow Armor
	if bow_armor_alive:
		var armor_col = Color.WHITE if hit_flash_armor > 0.0 else Color(0.7, 0.4, 0.15, 1.0)
		var armor_pts = PackedVector2Array([
			Vector2(45, -30),
			Vector2(70, 0),
			Vector2(45, 30),
			Vector2(55, 0)
		])
		draw_colored_polygon(armor_pts, armor_col)
		draw_polyline(armor_pts + PackedVector2Array([Vector2(45, -30)]), Color(1.0, 0.7, 0.2, 1.0), 2.0)
	
	# Port Railgun Battery
	if port_railgun_alive:
		var p_col = Color.WHITE if hit_flash_port > 0.0 else Color(0.2, 0.25, 0.35, 1.0)
		draw_rect(Rect2(Vector2(-20, -58), Vector2(40, 16)), p_col)
		draw_rect(Rect2(Vector2(-20, -58), Vector2(40, 16)), Color(1.0, 0.4, 0.1, 1.0), false, 1.5)
	
	# Starboard Railgun Battery
	if star_railgun_alive:
		var s_col = Color.WHITE if hit_flash_star > 0.0 else Color(0.2, 0.25, 0.35, 1.0)
		draw_rect(Rect2(Vector2(-20, 42), Vector2(40, 16)), s_col)
		draw_rect(Rect2(Vector2(-20, 42), Vector2(40, 16)), Color(1.0, 0.4, 0.1, 1.0), false, 1.5)
	
	# Central Fusion Reactor Core
	var core_col = Color(1.0, 0.25, 0.15, 0.95) if not bow_armor_alive else Color(0.4, 0.1, 0.1, 0.6)
	var pulse_speed = 14.0 if not bow_armor_alive else 6.0
	var pulse_mag = 0.25 if not bow_armor_alive else 0.15
	var pulse = 1.0 + sin(flight_time * pulse_speed) * pulse_mag
	draw_circle(Vector2(10, 0), 14.0 * pulse, core_col)
	var ring_col = Color(1.0, 0.8, 0.3, 1.0) if not bow_armor_alive else Color(1.0, 0.7, 0.4, 1.0)
	draw_arc(Vector2(10, 0), 18.0 * (1.1 if not bow_armor_alive else 1.0), 0, TAU, 24, ring_col, 2.0 if not bow_armor_alive else 1.5)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(2)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(2)
