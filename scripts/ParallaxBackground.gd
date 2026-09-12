extends Node2D

## ParallaxBackground.gd - Multi-layered cyberpunk starfield, neon circuit grid, and velocity streaks.

var stars_far: Array[Dictionary] = []
var stars_mid: Array[Dictionary] = []
var speed_streaks: Array[Dictionary] = []

var grid_offset: float = 0.0
var warp_speed_mult: float = 1.0

func trigger_warp_streak(duration: float = 0.45) -> void:
	var tw = create_tween()
	tw.tween_property(self, "warp_speed_mult", 5.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "warp_speed_mult", 1.0, duration - 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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
	var speed_scaler = warp_speed_mult
	
	grid_offset = fmod(grid_offset + 90.0 * delta * speed_scaler, 80.0)
	
	# Update far stars
	for s in stars_far:
		s.pos += dir * s.speed * delta * speed_scaler
		_wrap_particle(s, vp)
	
	# Update mid stars
	for s in stars_mid:
		s.pos += dir * s.speed * delta * speed_scaler
		_wrap_particle(s, vp)
	
	# Update speed streaks
	for s in speed_streaks:
		s.pos += dir * s.speed * delta * speed_scaler
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

var bg_color: Color = Color(0.03, 0.04, 0.07, 1.0)
var grid_color: Color = Color(0.1, 0.35, 0.5, 0.12)
var mid_star_color: Color = Color(0.2, 0.7, 1.0, 0.6)
var streak_color: Color = Color(0.3, 0.9, 1.0, 0.4)

func set_sector_theme(sector_num: int) -> void:
	match sector_num:
		1:
			bg_color = Color(0.03, 0.04, 0.07, 1.0)
			grid_color = Color(0.1, 0.35, 0.5, 0.12)
			mid_star_color = Color(0.2, 0.7, 1.0, 0.6)
			streak_color = Color(0.3, 0.9, 1.0, 0.4)
		2:
			bg_color = Color(0.06, 0.03, 0.08, 1.0)
			grid_color = Color(0.5, 0.3, 0.1, 0.15)
			mid_star_color = Color(1.0, 0.7, 0.2, 0.6)
			streak_color = Color(1.0, 0.85, 0.3, 0.45)
		3:
			bg_color = Color(0.05, 0.01, 0.04, 1.0)
			grid_color = Color(0.6, 0.1, 0.3, 0.16)
			mid_star_color = Color(0.9, 0.2, 0.6, 0.65)
			streak_color = Color(1.0, 0.2, 0.4, 0.5)
	
	for s in stars_mid:
		s.color = mid_star_color
	for st in speed_streaks:
		st.color = streak_color
	queue_redraw()

func _draw() -> void:
	var vp = get_viewport_rect().size
	
	# Background base tint
	draw_rect(Rect2(Vector2.ZERO, vp), bg_color)
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
