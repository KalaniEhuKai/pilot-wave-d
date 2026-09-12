extends "res://scripts/ItemModifier.gd"

## MeissnerShield.gd - Superconducting field negates first hit in every wave.

var is_active: bool = true

func _init() -> void:
	id = "meissner_shield"
	display_name = "Meissner Shield Matrix"
	description = "Superconducting magnetic field completely negates the first hit taken in every combat wave."
	tier = ItemTier.TIER_3_EXOTIC
	icon_color = Color(0.1, 0.95, 0.7, 1.0)
	icon_symbol = "[S]"
	is_active = true

func on_wave_start(_ship: CharacterBody2D, _wave_index: int) -> void:
	is_active = true
	SoundEffects.play_sfx("bonus", 0.08, -4.0)

func on_take_damage(ship: CharacterBody2D, _amount: int) -> bool:
	if is_active:
		is_active = false
		SoundEffects.play_sfx("bonus", 0.15, 2.0)
		GameManager.request_screen_shake(8.0, 0.25)
		if ship.has_method("spawn_meissner_fx"):
			ship.spawn_meissner_fx()
		return true
	return false
