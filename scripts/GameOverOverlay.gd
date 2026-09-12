extends CanvasLayer

## GameOverOverlay.gd - Cyberpunk terminal death recap screen with instant quick-restart.

@onready var panel: Control = $Panel
@onready var score_val: Label = $Panel/VBox/StatsGrid/ScoreVal
@onready var wipes_val: Label = $Panel/VBox/StatsGrid/WipesVal
@onready var kills_val: Label = $Panel/VBox/StatsGrid/KillsVal
@onready var time_val: Label = $Panel/VBox/StatsGrid/TimeVal
@onready var restart_button: Button = $Panel/VBox/RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	GameManager.game_over_triggered.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)

func _on_game_over(final_score: int, wipes: int, survival_time: float) -> void:
	score_val.text = str(final_score).pad_zeros(6)
	wipes_val.text = str(wipes)
	kills_val.text = str(GameManager.enemies_destroyed)
	
	var mins = int(survival_time / 60.0)
	var secs = int(fmod(survival_time, 60.0))
	time_val.text = "%02d:%02d" % [mins, secs]
	
	panel.visible = true
	panel.modulate.a = 0.0
	var tw = create_tween()
	if tw:
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		panel.modulate.a = 1.0

func _on_restart_pressed() -> void:
	GameManager.restart_game()
