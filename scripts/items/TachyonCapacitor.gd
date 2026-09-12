extends "res://scripts/ItemModifier.gd"

## TachyonCapacitor.gd - Hold primary fire to charge a piercing relativistic hyper-lance.

func _init() -> void:
	id = "tachyon_capacitor"
	display_name = "Tachyon Capacitor"
	description = "Charge primary fire to unleash a high-density relativistic lance that pierces all targets in its line of fire."
	tier = ItemTier.TIER_2_PARADIGM
	icon_color = Color(1.0, 0.2, 0.4, 1.0)
	icon_symbol = "[==>]"

func on_ship_init(ship: CharacterBody2D) -> void:
	ship.set("has_tachyon_capacitor", true)

func on_fire(ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var charge_time = ship.get("fire_charge_time")
	if charge_time == null or charge_time < 0.8:
		return [spawn_params]
	
	var p = spawn_params.duplicate()
	var base_dmg = p.get("damage", p.get("dmg", 1.0))
	var new_dmg = base_dmg * 5.5
	p["damage"] = new_dmg
	p["dmg"] = new_dmg
	p["is_tachyon_lance"] = true
	ship.set_meta("tachyon_discharged", true)
	SoundEffects.play_sfx("laser", 0.05, 1.5)
	return [p]

