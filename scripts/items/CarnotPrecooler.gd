extends "res://scripts/ItemModifier.gd"

## CarnotPrecooler.gd - 20% discount on all Sky Merchant wares and reroll fees.

func _init() -> void:
	id = "carnot_precooler"
	display_name = "Carnot Pre-Cooler"
	description = "Cryogenic pre-cooling loop grants a permanent 20% discount on all Sky Merchant items and rerolls."
	tier = ItemTier.TIER_2_PARADIGM
	category = "utility"
	icon_color = Color(0.3, 0.85, 1.0, 1.0)
	icon_symbol = "[20%]"

func on_ship_init(ship: CharacterBody2D) -> void:
	ship.set("has_carnot_precooler", true)
