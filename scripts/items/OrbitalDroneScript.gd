extends Area2D

## OrbitalDroneScript.gd - Lightweight orbital drone movement and micro-laser firing.

var angle: float = 0.0
var orbit_radius: float = 48.0
var orbit_speed: float = 2.8
var fire_timer: float = 0.8
var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

func _process(delta: float) -> void:
	angle += orbit_speed * delta
	position = Vector2(cos(angle), sin(angle)) * orbit_radius
	
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = 0.9
		_fire_support_laser()
	queue_redraw()

func _fire_support_laser() -> void:
	var parent_scene = get_tree().current_scene
	if not parent_scene:
		return
	
	var b = bullet_scene.instantiate()
	parent_scene.add_child(b)
	b.setup(global_position, GameAxis.forward, false, 0.5)
	b.scale = Vector2(0.6, 0.6)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.8, 1.0, 0.9))
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 16, Color(0.4, 1.0, 0.9, 0.8), 1.5)
