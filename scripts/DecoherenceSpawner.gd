class_name DecoherenceSpawner
extends Node2D

## DecoherenceSpawner.gd - Materializes 25+ sector-gated encounter wave templates from quantum probability bubbles.
## Spawns interactive environmental hazards and coordinates squad wipe bonuses.

var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")
var hazard_scene: PackedScene = preload("res://scenes/HazardObject.tscn")
const ProgressionModel = preload("res://scripts/ProgressionModel.gd")

enum WavePhase { IDLE, SPAWNING_COMBAT, WAVE_CLEARED_GRACE, QUANTUM_WARPING }

signal wave_cleared(wave_num: int, reason_title: String, reason_desc: String, is_wipe: bool, stats: Dictionary)
signal quantum_warp_started(duration: float)
signal quantum_warp_completed()

var next_squad_id: int = 1
var squads: Dictionary = {}

var wave_timer: float = 1.0
var wave_interval: float = 1.6
var current_wave_num: int = 0

var active_bubbles: Array[Dictionary] = []
var wave_director: WaveDirector = WaveDirector.new()

var wave_phase: WavePhase = WavePhase.IDLE
var wave_grace_timer: float = 0.0
var wave_grace_duration: float = 5.0
var vacuum_pulse_fired: bool = false
var warp_timer: float = 0.0
var warp_duration: float = 0.35

var current_wave_total: int = 0
var current_wave_killed: int = 0
var current_wave_escaped: int = 0
var current_wave_template_name: String = ""
var current_wave_drop_distribution: Dictionary = {}

func _ready() -> void:
	add_to_group("spawner")
	if GameManager.start_wave > 1:
		current_wave_num = GameManager.start_wave - 1

func is_wave_in_progress() -> bool:
	return wave_phase != WavePhase.IDLE

func skip_grace_period() -> void:
	if wave_phase == WavePhase.WAVE_CLEARED_GRACE:
		wave_grace_timer = 0.0

func _process(delta: float) -> void:
	if GameManager.is_game_over or GameManager.current_phase != GameManager.RunPhase.COMBAT_WAVES:
		return
	
	# Bubble materialization
	var remaining_bubbles: Array[Dictionary] = []
	for b in active_bubbles:
		b.elapsed += delta
		var progress = b.elapsed / b.duration
		if progress >= 1.0:
			_materialize_enemy(b.type, b.pos, b.squad_id, b.get("affix", 0), b.get("profile", -1))
		else:
			remaining_bubbles.append(b)
	active_bubbles = remaining_bubbles
	
	match wave_phase:
		WavePhase.IDLE:
			wave_timer -= delta
			if wave_timer <= 0.0:
				var active_enemies = get_tree().get_nodes_in_group("enemy")
				var has_active_squad = _has_active_squads()
				if not active_enemies.is_empty() or not active_bubbles.is_empty() or has_active_squad:
					wave_timer = 0.8
				else:
					_trigger_next_wave()
		
		WavePhase.SPAWNING_COMBAT:
			var active_enemies = get_tree().get_nodes_in_group("enemy")
			var has_active_squad = _has_active_squads()
			if active_enemies.is_empty() and active_bubbles.is_empty() and not has_active_squad:
				_on_wave_combat_cleared()
		
		WavePhase.WAVE_CLEARED_GRACE:
			wave_grace_timer -= delta
			
			# Manual collection active: Auto-vacuum pulse is disabled so players collect items themselves
			
			if wave_grace_timer <= 0.0:
				_start_quantum_warp_jump()
		
		WavePhase.QUANTUM_WARPING:
			warp_timer -= delta
			if warp_timer <= 0.0:
				_finish_quantum_warp_jump()
	
	queue_redraw()

