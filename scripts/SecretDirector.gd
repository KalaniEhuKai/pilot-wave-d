extends Node2D

## SecretDirector.gd - Orchestrates hidden Quantum Anomalies and the legendary Dirac Monopole landmark.

var anomaly_timer: float = 8.0
var anomaly_interval: float = 14.0
var monopole_spawned: bool = false

# Active anomalies in space: Array of Dictionaries
var anomalies: Array[Dictionary] = []
var dirac_monopole: Dictionary = {}

var scrap_scene: PackedScene = preload("res://scenes/ScrapPickup.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")

func _process(delta: float) -> void:
	if GameManager.is_game_over or get_tree().paused:
		return
	
	anomaly_timer -= delta
	if anomaly_timer <= 0.0:
		anomaly_timer = anomaly_interval
		_spawn_quantum_anomaly()
	
	# Spawn Dirac Monopole landmark on Wave 5
	if GameManager.current_wave >= 5 and not monopole_spawned:
		monopole_spawned = true
		_spawn_dirac_monopole()
	
	_update_anomalies(delta)
	_update_monopole(delta)
	queue_redraw()

func _spawn_quantum_anomaly() -> void:
	var pos = GameAxis.get_spawn_line(randf_range(0.2, 0.8))
	anomalies.append({
		"pos": pos,
		"radius": 24.0,
		"elapsed": 0.0,
		"shattered": false
	})

func _spawn_dirac_monopole() -> void:
	var pos = GameAxis.get_spawn_line(0.5)
	dirac_monopole = {
		"pos": pos,
		"health": 14.0,
		"max_health": 14.0,
		"active": true,
		"elapsed": 0.0
	}

func _update_anomalies(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for a in anomalies:
		a.elapsed += delta
		a.pos += GameAxis.scroll_dir * 90.0 * delta
		
		# Check collisions with player bullets or player rolling through
		if not a.shattered:
			_check_anomaly_interaction(a)
		
		if not a.shattered and not GameAxis.is_out_of_bounds(a.pos, 80.0):
			remaining.append(a)
	anomalies = remaining

func _check_anomaly_interaction(a: Dictionary) -> void:
	# Check player barrel roll
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.is_rolling:
			if p.global_position.distance_to(a.pos) < a.radius + 20.0:
				_shatter_anomaly(a)
				return
	
	# Check player bullets
	for b in get_tree().get_nodes_in_group("bullets"):
		if is_instance_valid(b) and not b.get("is_enemy"):
			if b.global_position.distance_to(a.pos) < a.radius:
				b.queue_free()
				_shatter_anomaly(a)
				return

func _shatter_anomaly(a: Dictionary) -> void:
	a.shattered = true
	SoundEffects.play_sfx("bonus", 0.05, 4.0)
	GameManager.notify_secret("QUANTUM ANOMALY REVEALED", 2500)
	
	var exp_node = explosion_scene.instantiate()
	get_parent().add_child(exp_node)
	exp_node.global_position = a.pos
	exp_node.max_radius = 60.0
	
	# Drops 2 scrap pellets
	for i in range(2):
		var sc = scrap_scene.instantiate()
		get_parent().add_child(sc)
		sc.global_position = a.pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))

func _update_monopole(delta: float) -> void:
	if not dirac_monopole.has("active") or not dirac_monopole.active:
		return
	
	dirac_monopole.elapsed += delta
	dirac_monopole.pos += GameAxis.scroll_dir * 55.0 * delta
	
	# Check player bullet hits
	for b in get_tree().get_nodes_in_group("bullets"):
		if is_instance_valid(b) and not b.get("is_enemy"):
			if b.global_position.distance_to(dirac_monopole.pos) < 32.0:
				b.queue_free()
				dirac_monopole.health -= 1.0
				SoundEffects.play_sfx("hit", 0.1, 2.0)
				if dirac_monopole.health <= 0.0:
					_shatter_dirac_monopole()
					return
	
	if GameAxis.is_out_of_bounds(dirac_monopole.pos, 80.0):
		dirac_monopole.active = false

func _shatter_dirac_monopole() -> void:
	dirac_monopole.active = false
	SoundEffects.play_sfx("bonus", 0.02, 6.0)
	GameManager.notify_secret("DIRAC MONOPOLE RESTORED (+10,000 PTS & FULL REPAIR)", 10000)
	
	# 100% full hull & shield repair for all players!
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			p.hull = p.max_hull
			p.shields = p.max_shields
			p._emit_health()
	
	var exp_node = explosion_scene.instantiate()
	get_parent().add_child(exp_node)
	exp_node.global_position = dirac_monopole.pos
	exp_node.max_radius = 120.0
	GameManager.request_screen_shake(16.0, 0.45)

func _draw() -> void:
	# Render subtle quantum anomalies
	for a in anomalies:
		if a.shattered:
			continue
		var pulse = 1.0 + sin(a.elapsed * 6.0) * 0.18
		var rad = a.radius * pulse
		draw_arc(to_local(a.pos), rad, 0, TAU, 28, Color(0.2, 0.8, 1.0, 0.4), 1.5, true)
		draw_arc(to_local(a.pos), rad * 0.6, 0, TAU, 20, Color(0.8, 0.3, 1.0, 0.3), 1.0, true)
	
	# Render the Dirac Monopole landmark
	if dirac_monopole.has("active") and dirac_monopole.active:
		var pos = to_local(dirac_monopole.pos)
		var t = dirac_monopole.elapsed
		# Ancient golden spin-core landmark
		draw_circle(pos, 26.0, Color(0.15, 0.1, 0.05, 0.9))
		draw_arc(pos, 28.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.9), 3.0, true)
		draw_arc(pos, 16.0, t * 4.0, t * 4.0 + PI, 16, Color(1.0, 0.95, 0.6, 1.0), 2.5, true)
