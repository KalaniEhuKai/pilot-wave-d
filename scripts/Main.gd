extends Node2D

## Main.gd - Full 3-Sector Roguelite Loop Coordinator with 3 Shop Dockings, 2 Minibosses, and Final Apex Titan Boss.

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
var boss_ouroboros_scene: PackedScene = preload("res://scenes/BossOuroboros.tscn")

var p1_instance: CharacterBody2D = null
var p2_instance: CharacterBody2D = null

# Screen shake variables
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

# Multi-shop checkpoints
var shop_w4_done: bool = false
var shop_w10_done: bool = false
var shop_w16_done: bool = false

# Boss encounter checkpoints
var boss_w6_done: bool = false
var boss_w12_done: bool = false
var boss_w18_done: bool = false

var current_boss_name: String = "Super-Dreadnought Corvus"

func _ready() -> void:
	GameManager.screen_shake_requested.connect(_on_screen_shake_requested)
	GameAxis.axis_changed.connect(_on_axis_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	_center_camera()
	_spawn_p1()
	
	if GameManager.is_coop_mode:
		_spawn_p2()
	
	if is_instance_valid(shop):
		shop.undocked.connect(func():
			if is_instance_valid(spawner):
				spawner.wave_timer = 2.5
		)
	
	# Display Sector 1 Threat Dossier briefing card at launch
	if is_instance_valid(dossier):
		get_tree().create_timer(0.05).timeout.connect(func():
			dossier.show_dossier(1, "Super-Dreadnought Corvus")
		)
	
	# Multi-Boss Progression Pipeline
	GameManager.boss_defeated.connect(_on_boss_defeated_progression)

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
	
	_evaluate_progression_triggers()

func _evaluate_progression_triggers() -> void:
	if GameManager.is_game_over or GameManager.current_phase == GameManager.RunPhase.SECTOR_VICTORY:
		return
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	var has_bubbles = is_instance_valid(spawner) and not spawner.active_bubbles.is_empty()
	var airspace_clear = enemies.is_empty() and not has_bubbles
	
	# --- SHOP DOCKING CHECKPOINTS ---
	# Shop 1: Wave 4 (Sector 1 Mid-Point)
	if GameManager.current_wave >= 4 and not shop_w4_done and airspace_clear and GameManager.current_sector == 1:
		shop_w4_done = true
		_trigger_shop_docking()
		return
		
	# Shop 2: Wave 10 (Sector 2 Mid-Point)
	if GameManager.current_wave >= 10 and not shop_w10_done and airspace_clear and GameManager.current_sector == 2:
		shop_w10_done = true
		_trigger_shop_docking()
		return
		
	# Shop 3: Wave 16 (Sector 3 Pre-Final Boss)
	if GameManager.current_wave >= 16 and not shop_w16_done and airspace_clear and GameManager.current_sector == 3:
		shop_w16_done = true
		_trigger_shop_docking()
		return
	
	# --- BOSS ENCOUNTER CHECKPOINTS ---
	# Boss 1: Wave 6 -> Sector 1 Miniboss Super-Dreadnought Corvus
	if GameManager.current_wave >= 6 and not boss_w6_done and airspace_clear and GameManager.current_sector == 1:
		boss_w6_done = true
		_spawn_boss(boss_corvus_scene, "Super-Dreadnought Corvus")
		return
		
	# Boss 2: Wave 12 -> Sector 2 Miniboss Armored Behemoth Goliath
	if GameManager.current_wave >= 12 and not boss_w12_done and airspace_clear and GameManager.current_sector == 2:
		boss_w12_done = true
		_spawn_boss(boss_goliath_scene, "Armored Behemoth Goliath")
		return
		
	# Boss 3: Wave 18 -> Sector 3 Climax Final Boss Apex Titan Ouroboros
	if GameManager.current_wave >= 18 and not boss_w18_done and airspace_clear and GameManager.current_sector == 3:
		boss_w18_done = true
		_spawn_boss(boss_ouroboros_scene, "Apex Titan Ouroboros")
		return

func _trigger_shop_docking() -> void:
	GameManager.current_phase = GameManager.RunPhase.SHOP_DOCKING
	# Clear lingering bullets
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and b.get("is_enemy"):
			b.queue_free()
	
	if is_instance_valid(shop):
		shop.open_shop()

func _spawn_boss(boss_packed: PackedScene, b_name: String) -> void:
	GameManager.current_phase = GameManager.RunPhase.BOSS_BATTLE
	current_boss_name = b_name
	
	# Clear hostile bullets before boss arrival
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and b.get("is_enemy"):
			b.queue_free()
	
	var boss = boss_packed.instantiate()
	add_child(boss)
	SoundEffects.play_sfx("bonus", 0.3, -3.0)

func _on_boss_defeated_progression(b_name: String) -> void:
	if "CORVUS" in b_name.to_upper():
		# Sector 1 Cleared -> Transition to Sector 2
		get_tree().create_timer(1.2).timeout.connect(func():
			_transition_to_sector(2, "Armored Behemoth Goliath")
		)
	elif "GOLIATH" in b_name.to_upper():
		# Sector 2 Cleared -> Transition to Sector 3
		get_tree().create_timer(1.2).timeout.connect(func():
			_transition_to_sector(3, "Apex Titan Ouroboros")
		)
	else:
		# Final Boss Ouroboros Defeated -> True Victory!
		get_tree().create_timer(1.4).timeout.connect(func():
			GameManager.trigger_victory(b_name)
		)

func _transition_to_sector(next_sec: int, next_boss_name: String) -> void:
	GameManager.advance_sector()
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_banner"):
		hud._show_banner("SECTOR %d CLEARED! ADVANCING..." % (next_sec - 1), Color(1.0, 0.85, 0.2, 1.0))
	
	# Background palette and speed transition
	if is_instance_valid(background) and background.has_method("set_sector_theme"):
		background.set_sector_theme(next_sec)
	
	# Display next Sector Threat Dossier briefing card
	if is_instance_valid(dossier):
		dossier.show_dossier(next_sec, next_boss_name)
	
	if is_instance_valid(spawner):
		spawner.wave_timer = 3.5

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
