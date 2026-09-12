extends Area2D

## Enemy.gd - Cyberpunk shmup enemy craft with Elite Affixes (Armored, Volatile) and Scrap/Crate drops.

enum EnemyType { SCOUT, BOMBER }
enum EliteAffix { NONE, ARMORED, VOLATILE }

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

# Visuals
var hit_flash_timer: float = 0.0
var main_color: Color = Color(1.0, 0.2, 0.4, 1.0)
var accent_color: Color = Color(1.0, 0.6, 0.1, 1.0)

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
	match enemy_type:
		EnemyType.SCOUT:
			max_health = 2.0
			speed = 320.0
			score_value = 100
			main_color = Color(1.0, 0.25, 0.45, 1.0)
			accent_color = Color(1.0, 0.7, 0.2, 1.0)
			fire_interval = 2.4
			fire_timer = randf_range(1.0, 2.0)
		EnemyType.BOMBER:
			max_health = 7.0
			speed = 170.0
			score_value = 250
			main_color = Color(0.95, 0.15, 0.85, 1.0)
			accent_color = Color(0.3, 0.9, 1.0, 1.0)
			fire_interval = 1.8
			fire_timer = 0.8
	
	# Apply Elite Affix modifiers
	match elite_affix:
		EliteAffix.ARMORED:
			max_health *= 2.5
			speed *= 0.8
			score_value *= 3
			main_color = Color(1.0, 0.85, 0.2, 1.0) # Golden Armor
			accent_color = Color(1.0, 0.95, 0.5, 1.0)
		EliteAffix.VOLATILE:
			max_health *= 1.4
			score_value *= 2
			main_color = Color(1.0, 0.35, 0.05, 1.0) # Volatile Orange
			accent_color = Color(1.0, 0.8, 0.1, 1.0)
	
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
	
	var fwd_progress = -GameAxis.forward * speed * delta
	var lat_offset = GameAxis.lateral * cos(flight_time * lateral_frequency) * lateral_amplitude * delta
	
	global_position += fwd_progress + lat_offset
	rotation = (-GameAxis.forward).normalized().angle()
	
	_handle_firing(delta)
	
	if GameAxis.is_out_of_bounds(global_position, 80.0) and flight_time > 1.0:
		if spawner_ref and spawner_ref.has_method("record_squad_escaped"):
			spawner_ref.record_squad_escaped(squad_id)
		queue_free()

func _handle_firing(delta: float) -> void:
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_interval
		
		var players = get_tree().get_nodes_in_group("player")
		var target_dir = -GameAxis.forward
		if players.size() > 0 and is_instance_valid(players[0]):
			target_dir = (players[0].global_position - global_position).normalized()
		
		if enemy_type == EnemyType.SCOUT:
			_spawn_bullet(global_position, target_dir)
		elif enemy_type == EnemyType.BOMBER:
			var side = target_dir.orthogonal() * 12.0
			_spawn_bullet(global_position + side, target_dir)
			_spawn_bullet(global_position - side, target_dir)

func _spawn_bullet(pos: Vector2, dir: Vector2) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(pos, dir, true, 1.0)

func take_damage(amount: float) -> void:
	health -= amount
	hit_flash_timer = 0.09
	queue_redraw()
	
	if health <= 0.0:
		_die()

func _die() -> void:
	GameManager.add_score(score_value)
	GameManager.record_kill()
	
	if spawner_ref and spawner_ref.has_method("record_squad_kill"):
		spawner_ref.record_squad_kill(squad_id)
	
	# Spawn explosion
	var exp_node = explosion_scene.instantiate()
	get_parent().add_child(exp_node)
	exp_node.global_position = global_position
	exp_node.max_radius = 56.0 if enemy_type == EnemyType.BOMBER else 36.0
	
	# Volatile death-burst (8-way ring of bullets)
	if elite_affix == EliteAffix.VOLATILE:
		var ring_count = 8
		for i in range(ring_count):
			var angle = (float(i) / ring_count) * TAU
			var dir = Vector2(cos(angle), sin(angle))
			_spawn_bullet(global_position, dir)
	
	# Drop Scrap / Joules
	var scrap_drops = 2
	if elite_affix != EliteAffix.NONE:
		scrap_drops = 6
	elif enemy_type == EnemyType.BOMBER:
		scrap_drops = 4
	
	for i in range(scrap_drops):
		var sc = scrap_scene.instantiate()
		get_parent().add_child(sc)
		sc.global_position = global_position
	
	# Elite Champions drop an Item Crate!
	if elite_affix != EliteAffix.NONE:
		var crate = crate_scene.instantiate()
		get_parent().add_child(crate)
		crate.global_position = global_position
	
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(1)
		take_damage(2.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		take_damage(2.0)

func _draw() -> void:
	var draw_col = main_color
	var core_col = accent_color
	
	if hit_flash_timer > 0.0:
		draw_col = Color.WHITE
		core_col = Color.WHITE
	
	if enemy_type == EnemyType.SCOUT:
		var nose = Vector2(18, 0)
		var wing_top = Vector2(-12, -14)
		var wing_bot = Vector2(-12, 14)
		var rear = Vector2(-8, 0)
		var poly = PackedVector2Array([nose, wing_top, rear, wing_bot])
		draw_colored_polygon(poly, Color(0.18, 0.04, 0.08, 0.95))
		draw_polyline(poly + PackedVector2Array([nose]), draw_col, 2.2, true)
		draw_circle(Vector2(2, 0), 3.0, core_col)
	else:
		var nose = Vector2(24, 0)
		var w_top1 = Vector2(8, -18)
		var w_top2 = Vector2(-16, -22)
		var rear = Vector2(-20, 0)
		var w_bot2 = Vector2(-16, 22)
		var w_bot1 = Vector2(8, 18)
		var poly = PackedVector2Array([nose, w_top1, w_top2, rear, w_bot2, w_bot1])
		draw_colored_polygon(poly, Color(0.15, 0.04, 0.18, 0.95))
		draw_polyline(poly + PackedVector2Array([nose]), draw_col, 2.8, true)
		draw_circle(Vector2(6, 0), 5.0, core_col)
		draw_line(Vector2(4, -10), Vector2(16, -10), core_col, 2.0)
		draw_line(Vector2(4, 10), Vector2(16, 10), core_col, 2.0)
	
	# Elite Champion aura ring
	if elite_affix != EliteAffix.NONE:
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 24, draw_col.lightened(0.2), 1.8, true)
