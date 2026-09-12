extends CanvasLayer

## HUD.gd - Responsive cyberpunk arcade HUD with health, shields, barrel rolls, score, Joules, Synergy Ribbon, and Item Choice Modal.

@onready var score_label: Label = $TopRight/VBox/ScoreLabel
@onready var joules_label: Label = $TopRight/VBox/JoulesLabel
@onready var wave_label: Label = $TopRight/VBox/WaveLabel
@onready var wipes_label: Label = $TopRight/VBox/WipesLabel
@onready var wipe_banner: Label = $CenterContainer/WipeBanner
@onready var axis_button: Button = $TopCenter/AxisButton

# Health & Shield UI elements
@onready var shield_bar: ProgressBar = $TopLeft/VBox/ShieldBar
@onready var hull_container: HBoxContainer = $TopLeft/VBox/HullContainer
@onready var roll_container: HBoxContainer = $TopLeft/VBox/RollContainer
@onready var synergy_ribbon: HBoxContainer = $TopLeft/VBox/SynergyRibbon

# Item Choice Modal
@onready var choice_modal: Control = $ItemChoiceModal
@onready var choice_btn_a: Button = $ItemChoiceModal/Panel/VBox/HBox/CardA/EquipBtnA
@onready var choice_btn_b: Button = $ItemChoiceModal/Panel/VBox/HBox/CardB/EquipBtnB
@onready var title_a: Label = $ItemChoiceModal/Panel/VBox/HBox/CardA/TitleA
@onready var title_b: Label = $ItemChoiceModal/Panel/VBox/HBox/CardB/TitleB
@onready var desc_a: Label = $ItemChoiceModal/Panel/VBox/HBox/CardA/DescA
@onready var desc_b: Label = $ItemChoiceModal/Panel/VBox/HBox/CardB/DescB
@onready var tier_a: Label = $ItemChoiceModal/Panel/VBox/HBox/CardA/TierA
@onready var tier_b: Label = $ItemChoiceModal/Panel/VBox/HBox/CardB/TierB

var current_choice_a: ItemModifier = null
var current_choice_b: ItemModifier = null

var display_score: int = 0
var target_score: int = 0
var banner_timer: float = 0.0

func _ready() -> void:
	add_to_group("hud")
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.wipe_bonus_awarded.connect(_on_wipe_bonus_awarded)
	GameManager.player_health_changed.connect(_on_health_changed)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].roll_charges_changed.connect(_on_roll_charges_changed)
		players[0].modifiers_updated.connect(_on_modifiers_updated)
	
	axis_button.pressed.connect(_on_axis_button_pressed)
	_update_axis_button_text()
	GameAxis.axis_changed.connect(func(_v): _update_axis_button_text())
	
	choice_btn_a.pressed.connect(func(): _select_choice(current_choice_a))
	choice_btn_b.pressed.connect(func(): _select_choice(current_choice_b))
	
	choice_modal.visible = false
	wipe_banner.modulate.a = 0.0

func _process(delta: float) -> void:
	if display_score < target_score:
		var step = maxi(10, int((target_score - display_score) * 0.15))
		display_score = mini(target_score, display_score + step)
		score_label.text = "SCORE: " + str(display_score).pad_zeros(6)
	
	joules_label.text = "JOULES: " + str(GameManager.scrap_joules) + " J"
	wave_label.text = "WAVE: " + str(GameManager.current_wave)
	wipes_label.text = "WIPES: " + str(GameManager.wipe_count)
	
	if banner_timer > 0.0:
		banner_timer -= delta
		wipe_banner.modulate.a = clampf(banner_timer / 0.5, 0.0, 1.0)

func _on_score_changed(new_score: int, _delta: int) -> void:
	target_score = new_score

