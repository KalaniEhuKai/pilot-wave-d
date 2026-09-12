extends Area2D

## Bullet.gd - High-readability projectile with combinatorial synergy hooks (Homing, Splitting, Suspension).

@export var is_enemy: bool = false:
	set(value):
		is_enemy = value
		_update_colors()
		queue_redraw()

@export var damage: float = 1.0
@export var speed: float = 540.0
@export var direction: Vector2 = Vector2.RIGHT

var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var glow_color: Color = Color(0.2, 0.95, 1.0, 1.0)
var length: float = 16.0
var radius: float = 4.0

# Synergy variables
var traveled_distance: float = 0.0
var has_split: bool = false
var is_suspended: bool = false
var suspension_timer: float = 0.0
var suspension_ship: CharacterBody2D = null

func _ready() -> void:
	add_to_group("bullet")
	_update_colors()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _update_colors() -> void:
	if is_enemy:
		core_color = Color(1.0, 0.9, 0.95, 1.0)
		glow_color = Color(1.0, 0.1, 0.65, 0.9)
		speed = 420.0
		length = 10.0
		radius = 5.0
		collision_layer = 8
		collision_mask = 1
	else:
		core_color = Color(0.85, 1.0, 1.0, 1.0)
		glow_color = Color(0.1, 0.85, 1.0, 0.9)
		speed = 540.0
		length = 16.0
		radius = 4.0
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
	if is_suspended:
		suspension_timer += delta
		# Slingshot burst on fire release or timeout (2.0s)
		var should_release = false
		if is_instance_valid(suspension_ship):
			if not suspension_ship.is_firing or suspension_timer >= 2.0:
				should_release = true
		else:
			should_release = true
		
		if should_release:
			is_suspended = false
			speed *= 1.45
			SoundEffects.play_sfx("laser", 0.15, -2.0)
		else:
			queue_redraw()
			return # Do not move while suspended
	
	# Projectile modifier hooks (e.g. Gravitational Lensing, Birefringence Prism)
	if not is_enemy:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]):
			var player = players[0]
			for mod in player.active_modifiers:
				mod.on_projectile_tick(self, delta)
	
	var step = speed * delta
	global_position += direction * step
	traveled_distance += step
	
	if GameAxis.is_out_of_bounds(global_position, 60.0):
		queue_free()

func _draw() -> void:
	if is_suspended:
		# Pulsing antimatter suspension plasma orb
		var pulse = 1.0 + sin(suspension_timer * 18.0) * 0.25
		draw_circle(Vector2.ZERO, radius * 3.2 * pulse, Color(1.0, 0.2, 0.5, 0.35))
		draw_circle(Vector2.ZERO, radius * 1.8, Color(1.0, 0.4, 0.7, 0.8))
		draw_circle(Vector2.ZERO, radius * 0.9, Color.WHITE)
		return
	
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
			var pierce = get_meta("pierce_count", 0)
			if pierce > 0:
				set_meta("pierce_count", pierce - 1)
			else:
				queue_free()
