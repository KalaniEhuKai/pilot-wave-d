extends "res://scripts/ItemModifier.gd"

## QuantumTunneling.gd - Bullets phase directly through enemy shields and armor, piercing up to 3 targets.

func _init() -> void:
	id = "quantum_tunneling"
	display_name = "Quantum Tunneling"
	description = "Spectral wavepacket: projectiles phase through enemy shields and armor, piercing through up to 3 targets."
	tier = ItemTier.TIER_1_BALLISTIC
	category = "offense"
	icon_color = Color(0.7, 0.4, 1.0, 1.0)
	icon_symbol = "[|||]"

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var p = spawn_params.duplicate()
	p["pierce_count"] = 3
	p["is_spectral"] = true
	return [p]
