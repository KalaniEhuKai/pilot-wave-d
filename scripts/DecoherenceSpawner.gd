extends Node2D

## DecoherenceSpawner.gd - Materializes 25+ sector-gated encounter wave templates from quantum probability bubbles.
## Spawns interactive environmental hazards and coordinates squad wipe bonuses.

var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
var hazard_scene: PackedScene = preload("res://scenes/HazardObject.tscn")

var next_squad_id: int = 1
var squads: Dictionary = {}

var wave_timer: float = 1.0
var wave_interval: float = 5.0
var current_wave_num: int = 1

var active_bubbles: Array[Dictionary] = []
var wave_director: WaveDirector = WaveDirector.new()

func _process(delta: float) -> void:
	if GameManager.is_game_over or GameManager.current_phase != GameManager.RunPhase.COMBAT_WAVES:
		return
	
	wave_timer -= delta
	if wave_timer <= 0.0:
		var active_enemies = get_tree().get_nodes_in_group("enemy")
		if not active_enemies.is_empty() or not active_bubbles.is_empty():
			wave_timer = 1.0
		else:
			_trigger_next_wave()
			wave_timer = wave_interval
	
	var remaining_bubbles: Array[Dictionary] = []
	for b in active_bubbles:
		b.elapsed += delta
		var progress = b.elapsed / b.duration
		if progress >= 1.0:
			_materialize_enemy(b.type, b.pos, b.squad_id, b.get("affix", 0))
		else:
			remaining_bubbles.append(b)
	active_bubbles = remaining_bubbles
	
	queue_redraw()

func _trigger_next_wave() -> void:
	var squad_id = next_squad_id
	next_squad_id += 1
	
	current_wave_num += 1
	GameManager.current_wave = current_wave_num
	
	# Trigger wave start hooks on player (e.g. Meissner Shield recharge)
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty() and is_instance_valid(players[0]):
		players[0].trigger_wave_start_hooks(current_wave_num)
	
	# Select sector-appropriate encounter template
	var template = wave_director.select_template_for_wave(GameManager.current_sector, current_wave_num)
	_execute_encounter_template(template, squad_id)

func _execute_encounter_template(template: Dictionary, squad_id: int) -> void:
	var template_name = template.get("name", "COMBAT WAVE")
	
	# Banner on HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_banner"):
		hud._show_banner("[ WAVE: " + template_name + " ]", Color(0.3, 0.9, 1.0, 1.0))
	
	# 1. Spawn Environmental Hazards
	var hazards = template.get("hazards", [])
	for h_data in hazards:
		var h_type = h_data.get("type", 0)
		var count = h_data.get("count", 1)
		for i in range(count):
			var hz = hazard_scene.instantiate()
			get_parent().add_child(hz)
			var vp = get_viewport_rect().size
			var pos = Vector2(randf_range(80, vp.x - 80), randf_range(60, vp.y * 0.45))
			hz.setup(h_type, pos)
	
	# 2. Spawn Enemies
	var spawns = template.get("spawns", [])
	var total_enemy_count = 0
	for batch in spawns:
		total_enemy_count += batch.get("count", 1)
	
	_register_squad(squad_id, total_enemy_count)
	
	for batch in spawns:
		var e_type = batch.get("type", 0)
		var count = batch.get("count", 1)
		var pattern = batch.get("pattern", "ROW")
		var delay = batch.get("delay", 0.0)
		var affix = batch.get("affix", 0)
		_spawn_pattern_batch(e_type, count, pattern, delay, squad_id, affix)

