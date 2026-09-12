extends Node

## GameManager.gd - Central run lifecycle, arcade scoring, wipe bonus coordinator, and game state.

signal score_changed(new_score: int, delta: int)
signal wipe_bonus_awarded(bonus_points: int, message: String)
signal player_health_changed(hull: int, shields: int, max_hull: int, max_shields: int)
signal player_died()
signal game_over_triggered(final_score: int, wipes: int, survival_time: float)
signal game_reset()
signal screen_shake_requested(intensity: float, duration: float)

var score: int = 0
var wipe_count: int = 0
var enemies_destroyed: int = 0
var survival_time: float = 0.0
var is_game_over: bool = false
var is_paused: bool = false
var current_wave: int = 1
var scrap_joules: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_game_over and not is_paused:
		survival_time += delta
	
	# Global input shortcuts
	if Input.is_action_just_pressed("toggle_axis"):
		GameAxis.toggle_axis()
	
	if Input.is_action_just_pressed("restart") and is_game_over:
		restart_game()

func add_score(amount: int) -> void:
	if is_game_over:
		return
	score += amount
	score_changed.emit(score, amount)

func award_wipe_bonus(amount: int = 1000) -> void:
	if is_game_over:
		return
	wipe_count += 1
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
	player_died.emit()
	game_over_triggered.emit(score, wipe_count, survival_time)

func restart_game() -> void:
	score = 0
	wipe_count = 0
	enemies_destroyed = 0
	survival_time = 0.0
	is_game_over = false
	current_wave = 1
	scrap_joules = 0
	game_reset.emit()
	get_tree().reload_current_scene()

func request_screen_shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	screen_shake_requested.emit(intensity, duration)
