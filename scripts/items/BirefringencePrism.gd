extends "res://scripts/ItemModifier.gd"

## BirefringencePrism.gd - Projectiles split into 3 refracted beams after 180px.

const BulletScript = preload("res://scripts/Bullet.gd")

func _init() -> void:
	id = "birefringence_prism"
	display_name = "Birefringence Prism"
	description = "Projectiles split into 3 refracted beams after traveling 180px."
	tier = ItemTier.TIER_2_PARADIGM
	icon_color = Color(0.3, 0.9, 1.0, 1.0)
	icon_symbol = "[/]"

func on_projectile_tick(bullet: Area2D, _delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	if not bullet.has_split and bullet.traveled_distance >= 180.0:
		bullet.has_split = true
		_split_bullet(bullet)

func _split_bullet(bullet: Area2D) -> void:
	var parent = bullet.get_parent()
	if not parent:
		return
	
	var base_dir = bullet.direction
	var angles = [-0.32, 0.32] # ~18 degrees split
	
	# Preserve metadata from source projectile
	var shooter = bullet.shooter if "shooter" in bullet and bullet.shooter != null else (bullet.get_meta("shooter") if bullet.has_meta("shooter") else null)
	var has_fey = bullet.has_feynman if "has_feynman" in bullet and bullet.has_feynman else (bullet.get_meta("has_feynman") if bullet.has_meta("has_feynman") else false)
	var is_crit = bullet.is_crit if "is_crit" in bullet and bullet.is_crit else (bullet.get_meta("is_crit") if bullet.has_meta("is_crit") else false)
	var is_cw = bullet.is_cw_dart if "is_cw_dart" in bullet and bullet.is_cw_dart else (bullet.get_meta("is_cw_dart") if bullet.has_meta("is_cw_dart") else false)
	var pierce = bullet.pierce_count if "pierce_count" in bullet and bullet.pierce_count > 0 else (bullet.get_meta("pierce_count") if bullet.has_meta("pierce_count") else 0)
	
	for angle in angles:
		var new_dir = base_dir.rotated(angle)
		var b = BulletScript.acquire(parent, false)
		b.setup(bullet.global_position, new_dir, false, bullet.damage * 0.75)
		b.has_split = true
		b.traveled_distance = 180.0
		b.speed = bullet.speed
		b.scale = bullet.scale
		b.glow_color = bullet.glow_color
		b.core_color = bullet.core_color
		b.shooter = shooter
		b.projectile_modifiers = bullet.projectile_modifiers.duplicate() if "projectile_modifiers" in bullet else []
		b.has_feynman = has_fey
		b.is_crit = is_crit
		b.is_cw_dart = is_cw
		b.pierce_count = pierce
		if shooter != null:
			b.set_meta("shooter", shooter)
		if has_fey:
			b.set_meta("has_feynman", true)
		if is_crit:
			b.set_meta("is_crit", true)
		if is_cw:
			b.set_meta("is_cw_dart", true)
		if pierce > 0:
			b.set_meta("pierce_count", pierce)
		b.queue_redraw()