func _spawn_pattern_batch(e_type: int, count: int, pattern: String, base_delay: float, squad_id: int, affix: int) -> void:
	var vp = get_viewport_rect().size
	var fwd = GameAxis.forward
	var lat = GameAxis.lateral
	
	match pattern:
		"RING":
			var center = Vector2(vp.x * 0.5, vp.y * 0.35)
			for i in range(count):
				var a = (float(i) / count) * TAU
				var r = randf_range(140.0, 220.0)
				var pos = center + Vector2(cos(a) * r, sin(a) * r)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.04, affix)
				
		"ROW":
			for i in range(count):
				var lateral_step = 0.2 + (float(i) / maxi(1, count - 1)) * 0.6
				var pos = GameAxis.get_spawn_line(lateral_step)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.1, affix)
				
		"FLANK_LEFT":
			for i in range(count):
				var pos = Vector2(-40, 80 + i * 65)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.12, affix)
				
		"FLANK_RIGHT":
			for i in range(count):
				var pos = Vector2(vp.x + 40, 80 + i * 65)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.12, affix)
				
		"FLANK_SPLIT":
			for i in range(count):
				var is_left = (i % 2 == 0)
				var pos = Vector2(-40 if is_left else vp.x + 40, 80 + (i / 2) * 80)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.1, affix)
				
		"CENTER":
			for i in range(count):
				var pos = GameAxis.get_spawn_line(0.5) + (fwd * i * 45.0)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.2, affix)
				
		"V_SHAPE":
			var mid = int(count * 0.5)
			for i in range(count):
				var lateral_step = (float(i) - mid) / float(maxi(1, mid)) * 0.35 + 0.5
				var pos = GameAxis.get_spawn_line(lateral_step) + fwd * (absf(float(i - mid)) * 36.0)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + absf(float(i - mid)) * 0.1, affix)
				
		_: # RANDOM_TOP
			for i in range(count):
				var lat_step = randf_range(0.15, 0.85)
				var pos = GameAxis.get_spawn_line(lat_step) + fwd * randf_range(0, 50.0)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.12, affix)

func _register_squad(squad_id: int, total_count: int) -> void:
	squads[squad_id] = {
		"total": total_count,
		"killed": 0,
		"escaped": 0,
		"awarded": false
	}

func _queue_quantum_bubble(type: int, pos: Vector2, squad_id: int, delay: float = 0.0, affix: int = 0) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		if not GameManager.is_game_over:
			active_bubbles.append({
				"type": type,
				"pos": pos,
				"squad_id": squad_id,
				"affix": affix,
				"elapsed": 0.0,
				"duration": 0.42
			})
	)

func _materialize_enemy(type: int, pos: Vector2, squad_id: int, affix: int = 0) -> void:
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	enemy.setup(type, pos, squad_id, self, affix)

func notify_kill(squad_id: int) -> void:
	record_squad_kill(squad_id)

func record_squad_kill(squad_id: int) -> void:
	if not squads.has(squad_id):
		return
	var sq = squads[squad_id]
	sq.killed += 1
	if sq.killed == sq.total and sq.escaped == 0 and not sq.awarded:
		sq.awarded = true
		GameManager.award_wipe_bonus(1000)
		SoundEffects.play_sfx("bonus", 0.04, 2.0)

func notify_escape(squad_id: int) -> void:
	record_squad_escaped(squad_id)

func record_squad_escaped(squad_id: int) -> void:
	if not squads.has(squad_id):
		return
	var sq = squads[squad_id]
	sq.escaped += 1

func _draw() -> void:
	for b in active_bubbles:
		var progress = b.elapsed / b.duration
		var bubble_pos = to_local(b.pos)
		var base_radius = 28.0 * sin(progress * PI)
		
		var fringe_color = Color(0.2, 0.9, 1.0, (1.0 - progress) * 0.8)
		if b.get("affix", 0) != 0:
			fringe_color = Color(1.0, 0.8, 0.2, (1.0 - progress) * 0.9)
			base_radius *= 1.3
		
		var inner_color = Color(0.8, 0.2, 1.0, (1.0 - progress) * 0.6)
		draw_arc(bubble_pos, base_radius, 0, TAU, 32, fringe_color, 2.5, true)
		draw_arc(bubble_pos, base_radius * 0.65, 0, TAU, 24, inner_color, 1.8, true)
		draw_circle(bubble_pos, 4.0 * (1.0 - progress), Color.WHITE)
