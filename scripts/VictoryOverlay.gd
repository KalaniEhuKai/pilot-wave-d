extends CanvasLayer

## VictoryOverlay.gd - Cyberpunk run victory dialog shown when the Sector Boss is defeated.

const MenuStyleHelper = preload("res://scripts/MenuStyleHelper.gd")

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/Subtitle
@onready var high_score_badge: Label = $Panel/VBox/HighScoreBadge
@onready var score_val: Label = $Panel/VBox/StatsGrid/ScoreVal
@onready var wipes_val: Label = $Panel/VBox/StatsGrid/WipesVal
@onready var kills_val: Label = $Panel/VBox/StatsGrid/KillsVal
@onready var time_val: Label = $Panel/VBox/StatsGrid/TimeVal
@onready var relics_val: Label = $Panel/VBox/StatsGrid/RelicsVal
@onready var joules_val: Label = $Panel/VBox/StatsGrid/JoulesVal
@onready var play_again_btn: Button = $Panel/VBox/ActionRow/PlayAgainButton
@onready var main_menu_btn: Button = $Panel/VBox/ActionRow/MainMenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	
	MenuStyleHelper.style_button(play_again_btn, Color(0.1, 1.0, 0.6, 1.0))
	MenuStyleHelper.style_button(main_menu_btn, Color(0.2, 0.85, 1.0, 1.0))
	
	play_again_btn.pressed.connect(_on_play_again_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	GameManager.victory_triggered.connect(_on_victory)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	
	if event.is_action_pressed("restart"):
		_on_play_again_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_main_menu_pressed()
		get_viewport().set_input_as_handled()

func _on_victory(final_score: int, wipes: int, survival_time: float, boss_name: String) -> void:
	get_tree().paused = true
	
	title_label.text = "RUN WON // SECTOR %02d SECURED!" % GameManager.current_sector
	subtitle_label.text = "FLAGSHIP %s VAPORIZED - QUANTUM COHERENCE RESTORED" % boss_name.to_upper()
	
	score_val.text = str(final_score).pad_zeros(6)
	wipes_val.text = str(wipes)
	kills_val.text = str(GameManager.enemies_destroyed)
	joules_val.text = "%d J" % GameManager.total_joules_collected
	time_val.text = HighScoreManager.format_time(survival_time)
	
	# Count active relics across players
	var relic_count = 0
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("active_modifiers") != null:
			relic_count += p.active_modifiers.size()
	relics_val.text = "%d RELICS" % relic_count
	
	# Record run to HighScoreManager
	var mode_name = "2P Co-Op" if GameManager.is_coop_mode else "1P Normal"
	var rank = HighScoreManager.record_run(
		final_score,
		GameManager.current_sector,
		GameManager.current_wave,
		mode_name,
		survival_time,
		GameManager.enemies_destroyed,
		true
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
	
	play_again_btn.grab_focus()
	
	var tw = create_tween()
	if tw:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		panel.modulate.a = 1.0
	
	SoundEffects.play_sfx("bonus", 0.05, 3.0)

func _on_play_again_pressed() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	GameManager.restart_game()

func _on_main_menu_pressed() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	GameManager.return_to_main_menu()
