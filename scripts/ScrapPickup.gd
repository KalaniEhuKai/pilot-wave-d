extends Area2D

## ScrapPickup.gd - Energy Scrap / Plasma Joules dropped by defeated enemies.

@export var value: int = 5
var velocity: Vector2 = Vector2.ZERO
var drift_friction: float = 0.95
var lifetime: float = 18.0
var elapsed: float = 0.0

var magnet_speed: float = 0.0

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
	if elapsed >= lifetime:
		queue_free()
		return
	
	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty() and is_instance_valid(players[0]):
		var player = players[0]
		var dist = global_position.distance_to(player.global_position)
		var magnet_range = player.get("scrap_magnet_radius")
		if magnet_range == null:
			magnet_range = 130.0
		
		if dist <= magnet_range:
			# Accelerate toward player
			var dir = (player.global_position - global_position).normalized()
			magnet_speed = move_toward(magnet_speed, 750.0, 1400.0 * delta)
			velocity = dir * magnet_speed
		else:
			magnet_speed = 0.0
			velocity *= drift_friction
	else:
		velocity *= drift_friction
	
	global_position += velocity * delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	_collect(body)

func _on_area_entered(area: Area2D) -> void:
	_collect(area)

func _collect(target: Node2D) -> void:
	if target.is_in_group("player"):
		GameManager.scrap_joules += value
		GameManager.add_score(value * 2) # Collecting scrap also adds bonus score
		SoundEffects.play_sfx("hit", 0.2, 4.0)
		queue_free()

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
