class_name ImpactFlash
extends Node2D

## ImpactFlash.gd - Ultra-lightweight vector kinetic shock-ring and spark.
## Spawns on projectile collision, expands and dissipates in 0.065s.

var current_radius: float = 2.0
var target_radius: float = 12.0
var color: Color = Color(0.1, 0.95, 1.0, 1.0)
var duration: float = 0.065
var elapsed: float = 0.0

func setup(pos: Vector2, p_target_radius: float, p_color: Color) -> void:
	global_position = pos
	target_radius = p_target_radius
	color = p_color
	current_radius = 2.0
	elapsed = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	var t = elapsed / duration
	if t >= 1.0:
		queue_free()
		return
	current_radius = lerpf(2.0, target_radius, sqrt(t))
	queue_redraw()

func _draw() -> void:
	var alpha = 1.0 - (elapsed / duration)
	var ring_col = color
	ring_col.a = alpha * 0.9
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 16, ring_col, 2.0, true)
	
	# Central incandescent core flash during the initial impact frame
	if elapsed < 0.03:
		var core_col = Color.WHITE
		core_col.a = (1.0 - elapsed / 0.03) * 0.8
		draw_circle(Vector2.ZERO, current_radius * 0.45, core_col)
