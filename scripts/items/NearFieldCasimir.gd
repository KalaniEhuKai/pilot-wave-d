extends "res://scripts/ItemModifier.gd"

## NearFieldCasimir.gd - The "Proptosis" Paradigm of <Pilot | Wave>.
## Massive +220% Point-Blank Damage and colossal projectile caliber up close,
## rapidly decaying over travel distance to -75% damage and needle size at long range.

func _init() -> void:
	id = "casimir_discharge"
	display_name = "Near-Field Casimir Discharge"
	description = "+220% Point-Blank Damage and enlarged bolts at close range (0-160px). Energy rapidly decays over distance (-75% damage past 400px)."
	tier = ItemTier.TIER_2_PARADIGM
	icon_color = Color(1.0, 0.45, 0.15, 1.0)
	icon_symbol = "[>|]"
	vector_glyph = "⦿"

func on_ship_init(ship: CharacterBody2D) -> void:
	ship.set("has_casimir_discharge", true)

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var p = spawn_params.duplicate()
	p["is_casimir"] = true
	return [p]

func on_projectile_tick(bullet: Area2D, _delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	if not bullet.has_meta("casimir_base_damage"):
		bullet.set_meta("casimir_base_damage", bullet.damage)
		bullet.set_meta("casimir_base_scale", bullet.scale)
	
	var base_dmg: float = bullet.get_meta("casimir_base_damage", bullet.damage)
	var base_scale: Vector2 = bullet.get_meta("casimir_base_scale", bullet.scale)
	var d = bullet.traveled_distance
	
	# Close range (0-140px): 2.2x damage and 1.6x size
	# Far range (420px+): 0.25x damage (-75%) and 0.5x size
	var t = clampf((d - 140.0) / 280.0, 0.0, 1.0)
	var dmg_factor = lerpf(2.2, 0.25, t)
	var scale_factor = lerpf(1.6, 0.5, t)
	
	bullet.damage = base_dmg * dmg_factor
	bullet.scale = base_scale * scale_factor
