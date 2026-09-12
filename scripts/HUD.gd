extends CanvasLayer

## HUD.gd - Responsive cyberpunk arcade HUD with health, shields, barrel rolls, score, Joules, Synergy Ribbon, Item Choice Modal, Boss Health Bar, and Co-Op status.

const ProgressionModel = preload("res://scripts/ProgressionModel.gd")

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

# Run Progression Telemetry & Debug Overlay
var debug_overlay: PanelContainer = null
var debug_text_label: RichTextLabel = null
var debug_button: Button = null
var is_debug_visible: bool = true
var debug_update_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.wipe_bonus_awarded.connect(_on_wipe_bonus_awarded)
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.player_roll_charges_changed.connect(_on_player_roll_charges_changed)
	GameManager.player_modifiers_updated.connect(_on_player_modifiers_updated)
	GameManager.boss_health_updated.connect(_on_boss_health_updated)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.secret_discovered.connect(_on_secret_discovered)
	GameManager.game_over_triggered.connect(_on_game_over)
	
	_connect_players()
	_setup_debug_overlay()
	
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
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			if p.player_id == 1:
				if not p.roll_charges_changed.is_connected(_on_roll_charges_changed):
					p.roll_charges_changed.connect(_on_roll_charges_changed)
				if not p.modifiers_updated.is_connected(_on_modifiers_updated):
					p.modifiers_updated.connect(_on_modifiers_updated)
				_on_roll_charges_changed(p.rolls, p.max_rolls, 0.0)
				_on_modifiers_updated(p.active_modifiers)

func _on_player_roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float, p_id: int) -> void:
	if p_id == 1:
		_on_roll_charges_changed(charges, max_charges, cooldown_ratio)

func _on_player_modifiers_updated(modifiers: Array, p_id: int) -> void:
	if p_id == 1:
		_on_modifiers_updated(modifiers)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.keycode == KEY_QUOTELEFT:
			toggle_debug_overlay()

func toggle_debug_overlay() -> void:
	is_debug_visible = not is_debug_visible
	if is_instance_valid(debug_overlay):
		debug_overlay.visible = is_debug_visible
	if is_instance_valid(debug_button):
		debug_button.text = "DBG: ON" if is_debug_visible else "DBG: OFF"
		debug_button.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0) if is_debug_visible else Color(0.6, 0.6, 0.6, 1.0))

func _setup_debug_overlay() -> void:
	# 1. Add [DBG] toggle button to TopCenter/HBox
	var top_hbox = get_node_or_null("TopCenter/HBox")
	if top_hbox:
		debug_button = Button.new()
		debug_button.name = "DebugButton"
		debug_button.text = "DBG: ON"
		debug_button.focus_mode = Control.FOCUS_NONE
		debug_button.add_theme_font_size_override("font_size", 11)
		debug_button.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
		if axis_button and axis_button.has_theme_stylebox("normal"):
			debug_button.add_theme_stylebox_override("normal", axis_button.get_theme_stylebox("normal"))
		top_hbox.add_child(debug_button)
		debug_button.pressed.connect(toggle_debug_overlay)

	# 2. Create Debug Overlay Panel Container at BottomLeft
	debug_overlay = PanelContainer.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.anchors_preset = Control.PRESET_BOTTOM_LEFT
	debug_overlay.anchor_left = 0.0
	debug_overlay.anchor_top = 1.0
	debug_overlay.anchor_right = 0.0
	debug_overlay.anchor_bottom = 1.0
	debug_overlay.offset_left = 20.0
	debug_overlay.offset_top = -155.0
	debug_overlay.offset_right = 440.0
	debug_overlay.offset_bottom = -15.0
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.07, 0.12, 0.88)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.18, 0.65, 0.85, 0.75)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 8
	debug_overlay.add_theme_stylebox_override("panel", panel_style)

	debug_text_label = RichTextLabel.new()
	debug_text_label.name = "DebugText"
	debug_text_label.bbcode_enabled = true
	debug_text_label.fit_content = true
	debug_text_label.scroll_active = false
	debug_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_text_label.add_theme_font_size_override("normal_font_size", 11)
	debug_overlay.add_child(debug_text_label)

	add_child(debug_overlay)
	debug_overlay.visible = is_debug_visible

