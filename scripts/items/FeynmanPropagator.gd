extends "res://scripts/ItemModifier.gd"

## FeynmanPropagator.gd - Bullets leave glowing vacuum ionization trails that burn enemies.

func _init() -> void:
	id = "feynman_propagator"
	display_name = "Feynman Propagator"
	description = "Bullets leave glowing ionized trails in vacuum space that burn passing hostiles."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(1.0, 0.4, 0.8, 1.0)
	icon_symbol = "[~~]"

func on_projectile_tick(bullet: Area2D, delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	var trail_timer = bullet.get_meta("trail_timer", 0.0) + delta
	if trail_timer >= 0.08:
		trail_timer = 0.0
		_spawn_trail_node(bullet)
	bullet.set_meta("trail_timer", trail_timer)

func _spawn_trail_node(bullet: Area2D) -> void:
	var parent = bullet.get_parent()
	if not parent:
		return
	
	var trail = Area2D.new()
	trail.collision_layer = 0
	trail.collision_mask = 4
	trail.global_position = bullet.global_position
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	trail.add_child(col)
	parent.add_child(trail)
	
	trail.area_entered.connect(func(area):
		if area.is_in_group("enemy") and area.has_method("take_damage"):
			area.take_damage(0.4)
	)
	
	var tw = trail.create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(trail.queue_free)
