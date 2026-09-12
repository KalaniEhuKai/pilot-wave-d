extends "res://scripts/ItemModifier.gd"

## CarnotEfficiency.gd - 50% discount on all Sky Merchant wares and reroll fees.

func _init() -> void:
	id = "carnot_efficiency"
	display_name = "Carnot Efficiency"
	description = "Thermal superconductivity grants a permanent 50% discount on all Sky Merchant items and rerolls."
	tier = ItemTier.TIER_3_EXOTIC
	icon_color = Color(1.0, 0.85, 0.1, 1.0)
	icon_symbol = "[50%]"

func on_ship_init(ship: CharacterBody2D) -> void:
	ship.set("has_carnot_efficiency", true)
