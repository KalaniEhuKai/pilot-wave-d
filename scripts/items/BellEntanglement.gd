extends "res://scripts/ItemModifier.gd"

## BellEntanglement.gd - Quantum resonance between ships/orbitals, granting +30% damage and double magnet radius.

func _init() -> void:
	id = "bell_entanglement"
	display_name = "Bell Entanglement"
	description = "Quantum Entanglement: collecting scrap or firing creates a resonance wave granting +30% damage and doubling magnet radius."
	tier = ItemTier.TIER_3_EXOTIC
	icon_color = Color(1.0, 0.7, 0.2, 1.0)
	icon_symbol = "[<->]"

func on_ship_init(ship: CharacterBody2D) -> void:
	ship.scrap_magnet_radius *= 2.0

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var p = spawn_params.duplicate()
	p["dmg"] = p.get("dmg", 1.0) * 1.3
	return [p]