func _update_debug_telemetry() -> void:
	if not is_debug_visible or not is_instance_valid(debug_text_label):
		return

	var sec = GameManager.current_sector
	var wave = GameManager.current_wave

	var p1: CharacterBody2D = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("player_id") == 1:
			p1 = p
			break

	var actual_relics = 0
	var t1_count = 0
	var t2_count = 0
	var t3_count = 0
	var current_dps = 7.6
	if is_instance_valid(p1):
		actual_relics = p1.active_modifiers.size()
		if p1.has_method("get_relic_counts_by_tier"):
			var counts = p1.get_relic_counts_by_tier()
			t1_count = counts.get(ItemModifier.ItemTier.TIER_1_BALLISTIC, 0)
			t2_count = counts.get(ItemModifier.ItemTier.TIER_2_PARADIGM, 0)
			t3_count = counts.get(ItemModifier.ItemTier.TIER_3_EXOTIC, 0)
		if p1.has_method("get_estimated_dps"):
			current_dps = p1.get_estimated_dps()

	var expected_range = ProgressionModel.get_expected_relics_range(sec, wave)
	var pacing_status = "[color=#00ff88]ON TRACK[/color]"
	if actual_relics > expected_range.y:
		pacing_status = "[color=#00e5ff]AHEAD (+%d)[/color]" % (actual_relics - expected_range.y)
	elif actual_relics < expected_range.x:
		pacing_status = "[color=#ffaa00]BEHIND (-%d)[/color]" % (expected_range.x - actual_relics)

	var target_dps = ProgressionModel.get_target_dps(sec, wave)
	var hp_mult = ProgressionModel.get_enemy_hp_multiplier(sec, wave)
	var next_shop = ProgressionModel.get_next_shop_wave(sec, wave)
	var total_w = (sec - 1) * 12 + ((wave - 1) % 12) + 1
	var shop_str = ("W%d (in %d)" % [next_shop, next_shop - total_w]) if next_shop > 0 else "All Visited"

	# Joules total collected vs expected total collected
	var exp_joules = ProgressionModel.get_expected_total_joules_range(sec, wave)
	var bonus_chance = p1.scrap_bonus_chance if p1 != null and "scrap_bonus_chance" in p1 else 0.0
	var wave_div = p1.wave_dividend_joules if p1 != null and "wave_dividend_joules" in p1 else 0
	if bonus_chance > 0.0:
		exp_joules.y = int(exp_joules.y * (1.0 + bonus_chance * 0.5))
	if wave_div > 0:
		exp_joules.y += wave_div * wave
	var total_j = GameManager.total_joules_collected
	var j_pacing = "[color=#00ff88]ON TRACK[/color]"
	if total_j > exp_joules.y:
		j_pacing = "[color=#00e5ff]AHEAD (+%d)[/color]" % (total_j - exp_joules.y)
	elif total_j < exp_joules.x:
		j_pacing = "[color=#ffaa00]BEHIND (-%d)[/color]" % (exp_joules.x - total_j)

	var active_enemies = get_tree().get_nodes_in_group("enemy").size()

	var txt = "[b][color=#00e5ff]TELEMETRY[/color] [color=#667788](Toggle: F3 / [DBG])[/color][/b]\n"
	txt += "• [b]Relics:[/b] %d [color=#8899aa](T1:%d|T2:%d|T3:%d)[/color] vs Exp: %d-%d %s\n" % [
		actual_relics, t1_count, t2_count, t3_count, expected_range.x, expected_range.y, pacing_status
	]
	txt += "• [b]DPS:[/b] %.1f vs Target: %.1f [color=#8899aa]| HP Scaler: %.2fx[/color]\n" % [
		current_dps, target_dps, hp_mult
	]
	txt += "• [b]Joules:[/b] %d J | [b]Total:[/b] %d vs Exp: %d-%d %s [color=#8899aa]| Next: %s[/color]\n" % [
		GameManager.scrap_joules, total_j, exp_joules.x, exp_joules.y, j_pacing, shop_str
	]
	txt += "• [b]Threat:[/b] %d hostiles [color=#8899aa]| Wipe Streak: %d/3[/color]" % [
		active_enemies, GameManager.consecutive_wipes
	]

	debug_text_label.text = txt

