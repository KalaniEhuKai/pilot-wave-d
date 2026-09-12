extends "res://scripts/ItemModifier.gd"

## HeisenbergLens.gd - Erratic quantum jitter with a 25% chance for a +150% critical damage spike.

func _init() -> void:
	id = "heisenberg_lens"
	display_name = "Heisenberg Lens"
	description = "Projectiles jitter with quantum uncertainty, gaining a 25% chance of rolling a +150% critical damage spike."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(1.0, 0.9, 0.2, 1.0)
	icon_symbol = "[?]"

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var p = spawn_params.duplicate()
	var dir = p.get("dir", Vector2.RIGHT)
	# Slight erratic angular jitter
	dir = dir.rotated(randf_range(-0.08, 0.08))
	p["dir"] = dir
	
	if randf() < 0.25:
		p["dmg"] = p.get("dmg", 1.0) * 2.5
	
	return [p]