func _on_wipe_bonus_awarded(_bonus: int, message: String) -> void:
	wipe_banner.text = message
	wipe_banner.modulate = Color(1.0, 0.85, 0.2, 1.0)
	banner_timer = 2.2
	var tw = create_tween()
	wipe_banner.scale = Vector2(1.35, 1.35)
	tw.tween_property(wipe_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_health_changed(hull: int, shields: int, max_hull: int, max_shields: int) -> void:
	shield_bar.max_value = max_shields
	shield_bar.value = shields
	
	for i in range(hull_container.get_child_count()):
		var pip = hull_container.get_child(i)
		if i < hull:
			pip.modulate = Color(0.1, 1.0, 0.6, 1.0)
		else:
			pip.modulate = Color(0.3, 0.1, 0.1, 0.4)

func _on_roll_charges_changed(charges: int, _max_charges: int, _cooldown_ratio: float) -> void:
	for i in range(roll_container.get_child_count()):
		var pip = roll_container.get_child(i)
		if i < charges:
			pip.modulate = Color(0.2, 0.9, 1.0, 1.0)
		else:
			pip.modulate = Color(0.2, 0.4, 0.5, 0.3)

func _on_modifiers_updated(modifiers: Array[ItemModifier]) -> void:
	for child in synergy_ribbon.get_children():
		child.queue_free()
	
	for mod in modifiers:
		var badge = Label.new()
		badge.text = mod.icon_symbol
		badge.tooltip_text = mod.display_name + ": " + mod.description
		badge.add_theme_color_override("font_color", mod.icon_color)
		badge.add_theme_font_size_override("font_size", 14)
		synergy_ribbon.add_child(badge)

func _on_axis_button_pressed() -> void:
	GameAxis.toggle_axis()

func _update_axis_button_text() -> void:
	if GameAxis.is_vertical:
		axis_button.text = "MODE: VERTICAL (9:16)"
	else:
		axis_button.text = "MODE: HORIZONTAL (16:9)"

# --- Item Choice Modal ---

func open_item_choice_modal() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	
	var equipped_ids: Array[String] = []
	for m in player.active_modifiers:
		equipped_ids.append(m.id)
	
	var choices = ItemDatabase.get_random_choice(equipped_ids, 2)
	if choices.is_empty():
		return
	
	current_choice_a = choices[0]
	current_choice_b = choices[1] if choices.size() > 1 else choices[0]
	
	_populate_card(current_choice_a, title_a, tier_a, desc_a)
	_populate_card(current_choice_b, title_b, tier_b, desc_b)
	
	choice_modal.visible = true
	choice_modal.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(choice_modal, "modulate:a", 1.0, 0.2)
	get_tree().paused = true

func _populate_card(item: ItemModifier, t_lbl: Label, tier_lbl: Label, d_lbl: Label) -> void:
	t_lbl.text = item.display_name
	t_lbl.add_theme_color_override("font_color", item.icon_color)
	
	match item.tier:
		ItemModifier.ItemTier.TIER_1_BALLISTIC:
			tier_lbl.text = "TIER 1 - BALLISTIC MODIFIER"
			tier_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
		ItemModifier.ItemTier.TIER_2_PARADIGM:
			tier_lbl.text = "TIER 2 - WEAPON PARADIGM"
			tier_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.6, 1.0))
		ItemModifier.ItemTier.TIER_3_EXOTIC:
			tier_lbl.text = "TIER 3 - EXOTIC RELIC"
			tier_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	
	d_lbl.text = item.description

func _select_choice(item: ItemModifier) -> void:
	get_tree().paused = false
	choice_modal.visible = false
	
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty() and is_instance_valid(players[0]):
		players[0].add_modifier(item)
		_on_modifiers_updated(players[0].active_modifiers)

# Mobile Touch Button handlers
func _on_fire_button_down() -> void:
	Input.action_press("fire")

func _on_fire_button_up() -> void:
	Input.action_release("fire")

func _on_roll_button_pressed() -> void:
	Input.action_press("barrel_roll")
	get_tree().create_timer(0.05).timeout.connect(func(): Input.action_release("barrel_roll"))
