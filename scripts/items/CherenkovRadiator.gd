extends "res://scripts/ItemModifier.gd"

## CherenkovRadiator.gd - Defeated hostiles emit an expansive radiation shockwave.

func _init() -> void:
	id = "cherenkov_radiator"
	display_name = "Cherenkov Radiator"
	description = "Defeated hostiles emit a luminous blue radiation shockwave damaging surrounding enemies."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(0.1, 0.6, 1.0, 1.0)
	icon_symbol = "[(o)]"

func on_kill(ship: CharacterBody2D, _victim: Node2D, pos: Vector2) -> void:
	var parent = ship.get_parent()
	if not parent:
		return
	
	SoundEffects.play_sfx("hit", 0.15, 2.5)
	var enemies = ship.get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			var d = pos.distance_to(e.global_position)
			if d <= 110.0:
				e.take_damage(2.0 * (1.0 - (d / 110.0)))
