extends CanvasLayer

## HUD.gd - Responsive cyberpunk arcade HUD with health pips, shield bar, barrel rolls, score, wipeout banner, and touch controls.

@onready var score_label: Label = $TopRight/VBox/ScoreLabel
@onready var wave_label: Label = $TopRight/VBox/WaveLabel
@onready var wipes_label: Label = $TopRight/VBox/WipesLabel
@onready var wipe_banner: Label = $CenterContainer/WipeBanner
@onready var axis_button: Button = $TopCenter/AxisButton

# Health & Shield UI elements
@onready var shield_bar: ProgressBar = $TopLeft/VBox/ShieldBar
@onready var hull_container: HBoxContainer = $TopLeft/VBox/HullContainer
@onready var roll_container: HBoxContainer = $TopLeft/VBox/RollContainer

var display_score: int = 0
var target_score: int = 0

var banner_timer: float = 0.0

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.wipe_bonus_awarded.connect(_on_wipe_bonus_awarded)
	GameManager.player_health_changed.connect(_on_health_changed)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].roll_charges_changed.connect(_on_roll_charges_changed)
	
	axis_button.pressed.connect(_on_axis_button_pressed)
	_update_axis_button_text()
	GameAxis.axis_changed.connect(func(_v): _update_axis_button_text())
	
	wipe_banner.modulate.a = 0.0

func _process(delta: float) -> void:
	# Rolling score interpolation
	if display_score < target_score:
		var step = maxi(10, int((target_score - display_score) * 0.15))
		display_score = mini(target_score, display_score + step)
		score_label.text = "SCORE: " + str(display_score).pad_zeros(6)
	
	wave_label.text = "WAVE: " + str(GameManager.current_wave)
	wipes_label.text = "WIPES: " + str(GameManager.wipe_count)
	
	# Fade out wipeout banner
	if banner_timer > 0.0:
		banner_timer -= delta
		wipe_banner.modulate.a = clampf(banner_timer / 0.5, 0.0, 1.0)

func _on_score_changed(new_score: int, _delta: int) -> void:
	target_score = new_score

func _on_wipe_bonus_awarded(bonus: int, message: String) -> void:
	wipe_banner.text = message
	wipe_banner.modulate = Color(1.0, 0.85, 0.2, 1.0) # Golden arcade glow
	banner_timer = 2.2
	
	# Scale punch animation
	var tw = create_tween()
	wipe_banner.scale = Vector2(1.35, 1.35)
	tw.tween_property(wipe_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_health_changed(hull: int, shields: int, max_hull: int, max_shields: int) -> void:
	shield_bar.max_value = max_shields
	shield_bar.value = shields
	
	# Update hull pips
	for i in range(hull_container.get_child_count()):
		var pip = hull_container.get_child(i)
		if i < hull:
			pip.modulate = Color(0.1, 1.0, 0.6, 1.0) # Active vibrant cyan-green
		else:
			pip.modulate = Color(0.3, 0.1, 0.1, 0.4) # Depleted dark red

func _on_roll_charges_changed(charges: int, _max_charges: int, _cooldown_ratio: float) -> void:
	for i in range(roll_container.get_child_count()):
		var pip = roll_container.get_child(i)
		if i < charges:
			pip.modulate = Color(0.2, 0.9, 1.0, 1.0) # Ready bright cyan
		else:
			pip.modulate = Color(0.2, 0.4, 0.5, 0.3) # On cooldown

func _on_axis_button_pressed() -> void:
	GameAxis.toggle_axis()

func _update_axis_button_text() -> void:
	if GameAxis.is_vertical:
		axis_button.text = "MODE: VERTICAL (9:16)"
	else:
		axis_button.text = "MODE: HORIZONTAL (16:9)"

# Mobile Touch Button handlers
func _on_fire_button_down() -> void:
	Input.action_press("fire")

func _on_fire_button_up() -> void:
	Input.action_release("fire")

func _on_roll_button_pressed() -> void:
	Input.action_press("barrel_roll")
	get_tree().create_timer(0.05).timeout.connect(func(): Input.action_release("barrel_roll"))
