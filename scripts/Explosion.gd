extends Node2D

## Explosion.gd - Multi-stage cyberpunk shockwave and particle burst with screen shake.

@export var max_radius: float = 48.0
@export var duration: float = 0.45
@export var blast_color: Color = Color(1.0, 0.6, 0.1, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 0.8, 1.0)

var current_radius: float = 0.0
var elapsed: float = 0.0
var particles: Array[Dictionary] = []

func _ready() -> void:
	SoundEffects.play_sfx("explosion", 0.12, -2.0)
	GameManager.request_screen_shake(5.0, 0.18)
	
	var stage = get_tree().get_first_node_in_group("stage_3d")
	if stage and stage.has_method("spawn_explosion_3d"):
		stage.spawn_explosion_3d(global_position, blast_color, max_radius, max_radius >= 60.0)
	
	# Create burst particles
	var particle_count = 16
	for i in range(particle_count):
		var angle = randf() * TAU
		var spd = randf_range(80.0, 260.0)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"size": randf_range(2.0, 4.5),
			"life": randf_range(0.25, 0.45),
			"color": blast_color.lerp(core_color, randf())
		})

func _process(delta: float) -> void:
	elapsed += delta
	var t = clampf(elapsed / duration, 0.0, 1.0)
	
	# Ease-out shockwave expansion
	current_radius = max_radius * (1.0 - pow(1.0 - t, 3.0))
	
	# Update particles
	for p in particles:
		p.pos += p.vel * delta
		p.vel *= 0.94
	
	queue_redraw()
	
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var t = clampf(elapsed / duration, 0.0, 1.0)
	var alpha = 1.0 - t
	
	# Shockwave ring
	var ring_col = blast_color
	ring_col.a = alpha * 0.8
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, ring_col, 3.0 * (1.0 - t * 0.5), true)
	
	# Intense core flash
	if t < 0.3:
		var core_t = 1.0 - (t / 0.3)
		var flash_col = core_color
		flash_col.a = core_t * 0.9
		draw_circle(Vector2.ZERO, current_radius * 0.5 * core_t, flash_col)
	
	# Spark particles
	for p in particles:
		var p_alpha = clampf(1.0 - (elapsed / p.life), 0.0, 1.0)
		if p_alpha > 0.0:
			var c = p.color
			c.a = p_alpha
			draw_circle(p.pos, p.size * p_alpha, c)
