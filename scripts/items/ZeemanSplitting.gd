extends "res://scripts/ItemModifier.gd"

## ZeemanSplitting.gd - Discharges orthogonal lateral beams whenever primary cannon fires.

func _init() -> void:
	id = "zeeman_splitting"
	display_name = "Zeeman Splitting"
	description = "Magnetic divergence discharges twin orthogonal lateral beams (90° flanks) whenever firing to destroy flanking hostiles."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(0.9, 0.3, 1.0, 1.0)
	icon_symbol = "[><]"

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = [spawn_params]
	var base_pos = spawn_params.get("pos", Vector2.ZERO)
	var base_dir = spawn_params.get("dir", Vector2.RIGHT)
	var base_dmg = spawn_params.get("damage", spawn_params.get("dmg", 1.0))
	
	# Twin orthogonal lateral beams angled at +90 and -90 degrees from forward
	var flank_1 = base_dir.rotated(PI * 0.5)
	var flank_2 = base_dir.rotated(-PI * 0.5)
	var flank_dmg = base_dmg * 0.75
	
	results.append({"pos": base_pos, "dir": flank_1, "damage": flank_dmg, "dmg": flank_dmg})
	results.append({"pos": base_pos, "dir": flank_2, "damage": flank_dmg, "dmg": flank_dmg})
	
	return results
