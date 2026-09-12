extends Node2D

## Main.gd - Orchestrates the 60-second playable combat prototype, camera shake, and stage boundaries.

@onready var camera: Camera2D = $Camera2D
@onready var player_spawn_point: Marker2D = $PlayerSpawnPoint
@onready var background: Node2D = $ParallaxBackground
@onready var spawner: Node2D = $DecoherenceSpawner

var player_scene: PackedScene = preload("res://scenes/Player.tscn")
var player_instance: Node2D = null

# Screen shake variables
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	GameManager.screen_shake_requested.connect(_on_screen_shake_requested)
	GameAxis.axis_changed.connect(_on_axis_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	_center_camera()
	_spawn_player()

func _center_camera() -> void:
	var vp = get_viewport_rect().size
	camera.position = vp * 0.5

func _spawn_player() -> void:
	var vp = get_viewport_rect().size
	var initial_pos: Vector2
	
	if GameAxis.is_vertical:
		# 25% from bottom in portrait
		initial_pos = Vector2(vp.x * 0.5, vp.y * 0.75)
	else:
		# 20% from left in landscape
		initial_pos = Vector2(vp.x * 0.2, vp.y * 0.5)
	
	player_instance = player_scene.instantiate()
	add_child(player_instance)
	player_instance.global_position = initial_pos

func _on_axis_changed(_is_vertical: bool) -> void:
	_center_camera()
	if is_instance_valid(player_instance):
		player_instance.global_position = GameAxis.clamp_position(player_instance.global_position, 40.0)

func _on_viewport_resized() -> void:
	_center_camera()

func _on_screen_shake_requested(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_duration = maxf(shake_duration, duration)
	shake_timer = shake_duration

func _process(delta: float) -> void:
	# Process decaying camera shake
	if shake_timer > 0.0:
		shake_timer -= delta
		var damp = clampf(shake_timer / shake_duration, 0.0, 1.0)
		var offset_shake = Vector2(
			randf_range(-1.0, 1.0) * shake_intensity * damp,
			randf_range(-1.0, 1.0) * shake_intensity * damp
		)
		camera.offset = offset_shake
	else:
		camera.offset = Vector2.ZERO
		shake_intensity = 0.0
