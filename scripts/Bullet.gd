extends Area2D

## Bullet.gd - High-readability relativistic particle projectile for player and enemy weaponry.

@export var is_enemy: bool = false:
	set(value):
		is_enemy = value
		_update_colors()
		queue_redraw()

@export var damage: float = 1.0
@export var speed: float = 800.0
@export var direction: Vector2 = Vector2.RIGHT

var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var glow_color: Color = Color(0.2, 0.95, 1.0, 1.0)
var length: float = 16.0
var radius: float = 4.0

func _ready() -> void:
	_update_colors()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _update_colors() -> void:
	if is_enemy:
		# High-contrast bright magenta with dark outer rim for enemy bullets
		core_color = Color(1.0, 0.9, 0.95, 1.0)
		glow_color = Color(1.0, 0.1, 0.65, 0.9)
		speed = 420.0
		length = 10.0
		radius = 5.0
		# Set collision layers: Enemy bullet is on layer 4, masks layer 1 (Player)
		collision_layer = 8
		collision_mask = 1
	else:
		# Bright cyan with hot white core for player bullets
		core_color = Color(0.85, 1.0, 1.0, 1.0)
		glow_color = Color(0.1, 0.85, 1.0, 0.9)
		speed = 950.0
		length = 18.0
		radius = 3.5
		# Set collision layers: Player bullet is on layer 2, masks layer 4 (Enemy)
		collision_layer = 2
		collision_mask = 4

func setup(p_pos: Vector2, p_dir: Vector2, p_is_enemy: bool = false, p_dmg: float = 1.0) -> void:
	global_position = p_pos
	direction = p_dir.normalized()
	is_enemy = p_is_enemy
	damage = p_dmg
	rotation = direction.angle()
	_update_colors()
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	
	if GameAxis.is_out_of_bounds(global_position, 60.0):
		queue_free()

func _draw() -> void:
	# Draw glowing outer capsule
	var start_pt = Vector2(-length * 0.5, 0)
	var end_pt = Vector2(length * 0.5, 0)
	
	# Wide outer aura
	draw_line(start_pt, end_pt, glow_color, radius * 2.6, true)
	# Saturated body
	draw_line(start_pt, end_pt, glow_color.lightened(0.2), radius * 1.6, true)
	# White-hot plasma core
	draw_line(start_pt + Vector2(2, 0), end_pt, core_color, radius * 0.8, true)

func _on_area_entered(area: Area2D) -> void:
	_handle_hit(area)

func _on_body_entered(body: Node2D) -> void:
	_handle_hit(body)

func _handle_hit(target: Node2D) -> void:
	if is_enemy:
		if target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(damage)
			queue_free()
	else:
		if target.is_in_group("enemy") and target.has_method("take_damage"):
			target.take_damage(damage)
			SoundEffects.play_sfx("hit", 0.15, -4.0)
			queue_free()
