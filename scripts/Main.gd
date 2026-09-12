extends Node2D

## Main.gd - Full Sector flow coordinator with Sky Merchant docking, Boss encounter, and 2-Player Co-Op.

@onready var camera: Camera2D = $Camera2D
@onready var player_spawn_point: Marker2D = $PlayerSpawnPoint
@onready var background: Node2D = $ParallaxBackground
@onready var spawner: Node2D = $DecoherenceSpawner
@onready var shop: CanvasLayer = $SkyMerchant
@onready var secrets: Node2D = $SecretDirector
@onready var dossier: CanvasLayer = $ThreatDossier

var player_scene: PackedScene = preload("res://scenes/Player.tscn")
var boss_corvus_scene: PackedScene = preload("res://scenes/BossCorvus.tscn")
var boss_goliath_scene: PackedScene = preload("res://scenes/BossGoliath.tscn")

var p1_instance: CharacterBody2D = null
var p2_instance: CharacterBody2D = null

# Screen shake variables
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

var shop_visited: bool = false
var boss_spawned: bool = false
var chosen_boss_name: String = "Super-Dreadnought Corvus"

func _ready() -> void:
	GameManager.screen_shake_requested.connect(_on_screen_shake_requested)
	GameAxis.axis_changed.connect(_on_axis_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Procedural / Seeded asymmetric boss selection for Sector 1
	chosen_boss_name = "Armored Behemoth Goliath" if (randf() > 0.5) else "Super-Dreadnought Corvus"
	
	_center_camera()
	_spawn_p1()
	
	if GameManager.is_coop_mode:
		_spawn_p2()
	
	if is_instance_valid(shop):
		shop.undocked.connect(func():
			if is_instance_valid(spawner):
				spawner.wave_timer = 2.5
		)
	
	# Display Sector Threat Dossier briefing card at launch
	if is_instance_valid(dossier):
		get_tree().create_timer(0.05).timeout.connect(func():
			dossier.show_dossier(GameManager.current_sector, chosen_boss_name)
		)
	
	GameManager.boss_defeated.connect(func(b_name):
		get_tree().create_timer(1.2).timeout.connect(func():
			GameManager.trigger_victory(b_name)
		)
	)

func _center_camera() -> void:
	var vp = get_viewport_rect().size
	camera.position = vp * 0.5

func _spawn_p1() -> void:
	var vp = get_viewport_rect().size
	var initial_pos = Vector2(vp.x * 0.5, vp.y * 0.75) if GameAxis.is_vertical else Vector2(vp.x * 0.2, vp.y * 0.45)
	
	p1_instance = player_scene.instantiate()
	p1_instance.player_id = 1
	add_child(p1_instance)
	p1_instance.global_position = initial_pos

func _spawn_p2() -> void:
	if is_instance_valid(p2_instance):
		return
	var vp = get_viewport_rect().size
	var initial_pos = Vector2(vp.x * 0.6, vp.y * 0.75) if GameAxis.is_vertical else Vector2(vp.x * 0.2, vp.y * 0.6)
	
	p2_instance = player_scene.instantiate()
	p2_instance.player_id = 2
	add_child(p2_instance)
	p2_instance.global_position = initial_pos
	
	# Connect P2 signals to HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_on_health_changed"):
		p2_instance.health_changed.connect(func(h, s, mh, ms): hud._on_health_changed(h, s, mh, ms, 2))

func toggle_coop_player(enable: bool) -> void:
	if enable:
		_spawn_p2()
	else:
		if is_instance_valid(p2_instance):
			p2_instance.queue_free()
			p2_instance = null

func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		var damp = clampf(shake_timer / shake_duration, 0.0, 1.0)
		camera.offset = Vector2(
			randf_range(-1.0, 1.0) * shake_intensity * damp,
			randf_range(-1.0, 1.0) * shake_intensity * damp
		)
	else:
		camera.offset = Vector2.ZERO
		shake_intensity = 0.0
	
	# Sector Progression Triggers
	# Wave 4 clear -> Sky Merchant docking (wait until wave 4 enemies are defeated)
	if GameManager.current_wave >= 5 and not shop_visited:
		var enemies = get_tree().get_nodes_in_group("enemy")
		var has_bubbles = is_instance_valid(spawner) and not spawner.active_bubbles.is_empty()
		if enemies.is_empty() and not has_bubbles:
			shop_visited = true
			_trigger_shop_docking()
	
	# Wave 7 -> Sector 1 Boss Super-Dreadnought Corvus (wait until wave 6 enemies are defeated)
	if GameManager.current_wave >= 7 and not boss_spawned:
		var enemies = get_tree().get_nodes_in_group("enemy")
		var has_bubbles = is_instance_valid(spawner) and not spawner.active_bubbles.is_empty()
		if enemies.is_empty() and not has_bubbles:
			boss_spawned = true
			_spawn_sector_boss()

func _trigger_shop_docking() -> void:
	GameManager.current_phase = GameManager.RunPhase.SHOP_DOCKING
	# Clear any lingering hostile bullets so player is 100% safe
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and b.get("is_enemy"):
			b.queue_free()
	
	if is_instance_valid(shop):
		shop.open_shop()

func _spawn_sector_boss() -> void:
	GameManager.current_phase = GameManager.RunPhase.BOSS_BATTLE
	# Clear any lingering hostile bullets before boss arrival
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and b.get("is_enemy"):
			b.queue_free()
	
	var boss_packed = boss_goliath_scene if chosen_boss_name == "Armored Behemoth Goliath" else boss_corvus_scene
	var boss = boss_packed.instantiate()
	add_child(boss)

func _on_axis_changed(_is_vertical: bool) -> void:
	_center_camera()
	if is_instance_valid(p1_instance):
		p1_instance.global_position = GameAxis.clamp_position(p1_instance.global_position, 40.0)
	if is_instance_valid(p2_instance):
		p2_instance.global_position = GameAxis.clamp_position(p2_instance.global_position, 40.0)

func _on_viewport_resized() -> void:
	_center_camera()

func _on_screen_shake_requested(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_duration = maxf(shake_duration, duration)
	shake_timer = shake_duration
