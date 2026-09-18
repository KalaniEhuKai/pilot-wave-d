class_name ImpactFlash
extends Node2D

## ImpactFlash.gd - Ultra-lightweight vector kinetic shock-ring and spark.
## Spawns on projectile collision, expands and dissipates in 0.065s.

static var active_count: int = 0
const MAX_ACTIVE_FLASHES: int = 32
static var _pool: Array[Node2D] = []

var current_radius: float = 2.0
var target_radius: float = 12.0
var color: Color = Color(0.1, 0.95, 1.0, 1.0)
var duration: float = 0.065
var elapsed: float = 0.0

static func acquire(parent: Node) -> Node2D:
	while not _pool.is_empty():
		var f = _pool.pop_back()
		if is_instance_valid(f) and not f.is_queued_for_deletion():
			if f.get_parent() != parent:
				if f.get_parent() != null:
					f.get_parent().remove_child(f)
				parent.add_child(f)
			f.reset_for_pool()
			return f
	var script = load("res://scripts/ImpactFlash.gd")
	var new_f = script.new()
	parent.add_child(new_f)
	return new_f

func reset_for_pool() -> void:
	elapsed = 0.0
	current_radius = 2.0
	visible = true
	set_process(true)
	active_count += 1

func recycle() -> void:
	if is_queued_for_deletion():
		return
	visible = false
	set_process(false)
	global_position = Vector2(-9999, -9999)
	active_count = max(0, active_count - 1)
	_pool.append(self)

func _ready() -> void:
	active_count += 1

func _exit_tree() -> void:
	active_count = max(0, active_count - 1)

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
		recycle()
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
