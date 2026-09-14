extends Node2D

## Main.gd - Full 3-Sector Roguelite Loop Coordinator with 3 Shop Dockings, 2 Minibosses, and Final Apex Titan Boss.

@onready var camera: Camera2D = $Camera2D
@onready var player_spawn_point: Marker2D = $PlayerSpawnPoint
@onready var background: Node2D = $ParallaxBackground
@onready var spawner: Node2D = $DecoherenceSpawner
@onready var shop: CanvasLayer = $SkyMerchant
@onready var secrets: Node2D = $SecretDirector
@onready var dossier: CanvasLayer = $ThreatDossier
@onready var pause_menu = get_node_or_null("PauseMenu")
const Stage3DScript = preload("res://scripts/Stage3D.gd")
@onready var stage_3d = get_node_or_null("Stage3D")

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

# 3 Shop checkpoints (one pre-miniboss per sector: Waves 5, 17, 29)
var shop_w5_done: bool = false
var shop_w17_done: bool = false
var shop_w29_done: bool = false
var shop_w6_done: bool:
	get: return shop_w5_done
	set(v): shop_w5_done = v
var shop_w18_done: bool:
	get: return shop_w17_done
	set(v): shop_w17_done = v
var shop_w30_done: bool:
	get: return shop_w29_done
	set(v): shop_w29_done = v

# Boss and Miniboss encounter checkpoints
var miniboss_w6_done: bool = false
var boss_w12_done: bool = false
var miniboss_w18_done: bool = false
var boss_w24_done: bool = false
var miniboss_w30_done: bool = false
var boss_w36_done: bool = false

var current_boss_name: String = "Super-Dreadnought Corvus"
var shake_direction: Vector2 = Vector2.ZERO
var shake_frequency: float = 45.0

func _ready() -> void:
	GameManager.screen_shake_requested.connect(_on_screen_shake_requested)
	if GameManager.has_signal("directional_shake_requested"):
		GameManager.directional_shake_requested.connect(_on_directional_shake_requested)
	if GameManager.has_signal("custom_shake_requested"):
		GameManager.custom_shake_requested.connect(_on_custom_shake_requested)
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
		if is_instance_valid(stage_3d) and stage_3d.has_method("register_station"):
			stage_3d.register_station(shop)
	
	if is_instance_valid(spawner) and spawner.has_signal("quantum_warp_started"):
		spawner.quantum_warp_started.connect(func(dur):
			GameManager.request_screen_shake(6.0, dur)
			if is_instance_valid(background) and background.has_method("trigger_warp_streak"):
				background.trigger_warp_streak(dur)
			if is_instance_valid(stage_3d) and stage_3d.has_method("trigger_warp_tunnel"):
				stage_3d.trigger_warp_tunnel(dur)
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("on_quantum_warp_started"):
				hud.on_quantum_warp_started()
		)
	
	# Display Sector 1 Threat Dossier briefing card at launch
	if is_instance_valid(dossier):
		get_tree().create_timer(0.05).timeout.connect(func():
			dossier.show_dossier(1, "Super-Dreadnought Corvus")
		)
	
	# Multi-Boss Progression Pipeline
	GameManager.boss_defeated.connect(_on_boss_defeated_progression)
	
	# Skip pre-requisite checkpoints if debug starting at later waves
	if GameManager.start_wave > 5:
		shop_w5_done = true
	if GameManager.start_wave > 6:
		miniboss_w6_done = true
	if GameManager.start_wave > 12:
		boss_w12_done = true
	if GameManager.start_wave > 17:
		shop_w17_done = true
	if GameManager.start_wave > 18:
		miniboss_w18_done = true
	if GameManager.start_wave > 24:
		boss_w24_done = true
	if GameManager.start_wave > 29:
		shop_w29_done = true
	if GameManager.start_wave > 30:
		miniboss_w30_done = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_instance_valid(pause_menu) and pause_menu.has_method("open_pause"):
			var modal_open = false
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and "choice_modal" in hud and is_instance_valid(hud.choice_modal) and hud.choice_modal.visible:
				modal_open = true
			if is_instance_valid(shop) and "panel" in shop and is_instance_valid(shop.panel) and shop.panel.visible:
				modal_open = true
			if is_instance_valid(dossier) and "panel" in dossier and is_instance_valid(dossier.panel) and dossier.panel.visible:
				modal_open = true
			if GameManager.is_game_over or GameManager.current_phase == GameManager.RunPhase.SECTOR_VICTORY:
				modal_open = true
			
			if not modal_open and not pause_menu.is_open:
				pause_menu.open_pause()
				get_viewport().set_input_as_handled()

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
	
	if is_instance_valid(stage_3d):
		stage_3d.register_player(p1_instance)
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_connect_players"):
		hud._connect_players()