func _process(delta: float) -> void:
	if display_score < target_score:
		var step = maxi(10, int((target_score - display_score) * 0.15))
		display_score = mini(target_score, display_score + step)
		score_label.text = "SCORE: " + str(display_score).pad_zeros(6)
	
	if GameManager.is_coop_mode:
		joules_label.text = "P1: %d J | P2: %d J" % [GameManager.p1_joules, GameManager.p2_joules]
	else:
		joules_label.text = "JOULES: " + str(GameManager.scrap_joules) + " J"
	
	wave_label.text = "SEC %d | WAVE %d" % [GameManager.current_sector, GameManager.current_wave]
	wipes_label.text = "WIPES: " + str(GameManager.wipe_count)
	
	if banner_timer > 0.0:
		banner_timer -= delta
		wipe_banner.modulate.a = clampf(banner_timer / 0.5, 0.0, 1.0)

	if warp_countdown_active:
		warp_countdown_time -= delta
		if warp_countdown_time > 0.0:
			var col = Color(1.0, 0.85, 0.2, 1.0) if warp_is_wipe else Color(0.2, 0.95, 1.0, 1.0)
			wipe_banner.text = "%s\n%s\n[ QUANTUM TELEPORT IN %.1fs ]" % [warp_countdown_title, warp_countdown_desc, warp_countdown_time]
			wipe_banner.modulate = col
			banner_timer = 1.0
		else:
			on_quantum_warp_started()

	debug_update_timer -= delta
	if debug_update_timer <= 0.0:
		debug_update_timer = 0.1
		_update_debug_telemetry()

func _on_score_changed(new_score: int, _delta: int) -> void:
	target_score = new_score

func _on_wipe_bonus_awarded(_bonus: int, message: String) -> void:
	_show_banner(message, Color(1.0, 0.85, 0.2, 1.0))

func _on_secret_discovered(name: String, _bonus: int) -> void:
	_show_banner("SECRET: " + name, Color(0.3, 1.0, 0.8, 1.0))

var warp_countdown_active: bool = false
var warp_countdown_time: float = 0.0
var warp_countdown_title: String = ""
var warp_countdown_desc: String = ""
var warp_is_wipe: bool = false

func show_wave_cleared_banner(title: String, reason: String, is_wipe: bool, duration: float = 5.0) -> void:
	warp_countdown_active = true
	warp_countdown_time = duration
	warp_countdown_title = title
	warp_countdown_desc = reason
	warp_is_wipe = is_wipe
	var col = Color(1.0, 0.85, 0.2, 1.0) if is_wipe else Color(0.2, 0.95, 1.0, 1.0)
	_show_banner("%s\n%s\n[ QUANTUM TELEPORT IN %.1fs ]" % [title, reason, warp_countdown_time], col)
	banner_timer = duration + 0.5

func on_quantum_warp_started() -> void:
	warp_countdown_active = false
	_show_banner("[ QUANTUM TELEPORT ENGAGED ]", Color(0.3, 1.0, 0.8, 1.0))
	banner_timer = 0.8

