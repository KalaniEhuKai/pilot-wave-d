extends "res://scripts/ItemModifier.gd"

## ZeemanSplitting.gd - Emits rear-firing counter-projectiles whenever primary cannon fires.

func _init() -> void:
	id = "zeeman_splitting"
	display_name = "Zeeman Splitting"
	description = "Magnetic divergence emits twin rear counter-projectiles whenever firing to protect against flankers."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(0.9, 0.3, 1.0, 1.0)
	icon_symbol = "[><]"

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = [spawn_params]
	var base_pos = spawn_params.get("pos", Vector2.ZERO)
	var base_dir = spawn_params.get("dir", Vector2.RIGHT)
	var base_dmg = spawn_params.get("dmg", 1.0)
	
	# Twin rear shots angled at 165 and 195 degrees from forward
	var rear_1 = base_dir.rotated(PI * 0.9)
	var rear_2 = base_dir.rotated(-PI * 0.9)
	
	results.append({"pos": base_pos, "dir": rear_1, "dmg": base_dmg * 0.6})
	results.append({"pos": base_pos, "dir": rear_2, "dmg": base_dmg * 0.6})
	
	return results
