extends Area2D

## HazardObject.gd - Interactive Environmental Arena Features ("Isaac Room Elements").
## Supports Destructible Asteroids, Explosive Plasma Barrels (TNT), and Quantum Storm Cells.

enum HazardType { ASTEROID, PLASMA_BARREL, STORM_CELL }

@export var hazard_type: HazardType = HazardType.ASTEROID
@export var max_health: float = 15.0
var health: float = 15.0

var velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.5
var radius: float = 24.0

var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")

var is_detonating: bool = false

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 4 # Targetable by bullets
	collision_mask = 3  # Collides with players and player bullets
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	_setup_hazard()

func _setup_hazard() -> void:
	match hazard_type:
		HazardType.ASTEROID:
			max_health = 16.0
			health = max_health
			radius = randf_range(20.0, 32.0)
			rotation_speed = randf_range(-1.2, 1.2)
			var angle = randf() * TAU
			velocity = Vector2(cos(angle), sin(angle)) * randf_range(20.0, 60.0)
		HazardType.PLASMA_BARREL:
			max_health = 2.0
			health = max_health
			radius = 16.0
			rotation_speed = 0.2
			velocity = Vector2(0, randf_range(15.0, 35.0))
		HazardType.STORM_CELL:
			max_health = 9999.0
			health = max_health
			radius = 65.0
			rotation_speed = 0.1
			velocity = Vector2(0, 10.0)

func setup(p_type: HazardType, p_pos: Vector2) -> void:
	hazard_type = p_type
	global_position = p_pos
	_setup_hazard()
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	rotation += rotation_speed * delta
	
	# Wrap or despawn when far off screen
	var vp = get_viewport_rect().size
	if global_position.x < -120 or global_position.x > vp.x + 120 or global_position.y < -120 or global_position.y > vp.y + 120:
		queue_free()
		return
	
	if hazard_type == HazardType.STORM_CELL:
		_apply_storm_slowdown()

func _apply_storm_slowdown() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and global_position.distance_to(p.global_position) <= radius:
			p.current_velocity *= 0.92
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= radius:
			e.position += -e.move_direction * 20.0 * get_physics_process_delta_time()

func take_damage(amount: float) -> void:
	if hazard_type == HazardType.STORM_CELL:
		return
	
	health -= amount
	SoundEffects.play_sfx("hit", 0.08, 2.0)
	
	if health <= 0.0:
		_destroy_hazard()
	else:
		queue_redraw()

func _destroy_hazard() -> void:
	if is_detonating:
		return
	is_detonating = true
	
	match hazard_type:
		HazardType.ASTEROID:
			# Shatters into dust and drops scrap
			var ex = explosion_scene.instantiate()
			get_parent().add_child(ex)
			ex.global_position = global_position
			ex.scale = Vector2(0.8, 0.8)
			
			# Drop 2 scrap pellets
			for i in range(2):
				var s = scrap_scene.instantiate()
				s.value = 5
				get_parent().add_child(s)
				s.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			
			SoundEffects.play_sfx("explosion", 0.12, 1.0)
			queue_free()
			
		HazardType.PLASMA_BARREL:
			# Massive chain-reaction explosion!
			var ex = explosion_scene.instantiate()
			get_parent().add_child(ex)
			ex.global_position = global_position
			ex.scale = Vector2(2.5, 2.5)
			
			SoundEffects.play_sfx("explosion", 0.35, -3.0)
			GameManager.request_screen_shake(12.0, 0.35)
			
			# AOE damage to all nearby enemies in 220px!
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and global_position.distance_to(e.global_position) <= 220.0:
					if e.has_method("take_damage"):
						e.take_damage(35.0)
			
			# Also detonate nearby barrels for chain reactions
			for h in get_tree().get_nodes_in_group("hazard"):
				if is_instance_valid(h) and h != self and h.hazard_type == HazardType.PLASMA_BARREL:
					if global_position.distance_to(h.global_position) <= 220.0:
						h.take_damage(10.0)
			
			queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet"):
		var dmg = area.get("damage")
		take_damage(dmg if dmg != null else 1.0)
		# Asteroids and Barrels absorb the bullet unless piercing
		if hazard_type != HazardType.STORM_CELL:
			if not area.has_meta("pierce_count") or area.get_meta("pierce_count") <= 0:
				area.queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if hazard_type == HazardType.ASTEROID:
			if body.has_method("take_damage"):
				body.take_damage(1)
				take_damage(5.0)
		elif hazard_type == HazardType.PLASMA_BARREL:
			take_damage(10.0)

func _draw() -> void:
	match hazard_type:
		HazardType.ASTEROID:
			var pts: PackedVector2Array = []
			var n = 8
			for i in range(n):
				var a = (float(i) / n) * TAU
				var r = radius * (0.8 + 0.2 * sin(float(i) * 2.5))
				pts.append(Vector2(cos(a) * r, sin(a) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, Color(0.18, 0.22, 0.28, 0.95))
			draw_polyline(pts, Color(0.4, 0.55, 0.7, 1.0), 2.0, true)
		HazardType.PLASMA_BARREL:
			# Red explosive barrel / canister
			var w = 14.0
			var h = 18.0
			var rect = Rect2(-w, -h, w * 2.0, h * 2.0)
			draw_rect(rect, Color(0.9, 0.15, 0.15, 0.95), true)
			draw_rect(rect, Color(1.0, 0.6, 0.1, 1.0), false, 2.0)
			# Hazard cross / stripe
			draw_line(Vector2(-w, 0), Vector2(w, 0), Color(1.0, 0.9, 0.2, 1.0), 2.0)
			draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
		HazardType.STORM_CELL:
			# Shimmering quantum nebula zone
			draw_circle(Vector2.ZERO, radius, Color(0.3, 0.1, 0.6, 0.25))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(0.7, 0.3, 1.0, 0.6), 1.5)
			draw_circle(Vector2.ZERO, radius * 0.5, Color(0.4, 0.2, 0.8, 0.2))
