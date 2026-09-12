extends Area2D

## BossGoliath.gd - Asymmetric Sector 1 Boss: Armored Behemoth Goliath.
## A heavy fortress carrier with sweeping railgun targeting lasers, breakable bow armor, and fighter hangar bays.

signal subsystem_destroyed(subsystem_name: String)

@export var is_miniboss: bool = false
@export var max_core_health: float = 350.0
var core_health: float = 350.0

@export var max_railgun_health: float = 150.0
var port_railgun_health: float = 150.0
var star_railgun_health: float = 150.0

@export var max_armor_health: float = 200.0
var bow_armor_health: float = 200.0

var port_railgun_alive: bool = true
var star_railgun_alive: bool = true
var bow_armor_alive: bool = true

var entry_done: bool = false
var target_entry_pos: Vector2
var strafe_direction: float = 1.0
var flight_time: float = 0.0

# Attack states
var railgun_timer: float = 2.0
var is_charging_railgun: bool = false
var charge_elapsed: float = 0.0
var charge_duration: float = 0.75

var drone_launch_timer: float = 4.0

# Hit flashes
var hit_flash_core: float = 0.0
var hit_flash_port: float = 0.0
var hit_flash_star: float = 0.0
var hit_flash_armor: float = 0.0

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")
var crate_scene: PackedScene = preload("res://scenes/ItemCrate.tscn")
var drone_scene: PackedScene = preload("res://scenes/Enemy.tscn")

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 3
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if is_miniboss:
		max_core_health = 110.0
		max_railgun_health = 45.0
		max_armor_health = 40.0
	
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
	var total = core_health + port_railgun_health + star_railgun_health + bow_armor_health
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
	var strafe_speed = 70.0 if bow_armor_alive else 110.0
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
	# 1. Fighter Drone Hangar Launch
	drone_launch_timer -= delta
	if drone_launch_timer <= 0.0:
		drone_launch_timer = 5.0 if bow_armor_alive else 3.2
		_launch_fighters(2)
	
	# 2. Railgun Battery Charging & Salvo
	if not is_charging_railgun:
		railgun_timer -= delta
		if railgun_timer <= 0.0:
			if port_railgun_alive or star_railgun_alive:
				is_charging_railgun = true
				charge_elapsed = 0.0
				SoundEffects.play_sfx("laser", 0.05, 5.0)
	else:
		charge_elapsed += delta
		if charge_elapsed >= charge_duration:
			is_charging_railgun = false
			railgun_timer = 2.4
			_fire_railguns()

func _fire_railguns() -> void:
	var fwd = -GameAxis.forward
	var lat = GameAxis.lateral
	
	if port_railgun_alive:
		var port_pos = global_position - lat * 48.0
		_spawn_heavy_beam(port_pos, fwd)
	
	if star_railgun_alive:
		var star_pos = global_position + lat * 48.0
		_spawn_heavy_beam(star_pos, fwd)

func _spawn_heavy_beam(pos: Vector2, dir: Vector2) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(pos, dir, true, 2.0)
	b.scale = Vector2(2.0, 1.6)
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
		var offset = GameAxis.lateral * ((i - 0.5) * 60.0)
		drone.setup(0, global_position + offset, 999, null, 0)
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
		var laser_col = Color(1.0, 0.3, 0.1, 0.4 + charge_ratio * 0.5)
		if port_railgun_alive:
			draw_line(-lat * 48.0, -lat * 48.0 + fwd * 750.0, laser_col, 1.5 + charge_ratio * 2.5)
		if star_railgun_alive:
			draw_line(lat * 48.0, lat * 48.0 + fwd * 750.0, laser_col, 1.5 + charge_ratio * 2.5)
	
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
	var core_col = Color(1.0, 0.3, 0.2, 0.9) if not bow_armor_alive else Color(0.4, 0.1, 0.1, 0.6)
	var pulse = 1.0 + sin(flight_time * 6.0) * 0.15
	draw_circle(Vector2(10, 0), 14.0 * pulse, core_col)
	draw_arc(Vector2(10, 0), 18.0, 0, TAU, 24, Color(1.0, 0.7, 0.4, 1.0), 1.5)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(2)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(2)
