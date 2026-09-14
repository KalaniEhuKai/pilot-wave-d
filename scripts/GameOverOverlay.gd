extends CanvasLayer

## GameOverOverlay.gd - Cyberpunk terminal death recap screen with instant quick-restart.

const MenuStyleHelper = preload("res://scripts/MenuStyleHelper.gd")

@onready var panel: Control = $Panel
@onready var high_score_badge: Label = $Panel/VBox/HighScoreBadge
@onready var score_val: Label = $Panel/VBox/StatsGrid/ScoreVal
@onready var sector_val: Label = $Panel/VBox/StatsGrid/SectorVal
@onready var wipes_val: Label = $Panel/VBox/StatsGrid/WipesVal
@onready var kills_val: Label = $Panel/VBox/StatsGrid/KillsVal
@onready var time_val: Label = $Panel/VBox/StatsGrid/TimeVal
@onready var joules_val: Label = $Panel/VBox/StatsGrid/JoulesVal
@onready var restart_button: Button = $Panel/VBox/ActionRow/RestartButton
@onready var main_menu_button: Button = $Panel/VBox/ActionRow/MainMenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	
	MenuStyleHelper.style_button(restart_button, Color(0.2, 0.95, 1.0, 1.0))
	MenuStyleHelper.style_button(main_menu_button, Color(1.0, 0.3, 0.6, 1.0))
	
	GameManager.game_over_triggered.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	
	if event.is_action_pressed("restart"):
		_on_restart_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_main_menu_pressed()
		get_viewport().set_input_as_handled()

func _on_game_over(final_score: int, wipes: int, survival_time: float) -> void:
	score_val.text = str(final_score).pad_zeros(6)
	wipes_val.text = str(wipes)
	kills_val.text = str(GameManager.enemies_destroyed)
	sector_val.text = "SECTOR %02d (WAVE %02d)" % [GameManager.current_sector, GameManager.current_wave]
	joules_val.text = "%d J" % GameManager.total_joules_collected
	time_val.text = HighScoreManager.format_time(survival_time)
	
	# Record to HighScoreManager
	var mode_name = "2P Co-Op" if GameManager.is_coop_mode else "1P Normal"
	var rank = HighScoreManager.record_run(
		final_score,
		GameManager.current_sector,
		GameManager.current_wave,
		mode_name,
		survival_time,
		GameManager.enemies_destroyed,
		false
	)
	
	if not GameManager.high_score_recording_enabled or not HighScoreManager.high_score_recording_enabled:
		high_score_badge.text = "⚠ DEBUG OVERRIDE ACTIVE // HIGH SCORES VOIDED ⚠"
		high_score_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.45, 1.0))
		high_score_badge.visible = true
	elif rank > 0:
		high_score_badge.text = "★ NEW HIGH SCORE ARCHIVED: #%d ★" % rank
		high_score_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		high_score_badge.visible = true
	else:
		high_score_badge.visible = false
	
	panel.visible = true
	panel.modulate.a = 0.0
	
	restart_button.grab_focus()
	
	var tw = create_tween()
	if tw:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		panel.modulate.a = 1.0

func _on_restart_pressed() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	GameManager.restart_game()

func _on_main_menu_pressed() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	GameManager.return_to_main_menu()
