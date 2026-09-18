extends Area2D

## HazardObject.gd - Interactive Environmental Arena Features ("Isaac Room Elements").
## Supports Destructible Asteroids, Explosive Plasma Barrels (TNT), and Quantum Storm Cells.

enum HazardType { ASTEROID, PLASMA_BARREL, STORM_CELL }

@export var hazard_type: HazardType = HazardType.ASTEROID
@export var max_health: float = 15.0
var health: float = 15.0
var use_3d_model: bool = true

var velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.5
var radius: float = 24.0

var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")

var is_detonating: bool = false
var drop_guaranteed: int = 1
var drop_chance: float = 0.0

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 4 # Targetable by bullets
	collision_mask = 3  # Collides with players and player bullets
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	_setup_hazard()
	_register_with_stage_3d()

func _register_with_stage_3d() -> void:
	if use_3d_model and is_inside_tree():
		var stage = get_tree().get_first_node_in_group("stage_3d")
		if not is_instance_valid(stage):
			stage = get_tree().get_root().find_child("Stage3D", true, false)
		if is_instance_valid(stage) and stage.has_method("register_hazard"):
			stage.register_hazard(self)

func _setup_hazard() -> void:
	var scroll = GameAxis.scroll_dir
	var lat = GameAxis.lateral
	match hazard_type:
		HazardType.ASTEROID:
			max_health = 16.0
			health = max_health
			radius = randf_range(20.0, 32.0)
			rotation_speed = randf_range(-1.2, 1.2)
			var scroll_speed = randf_range(75.0, 110.0)
			var lat_drift = randf_range(-20.0, 20.0)
			velocity = (scroll * scroll_speed) + (lat * lat_drift)
		HazardType.PLASMA_BARREL:
			max_health = 2.0
			health = max_health
			radius = 16.0
			rotation_speed = 0.2
			var scroll_speed = randf_range(65.0, 95.0)
			var lat_drift = randf_range(-12.0, 12.0)
			velocity = (scroll * scroll_speed) + (lat * lat_drift)
		HazardType.STORM_CELL:
			max_health = 9999.0
			health = max_health
			radius = 65.0
			rotation_speed = 0.1
			var scroll_speed = 45.0
			velocity = scroll * scroll_speed

func setup(p_type: HazardType, p_pos: Vector2, p_drop_profile: Dictionary = {}) -> void:
	hazard_type = p_type
	global_position = p_pos
	if not p_drop_profile.is_empty():
		drop_guaranteed = p_drop_profile.get("guaranteed", 1)
		drop_chance = p_drop_profile.get("chance", 0.0)
	elif p_type == HazardType.ASTEROID:
		drop_guaranteed = 1
		drop_chance = 0.0
	else:
		drop_guaranteed = 0
		drop_chance = 0.0
	_setup_hazard()
	_register_with_stage_3d()
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	rotation += rotation_speed * delta
	
	# Despawn when drifted past the screen along scroll direction
	if GameAxis.is_out_of_bounds(global_position, 80.0):
		queue_free()
		return

func fade_and_despawn() -> void:
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "modulate:a", 0.0, 0.45)
		tween.tween_callback(queue_free)
	else:
		queue_free()
	
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
			
			# Dynamic scrap drop
			var count = drop_guaranteed + (1 if randf() < drop_chance else 0)
			for i in range(count):
				var s = scrap_scene.instantiate()
				s.value = 1
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
	if hazard_type == HazardType.STORM_CELL:
		return
	if area.has_method("_handle_hit"):
		area._handle_hit(self)
	elif area.is_in_group("bullet"):
		var dmg = area.get("damage")
		take_damage(dmg if dmg != null else 1.0)
		# Asteroids and Barrels absorb the bullet unless piercing
		if not area.has_meta("pierce_count") or area.get_meta("pierce_count") <= 0:
			if area.has_method("recycle"):
				area.recycle()
			else:
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
	if use_3d_model:
		return
		
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