func _on_wave_combat_cleared() -> void:
	var is_wipe = (current_wave_escaped == 0)
	var reason_title = "WAVE %d CLEARED" % current_wave_num
	var reason_desc = ""
	if is_wipe:
		reason_desc = "100% SQUAD WIPED // BONUS +1000 J"
	else:
		reason_desc = "SECTOR DEFENDED // %d DESTROYED, %d ESCAPED" % [current_wave_killed, current_wave_escaped]
	
	SoundEffects.play_sfx("wave_cleared", 0.04, 1.0)
	
	var stats = {
		"wave": current_wave_num,
		"killed": current_wave_killed,
		"escaped": current_wave_escaped,
		"total": current_wave_total,
		"is_wipe": is_wipe
	}
	wave_cleared.emit(current_wave_num, reason_title, reason_desc, is_wipe, stats)
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_wave_cleared_banner"):
		hud.show_wave_cleared_banner(reason_title, reason_desc, is_wipe, wave_grace_duration)
	elif hud and hud.has_method("_show_banner"):
		var col = Color(1.0, 0.85, 0.2, 1.0) if is_wipe else Color(0.3, 0.9, 1.0, 1.0)
		hud._show_banner("[ %s: %s ]" % [reason_title, reason_desc], col)
	
	wave_phase = WavePhase.WAVE_CLEARED_GRACE
	wave_grace_timer = wave_grace_duration
	vacuum_pulse_fired = false
	
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			if p.has_method("start_quantum_charge"):
				p.start_quantum_charge(wave_grace_duration)
			if p.has_method("trigger_wave_cleared_hooks"):
				p.trigger_wave_cleared_hooks(current_wave_num)

func _start_quantum_warp_jump() -> void:
	wave_phase = WavePhase.QUANTUM_WARPING
	warp_timer = warp_duration
	
	# Purge all uncollected scrap, bullets, crates, and hazards for a clean next wave transition
	_purge_uncollected_debris()
	
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.has_method("trigger_quantum_jump"):
			p.trigger_quantum_jump(warp_duration)
	
	quantum_warp_started.emit(warp_duration)

func _finish_quantum_warp_jump() -> void:
	wave_phase = WavePhase.IDLE
	wave_timer = 0.2
	
	# Final sweep to guarantee clean combat arena for next wave
	for s in get_tree().get_nodes_in_group("scrap"):
		if is_instance_valid(s):
			s.queue_free()
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b):
			b.queue_free()
	
	quantum_warp_completed.emit()

func _purge_uncollected_debris() -> void:
	# Purge all uncollected scrap pickups
	for s in get_tree().get_nodes_in_group("scrap"):
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			s.queue_free()
	
	# Purge all bullets
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			b.queue_free()
	
	# Purge uncollected crates
	for c in get_tree().get_nodes_in_group("crate"):
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			c.queue_free()
	
	# Purge lingering hazards
	for h in get_tree().get_nodes_in_group("hazard"):
		if is_instance_valid(h) and not h.is_queued_for_deletion():
			h.queue_free()

func _has_active_squads() -> bool:
	for sid in squads:
		var sq = squads[sid]
		if (sq.killed + sq.escaped) < sq.total:
			return true
	return false

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
	current_wave_template_name = template_name
	current_wave_killed = 0
	current_wave_escaped = 0
	wave_phase = WavePhase.SPAWNING_COMBAT
	
	# Banner on HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_wave_incoming_banner"):
		hud.show_wave_incoming_banner(current_wave_num, template_name)
	elif hud and hud.has_method("_show_banner"):
		hud._show_banner("[ WAVE %d: %s ]" % [current_wave_num, template_name], Color(0.3, 0.9, 1.0, 1.0))
	
	# 0. Clean up any stale hazards from previous waves to prevent clutter
	_cleanup_stale_hazards()

	var hazards = template.get("hazards", [])
	var spawns = template.get("spawns", [])
	var sec = GameManager.current_sector if GameManager != null else 1

	# Dynamic target-driven drop distribution: normalizes all enemy & hazard drops to wave budget
	current_wave_drop_distribution = ProgressionModel.calculate_wave_drop_distribution(spawns, hazards, sec, current_wave_num)

	# 1. Spawn Environmental Hazards along the forward horizon (visible on screen)
	var oncoming_h = -GameAxis.forward
	for h_data in hazards:
		var h_type = h_data.get("type", 0)
		var count = h_data.get("count", 0)
		for i in range(count):
			var hz = hazard_scene.instantiate()
			hz.hazard_type = h_type
			get_parent().add_child(hz)
			var lat_step = randf_range(0.14, 0.86)
			var stagger = oncoming_h * (i * 36.0)
			var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(lat_step) + stagger)
			var h_drop_prof = current_wave_drop_distribution.get("hazard_%d" % h_type, {})
			hz.setup(h_type, pos, h_drop_prof)
	
	# 2. Spawn Enemies from collapsing wave functions along the forward horizon
	var total_enemy_count = 0
	for batch in spawns:
		total_enemy_count += batch.get("count", 1)
	
	current_wave_total = total_enemy_count
	_register_squad(squad_id, total_enemy_count)
	
	for batch in spawns:
		var e_type = batch.get("type", 0)
		var count = batch.get("count", 1)
		var pattern = batch.get("pattern", "ROW")
		var delay = batch.get("delay", 0.0)
		var affix = batch.get("affix", 0)
		_spawn_pattern_batch(e_type, count, pattern, delay, squad_id, affix)

