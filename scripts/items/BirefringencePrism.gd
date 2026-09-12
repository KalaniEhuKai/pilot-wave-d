extends "res://scripts/ItemModifier.gd"

## BirefringencePrism.gd - Projectiles split into 3 refracted beams after 180px.

func _init() -> void:
	id = "birefringence_prism"
	display_name = "Birefringence Prism"
	description = "Projectiles split into 3 refracted beams after traveling 180px."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(0.3, 0.9, 1.0, 1.0)
	icon_symbol = "[/]"

func on_projectile_tick(bullet: Area2D, _delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	if not bullet.has_split and bullet.traveled_distance >= 180.0:
		bullet.has_split = true
		_split_bullet(bullet)

func _split_bullet(bullet: Area2D) -> void:
	var parent = bullet.get_parent()
	if not parent:
		return
	
	var base_dir = bullet.direction
	var angles = [-0.32, 0.32] # ~18 degrees split
	
	for angle in angles:
		var new_dir = base_dir.rotated(angle)
		var b = bullet.duplicate()
		parent.add_child(b)
		b.setup(bullet.global_position, new_dir, false, bullet.damage * 0.75)
		b.has_split = true
		b.traveled_distance = 180.0
