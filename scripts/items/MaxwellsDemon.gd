extends "res://scripts/ItemModifier.gd"

## MaxwellsDemon.gd - Magnetically pulls all energy scrap across screen into engine.

func _init() -> void:
	id = "maxwells_demon"
	display_name = "Maxwell's Demon"
	description = "Violates entropy to magnetically pull all Energy Scrap across the entire screen directly into your ship."
	tier = ItemTier.TIER_3_EXOTIC
	icon_color = Color(1.0, 0.85, 0.2, 1.0)
	icon_symbol = "[M]"

func on_ship_init(ship: CharacterBody2D) -> void:
	if ship.has_method("set_scrap_magnet_radius"):
		ship.set_scrap_magnet_radius(9999.0)
