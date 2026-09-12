extends "res://scripts/ItemModifier.gd"

## ElasticMomentum.gd - Bullets ricochet off screen edges up to 2 times with +25% damage on bounce.

func _init() -> void:
	id = "elastic_momentum"
	display_name = "Elastic Momentum"
	description = "Bullets ricochet off screen bounds up to 2 times, gaining +25% kinetic damage per bounce."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(0.2, 1.0, 0.5, 1.0)
	icon_symbol = "[<>]"

func on_projectile_tick(bullet: Area2D, _delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	var bounces = bullet.get_meta("bounces", 0)
	if bounces >= 2:
		return
	
	var vp = bullet.get_viewport_rect()
	var pos = bullet.global_position
	var bounced = false
	var dir = bullet.direction
	
	if pos.x <= vp.position.x + 8.0 and dir.x < 0:
		dir.x = -dir.x
		bounced = true
	elif pos.x >= vp.position.x + vp.size.x - 8.0 and dir.x > 0:
		dir.x = -dir.x
		bounced = true
	
	if pos.y <= vp.position.y + 8.0 and dir.y < 0:
		dir.y = -dir.y
		bounced = true
	elif pos.y >= vp.position.y + vp.size.y - 8.0 and dir.y > 0:
		dir.y = -dir.y
		bounced = true
	
	if bounced:
		bullet.direction = dir.normalized()
		bullet.damage *= 1.25
		bullet.set_meta("bounces", bounces + 1)
		bullet.glow_color = Color(0.3, 1.0, 0.4, 1.0)
		SoundEffects.play_sfx("hit", 0.1, 3.5)
