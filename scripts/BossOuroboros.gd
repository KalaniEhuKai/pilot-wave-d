extends Area2D

## BossOuroboros.gd - Sector 3 Climax Final Boss: Apex Titan "Ouroboros".
## Features a rotating directional barrier gate, sweeping tachyon lances, quantum phase blinks, and bullet hell vortex.

signal boss_defeated(boss_name: String)

@export var max_health: float = 1200.0
var health: float = 1200.0

var shield_gate_hp: float = 400.0
var shield_gate_alive: bool = true
var shield_angle: float = 0.0

var entry_done: bool = false
var target_pos: Vector2 = Vector2.ZERO
var boss_name: String = "APEX TITAN OUROBOROS"

# Combat phase
var phase: int = 1 # 1 = Shielded Fortress, 2 = Singularity Meltdown
var attack_timer: float = 0.0
var vortex_timer: float = 0.0
var blink_timer: float = 6.0
var spiral_angle: float = 0.0

var hit_flash_timer: float = 0.0
var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")
var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")
var crate_scene: PackedScene = preload("res://scenes/ItemCrate.tscn")

func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 3
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	var vp = get_viewport_rect().size
	if GameAxis.is_vertical:
		global_position = Vector2(vp.x * 0.5, -140)
		target_pos = Vector2(vp.x * 0.5, 140)
	else:
		global_position = Vector2(vp.x + 140, vp.y * 0.5)
		target_pos = Vector2(vp.x - 160, vp.y * 0.5)
	
	GameManager.boss_health_updated.emit(health, max_health, boss_name)

func _physics_process(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		queue_redraw()
	
	# Entry glide
	if not entry_done:
		global_position = global_position.move_toward(target_pos, 160.0 * delta)
		if global_position.distance_to(target_pos) < 2.0:
			entry_done = true
			SoundEffects.play_sfx("bonus", 0.25, -2.0)
			GameManager.request_screen_shake(12.0, 0.4)
		return
	
	# Phase evaluation
	if phase == 1 and health <= max_health * 0.5:
		_transition_to_phase_2()
	
	# Shield gate rotation
	if shield_gate_alive:
		shield_angle += 1.2 * delta
	
	# Lateral sway
	var fwd = GameAxis.forward
	var lat = GameAxis.lateral
	var sway = sin(Time.get_ticks_msec() * 0.0015) * 120.0
	global_position = target_pos + lat * sway
	
	_handle_attacks(delta)
	queue_redraw()

func _handle_attacks(delta: float) -> void:
	attack_timer += delta
	
	if phase == 1:
		# Quantum Phase Blink
		blink_timer -= delta
		if blink_timer <= 0.0:
			blink_timer = 7.0
			_perform_phase_blink()
		
		# Tachyon sweeping barrages every 2.0s
		if attack_timer >= 2.0:
			attack_timer = 0.0
			_fire_tachyon_salvo()
	else:
		# Phase 2: Continuous spiral bullet hell vortex
		vortex_timer += delta
		if vortex_timer >= 0.12:
			vortex_timer = 0.0
			_fire_vortex_pulse()
		
		if attack_timer >= 3.5:
			attack_timer = 0.0
			_spawn_escort_drones(2)

func _perform_phase_blink() -> void:
	# Flash decoherence explosion
	var ex = explosion_scene.instantiate()
	get_parent().add_child(ex)
	ex.global_position = global_position
	ex.scale = Vector2(2.0, 2.0)
	
	var vp = get_viewport_rect().size
	if GameAxis.is_vertical:
		target_pos = Vector2(randf_range(vp.x * 0.25, vp.x * 0.75), 140)
	else:
		target_pos = Vector2(vp.x - 160, randf_range(vp.y * 0.25, vp.y * 0.75))
	
	global_position = target_pos
	SoundEffects.play_sfx("roll", 0.2, 2.0)
	GameManager.request_screen_shake(8.0, 0.3)

func _fire_tachyon_salvo() -> void:
	var fwd = GameAxis.forward
	var lat = GameAxis.lateral
	
	# Sweeping dual fan
	for i in range(-3, 4):
		var angle = deg_to_rad(i * 9.0)
		var d = fwd.rotated(angle)
		_spawn_boss_bullet(global_position + fwd * 40.0 + lat * (i * 10.0), d, 440.0)
	SoundEffects.play_sfx("laser", 0.15, -4.0)

func _fire_vortex_pulse() -> void:
	spiral_angle += 0.32
	var count = 4
	for i in range(count):
		var a = spiral_angle + (float(i) / count) * TAU
		var d = Vector2(cos(a), sin(a))
		_spawn_boss_bullet(global_position + d * 30.0, d, 360.0)

func _spawn_escort_drones(count: int) -> void:
	var enemy_scene = load("res://scenes/Enemy.tscn")
	for i in range(count):
		var e = enemy_scene.instantiate()
		get_parent().add_child(e)
		e.setup(2, global_position + Vector2(randf_range(-40, 40), 40), -1, null, 0) # Interceptors
	SoundEffects.play_sfx("bonus", 0.1, 4.0)

func _spawn_boss_bullet(pos: Vector2, dir: Vector2, b_speed: float) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(pos, dir, true, 1.0)
	b.speed = b_speed
	b.glow_color = Color(1.0, 0.2, 0.6, 1.0)

func _transition_to_phase_2() -> void:
	phase = 2
	shield_gate_alive = false
	
	# Detonation of shield gate
	var ex = explosion_scene.instantiate()
	get_parent().add_child(ex)
	ex.global_position = global_position
	ex.scale = Vector2(3.0, 3.0)
	
	SoundEffects.play_sfx("explosion", 0.4, -4.0)
	GameManager.request_screen_shake(18.0, 0.6)

func take_damage(amount: float) -> void:
	if not entry_done:
		return
	
	# If shield gate alive, deflect shots hitting the shield arc
	if shield_gate_alive:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]):
			var to_player = (players[0].global_position - global_position).normalized()
			var shield_dir = Vector2(cos(shield_angle), sin(shield_angle))
			var dot = to_player.dot(shield_dir)
			if dot > 0.4: # Shield absorbs shot
				shield_gate_hp -= amount
				SoundEffects.play_sfx("hit", 0.08, 6.0)
				hit_flash_timer = 0.08
				if shield_gate_hp <= 0.0:
					shield_gate_alive = false
					SoundEffects.play_sfx("explosion", 0.2, 2.0)
				queue_redraw()
				return
	
	health -= amount
	hit_flash_timer = 0.08
	GameManager.boss_health_updated.emit(maxf(0.0, health), max_health, boss_name)
	SoundEffects.play_sfx("hit", 0.1, randf_range(-2.0, 1.0))
	
	if phase == 1 and health <= max_health * 0.5:
		_transition_to_phase_2()
	
	if health <= 0.0:
		_die()
	else:
		queue_redraw()

