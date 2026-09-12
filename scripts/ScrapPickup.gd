extends Area2D

## ScrapPickup.gd - Energy Scrap / Plasma Joules dropped by defeated enemies.

const ProgressionModel = preload("res://scripts/ProgressionModel.gd")

@export var value: int = ProgressionModel.BASE_SCRAP_VALUE
@export var drift_speed: float = 60.0
var velocity: Vector2 = Vector2.ZERO
var drift_friction: float = 0.95
var lifetime: float = 18.0
var elapsed: float = 0.0

var magnet_speed: float = 0.0
var is_collected: bool = false

func _ready() -> void:
	add_to_group("scrap")
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Initial outward pop
	var angle = randf() * TAU
	velocity = Vector2(cos(angle), sin(angle)) * randf_range(60.0, 160.0)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime or GameAxis.is_out_of_bounds(global_position, 100.0):
		_check_singularity_recovery()
		queue_free()
		return
	
	# Find nearest player
	var players = get_tree().get_nodes_in_group("player")
	var closest_player: Node2D = null
	var min_dist: float = INF
	for p in players:
		if is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest_player = p
	
	if closest_player != null:
		var magnet_range = closest_player.get("scrap_magnet_radius")
		if magnet_range == null:
			magnet_range = 130.0
		
		if min_dist <= magnet_range:
			# Accelerate toward nearest player
			var dir = (closest_player.global_position - global_position).normalized()
			magnet_speed = move_toward(magnet_speed, 750.0, 1400.0 * delta)
			velocity = dir * magnet_speed
			global_position += velocity * delta
		else:
			magnet_speed = 0.0
			velocity *= drift_friction
			global_position += (velocity + GameAxis.scroll_dir * drift_speed) * delta
	else:
		velocity *= drift_friction
		global_position += (velocity + GameAxis.scroll_dir * drift_speed) * delta
	
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	_collect(body)

func _on_area_entered(area: Area2D) -> void:
	_collect(area)

func _collect(target: Node2D) -> void:
	if is_collected or is_queued_for_deletion():
		return
	var player: Node2D = target
	if not player.is_in_group("player") and target.get_parent() != null and target.get_parent().is_in_group("player"):
		player = target.get_parent()
	
	if player.is_in_group("player"):
		is_collected = true
		var bonus_chance = player.get("scrap_bonus_chance")
		var legacy_bonus = player.get("bonus_scrap_val")
		var extra_j = (int(legacy_bonus) if legacy_bonus != null else 0)
		if bonus_chance != null and randf() < float(bonus_chance):
			extra_j += 1
		var add_val = value + extra_j
		GameManager.add_joules(add_val) # 0 = shared pickup, credits both players in co-op
		GameManager.add_score(add_val * 2)
		SoundEffects.play_sfx("hit", 0.2, 4.0)
		queue_free()

func _check_singularity_recovery() -> void:
	if is_collected:
		return
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.get("has_singularity_recovery"):
			is_collected = true
			GameManager.add_joules(value)
			GameManager.add_score(value * 2)
			SoundEffects.play_sfx("bonus", 0.05, 5.0)
			break

func _draw() -> void:
	# Draw glowing plasma rhomboid / diamond
	var pts = PackedVector2Array([
		Vector2(0, -7),
		Vector2(5, 0),
		Vector2(0, 7),
		Vector2(-5, 0)
	])
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.25, 0.95))
	draw_polyline(pts + PackedVector2Array([Vector2(0, -7)]), Color(1.0, 1.0, 0.8, 1.0), 1.5, true)
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
