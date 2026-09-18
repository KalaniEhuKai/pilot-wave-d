extends Area2D

## FeynmanTrailNode.gd - Glowing vacuum ionization node spawned along bullet trajectories.
## Renders an unmistakable glowing quantum field with path integral wavelets (∿) and burns enemies.

static var active_count: int = 0
const MAX_ACTIVE_TRAILS: int = 64
static var _pool: Array[Node] = []

const ImpactFlashScript = preload("res://scripts/ImpactFlash.gd")

static var _shared_shape: CircleShape2D = null

var damage: float = 0.45
var duration: float = 0.52
var elapsed: float = 0.0
var base_radius: float = 16.0
var current_radius: float = 16.0
var trail_color: Color = Color(1.0, 0.35, 0.85, 0.9) # Hot ionized magenta
var core_color: Color = Color(1.0, 0.95, 1.0, 0.95)   # Incandescent white quantum singularity
var wave_phase: float = 0.0
var trail_angle: float = 0.0
var damaged_ids: Dictionary = {}
var col_shape: CollisionShape2D

static func acquire(parent: Node) -> Node:
	while not _pool.is_empty():
		var n = _pool.pop_back()
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			if n.get_parent() != parent:
				if n.get_parent() != null:
					n.get_parent().remove_child(n)
				parent.add_child(n)
			n.reset_for_pool()
			return n
	var script = load("res://scripts/items/FeynmanTrailNode.gd")
	var new_n = script.new()
	parent.add_child(new_n)
	return new_n

func reset_for_pool() -> void:
	elapsed = 0.0
	damaged_ids.clear()
	modulate.a = 1.0
	visible = true
	set_process(true)
	monitoring = true
	monitorable = false
	active_count += 1

func recycle() -> void:
	if is_queued_for_deletion():
		return
	visible = false
	set_process(false)
	monitoring = false
	monitorable = false
	global_position = Vector2(-9999, -9999)
	active_count = max(0, active_count - 1)
	_pool.append(self)

func setup(pos: Vector2, p_angle: float = 0.0, p_damage: float = 0.45, p_radius: float = 16.0, p_duration: float = 0.52, p_color: Color = Color(1.0, 0.35, 0.85, 0.9)) -> void:
	global_position = pos
	trail_angle = p_angle
	damage = p_damage
	base_radius = p_radius
	current_radius = p_radius
	duration = p_duration
	trail_color = p_color
	wave_phase = randf_range(0.0, TAU)
	queue_redraw()

func _ready() -> void:
	active_count += 1
	collision_layer = 0
	collision_mask = 4 # Hostiles & Destructible Hazards
	
	col_shape = CollisionShape2D.new()
	if _shared_shape == null:
		_shared_shape = CircleShape2D.new()
		_shared_shape.radius = 16.0
	col_shape.shape = _shared_shape
	add_child(col_shape)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _exit_tree() -> void:
	active_count = max(0, active_count - 1)

func _on_area_entered(area: Area2D) -> void:
	_apply_burn(area)

func _on_body_entered(body: Node2D) -> void:
	_apply_burn(body)

func _apply_burn(target: Node2D) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	
	var tid = target.get_instance_id()
	if damaged_ids.has(tid):
		return
	
	if target.is_in_group("enemy") or target.is_in_group("boss") or target.has_method("take_damage"):
		if target.has_method("take_damage"):
			damaged_ids[tid] = true
			target.take_damage(damage)
			
			# Micro visual impact spark at the burn point (throttled)
			if ImpactFlashScript.active_count < ImpactFlashScript.MAX_ACTIVE_FLASHES:
				var parent_node = get_parent()
				if parent_node:
					var flash = ImpactFlashScript.acquire(parent_node)
					flash.setup(target.global_position, 14.0, trail_color)
			
			# Crisp high-frequency audio tick
			SoundEffects.play_sfx("hit", 0.04, -8.0, 1.85)

func _process(delta: float) -> void:
	elapsed += delta
	var t = clampf(elapsed / duration, 0.0, 1.0)
	if t >= 1.0:
		recycle()
		return
	
	# Fade smoothly using GPU canvas item modulate rather than regenerating vector vertices
	modulate.a = 1.0 - t

func _draw() -> void:
	# 1. Outer Translucent Ionization Glow / Vacuum Distortion Bubble
	var outer_halo = trail_color
	outer_halo.a = 0.35
	draw_circle(Vector2.ZERO, current_radius * 1.35, outer_halo)
	
	# 2. Mid-Field Ionized Plasma Core
	var mid_shroud = trail_color.lightened(0.2)
	mid_shroud.a = 0.65
	draw_circle(Vector2.ZERO, current_radius * 0.75, mid_shroud)
	
	# 3. White-Hot Quantum Singularity Center
	var c_col = core_color
	c_col.a = 0.95
	draw_circle(Vector2.ZERO, current_radius * 0.32, c_col)
	
	# 4. Feynman Propagator Sinusoidal Path Integral Wiggle (∿)
	var num_pts = 9
	var half_w = current_radius * 1.15
	var pts = PackedVector2Array()
	for i in range(num_pts):
		var nx = lerpf(-half_w, half_w, float(i) / float(num_pts - 1))
		var ny = sin(nx * 0.30 + wave_phase) * (current_radius * 0.35)
		pts.append(Vector2(nx, ny).rotated(trail_angle))
	
	var wave_col = Color(1.0, 0.88, 1.0, 0.85)
	draw_polyline(pts, wave_col, 1.8, true)
	
	# 5. Quantum Vacuum Virtual Particle Flecks (2 orbiting micro-sparks)
	for s_idx in range(2):
		var s_ang = wave_phase * (1.6 if s_idx == 0 else -1.8) + s_idx * PI
		var s_dist = current_radius * (0.6 + 0.3 * sin(wave_phase * 0.5 + s_idx))
		var spark_pos = Vector2(cos(s_ang), sin(s_ang)) * s_dist
		var spark_col = Color(1.0, 0.92, 1.0, 0.8)
		draw_circle(spark_pos, 1.4, spark_col)
