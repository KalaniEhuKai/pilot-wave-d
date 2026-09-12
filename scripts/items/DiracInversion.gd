extends "res://scripts/ItemModifier.gd"

## DiracInversion.gd - The Inverted Time Anchor. Absorbs fatal damage once per run, triggering an EMP shockwave and restoring 1 shield.

var has_triggered: bool = false

func _init() -> void:
	id = "dirac_inversion"
	display_name = "Dirac Inversion"
	description = "Absorbs fatal hull damage once per run, triggering an EMP screen clear and restoring 1 shield pip."
	tier = ItemTier.TIER_3_EXOTIC
	icon_color = Color(0.1, 1.0, 0.7, 1.0)
	icon_symbol = "[1UP]"

func on_take_damage(ship: CharacterBody2D, amount: int) -> bool:
	if has_triggered:
		return false
	
	# If incoming damage would deplete final hull pip
	if ship.hull <= amount and ship.shields <= 0:
		has_triggered = true
		SoundEffects.play_sfx("bonus", 0.02, 1.5)
		GameManager.request_screen_shake(15.0, 0.4)
		
		# Restore 1 shield
		ship.shields = 1
		if ship.has_method("_emit_health"):
			ship._emit_health()
		
		# Screen-clearing EMP: erase all enemy bullets
		var tree = ship.get_tree()
		if tree:
			for b in tree.get_nodes_in_group("bullet"):
				if is_instance_valid(b) and b.get("is_enemy") == true:
					b.queue_free()
		return true # Negate the fatal damage!
	
	return false
