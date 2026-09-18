extends Node

## GameAxis.gd - Unified coordinate abstraction for Horizontal (16:9) & Vertical (9:16) shmup play.
## Provides forward, lateral, and boundary vectors so gameplay logic remains axis-agnostic.

signal axis_changed(is_vertical: bool)

var is_vertical: bool = false:
	set(value):
		if is_vertical != value:
			is_vertical = value
			_update_vectors()
			axis_changed.emit(is_vertical)

# Directional vectors
var forward: Vector2 = Vector2.RIGHT
var lateral: Vector2 = Vector2.DOWN
var scroll_dir: Vector2 = Vector2.LEFT
var ship_base_rotation: float = 0.0

var _cached_viewport_rect: Rect2 = Rect2(0, 0, 1280, 720)
var _cached_bounds_60: Rect2 = Rect2(0, 0, 1280, 720).grow(60.0)
var _cached_bounds_80: Rect2 = Rect2(0, 0, 1280, 720).grow(80.0)

func _ready() -> void:
	# Ensure desktop platforms launch maximized
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web") and not OS.has_feature("mobile"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	
	# Auto-detect orientation based on window size
	_check_viewport_aspect()
	_refresh_cached_rects()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_vectors()

func _refresh_cached_rects() -> void:
	var vp = get_viewport()
	if vp:
		_cached_viewport_rect = vp.get_visible_rect()
		_cached_bounds_60 = _cached_viewport_rect.grow(60.0)
		_cached_bounds_80 = _cached_viewport_rect.grow(80.0)

func _check_viewport_aspect() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	if vp_size.y > vp_size.x * 1.15:
		is_vertical = true
	else:
		is_vertical = false

func _on_viewport_size_changed() -> void:
	_check_viewport_aspect()
	_refresh_cached_rects()

func toggle_axis() -> void:
	is_vertical = !is_vertical

func set_axis_vertical(vertical: bool) -> void:
	is_vertical = vertical

func _update_vectors() -> void:
	if is_vertical:
		# Flying Upward (Vertical 9:16 Portrait)
		forward = Vector2.UP
		lateral = Vector2.RIGHT
		scroll_dir = Vector2.DOWN
		ship_base_rotation = -PI * 0.5
	else:
		# Flying Rightward (Horizontal 16:9 Landscape)
		forward = Vector2.RIGHT
		lateral = Vector2.DOWN
		scroll_dir = Vector2.LEFT
		ship_base_rotation = 0.0

func get_viewport_rect() -> Rect2:
	return _cached_viewport_rect

func clamp_position(pos: Vector2, margin: float = 32.0) -> Vector2:
	var rect = _cached_viewport_rect
	var min_x = rect.position.x + margin
	var max_x = rect.position.x + rect.size.x - margin
	var min_y = rect.position.y + margin
	var max_y = rect.position.y + rect.size.y - margin
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))

func is_out_of_bounds(pos: Vector2, extra_margin: float = 80.0) -> bool:
	if extra_margin == 60.0:
		return not _cached_bounds_60.has_point(pos)
	elif extra_margin == 80.0:
		return not _cached_bounds_80.has_point(pos)
	return not _cached_viewport_rect.grow(extra_margin).has_point(pos)

func get_spawn_line(offset_along_lateral: float = 0.5) -> Vector2:
	var rect = get_viewport_rect()
	if is_vertical:
		# Spawns 15px from top edge, close to screen edge but on-screen
		var x = rect.position.x + rect.size.x * clampf(offset_along_lateral, 0.05, 0.95)
		var y = rect.position.y + 15.0
		return Vector2(x, y)
	else:
		# Spawns 15px from right edge, close to screen edge but on-screen
		var x = rect.position.x + rect.size.x - 15.0
		var y = rect.position.y + rect.size.y * clampf(offset_along_lateral, 0.05, 0.95)
		return Vector2(x, y)
