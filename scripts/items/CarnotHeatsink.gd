extends "res://scripts/ItemModifier.gd"

## CarnotHeatsink.gd - Overclocks weapon cooling: firing while shields are depleted doubles fire rate.

func _init() -> void:
	id = "carnot_heatsink"
	display_name = "Carnot Heat Sink"
	description = "Emergency thermal protocol: whenever your shields are fully depleted, primary cannon fire rate is doubled."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(1.0, 0.45, 0.1, 1.0)
	icon_symbol = "[^^]"

func on_ship_init(ship: CharacterBody2D) -> void:
	ship.set("has_carnot_heatsink", true)
