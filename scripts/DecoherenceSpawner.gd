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
	
	# 0. Clean up any stale hazards from previous waves to prevent clutter
	_cleanup_stale_hazards()
	
	# 1. Spawn Environmental Hazards along the forward horizon
	var hazards = template.get("hazards", [])
	for h_data in hazards:
		var h_type = h_data.get("type", 0)
		var count = h_data.get("count", 1)
		for i in range(count):
			var hz = hazard_scene.instantiate()
			get_parent().add_child(hz)
			var lat_step = randf_range(0.15, 0.85)
			# Spawn off-screen along forward horizon, drifting naturally downfield
			var deep_offset = -GameAxis.scroll_dir * (i * 45.0 + randf_range(15.0, 40.0))
			var pos = GameAxis.get_spawn_line(lat_step) + deep_offset
			hz.setup(h_type, pos)
	
	# 2. Spawn Enemies from collapsing wave functions along the forward horizon
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

func _cleanup_stale_hazards() -> void:
	for h in get_tree().get_nodes_in_group("hazard"):
		if is_instance_valid(h):
			if h.has_method("fade_and_despawn"):
				h.fade_and_despawn()
			else:
				h.queue_free()

func _spawn_pattern_batch(e_type: int, count: int, pattern: String, base_delay: float, squad_id: int, affix: int) -> void:
	var scroll = GameAxis.scroll_dir
	
	match pattern:
		"ROW", "HORIZON_SPREAD":
			for i in range(count):
				var lateral_step = 0.18 + (float(i) / maxi(1, count - 1)) * 0.64
				var pos = GameAxis.get_spawn_line(lateral_step)
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.1, affix)
				
		"SWEEP_ROW", "ECHELON":
			for i in range(count):
				var lateral_step = 0.15 + (float(i) / maxi(1, count - 1)) * 0.7
				var deep_offset = -scroll * (i * 26.0)
				var pos = GameAxis.get_spawn_line(lateral_step) + deep_offset
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.16, affix)
				
		"V_SHAPE":
			var mid = int(count * 0.5)
			for i in range(count):
				var lateral_step = (float(i) - mid) / float(maxi(1, mid)) * 0.35 + 0.5
				var deep_offset = -scroll * (absf(float(i - mid)) * 34.0)
				var pos = GameAxis.get_spawn_line(lateral_step) + deep_offset
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + absf(float(i - mid)) * 0.12, affix)
				
		"CENTER", "CENTER_STREAM":
			for i in range(count):
				var deep_offset = -scroll * (i * 45.0)
				var pos = GameAxis.get_spawn_line(0.5) + deep_offset
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.18, affix)
				
		"FLANK_LEFT":
			for i in range(count):
				var deep_offset = -scroll * (i * 32.0)
				var pos = GameAxis.get_spawn_line(0.18) + deep_offset
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.14, affix)
				
		"FLANK_RIGHT":
			for i in range(count):
				var deep_offset = -scroll * (i * 32.0)
				var pos = GameAxis.get_spawn_line(0.82) + deep_offset
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.14, affix)
				
		"FLANK_SPLIT", "PINCER_FLANK":
			for i in range(count):
				var is_left = (i % 2 == 0)
				var lateral_step = 0.18 if is_left else 0.82
				var deep_offset = -scroll * ((i / 2) * 32.0)
				var pos = GameAxis.get_spawn_line(lateral_step) + deep_offset
				_queue_quantum_bubble(e_type, pos, squad_id, base_delay + i * 0.12, affix)
				
		_: # RANDOM_HORIZON / Fallback
			for i in range(count):
				var lat_step = randf_range(0.15, 0.85)
				var deep_offset = -scroll * randf_range(0.0, 40.0)
				var pos = GameAxis.get_spawn_line(lat_step) + deep_offset
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
				"duration": 0.72,
				"sfx_played": false
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
		
		# Audio cue right as wave function collapses into eigenstate
		if progress >= 0.85 and not b.get("sfx_played", false):
			b["sfx_played"] = true
			SoundEffects.play_sfx("quantum_collapse", 0.08, -3.0)
		
		# Quantum collapsing wave dynamics: wide probability ripples rapidly contract inward
		var outer_radius = lerpf(52.0, 3.0, pow(progress, 2.2))
		var inner_radius = outer_radius * 0.6
		
		var is_elite = b.get("affix", 0) != 0
		var primary_col = Color(1.0, 0.8, 0.2) if is_elite else Color(0.2, 0.9, 1.0)
		var secondary_col = Color(1.0, 0.35, 0.1) if is_elite else Color(0.85, 0.2, 1.0)
		
		# 1. Concentric de Broglie phase rings
		var alpha = (1.0 - progress * 0.4)
		draw_arc(bubble_pos, outer_radius, 0, TAU, 32, Color(primary_col.r, primary_col.g, primary_col.b, alpha * 0.8), 2.2, true)
		draw_arc(bubble_pos, inner_radius, 0, TAU, 24, Color(secondary_col.r, secondary_col.g, secondary_col.b, alpha * 0.9), 1.8, true)
		
		# 2. Quantum probability brackets / crosshairs contracting toward eigenstate
		var bracket_dist = outer_radius + 4.0
		var bracket_len = 7.0 * (1.0 - progress)
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var p_start = bubble_pos + dir * bracket_dist
			var p_end = bubble_pos + dir * (bracket_dist - bracket_len)
			draw_line(p_start, p_end, Color(primary_col.r, primary_col.g, primary_col.b, alpha), 1.5)
		
		# 3. High-energy eigenstate collapse spark
		if progress > 0.65:
			var spark_t = (progress - 0.65) / 0.35
			var spark_radius = lerpf(2.0, 7.5, spark_t)
			draw_circle(bubble_pos, spark_radius, Color(1.0, 1.0, 1.0, spark_t))
			# Crosshair flash
			var flash_len = spark_radius * 1.6
			draw_line(bubble_pos - Vector2(flash_len, 0), bubble_pos + Vector2(flash_len, 0), Color.WHITE, 1.5)
			draw_line(bubble_pos - Vector2(0, flash_len), bubble_pos + Vector2(0, flash_len), Color.WHITE, 1.5)

