extends Node

## GameManager.gd - Central run lifecycle, sector progression, co-op economy, arcade scoring, and boss director.

enum RunPhase { COMBAT_WAVES, SHOP_DOCKING, BOSS_BATTLE, SECTOR_VICTORY }
enum GameMode { NORMAL, ENDLESS, ASCENSION }

signal phase_changed(new_phase: RunPhase)
signal game_mode_changed(new_mode: GameMode)
signal score_changed(new_score: int, delta: int)
signal wipe_bonus_awarded(bonus_points: int, message: String)
signal player_health_changed(hull: int, shields: int, max_hull: int, max_shields: int, player_id: int)
signal player_roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float, player_id: int)
signal player_shield_charges_changed(shields: int, max_shields: int, cooldown_ratio: float, player_id: int)
signal player_modifiers_updated(modifiers: Array, player_id: int)
signal player_died(player_id: int)
signal game_over_triggered(final_score: int, wipes: int, survival_time: float)
signal game_reset()
signal screen_shake_requested(intensity: float, duration: float)
signal directional_shake_requested(direction: Vector2, intensity: float, duration: float)
signal custom_shake_requested(direction: Vector2, intensity: float, duration: float, frequency: float)
signal player_hull_damaged(player_id: int, hull: int, max_hull: int)
signal player_shield_broken(player_id: int)
signal joules_changed(p1: int, p2: int)
signal boss_health_updated(current_hp: float, max_hp: float, boss_name: String)
signal boss_defeated(boss_name: String)
signal victory_triggered(final_score: int, wipes: int, survival_time: float, boss_name: String)
signal sector_cleared(sector_num: int, rank: String, bonus_points: int)
signal secret_discovered(secret_name: String, bonus_pts: int)

var current_game_mode: GameMode = GameMode.NORMAL:
	set(value):
		current_game_mode = value
		game_mode_changed.emit(current_game_mode)

var current_phase: RunPhase = RunPhase.COMBAT_WAVES:
	set(value):
		current_phase = value
		phase_changed.emit(current_phase)

var score: int = 0
var wipe_count: int = 0
var consecutive_wipes: int = 0
var enemies_destroyed: int = 0
var survival_time: float = 0.0
var is_game_over: bool = false
var is_paused: bool = false
var current_wave: int = 1
var current_sector: int = 1

# 2-Player Co-Op Economy
var is_coop_mode: bool = false
var scrap_joules: int = 0 # Single-player shared alias
var total_joules_collected: int = 0 # Cumulative lifetime Joules collected across run
var p1_joules: int = 0
var p2_joules: int = 0

# Reroll price curves
var p1_reroll_cost: int = 5
var p2_reroll_cost: int = 5

# Secret Debug & Telemetry State
var debug_mode_unlocked: bool = false
var high_score_recording_enabled: bool = true
var telemetry_enabled: bool = true
var debug_god_mode: bool = false
var debug_infinite_rolls: bool = false
var debug_give_god_build: bool = false
var debug_starting_relics: Array[String] = []
var start_sector: int = 1
var start_wave: int = 1
var force_unlocked_modes: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_game_over and not is_paused and current_phase != RunPhase.SECTOR_VICTORY:
		survival_time += delta
	
	if Input.is_action_just_pressed("toggle_axis"):
		GameAxis.toggle_axis()
	
	if Input.is_action_just_pressed("restart") and (is_game_over or current_phase == RunPhase.SECTOR_VICTORY):
		restart_game()

func add_score(amount: int) -> void:
	if is_game_over:
		return
	score += amount
	score_changed.emit(score, amount)

func add_joules(amount: int, target_player_id: int = 0) -> void:
	total_joules_collected += amount
	if is_coop_mode:
		if target_player_id == 1:
			p1_joules += amount
		elif target_player_id == 2:
			p2_joules += amount
		else:
			# Shared pickup in flight gives equal scrap to both players!
			p1_joules += amount
			p2_joules += amount
		scrap_joules = p1_joules
	else:
		scrap_joules += amount
		p1_joules = scrap_joules
	joules_changed.emit(p1_joules, p2_joules)

func spend_joules(amount: int, player_id: int = 1) -> bool:
	if is_coop_mode:
		if player_id == 2:
			if p2_joules >= amount:
				p2_joules -= amount
				joules_changed.emit(p1_joules, p2_joules)
				return true
			return false
		else:
			if p1_joules >= amount:
				p1_joules -= amount
				scrap_joules = p1_joules
				joules_changed.emit(p1_joules, p2_joules)
				return true
			return false
	else:
		if scrap_joules >= amount:
			scrap_joules -= amount
			p1_joules = scrap_joules
			joules_changed.emit(p1_joules, p2_joules)
			return true
		return false

func award_wipe_bonus(amount: int = 1000) -> void:
	if is_game_over:
		return
	wipe_count += 1
	consecutive_wipes += 1
	score += amount
	score_changed.emit(score, amount)
	wipe_bonus_awarded.emit(amount, "100% FORMATION WIPE! +" + str(amount) + " PTS")
	request_screen_shake(6.0, 0.2)

func record_kill() -> void:
	enemies_destroyed += 1

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	consecutive_wipes = 0
	get_tree().paused = false
	player_died.emit(1)
	game_over_triggered.emit(score, wipe_count, survival_time)

func trigger_victory(boss_name: String = "FLAGSHIP") -> void:
	current_phase = RunPhase.SECTOR_VICTORY
	victory_triggered.emit(score, wipe_count, survival_time, boss_name)

func advance_sector() -> void:
	current_sector += 1
	var bonus = 10000 * (current_sector - 1)
	score += bonus
	score_changed.emit(score, bonus)
	sector_cleared.emit(current_sector - 1, "S", bonus)
	current_phase = RunPhase.COMBAT_WAVES

func disable_scores_and_telemetry() -> void:
	debug_mode_unlocked = true
	high_score_recording_enabled = false
	telemetry_enabled = false
	if HighScoreManager != null and "high_score_recording_enabled" in HighScoreManager:
		HighScoreManager.high_score_recording_enabled = false

func reset_run_state() -> void:
	score = 0
	wipe_count = 0
	consecutive_wipes = 0
	enemies_destroyed = 0
	survival_time = 0.0
	is_game_over = false
	is_paused = false
	current_wave = start_wave
	current_sector = start_sector
	scrap_joules = 0
	total_joules_collected = 0
	p1_joules = 0
	p2_joules = 0
	p1_reroll_cost = 5
	p2_reroll_cost = 5
	current_phase = RunPhase.COMBAT_WAVES

func restart_game() -> void:
	get_tree().paused = false
	reset_run_state()
	game_reset.emit()
	get_tree().reload_current_scene()

func return_to_main_menu() -> void:
	get_tree().paused = false
	reset_run_state()
	game_reset.emit()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func request_screen_shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	screen_shake_requested.emit(intensity, duration)

func request_directional_shake(direction: Vector2, intensity: float = 10.0, duration: float = 0.2) -> void:
	directional_shake_requested.emit(direction, intensity, duration)


func trigger_hit_stop(duration_sec: float = 0.04) -> void:
	if is_game_over or (get_tree() != null and get_tree().paused):
		return
	Engine.time_scale = 0.05
	if get_tree():
		get_tree().create_timer(duration_sec, true, false, true).timeout.connect(func():
			Engine.time_scale = 1.0
		)

func notify_secret(name: String, bonus: int) -> void:
	score += bonus
	score_changed.emit(score, bonus)
	secret_discovered.emit(name, bonus)
	request_screen_shake(8.0, 0.25)
