extends "res://scripts/ItemModifier.gd"

## FeynmanPropagator.gd - Bullets leave glowing vacuum ionization trails that burn enemies.

const FeynmanTrailNodeScript = preload("res://scripts/items/FeynmanTrailNode.gd")

func _init() -> void:
	id = "feynman_propagator"
	display_name = "Feynman Propagator"
	description = "Bullets leave glowing ionized trails in vacuum space that burn passing hostiles."
	tier = ItemTier.TIER_1_BALLISTIC
	icon_color = Color(1.0, 0.4, 0.8, 1.0)
	icon_symbol = "[~~]"
	vector_glyph = "∿"

func on_fire(_ship: CharacterBody2D, spawn_params: Dictionary) -> Array[Dictionary]:
	var p = spawn_params.duplicate()
	p["has_feynman"] = true
	return [p]

func on_projectile_tick(bullet: Area2D, delta: float) -> void:
	if bullet.get("is_enemy") == true:
		return
	
	if not bullet.get("has_feynman") and not bullet.has_meta("has_feynman"):
		if "has_feynman" in bullet:
			bullet.has_feynman = true
		bullet.set_meta("has_feynman", true)
		bullet.queue_redraw()
	
	var last_pos: Vector2 = bullet.feynman_last_pos if "feynman_last_pos" in bullet else bullet.get_meta("feynman_last_pos", Vector2.INF)
	var trail_timer: float = (bullet.feynman_trail_timer if "feynman_trail_timer" in bullet else bullet.get_meta("feynman_trail_timer", 0.0)) + delta
	var dist: float = bullet.global_position.distance_to(last_pos) if last_pos != Vector2.INF else 999.0
	
	# Spawn seamless trail either every 48px traveled or every 0.085s, respecting global active trail budget
	if dist >= 48.0 or trail_timer >= 0.085:
		trail_timer = 0.0
		last_pos = bullet.global_position
		if "feynman_last_pos" in bullet:
			bullet.feynman_last_pos = last_pos
		bullet.set_meta("feynman_last_pos", last_pos)
		if FeynmanTrailNodeScript.active_count < FeynmanTrailNodeScript.MAX_ACTIVE_TRAILS:
			_spawn_trail_node(bullet)
	
	if "feynman_trail_timer" in bullet:
		bullet.feynman_trail_timer = trail_timer
	bullet.set_meta("feynman_trail_timer", trail_timer)

func _spawn_trail_node(bullet: Area2D) -> void:
	var parent = bullet.get_parent()
	if not parent:
		return
	
	var trail = FeynmanTrailNodeScript.acquire(parent)
	var b_dir = bullet.get("direction")
	var angle: float = b_dir.angle() if b_dir is Vector2 else 0.0
	trail.setup(bullet.global_position, angle, 0.45, 16.0, 0.52, icon_color)