func _spawn_p2() -> void:
	if is_instance_valid(p2_instance):
		return
	var vp = get_viewport_rect().size
	var initial_pos = Vector2(vp.x * 0.6, vp.y * 0.75) if GameAxis.is_vertical else Vector2(vp.x * 0.2, vp.y * 0.6)
	
	p2_instance = player_scene.instantiate()
	p2_instance.player_id = 2
	add_child(p2_instance)
	p2_instance.global_position = initial_pos
	
	if is_instance_valid(stage_3d):
		stage_3d.register_player(p2_instance)
	
	# Connect P2 signals to HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_on_health_changed"):
		p2_instance.health_changed.connect(func(h, s, mh, ms): hud._on_health_changed(h, s, mh, ms, 2))
	if hud and hud.has_method("_connect_players"):
		hud._connect_players()

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
		var dir_offset = shake_direction * shake_intensity * damp * sin(shake_timer * shake_frequency)
		var rand_offset = Vector2(
			randf_range(-0.4, 0.4) * shake_intensity * damp,
			randf_range(-0.4, 0.4) * shake_intensity * damp
		)
		var total_offset = dir_offset + rand_offset
		camera.offset = total_offset
		if is_instance_valid(stage_3d) and stage_3d.camera:
			var vp_size = get_viewport_rect().size
			stage_3d.camera.position = Vector3(vp_size.x * 0.5 + total_offset.x, -vp_size.y * 0.5 - total_offset.y, 400.0)
	else:
		camera.offset = Vector2.ZERO
		shake_intensity = 0.0
		shake_direction = Vector2.ZERO
		if is_instance_valid(stage_3d) and stage_3d.camera:
			var vp_size = get_viewport_rect().size
			stage_3d.camera.position = Vector3(vp_size.x * 0.5, -vp_size.y * 0.5, 400.0)
	
	_evaluate_progression_triggers()

func _evaluate_progression_triggers() -> void:
	if GameManager.is_game_over or GameManager.current_phase == GameManager.RunPhase.SECTOR_VICTORY:
		return
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	var has_bubbles = is_instance_valid(spawner) and not spawner.active_bubbles.is_empty()
	var airspace_clear = enemies.is_empty() and not has_bubbles
	if is_instance_valid(spawner) and spawner.has_method("_has_active_squads") and spawner._has_active_squads():
		airspace_clear = false
	if is_instance_valid(spawner) and spawner.has_method("is_wave_in_progress") and spawner.is_wave_in_progress():
		airspace_clear = false

	# --- SECTOR 1 (Waves 1-12) ---
	if GameManager.current_sector == 1:
		# Pre-Miniboss Shop 1: Wave 5
		if GameManager.current_wave >= 5 and not shop_w5_done and airspace_clear:
			shop_w5_done = true
			_trigger_shop_docking()
			return
		# Wave 6: Miniboss 1 (Siege Goliath-Lite)
		if GameManager.current_wave >= 6 and not miniboss_w6_done and airspace_clear:
			miniboss_w6_done = true
			_spawn_boss(boss_goliath_scene, "MINIBOSS: SIEGE GOLIATH", true)
			return
		# Wave 12: Sector 1 Climax Boss (Super-Dreadnought Corvus)
		if GameManager.current_wave >= 12 and not boss_w12_done and airspace_clear:
			boss_w12_done = true
			_spawn_boss(boss_corvus_scene, "Super-Dreadnought Corvus")
			return

	# --- SECTOR 2 (Waves 13-24) ---
	elif GameManager.current_sector == 2:
		# Pre-Miniboss Shop 2: Wave 17
		if GameManager.current_wave >= 17 and not shop_w17_done and airspace_clear:
			shop_w17_done = true
			_trigger_shop_docking()
			return
		# Wave 18: Miniboss 2 (Siege Goliath-Lite Variant)
		if GameManager.current_wave >= 18 and not miniboss_w18_done and airspace_clear:
			miniboss_w18_done = true
			_spawn_boss(boss_goliath_scene, "MINIBOSS: SIEGE GOLIATH", true)
			return
		# Wave 24: Sector 2 Climax Boss (Armored Behemoth Goliath)
		if GameManager.current_wave >= 24 and not boss_w24_done and airspace_clear:
			boss_w24_done = true
			_spawn_boss(boss_goliath_scene, "Armored Behemoth Goliath")
			return

	# --- SECTOR 3 (Waves 25-36) ---
	elif GameManager.current_sector == 3:
		# Pre-Miniboss Shop 3: Wave 29 (Final Shop Visit)
		if GameManager.current_wave >= 29 and not shop_w29_done and airspace_clear:
			shop_w29_done = true
			_trigger_shop_docking()
			return
		# Wave 30: Miniboss 3 (Quantum Corvus Miniboss)
		if GameManager.current_wave >= 30 and not miniboss_w30_done and airspace_clear:
			miniboss_w30_done = true
			_spawn_boss(boss_corvus_scene, "MINIBOSS: QUANTUM CORVUS")
			return
		# Wave 36: Grand Finale Climax Boss (Apex Titan Ouroboros)
		if GameManager.current_wave >= 36 and not boss_w36_done and airspace_clear:
			boss_w36_done = true
			_spawn_boss(boss_ouroboros_scene, "Apex Titan Ouroboros")
			return

