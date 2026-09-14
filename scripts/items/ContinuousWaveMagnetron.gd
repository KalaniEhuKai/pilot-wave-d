extends "res://scripts/ItemModifier.gd"

## ContinuousWaveMagnetron.gd - The "Soy Milk" Paradigm of <Pilot | Wave>.
## Massive +350% Fire Rate boost, -70% Damage penalty, slight dispersion, and needle dart velocity.

func _init() -> void:
	id = "continuous_wave_magnetron"
	display_name = "Continuous Wave Magnetron"
	description = "+350% Fire Rate, but -70% Damage. Discharges an unbroken, slightly dispersed torrent of high-frequency plasma darts."
	tier = ItemTier.TIER_2_PARADIGM
	icon_color = Color(0.2, 1.0, 0.7, 1.0)
	icon_symbol = "[===]"
	vector_glyph = "≋"

func on_ship_init(ship: CharacterBody2D) -> void:
	ship.set("has_cw_magnetron", true)
	if "bonus_fire_rate_pct" in ship:
		ship.bonus_fire_rate_pct += 3.5
		ship.bonus_damage_pct -= 0.70
		ship.bonus_bullet_scale_pct -= 0.30
		if ship.has_method("recalculate_stats"):
			ship.recalculate_stats()
	else:
		# Direct fallback for mock / legacy objects
		ship.fire_rate *= 4.5
		if ship.get("damage_mult") != null:
			ship.damage_mult = maxf(0.05, ship.damage_mult * 0.30)
		if ship.get("bullet_scale") != null:
			ship.bullet_scale = maxf(0.2, ship.bullet_scale * 0.70)

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var p = spawn_params.duplicate()
	var dir: Vector2 = p.get("dir", GameAxis.forward if GameAxis != null else Vector2.RIGHT)
	# Subtle natural beam scatter (+-4.3 degrees) for authentic vulcan spray
	var spread_angle = randf_range(-0.075, 0.075)
	p["dir"] = dir.rotated(spread_angle)
	p["is_cw_dart"] = true
	return [p]
