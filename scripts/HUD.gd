extends CanvasLayer

## HUD.gd - Responsive cyberpunk arcade HUD with health, shields, barrel rolls, score, Joules, Synergy Ribbon, Item Choice Modal, Boss Health Bar, and Co-Op status.

@onready var score_label: Label = $TopRight/VBox/ScoreLabel
@onready var joules_label: Label = $TopRight/VBox/JoulesLabel
@onready var wave_label: Label = $TopRight/VBox/WaveLabel
@onready var wipes_label: Label = $TopRight/VBox/WipesLabel
@onready var wipe_banner: Label = $CenterContainer/WipeBanner
@onready var axis_button: Button = $TopCenter/HBox/AxisButton
@onready var coop_button: Button = $TopCenter/HBox/CoopButton

# Boss Health Bar
@onready var boss_container: VBoxContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/BossNameLabel
@onready var boss_bar: ProgressBar = $BossBarContainer/BossBar

# P1 UI
@onready var shield_bar: ProgressBar = $TopLeft/VBox/ShieldBar
@onready var hull_container: HBoxContainer = $TopLeft/VBox/HullContainer
@onready var roll_container: HBoxContainer = $TopLeft/VBox/RollContainer
@onready var synergy_ribbon: HBoxContainer = $TopLeft/VBox/SynergyRibbon

# P2 UI (Co-Op)
@onready var p2_container: VBoxContainer = $TopLeft/VBox/P2Container
@onready var p2_shield_bar: ProgressBar = $TopLeft/VBox/P2Container/P2ShieldBar
@onready var p2_hull_container: HBoxContainer = $TopLeft/VBox/P2Container/P2HullContainer

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.wipe_bonus_awarded.connect(_on_wipe_bonus_awarded)
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.boss_health_updated.connect(_on_boss_health_updated)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.secret_discovered.connect(_on_secret_discovered)
	
	_connect_players()
	
	axis_button.pressed.connect(_on_axis_button_pressed)
	coop_button.pressed.connect(_on_coop_button_pressed)
	_update_axis_button_text()
	_update_coop_button_text()
	
	GameAxis.axis_changed.connect(func(_v): _update_axis_button_text())
	
	choice_btn_a.pressed.connect(func(): _select_choice(current_choice_a))
	choice_btn_b.pressed.connect(func(): _select_choice(current_choice_b))
	
	choice_modal.visible = false
	wipe_banner.modulate.a = 0.0
	boss_container.visible = false
	p2_container.visible = GameManager.is_coop_mode

func _connect_players() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			if p.player_id == 1:
				p.roll_charges_changed.connect(_on_roll_charges_changed)
				p.modifiers_updated.connect(_on_modifiers_updated)

func _process(delta: float) -> void:
	if display_score < target_score:
		var step = maxi(10, int((target_score - display_score) * 0.15))
		display_score = mini(target_score, display_score + step)
		score_label.text = "SCORE: " + str(display_score).pad_zeros(6)
	
	if GameManager.is_coop_mode:
		joules_label.text = "P1: %d J | P2: %d J" % [GameManager.p1_joules, GameManager.p2_joules]
	else:
		joules_label.text = "JOULES: " + str(GameManager.scrap_joules) + " J"
	
	wave_label.text = "WAVE: " + str(GameManager.current_wave)
	wipes_label.text = "WIPES: " + str(GameManager.wipe_count)
	
	if banner_timer > 0.0:
		banner_timer -= delta
		wipe_banner.modulate.a = clampf(banner_timer / 0.5, 0.0, 1.0)

func _on_score_changed(new_score: int, _delta: int) -> void:
	target_score = new_score

func _on_wipe_bonus_awarded(_bonus: int, message: String) -> void:
	_show_banner(message, Color(1.0, 0.85, 0.2, 1.0))

func _on_secret_discovered(name: String, _bonus: int) -> void:
	_show_banner("SECRET: " + name, Color(0.3, 1.0, 0.8, 1.0))

func _show_banner(msg: String, col: Color) -> void:
	wipe_banner.text = msg
	wipe_banner.modulate = col
	banner_timer = 2.4
	var tw = create_tween()
	wipe_banner.scale = Vector2(1.35, 1.35)
	tw.tween_property(wipe_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_boss_health_updated(curr_hp: float, max_hp: float, b_name: String) -> void:
	boss_container.visible = true
	boss_name_label.text = b_name
	boss_bar.max_value = max_hp
	boss_bar.value = curr_hp

func _on_boss_defeated(_b_name: String) -> void:
	boss_container.visible = false
	_show_banner("SECTOR 1 CLEARED! +15,000 PTS", Color(1.0, 0.85, 0.2, 1.0))

func _on_health_changed(hull: int, shields: int, max_hull: int, max_shields: int, p_id: int) -> void:
	if p_id == 2:
		p2_shield_bar.max_value = max_shields
		p2_shield_bar.value = shields
		for i in range(p2_hull_container.get_child_count()):
			var pip = p2_hull_container.get_child(i)
			pip.modulate = Color(1.0, 0.75, 0.2, 1.0) if i < hull else Color(0.3, 0.1, 0.1, 0.4)
	else:
		shield_bar.max_value = max_shields
		shield_bar.value = shields
		for i in range(hull_container.get_child_count()):
			var pip = hull_container.get_child(i)
			pip.modulate = Color(0.1, 1.0, 0.6, 1.0) if i < hull else Color(0.3, 0.1, 0.1, 0.4)

func _on_roll_charges_changed(charges: int, _max_charges: int, _cooldown_ratio: float) -> void:
	for i in range(roll_container.get_child_count()):
		var pip = roll_container.get_child(i)
		pip.modulate = Color(0.2, 0.9, 1.0, 1.0) if i < charges else Color(0.2, 0.4, 0.5, 0.3)

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

func _on_coop_button_pressed() -> void:
	GameManager.is_coop_mode = not GameManager.is_coop_mode
	_update_coop_button_text()
	p2_container.visible = GameManager.is_coop_mode
	
	var main = get_tree().current_scene
	if main and main.has_method("toggle_coop_player"):
		main.toggle_coop_player(GameManager.is_coop_mode)

func _update_axis_button_text() -> void:
	axis_button.text = "MODE: VERTICAL (9:16)" if GameAxis.is_vertical else "MODE: HORIZONTAL (16:9)"

func _update_coop_button_text() -> void:
	coop_button.text = "CO-OP: 2-PLAYER" if GameManager.is_coop_mode else "MODE: 1-PLAYER"

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
	
	choice_modal.modulate.a = 1.0
	choice_modal.visible = true
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
	choice_modal.visible = false
	get_tree().paused = false
	
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	
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
