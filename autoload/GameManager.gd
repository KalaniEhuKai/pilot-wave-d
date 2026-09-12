extends Node

## GameManager.gd - Central run lifecycle, sector progression, co-op economy, arcade scoring, and boss director.

enum RunPhase { COMBAT_WAVES, SHOP_DOCKING, BOSS_BATTLE, SECTOR_VICTORY }

signal phase_changed(new_phase: RunPhase)
signal score_changed(new_score: int, delta: int)
signal wipe_bonus_awarded(bonus_points: int, message: String)
signal player_health_changed(hull: int, shields: int, max_hull: int, max_shields: int, player_id: int)
signal player_roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float, player_id: int)
signal player_modifiers_updated(modifiers: Array, player_id: int)
signal player_died(player_id: int)
signal game_over_triggered(final_score: int, wipes: int, survival_time: float)
signal game_reset()
signal screen_shake_requested(intensity: float, duration: float)
signal joules_changed(p1: int, p2: int)
signal boss_health_updated(current_hp: float, max_hp: float, boss_name: String)
signal boss_defeated(boss_name: String)
signal victory_triggered(final_score: int, wipes: int, survival_time: float, boss_name: String)
signal sector_cleared(sector_num: int, rank: String, bonus_points: int)
signal secret_discovered(secret_name: String, bonus_pts: int)

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

func restart_game() -> void:
	get_tree().paused = false
	score = 0
	wipe_count = 0
	consecutive_wipes = 0
	enemies_destroyed = 0
	survival_time = 0.0
	is_game_over = false
	current_wave = 1
	current_sector = 1
	scrap_joules = 0
	total_joules_collected = 0
	p1_joules = 0
	p2_joules = 0
	p1_reroll_cost = 5
	p2_reroll_cost = 5
	current_phase = RunPhase.COMBAT_WAVES
	game_reset.emit()
	get_tree().reload_current_scene()

func request_screen_shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	screen_shake_requested.emit(intensity, duration)

func notify_secret(name: String, bonus: int) -> void:
	score += bonus
	score_changed.emit(score, bonus)
	secret_discovered.emit(name, bonus)
	request_screen_shake(8.0, 0.25)