func show_wave_incoming_banner(wave_num: int, wave_name: String) -> void:
	warp_countdown_active = false
	_show_banner("[ ENTERING WAVE %d: %s ]" % [wave_num, wave_name], Color(0.2, 0.95, 1.0, 1.0))
	banner_timer = 2.4

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
	var container = p2_hull_container if p_id == 2 else hull_container
	var s_bar = p2_shield_bar if p_id == 2 else shield_bar
	var active_color = Color(1.0, 0.75, 0.2, 1.0) if p_id == 2 else Color(0.1, 1.0, 0.6, 1.0)
	
	s_bar.max_value = max_shields
	s_bar.value = shields
	
	while container.get_child_count() < max_hull:
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 12)
		container.add_child(pip)
	while container.get_child_count() > max_hull:
		var last = container.get_child(container.get_child_count() - 1)
		container.remove_child(last)
		last.queue_free()
	
	for i in range(container.get_child_count()):
		var pip = container.get_child(i)
		pip.color = Color.WHITE
		pip.modulate = active_color if i < hull else Color(0.3, 0.1, 0.1, 0.4)

func _on_roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float) -> void:
	while roll_container.get_child_count() < max_charges:
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 9)
		roll_container.add_child(pip)
	while roll_container.get_child_count() > max_charges:
		var last = roll_container.get_child(roll_container.get_child_count() - 1)
		roll_container.remove_child(last)
		last.queue_free()

	for i in range(roll_container.get_child_count()):
		var pip = roll_container.get_child(i)
		pip.color = Color.WHITE
		if i < charges:
			pip.modulate = Color(0.2, 0.9, 1.0, 1.0)
		elif i == charges and cooldown_ratio > 0.0:
			pip.modulate = Color(0.2, 0.9, 1.0, lerpf(0.25, 0.85, cooldown_ratio))
		else:
			pip.modulate = Color(0.15, 0.35, 0.45, 0.25)

func _on_modifiers_updated(modifiers: Array) -> void:
	for child in synergy_ribbon.get_children():
		child.queue_free()
	
	for mod in modifiers:
		if not is_instance_valid(mod):
			continue
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
	if GameManager != null and GameManager.is_game_over:
		return
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var living_player: Node2D = null
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.get("hull") != null and p.hull > 0:
			living_player = p
			break
	if living_player == null:
		return
	var player = living_player
	var sec = GameManager.current_sector if GameManager != null else 1
	
	var item_a = ProgressionModel.select_weighted_item(player, sec)
	var exclude_b: Array[String] = []
	if item_a != null:
		exclude_b.append(item_a.id)
	var item_b = ProgressionModel.select_weighted_item(player, sec, -1, "", exclude_b)
	
	if item_a == null and item_b == null:
		return
	
	current_choice_a = item_a if item_a != null else item_b
	current_choice_b = item_b if item_b != null else item_a
	
	_populate_card(current_choice_a, title_a, tier_a, desc_a)
	_populate_card(current_choice_b, title_b, tier_b, desc_b)
	
	choice_modal.modulate.a = 1.0
	choice_modal.visible = true
	get_tree().paused = true

func dismiss_item_choice_modal() -> void:
	if choice_modal:
		choice_modal.visible = false
	if get_tree().paused:
		get_tree().paused = false
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

func _on_game_over(_score: int, _wipes: int, _time: float) -> void:
	dismiss_item_choice_modal()

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
	dismiss_item_choice_modal()
	
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.get("hull") != null and p.hull > 0:
			p.add_modifier(item)
			_on_modifiers_updated(p.active_modifiers)
			break

# Mobile Touch Button handlers
func _on_fire_button_down() -> void:
	Input.action_press("fire")

func _on_fire_button_up() -> void:
	Input.action_release("fire")

func _on_roll_button_pressed() -> void:
	Input.action_press("barrel_roll")
	get_tree().create_timer(0.05).timeout.connect(func(): Input.action_release("barrel_roll"))
