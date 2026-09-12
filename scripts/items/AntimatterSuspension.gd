extends "res://scripts/ItemModifier.gd"

## AntimatterSuspension.gd - Freezes bullets in space upon firing, releasing into synchronized burst.

func _init() -> void:
	id = "antimatter_suspension"
	display_name = "Anti-Matter Suspension"
	description = "Bullets freeze motionless in space upon firing. Releasing fire violently slingshots them all forward in a synchronized burst."
	tier = ItemTier.TIER_2_PARADIGM
	icon_color = Color(1.0, 0.3, 0.5, 1.0)
	icon_symbol = "[#]"

func on_fire(ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var params = spawn_params.duplicate()
	params["is_suspended"] = true
	params["suspension_ship"] = ship
	return [params]
