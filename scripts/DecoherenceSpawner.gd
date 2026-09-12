extends Node2D

## DecoherenceSpawner.gd - Materializes enemy squadrons and elite champions from quantum probability bubbles.

var enemy_scene: PackedScene = preload("res://scenes/Enemy.tscn")

var next_squad_id: int = 1
var squads: Dictionary = {}

var wave_timer: float = 1.0
var wave_interval: float = 5.2
var current_wave_num: int = 1

var active_bubbles: Array[Dictionary] = []

func _process(delta: float) -> void:
	if GameManager.is_game_over or GameManager.current_phase != GameManager.RunPhase.COMBAT_WAVES:
		return
	
	wave_timer -= delta
	if wave_timer <= 0.0:
		# If enemies or telegraph bubbles are still active, wait before starting next wave
		var active_enemies = get_tree().get_nodes_in_group("enemy")
		if not active_enemies.is_empty() or not active_bubbles.is_empty():
			# Delay next wave check slightly until airspace is clear
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
	
	var is_elite_wave = (current_wave_num % 4 == 0)
	
	if is_elite_wave:
		_spawn_elite_champion_wave(squad_id)
	else:
		var wave_pattern = (current_wave_num - 1) % 4
		match wave_pattern:
			0: _spawn_scout_v_formation(squad_id, 5)
			1: _spawn_pincer_formation(squad_id, 3)
			2: _spawn_bomber_echelon(squad_id, 3)
			3: _spawn_strike_group(squad_id)

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

func _spawn_scout_v_formation(squad_id: int, count: int) -> void:
	_register_squad(squad_id, count)
	var mid = int(count * 0.5)
	for i in range(count):
		var lateral_step = (float(i) - mid) / float(mid) * 0.35 + 0.5
		var pos = GameAxis.get_spawn_line(lateral_step)
		var fwd_offset = absf(float(i - mid)) * 36.0
		pos += GameAxis.forward * fwd_offset
		_queue_quantum_bubble(0, pos, squad_id, absf(float(i - mid)) * 0.1)

func _spawn_pincer_formation(squad_id: int, per_side: int) -> void:
	_register_squad(squad_id, per_side * 2)
	for i in range(per_side):
		var pos1 = GameAxis.get_spawn_line(0.18 + i * 0.08)
		_queue_quantum_bubble(0, pos1, squad_id, i * 0.14)
		var pos2 = GameAxis.get_spawn_line(0.82 - i * 0.08)
		_queue_quantum_bubble(0, pos2, squad_id, i * 0.14)

func _spawn_bomber_echelon(squad_id: int, count: int) -> void:
	_register_squad(squad_id, count)
	for i in range(count):
		var lateral_step = 0.28 + (float(i) / (count - 1)) * 0.44
		var pos = GameAxis.get_spawn_line(lateral_step)
		pos += GameAxis.forward * (i * 45.0)
		_queue_quantum_bubble(1, pos, squad_id, i * 0.2)

func _spawn_strike_group(squad_id: int) -> void:
	_register_squad(squad_id, 6)
	var b_pos1 = GameAxis.get_spawn_line(0.4)
	var b_pos2 = GameAxis.get_spawn_line(0.6)
	_queue_quantum_bubble(1, b_pos1, squad_id, 0.0)
	_queue_quantum_bubble(1, b_pos2, squad_id, 0.1)
	
	var s_positions = [0.22, 0.3, 0.7, 0.78]
	for i in range(s_positions.size()):
		var s_pos = GameAxis.get_spawn_line(s_positions[i])
		s_pos += GameAxis.forward * 40.0
		_queue_quantum_bubble(0, s_pos, squad_id, 0.25 + i * 0.08)

func _spawn_elite_champion_wave(squad_id: int) -> void:
	# 1 Armored or Volatile Bomber + 2 Elite Scouts
	_register_squad(squad_id, 3)
	var affix = 1 if (randf() > 0.5) else 2 # 1 = ARMORED, 2 = VOLATILE
	
	var b_pos = GameAxis.get_spawn_line(0.5)
	_queue_quantum_bubble(1, b_pos, squad_id, 0.0, affix)
	
	var s1_pos = GameAxis.get_spawn_line(0.28) + GameAxis.forward * 30.0
	var s2_pos = GameAxis.get_spawn_line(0.72) + GameAxis.forward * 30.0
	_queue_quantum_bubble(0, s1_pos, squad_id, 0.2, 0)
	_queue_quantum_bubble(0, s2_pos, squad_id, 0.2, 0)

func record_squad_kill(squad_id: int) -> void:
	if not squads.has(squad_id):
		return
	var sq = squads[squad_id]
	sq.killed += 1
	if sq.killed == sq.total and sq.escaped == 0 and not sq.awarded:
		sq.awarded = true
		GameManager.award_wipe_bonus(1000)
		SoundEffects.play_sfx("bonus", 0.04, 2.0)

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
		
		# If elite, bubble has golden-amber interference rings!
		var fringe_color = Color(0.2, 0.9, 1.0, (1.0 - progress) * 0.8)
		if b.get("affix", 0) != 0:
			fringe_color = Color(1.0, 0.8, 0.2, (1.0 - progress) * 0.9)
			base_radius *= 1.3
		
		var inner_color = Color(0.8, 0.2, 1.0, (1.0 - progress) * 0.6)
		draw_arc(bubble_pos, base_radius, 0, TAU, 32, fringe_color, 2.5, true)
		draw_arc(bubble_pos, base_radius * 0.65, 0, TAU, 24, inner_color, 1.8, true)
		draw_circle(bubble_pos, 4.0 * (1.0 - progress), Color.WHITE)