func _clamp_to_spawn_zone(pos: Vector2) -> Vector2:
	var rect = GameAxis.get_viewport_rect()
	if GameAxis.is_vertical:
		return Vector2(
			clampf(pos.x, rect.position.x + 15.0, rect.position.x + rect.size.x - 15.0),
			clampf(pos.y, rect.position.y + 15.0, rect.position.y + 180.0)
		)
	else:
		return Vector2(
			clampf(pos.x, rect.position.x + rect.size.x - 220.0, rect.position.x + rect.size.x - 15.0),
			clampf(pos.y, rect.position.y + 15.0, rect.position.y + rect.size.y - 15.0)
		)

func _cleanup_stale_hazards() -> void:
	for h in get_tree().get_nodes_in_group("hazard"):
		if is_instance_valid(h):
			if h.has_method("fade_and_despawn"):
				h.fade_and_despawn()
			else:
				h.queue_free()

func get_craft_affix(craft_idx: int, count: int, pattern: String, batch_affix: int) -> int:
	if batch_affix == 0:
		return 0
	var leader_index = int(count * 0.5) if pattern == "V_SHAPE" else 0
	return batch_affix if craft_idx == leader_index else 0

func _spawn_pattern_batch(e_type: int, count: int, pattern: String, base_delay: float, squad_id: int, affix: int) -> void:
	var oncoming = -GameAxis.forward
	var profile = -1
	
	match pattern:
		"V_SHAPE", "ARROW_WEDGE":
			profile = 1 # FlightProfile.ARROW_WEDGE (banking arrowhead)
			var mid = int(count * 0.5)
			for i in range(count):
				var lateral_step = (float(i) - mid) / float(maxi(1, mid)) * 0.35 + 0.5
				var stagger = oncoming * ((mid - absf(float(i - mid))) * 18.0)
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(lateral_step) + stagger)
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				# CADENCE_APEX_LEAD: Apex leader materializes first, wingmen follow in trailing pairs
				var cadence = base_delay + absf(float(i - mid)) * 0.22
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

		"SWEEP_ROW", "ECHELON", "SERPENTINE_STREAM":
			profile = 2 # FlightProfile.SERPENTINE_STREAM (sinusoidal wave flow)
			for i in range(count):
				var lateral_step = 0.14 + (float(i) / maxi(1, count - 1)) * 0.72
				var stagger = oncoming * (i * 14.0)
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(lateral_step) + stagger)
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				# CADENCE_RIPPLE: Sequential stream emerging one by one in rhythm
				var cadence = base_delay + i * 0.24
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

		"FLANK_SPLIT", "PINCER_FLANK", "PINCER_CONVERGE":
			profile = 3 # FlightProfile.PINCER_CONVERGE (converging toward center corridor)
			for i in range(count):
				var is_left = (i % 2 == 0)
				var lateral_step = 0.18 if is_left else 0.82
				var stagger = oncoming * ((i / 2) * 18.0)
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(lateral_step) + stagger)
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				# CADENCE_ALTERNATING: Upper and lower horizon alternate in rhythm
				var cadence = base_delay + i * 0.20
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

		"FLANK_LEFT", "UPPER_CORRIDOR":
			profile = 3 # FlightProfile.PINCER_CONVERGE (upper horizon bank)
			for i in range(count):
				var stagger = oncoming * (i * 18.0)
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(0.18) + stagger)
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				var cadence = base_delay + i * 0.22
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

		"FLANK_RIGHT", "LOWER_CORRIDOR":
			profile = 3 # FlightProfile.PINCER_CONVERGE (lower horizon bank)
			for i in range(count):
				var stagger = oncoming * (i * 18.0)
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(0.82) + stagger)
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				var cadence = base_delay + i * 0.22
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

		"CENTER", "CENTER_STREAM":
			profile = 4 # FlightProfile.CENTER_STREAM (focused center line)
			for i in range(count):
				var stagger = oncoming * (i * 20.0)
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(0.5) + stagger)
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				var cadence = base_delay + i * 0.25
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

		"ROW", "HORIZON_SPREAD", "DISCIPLINED_LINE":
			profile = 0 # FlightProfile.DISCIPLINED_LINE (clean parallel battle wall)
			for i in range(count):
				var lateral_step = 0.15 + (float(i) / maxi(1, count - 1)) * 0.70
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(lateral_step))
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				# CADENCE_SIMULTANEOUS: Full firing line emerges simultaneously on horizon
				var cadence = base_delay + 0.0
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

		_: # RANDOM_HORIZON / Fallback
			profile = 0 # FlightProfile.DIRECT_ADVANCE
			for i in range(count):
				var lat_step = randf_range(0.15, 0.85)
				var pos = _clamp_to_spawn_zone(GameAxis.get_spawn_line(lat_step))
				var craft_affix = get_craft_affix(i, count, pattern, affix)
				var cadence = base_delay + i * 0.18
				_queue_quantum_bubble(e_type, pos, squad_id, cadence, craft_affix, profile)