func _die() -> void:
	# Massive cascading boss explosion
	for i in range(8):
		var ex = explosion_scene.instantiate()
		get_parent().add_child(ex)
		ex.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-70, 70))
		ex.scale = Vector2(2.2, 2.2)
	
	SoundEffects.play_sfx("explosion", 0.5, -6.0)
	GameManager.request_screen_shake(22.0, 0.8)
	
	# Drop massive scrap reward + 2 Relic Crates
	for i in range(16):
		var s = scrap_scene.instantiate()
		s.value = 10
		get_parent().add_child(s)
		s.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	
	for i in range(2):
		var crate = crate_scene.instantiate()
		get_parent().add_child(crate)
		crate.global_position = global_position + Vector2((i - 0.5) * 60.0, 30.0)
	
	GameManager.add_score(25000)
	GameManager.boss_defeated.emit(boss_name)
	boss_defeated.emit(boss_name)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and not area.get("is_enemy"):
		var dmg = area.get("damage")
		take_damage(dmg if dmg != null else 1.0)
		if not area.has_meta("pierce_count") or area.get_meta("pierce_count") <= 0:
			area.queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(1)

func _draw() -> void:
	var col = Color.WHITE if hit_flash_timer > 0.0 else Color(0.9, 0.15, 0.35, 1.0)
	
	# Draw rotating shield gate
	if shield_gate_alive:
		var start_a = shield_angle - PI * 0.4
		var end_a = shield_angle + PI * 0.4
		draw_arc(Vector2.ZERO, 68.0, start_a, end_a, 24, Color(0.2, 0.9, 1.0, 0.95), 5.0)
	
	# Massive Ouroboros Titan Dreadnought Hull
	var pts = PackedVector2Array([
		Vector2(55, 0),
		Vector2(35, -45),
		Vector2(-15, -55),
		Vector2(-55, -30),
		Vector2(-40, 0),
		Vector2(-55, 30),
		Vector2(-15, 55),
		Vector2(35, 45)
	])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([Vector2(55, 0)]), Color(1.0, 0.85, 0.3, 1.0), 3.0)
	
	# Glowing Singularity Core
	var core_col = Color(1.0, 0.1, 0.1, 1.0) if phase == 2 else Color(0.2, 0.8, 1.0, 0.9)
	draw_circle(Vector2.ZERO, 16.0, core_col)
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 24, Color.WHITE, 2.0)