func _trigger_shop_docking(with_animation: bool = true) -> void:
	GameManager.current_phase = GameManager.RunPhase.SHOP_DOCKING
	# Clear lingering bullets
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and b.get("is_enemy"):
			b.queue_free()
	
	if is_instance_valid(shop):
		if not with_animation or DisplayServer.get_name() == "headless":
			shop.open_shop()
		elif shop.has_method("dock_with_animation"):
			shop.dock_with_animation()
		else:
			shop.open_shop()

func _spawn_boss(boss_packed: PackedScene, b_name: String, is_mini: bool = false) -> void:
	GameManager.current_phase = GameManager.RunPhase.BOSS_BATTLE
	current_boss_name = b_name
	
	# Clear hostile bullets before boss arrival
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and b.get("is_enemy"):
			b.queue_free()
	
	var boss = boss_packed.instantiate()
	if is_mini and "is_miniboss" in boss:
		boss.is_miniboss = true
	add_child(boss)
	SoundEffects.play_sfx("bonus", 0.3, -3.0)

func _on_boss_defeated_progression(b_name: String) -> void:
	if "MINIBOSS" in b_name.to_upper():
		# Miniboss cleared: return to combat phase so wave progression continues to next wave
		GameManager.current_phase = GameManager.RunPhase.COMBAT_WAVES
		if is_instance_valid(spawner):
			spawner.wave_timer = 1.0
		return

	if "CORVUS" in b_name.to_upper() and GameManager.current_sector == 1:
		# Sector 1 Cleared -> Transition to Sector 2
		get_tree().create_timer(1.2).timeout.connect(func():
			_transition_to_sector(2, "Armored Behemoth Goliath")
		)
	elif "GOLIATH" in b_name.to_upper() and GameManager.current_sector == 2:
		# Sector 2 Cleared -> Transition to Sector 3
		get_tree().create_timer(1.2).timeout.connect(func():
			_transition_to_sector(3, "Apex Titan Ouroboros")
		)
	elif "OUROBOROS" in b_name.to_upper() and GameManager.current_sector == 3:
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
	if is_instance_valid(stage_3d) and stage_3d.has_method("set_sector_theme"):
		stage_3d.set_sector_theme(next_sec)
	
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
	shake_timer = shake_duration
	shake_direction = Vector2.ZERO

func _on_directional_shake_requested(dir: Vector2, intensity: float, duration: float) -> void:
	shake_direction = dir.normalized()
	shake_intensity = maxf(shake_intensity, intensity)
	shake_duration = maxf(shake_duration, duration)
	shake_frequency = 45.0
	shake_timer = shake_duration

func _on_custom_shake_requested(dir: Vector2, intensity: float, duration: float, frequency: float) -> void:
	shake_direction = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO
	shake_intensity = maxf(shake_intensity, intensity)
	shake_duration = maxf(shake_duration, duration)
	shake_frequency = frequency
	shake_timer = shake_duration

