extends CanvasLayer

## VictoryOverlay.gd - Cyberpunk run victory dialog shown when the Sector Boss is defeated.

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/Subtitle
@onready var score_val: Label = $Panel/VBox/StatsGrid/ScoreVal
@onready var wipes_val: Label = $Panel/VBox/StatsGrid/WipesVal
@onready var kills_val: Label = $Panel/VBox/StatsGrid/KillsVal
@onready var time_val: Label = $Panel/VBox/StatsGrid/TimeVal
@onready var relics_val: Label = $Panel/VBox/StatsGrid/RelicsVal
@onready var play_again_btn: Button = $Panel/VBox/PlayAgainButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	play_again_btn.focus_mode = Control.FOCUS_NONE
	play_again_btn.pressed.connect(_on_play_again_pressed)
	GameManager.victory_triggered.connect(_on_victory)

func _on_victory(final_score: int, wipes: int, survival_time: float, boss_name: String) -> void:
	get_tree().paused = true
	
	title_label.text = "RUN WON // SECTOR 01 CLEARED!"
	subtitle_label.text = "FLAGSHIP %s VAPORIZED - QUANTUM COHERENCE RESTORED" % boss_name.to_upper()
	
	score_val.text = str(final_score).pad_zeros(6)
	wipes_val.text = str(wipes)
	kills_val.text = str(GameManager.enemies_destroyed)
	
	var mins = int(survival_time / 60.0)
	var secs = int(fmod(survival_time, 60.0))
	time_val.text = "%02d:%02d" % [mins, secs]
	
	# Count active relics across players
	var relic_count = 0
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("active_modifiers") != null:
			relic_count += p.active_modifiers.size()
	relics_val.text = "%d RELICS SYNCHRONIZED" % relic_count
	
	panel.visible = true
	panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	SoundEffects.play_sfx("bonus", 0.05, 3.0)

func _on_play_again_pressed() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	GameManager.restart_game()