func _register_squad(squad_id: int, total_count: int) -> void:
	squads[squad_id] = {
		"total": total_count,
		"killed": 0,
		"escaped": 0,
		"awarded": false
	}

func _queue_quantum_bubble(type: int, pos: Vector2, squad_id: int, delay: float = 0.0, affix: int = 0, profile: int = -1) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		if not GameManager.is_game_over:
			var dur = randf_range(0.36, 0.42)
			active_bubbles.append({
				"type": type,
				"pos": pos,
				"squad_id": squad_id,
				"affix": affix,
				"profile": profile,
				"elapsed": 0.0,
				"duration": dur,
				"sfx_played": false
			})
			var stage = get_tree().get_first_node_in_group("stage_3d")
			if is_instance_valid(stage):
				if stage.has_method("trigger_nexus_surge"):
					stage.trigger_nexus_surge(0.4)
				if stage.has_method("spawn_materialization_aperture"):
					stage.spawn_materialization_aperture(pos, dur)
	)

func _materialize_enemy(type: int, pos: Vector2, squad_id: int, affix: int = 0, profile: int = -1) -> void:
	var stage = get_tree().get_first_node_in_group("stage_3d")
	if is_instance_valid(stage) and stage.has_method("trigger_materialization_flash"):
		stage.trigger_materialization_flash(pos)
		
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	var drop_prof = current_wave_drop_distribution.get(type, {})
	enemy.setup(type, pos, squad_id, self, affix, profile, drop_prof)

func notify_kill(squad_id: int) -> void:
	record_squad_kill(squad_id)

func record_squad_kill(squad_id: int) -> void:
	current_wave_killed += 1
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
	current_wave_escaped += 1
	if not squads.has(squad_id):
		return
	var sq = squads[squad_id]
	sq.escaped += 1
	if GameManager != null:
		GameManager.consecutive_wipes = 0

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

