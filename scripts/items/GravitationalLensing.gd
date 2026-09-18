extends "res://scripts/ItemModifier.gd"

## GravitationalLensing.gd - Homing curvature bending paths toward nearest enemy.

var homing_strength: float = 2.2
var detection_radius: float = 360.0

func _init() -> void:
	id = "gravitational_lensing"
	display_name = "Gravitational Lensing"
	description = "Spacetime curvature bends projectile paths toward the nearest enemy."
	tier = ItemTier.TIER_2_PARADIGM
	icon_color = Color(0.8, 0.4, 1.0, 1.0)
	icon_symbol = "[O]"

func on_projectile_tick(bullet: Area2D, delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	var retarget_timer: float = bullet.get_meta("gl_retarget_timer", 0.0) + delta
	var target: Node2D = bullet.get_meta("gl_target", null)
	
	if not is_instance_valid(target) or target.is_queued_for_deletion() or retarget_timer >= 0.08:
		retarget_timer = 0.0
		var tree = bullet.get_tree()
		if not tree:
			return
		
		var enemies = tree.get_nodes_in_group("enemy")
		if enemies.is_empty():
			bullet.set_meta("gl_target", null)
			bullet.set_meta("gl_retarget_timer", retarget_timer)
			return
		
		var nearest_enemy: Node2D = null
		var min_dist_sq: float = detection_radius * detection_radius
		
		for e in enemies:
			if not is_instance_valid(e) or e.is_queued_for_deletion():
				continue
			var d_sq = bullet.global_position.distance_squared_to(e.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				nearest_enemy = e
		
		target = nearest_enemy
		bullet.set_meta("gl_target", target)
	
	bullet.set_meta("gl_retarget_timer", retarget_timer)
	
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		var desired_dir = (target.global_position - bullet.global_position).normalized()
		bullet.direction = bullet.direction.slerp(desired_dir, homing_strength * delta).normalized()
		bullet.rotation = bullet.direction.angle()
