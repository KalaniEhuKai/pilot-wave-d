extends Node2D

## ParallaxBackground.gd - Multi-layered cyberpunk starfield, neon circuit grid, and velocity streaks.

var stars_far: Array[Dictionary] = []
var stars_mid: Array[Dictionary] = []
var speed_streaks: Array[Dictionary] = []

var grid_offset: float = 0.0

func _ready() -> void:
	_init_particles()
	get_viewport().size_changed.connect(_init_particles)

func _init_particles() -> void:
	var vp = get_viewport_rect().size
	var count_far = 80
	var count_mid = 45
	var count_streaks = 25
	
	stars_far.clear()
	for i in range(count_far):
		stars_far.append({
			"pos": Vector2(randf() * vp.x, randf() * vp.y),
			"size": randf_range(1.0, 2.0),
			"alpha": randf_range(0.3, 0.7),
			"speed": randf_range(30.0, 60.0)
		})
	
	stars_mid.clear()
	for i in range(count_mid):
		stars_mid.append({
			"pos": Vector2(randf() * vp.x, randf() * vp.y),
			"size": randf_range(2.0, 3.5),
			"color": Color(0.2, 0.7, 1.0, randf_range(0.4, 0.8)),
			"speed": randf_range(100.0, 160.0)
		})
	
	speed_streaks.clear()
	for i in range(count_streaks):
		speed_streaks.append({
			"pos": Vector2(randf() * vp.x, randf() * vp.y),
			"length": randf_range(40.0, 110.0),
			"color": Color(0.3, 0.9, 1.0, randf_range(0.2, 0.6)),
			"speed": randf_range(380.0, 650.0)
		})

func _process(delta: float) -> void:
	var vp = get_viewport_rect().size
	var dir = GameAxis.scroll_dir
	
	grid_offset = fmod(grid_offset + 90.0 * delta, 80.0)
	
	# Update far stars
	for s in stars_far:
		s.pos += dir * s.speed * delta
		_wrap_particle(s, vp)
	
	# Update mid stars
	for s in stars_mid:
		s.pos += dir * s.speed * delta
		_wrap_particle(s, vp)
	
	# Update speed streaks
	for s in speed_streaks:
		s.pos += dir * s.speed * delta
		_wrap_particle(s, vp)
	
	queue_redraw()

func _wrap_particle(p: Dictionary, vp: Vector2) -> void:
	if p.pos.x < -40.0:
		p.pos.x = vp.x + 40.0
		p.pos.y = randf() * vp.y
	elif p.pos.x > vp.x + 40.0:
		p.pos.x = -40.0
		p.pos.y = randf() * vp.y
	
	if p.pos.y < -40.0:
		p.pos.y = vp.y + 40.0
		p.pos.x = randf() * vp.x
	elif p.pos.y > vp.y + 40.0:
		p.pos.y = -40.0
		p.pos.x = randf() * vp.x

func _draw() -> void:
	var vp = get_viewport_rect().size
	
	# Background base tint
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.07, 1.0))
	
	# Cyberpunk subtle neon grid
	var grid_color = Color(0.1, 0.35, 0.5, 0.12)
	var step = 80.0
	
	if GameAxis.is_vertical:
		# Vertical grid lines
		var x = 0.0
		while x <= vp.x:
			draw_line(Vector2(x, 0), Vector2(x, vp.y), grid_color, 1.0)
			x += step
		# Scrolling horizontal grid lines
		var y = grid_offset
		while y <= vp.y:
			draw_line(Vector2(0, y), Vector2(vp.x, y), grid_color, 1.0)
			y += step
	else:
		# Horizontal grid lines
		var y = 0.0
		while y <= vp.y:
			draw_line(Vector2(0, y), Vector2(vp.x, y), grid_color, 1.0)
			y += step
		# Scrolling vertical grid lines
		var x = grid_offset
		while x <= vp.x:
			draw_line(Vector2(x, 0), Vector2(x, vp.y), grid_color, 1.0)
			x += step
	
	# Draw far stars
	for s in stars_far:
		draw_circle(s.pos, s.size, Color(0.8, 0.9, 1.0, s.alpha))
	
	# Draw mid stars
	for s in stars_mid:
		draw_circle(s.pos, s.size, s.color)
	
	# Draw velocity streaks along scroll direction
	for s in speed_streaks:
		var start_pt = s.pos
		var end_pt = s.pos + (-GameAxis.forward) * s.length
		draw_line(start_pt, end_pt, s.color, 1.5, true)
