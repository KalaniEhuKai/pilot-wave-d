extends "res://scripts/ItemModifier.gd"

## GravitationalLensing.gd - Homing curvature bending paths toward nearest enemy.

var homing_strength: float = 6.0
var detection_radius: float = 400.0

func _init() -> void:
	id = "gravitational_lensing"
	display_name = "Gravitational Lensing"
	description = "Spacetime curvature bends projectile paths violently toward the nearest enemy."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(0.8, 0.4, 1.0, 1.0)
	icon_symbol = "[O]"

func on_projectile_tick(bullet: Area2D, delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	var tree = bullet.get_tree()
	if not tree:
		return
	
	var enemies = tree.get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	
	var nearest_enemy: Node2D = null
	var min_dist_sq: float = detection_radius * detection_radius
	
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d_sq = bullet.global_position.distance_squared_to(e.global_position)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			nearest_enemy = e
	
	if nearest_enemy:
		var desired_dir = (nearest_enemy.global_position - bullet.global_position).normalized()
		bullet.direction = bullet.direction.slerp(desired_dir, homing_strength * delta).normalized()
		bullet.rotation = bullet.direction.angle()
