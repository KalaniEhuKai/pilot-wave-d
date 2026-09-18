extends CanvasLayer

## HUD.gd - Responsive cyberpunk arcade HUD with health, shields, barrel rolls, score, Joules, Synergy Ribbon, Item Choice Modal, Boss Health Bar, and Co-Op status.

const ProgressionModel = preload("res://scripts/ProgressionModel.gd")
const MenuStyleHelper = preload("res://scripts/MenuStyleHelper.gd")

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
@onready var shield_container: HBoxContainer = $TopLeft/VBox/ShieldContainer
@onready var hull_container: HBoxContainer = $TopLeft/VBox/HullContainer
@onready var roll_container: HBoxContainer = $TopLeft/VBox/RollContainer
@onready var synergy_ribbon: HBoxContainer = $TopLeft/VBox/SynergyRibbon

# P2 UI (Co-Op)
@onready var p2_container: VBoxContainer = $TopLeft/VBox/P2Container
@onready var p2_shield_container: HBoxContainer = $TopLeft/VBox/P2Container/P2ShieldContainer
@onready var p2_hull_container: HBoxContainer = $TopLeft/VBox/P2Container/P2HullContainer

# Backward-compatibility alias
var shield_bar: Control:
	get: return shield_container
var p2_shield_bar: Control:
	get: return p2_shield_container

var hull_vignette_timer: float = 0.0

# Item Choice Modal
@onready var choice_modal: Control = $ItemChoiceModal
@onready var modal_panel: Panel = $ItemChoiceModal/Panel
@onready var modal_header: Label = $ItemChoiceModal/Panel/VBox/Header
@onready var p1_column: VBoxContainer = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column
@onready var p2_column: VBoxContainer = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column
@onready var p1_header: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Header
@onready var p2_header: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Header
@onready var p1_status_lbl: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Status
@onready var p2_status_lbl: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Status

@onready var card_a: Panel = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardA
@onready var card_b: Panel = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardB
@onready var choice_btn_a: Button = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardA/EquipBtnA
@onready var choice_btn_b: Button = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardB/EquipBtnB
@onready var title_a: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardA/TitleA
@onready var title_b: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardB/TitleB
@onready var desc_a: Control = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardA/DescA
@onready var desc_b: Control = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardB/DescB
@onready var tier_a: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardA/TierA
@onready var tier_b: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P1Column/P1Cards/CardB/TierB

@onready var p2_card_a: Panel = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardA
@onready var p2_card_b: Panel = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardB
@onready var p2_choice_btn_a: Button = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardA/P2EquipBtnA
@onready var p2_choice_btn_b: Button = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardB/P2EquipBtnB
@onready var p2_title_a: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardA/P2TitleA
@onready var p2_title_b: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardB/P2TitleB
@onready var p2_desc_a: Control = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardA/P2DescA
@onready var p2_desc_b: Control = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardB/P2DescB
@onready var p2_tier_a: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardA/P2TierA
@onready var p2_tier_b: Label = $ItemChoiceModal/Panel/VBox/HBoxColumns/P2Column/P2Cards/P2CardB/P2TierB

var current_choice_a: ItemModifier = null
var current_choice_b: ItemModifier = null
var p2_current_choice_a: ItemModifier = null
var p2_current_choice_b: ItemModifier = null

var p1_selected_idx: int = 0
var p2_selected_idx: int = 0
var p1_confirmed: bool = false
var p2_confirmed: bool = false
var p1_chosen_item: ItemModifier = null
var p2_chosen_item: ItemModifier = null

var display_score: int = 0
var target_score: int = 0
var banner_timer: float = 0.0

# Run Progression Telemetry & Debug Overlay
var debug_overlay: PanelContainer = null
var debug_text_label: RichTextLabel = null
var debug_button: Button = null
var is_debug_visible: bool = true
var debug_update_timer: float = 0.0
var holo_overlay: HoloCyberOverlay = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.wipe_bonus_awarded.connect(_on_wipe_bonus_awarded)
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.player_roll_charges_changed.connect(_on_player_roll_charges_changed)
	GameManager.player_shield_charges_changed.connect(_on_player_shield_charges_changed)
	GameManager.player_modifiers_updated.connect(_on_player_modifiers_updated)
	GameManager.boss_health_updated.connect(_on_boss_health_updated)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.secret_discovered.connect(_on_secret_discovered)
	GameManager.game_over_triggered.connect(_on_game_over)
	if GameManager.has_signal("player_hull_damaged"):
		GameManager.player_hull_damaged.connect(_on_player_hull_damaged)
	
	_connect_players()
	_setup_debug_overlay()
	
	holo_overlay = HoloCyberOverlay.new()
	holo_overlay.name = "HoloCyberOverlay"
	holo_overlay.hud_ref = self
	add_child(holo_overlay)
	move_child(holo_overlay, 0)
	
	axis_button.pressed.connect(_on_axis_button_pressed)
	coop_button.pressed.connect(_on_coop_button_pressed)
	_update_axis_button_text()
	_update_coop_button_text()
	
	GameAxis.axis_changed.connect(func(_v): _update_axis_button_text())
	
	choice_btn_a.pressed.connect(func(): _confirm_p1_choice(0))
	choice_btn_b.pressed.connect(func(): _confirm_p1_choice(1))
	p2_choice_btn_a.pressed.connect(func(): _confirm_p2_choice(0))
	p2_choice_btn_b.pressed.connect(func(): _confirm_p2_choice(1))
	
	choice_btn_a.focus_entered.connect(_on_choice_btn_a_focus_entered)
	choice_btn_b.focus_entered.connect(_on_choice_btn_b_focus_entered)
	choice_btn_a.mouse_entered.connect(_on_choice_btn_a_mouse_entered)
	choice_btn_b.mouse_entered.connect(_on_choice_btn_b_mouse_entered)
	
	p2_choice_btn_a.focus_entered.connect(_on_p2_choice_btn_a_focus_entered)
	p2_choice_btn_b.focus_entered.connect(_on_p2_choice_btn_b_focus_entered)
	p2_choice_btn_a.mouse_entered.connect(_on_p2_choice_btn_a_mouse_entered)
	p2_choice_btn_b.mouse_entered.connect(_on_p2_choice_btn_b_mouse_entered)
	
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
				if not p.shield_charges_changed.is_connected(_on_shield_charges_changed):
					p.shield_charges_changed.connect(_on_shield_charges_changed)
				if not p.modifiers_updated.is_connected(_on_modifiers_updated):
					p.modifiers_updated.connect(_on_modifiers_updated)
				_on_roll_charges_changed(p.rolls, p.max_rolls, 0.0)
				_update_shield_pips(p.shields, p.max_shields, 0.0, 1)
				_on_modifiers_updated(p.active_modifiers)

func _on_player_roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float, p_id: int) -> void:
	if p_id == 1:
		_on_roll_charges_changed(charges, max_charges, cooldown_ratio)

func _on_player_shield_charges_changed(s_count: int, s_max: int, s_ratio: float, p_id: int) -> void:
	_update_shield_pips(s_count, s_max, s_ratio, p_id)

func _on_shield_charges_changed(s_count: int, s_max: int, s_ratio: float) -> void:
	_update_shield_pips(s_count, s_max, s_ratio, 1)

func _on_player_modifiers_updated(modifiers: Array, p_id: int) -> void:
	if p_id == 1:
		_on_modifiers_updated(modifiers)

func _input(event: InputEvent) -> void:
	if choice_modal and choice_modal.visible:
		# Let mouse button clicks reach buttons naturally without being consumed
		if event is InputEventMouseButton:
			return
		
		# P1 Controls (WASD / Space / 1 / 2 / Gamepad)
		if not p1_confirmed:
			if event.is_action_pressed("move_left") or (not GameManager.is_coop_mode and event.is_action_pressed("ui_left")):
				_select_p1_idx(0)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("move_right") or (not GameManager.is_coop_mode and event.is_action_pressed("ui_right")):
				_select_p1_idx(1)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("fire") or (not GameManager.is_coop_mode and event.is_action_pressed("ui_accept")):
				_confirm_p1_choice(p1_selected_idx)
				get_viewport().set_input_as_handled()
				return
			elif event is InputEventKey and event.pressed and not event.echo:
				if event.keycode == KEY_1:
					_confirm_p1_choice(0)
					get_viewport().set_input_as_handled()
					return
				elif event.keycode == KEY_2:
					_confirm_p1_choice(1)
					get_viewport().set_input_as_handled()
					return
		
		# P2 Controls (Arrow Keys / Enter / Numpad 1 / 2)
		if GameManager.is_coop_mode and not p2_confirmed:
			if event.is_action_pressed("p2_move_left"):
				_select_p2_idx(0)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("p2_move_right"):
				_select_p2_idx(1)
				get_viewport().set_input_as_handled()
				return
			elif event.is_action_pressed("p2_fire"):
				_confirm_p2_choice(p2_selected_idx)
				get_viewport().set_input_as_handled()
				return
			elif event is InputEventKey and event.pressed and not event.echo:
				if event.keycode == KEY_KP_1:
					_confirm_p2_choice(0)
					get_viewport().set_input_as_handled()
					return
				elif event.keycode == KEY_KP_2:
					_confirm_p2_choice(1)
					get_viewport().set_input_as_handled()
					return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.keycode == KEY_QUOTELEFT:
			toggle_debug_overlay()
			return

func _select_p1_idx(idx: int) -> void:
	if p1_confirmed:
		return
	var changed = (p1_selected_idx != idx)
	p1_selected_idx = idx
	if changed:
		SoundEffects.play_sfx("ui_hover", 0.05, -4.0)
	_update_modal_visuals()
	var target_btn = choice_btn_a if idx == 0 else choice_btn_b
	if is_instance_valid(target_btn) and target_btn.is_inside_tree():
		if target_btn.focus_mode != Control.FOCUS_NONE and not target_btn.has_focus():
			target_btn.grab_focus()

func _select_p2_idx(idx: int) -> void:
	if p2_confirmed:
		return
	var changed = (p2_selected_idx != idx)
	p2_selected_idx = idx
	if changed:
		SoundEffects.play_sfx("ui_hover", 0.05, -4.0)
	_update_modal_visuals()
	var target_btn = p2_choice_btn_a if idx == 0 else p2_choice_btn_b
	if is_instance_valid(target_btn) and target_btn.is_inside_tree():
		if target_btn.focus_mode != Control.FOCUS_NONE and not target_btn.has_focus():
			target_btn.grab_focus()

func _on_choice_btn_a_focus_entered() -> void:
	if choice_modal and choice_modal.visible and not p1_confirmed and p1_selected_idx != 0:
		_select_p1_idx(0)

func _on_choice_btn_b_focus_entered() -> void:
	if choice_modal and choice_modal.visible and not p1_confirmed and p1_selected_idx != 1:
		_select_p1_idx(1)

func _on_choice_btn_a_mouse_entered() -> void:
	if choice_modal and choice_modal.visible and not p1_confirmed and p1_selected_idx != 0:
		_select_p1_idx(0)

func _on_choice_btn_b_mouse_entered() -> void:
	if choice_modal and choice_modal.visible and not p1_confirmed and p1_selected_idx != 1:
		_select_p1_idx(1)

func _on_p2_choice_btn_a_focus_entered() -> void:
	if choice_modal and choice_modal.visible and GameManager.is_coop_mode and not p2_confirmed and p2_selected_idx != 0:
		_select_p2_idx(0)

func _on_p2_choice_btn_b_focus_entered() -> void:
	if choice_modal and choice_modal.visible and GameManager.is_coop_mode and not p2_confirmed and p2_selected_idx != 1:
		_select_p2_idx(1)

func _on_p2_choice_btn_a_mouse_entered() -> void:
	if choice_modal and choice_modal.visible and GameManager.is_coop_mode and not p2_confirmed and p2_selected_idx != 0:
		_select_p2_idx(0)

func _on_p2_choice_btn_b_mouse_entered() -> void:
	if choice_modal and choice_modal.visible and GameManager.is_coop_mode and not p2_confirmed and p2_selected_idx != 1:
		_select_p2_idx(1)

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

	var txt = "[b][color=#00e5ff]TELEMETRY[/color] [color=#667788](Toggle: F3 / [DBG])[/color][/b]"
	if GameManager != null and not GameManager.telemetry_enabled:
		txt += " [b][color=#ff3366][DISABLED - DEBUG RUN][/color][/b]"
	txt += "\n"
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

	if hull_vignette_timer > 0.0:
		hull_vignette_timer -= delta

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

func _on_player_hull_damaged(_p_id: int, _hull: int, _max_hull: int) -> void:
	hull_vignette_timer = 0.35

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

func _update_shield_pips(shields: int, max_shields: int, cooldown_ratio: float, p_id: int) -> void:
	var s_container = p2_shield_container if p_id == 2 else shield_container
	var shield_color = Color(1.0, 0.75, 0.2, 1.0) if p_id == 2 else Color(0.15, 0.85, 1.0, 1.0)
	if not is_instance_valid(s_container):
		return
	while s_container.get_child_count() < max_shields:
		var s_pip = ColorRect.new()
		s_pip.custom_minimum_size = Vector2(24, 8)
		s_pip.clip_contents = true
		s_container.add_child(s_pip)
	while s_container.get_child_count() > max_shields:
		var last_s = s_container.get_child(s_container.get_child_count() - 1)
		s_container.remove_child(last_s)
		last_s.queue_free()
	
	for i in range(s_container.get_child_count()):
		var s_pip = s_container.get_child(i)
		s_pip.clip_contents = true
		var fill = s_pip.get_node_or_null("Fill") as ColorRect
		if not fill:
			fill = ColorRect.new()
			fill.name = "Fill"
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_pip.add_child(fill)
		
		if i < shields:
			s_pip.color = Color.WHITE
			s_pip.modulate = shield_color
			fill.size = Vector2(24, 8)
			fill.color = Color.WHITE
		elif i == shields and shields < max_shields:
			s_pip.color = Color(0.28, 0.46, 0.62, 0.48)
			s_pip.modulate = Color(shield_color.r * 0.6, shield_color.g * 0.7, shield_color.b * 0.85, 0.48)
			var fill_w = clampf(cooldown_ratio * 24.0, 0.0, 24.0)
			fill.size = Vector2(fill_w, 8)
			fill.color = Color.WHITE
		else:
			s_pip.color = Color(0.28, 0.46, 0.62, 0.48)
			s_pip.modulate = Color(0.28, 0.46, 0.62, 0.48)
			fill.size = Vector2(0, 8)

func _on_health_changed(hull: int, shields: int, max_hull: int, max_shields: int, p_id: int) -> void:
	var h_container = p2_hull_container if p_id == 2 else hull_container
	var hull_color = Color(1.0, 0.75, 0.2, 1.0) if p_id == 2 else Color(0.1, 1.0, 0.6, 1.0)
	
	_update_shield_pips(shields, max_shields, 0.0, p_id)

	# Update discrete hull pips
	if is_instance_valid(h_container):
		while h_container.get_child_count() < max_hull:
			var pip = ColorRect.new()
			pip.custom_minimum_size = Vector2(24, 8)
			h_container.add_child(pip)
		while h_container.get_child_count() > max_hull:
			var last = h_container.get_child(h_container.get_child_count() - 1)
			h_container.remove_child(last)
			last.queue_free()
		
		for i in range(h_container.get_child_count()):
			var pip = h_container.get_child(i)
			pip.color = Color.WHITE
			pip.modulate = hull_color if i < hull else Color(0.3, 0.1, 0.1, 0.4)


func _on_roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float) -> void:
	while roll_container.get_child_count() < max_charges:
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 9)
		pip.clip_contents = true
		roll_container.add_child(pip)
	while roll_container.get_child_count() > max_charges:
		var last = roll_container.get_child(roll_container.get_child_count() - 1)
		roll_container.remove_child(last)
		last.queue_free()

	for i in range(roll_container.get_child_count()):
		var pip = roll_container.get_child(i)
		pip.clip_contents = true
		var fill = pip.get_node_or_null("Fill") as ColorRect
		if not fill:
			fill = ColorRect.new()
			fill.name = "Fill"
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.add_child(fill)
		
		if i < charges:
			pip.color = Color.WHITE
			pip.modulate = Color(0.2, 0.9, 1.0, 1.0)
			fill.size = Vector2(16, 9)
			fill.color = Color.WHITE
		elif i == charges and cooldown_ratio > 0.0:
			pip.color = Color(0.26, 0.45, 0.60, 0.45)
			pip.modulate = Color(0.12, 0.55, 0.80, 0.55)
			var fill_w = clampf(cooldown_ratio * 16.0, 0.0, 16.0)
			fill.size = Vector2(fill_w, 9)
			fill.color = Color.WHITE
		else:
			pip.color = Color(0.26, 0.45, 0.60, 0.45)
			pip.modulate = Color(0.26, 0.45, 0.60, 0.45)
			fill.size = Vector2(0, 9)

func _on_modifiers_updated(modifiers: Array) -> void:
	for child in synergy_ribbon.get_children():
		child.queue_free()
	
	for mod in modifiers:
		if not is_instance_valid(mod):
			continue
		var badge = Label.new()
		badge.text = mod.get_glyph() if mod.has_method("get_glyph") else mod.icon_symbol
		badge.tooltip_text = mod.display_name + ": " + mod.description
		badge.add_theme_color_override("font_color", mod.icon_color)
		badge.add_theme_font_size_override("font_size", 16)
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
	var p1: CharacterBody2D = null
	var p2: CharacterBody2D = null
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			if p.player_id == 1 and p.get("hull") != null and p.hull > 0:
				p1 = p
			elif p.player_id == 2 and p.get("hull") != null and p.hull > 0:
				p2 = p
	
	if p1 == null and p2 == null:
		return
	
	var sec = GameManager.current_sector if GameManager != null else 1
	var is_coop = GameManager.is_coop_mode and p2 != null
	
	if not is_coop:
		p2_column.visible = false
		modal_panel.custom_minimum_size = Vector2(640, 380)
		modal_header.text = "QUANTUM RELIC DISCOVERED // SELECT SYNERGY"
		p1_header.text = "CHOOSE SYNERGY // [A / D] SELECT • [SPACE / ENTER] EQUIP"
		p2_confirmed = true
	else:
		p2_column.visible = true
		modal_panel.custom_minimum_size = Vector2(980, 440)
		modal_header.text = "QUANTUM RELIC DISCOVERED // DUAL SYNERGY DEPLOYMENT"
		p1_header.text = "PLAYER 1 // [A / D] SELECT • [SPACE] EQUIP"
		p2_header.text = "PLAYER 2 // [◄ / ►] SELECT • [ENTER] EQUIP"
		p2_confirmed = false
	
	# Generate P1 items
	var p1_target = p1 if p1 != null else p2
	var item_a = ProgressionModel.select_weighted_item(p1_target, sec)
	var exclude_b: Array[String] = []
	if item_a != null:
		exclude_b.append(item_a.id)
	var item_b = ProgressionModel.select_weighted_item(p1_target, sec, -1, "", exclude_b)
	
	current_choice_a = item_a if item_a != null else item_b
	current_choice_b = item_b if item_b != null else item_a
	
	_populate_card(current_choice_a, title_a, tier_a, desc_a, card_a, p1_target)
	_populate_card(current_choice_b, title_b, tier_b, desc_b, card_b, p1_target)
	
	# Generate P2 items if co-op
	if is_coop and p2 != null:
		var p2_item_a = ProgressionModel.select_weighted_item(p2, sec)
		var p2_exclude_b: Array[String] = []
		if p2_item_a != null:
			p2_exclude_b.append(p2_item_a.id)
		var p2_item_b = ProgressionModel.select_weighted_item(p2, sec, -1, "", p2_exclude_b)
		p2_current_choice_a = p2_item_a if p2_item_a != null else p2_item_b
		p2_current_choice_b = p2_item_b if p2_item_b != null else p2_item_a
		_populate_card(p2_current_choice_a, p2_title_a, p2_tier_a, p2_desc_a, p2_card_a, p2)
		_populate_card(p2_current_choice_b, p2_title_b, p2_tier_b, p2_desc_b, p2_card_b, p2)
	
	p1_selected_idx = 0
	p2_selected_idx = 0
	p1_confirmed = (p1 == null)
	p1_chosen_item = null
	p2_chosen_item = null
	
	# Explicit focus wrapping within cards & isolation between columns
	choice_btn_a.focus_neighbor_left = choice_btn_b.get_path()
	choice_btn_a.focus_neighbor_right = choice_btn_b.get_path()
	choice_btn_a.focus_neighbor_top = choice_btn_a.get_path()
	choice_btn_a.focus_neighbor_bottom = choice_btn_a.get_path()
	
	choice_btn_b.focus_neighbor_left = choice_btn_a.get_path()
	choice_btn_b.focus_neighbor_right = choice_btn_a.get_path()
	choice_btn_b.focus_neighbor_top = choice_btn_b.get_path()
	choice_btn_b.focus_neighbor_bottom = choice_btn_b.get_path()
	
	p2_choice_btn_a.focus_neighbor_left = p2_choice_btn_b.get_path()
	p2_choice_btn_a.focus_neighbor_right = p2_choice_btn_b.get_path()
	p2_choice_btn_a.focus_neighbor_top = p2_choice_btn_a.get_path()
	p2_choice_btn_a.focus_neighbor_bottom = p2_choice_btn_a.get_path()
	
	p2_choice_btn_b.focus_neighbor_left = p2_choice_btn_a.get_path()
	p2_choice_btn_b.focus_neighbor_right = p2_choice_btn_a.get_path()
	p2_choice_btn_b.focus_neighbor_top = p2_choice_btn_b.get_path()
	p2_choice_btn_b.focus_neighbor_bottom = p2_choice_btn_b.get_path()
	
	_update_modal_visuals()
	choice_btn_a.grab_focus()
	
	choice_modal.modulate.a = 1.0
	choice_modal.visible = true
	get_tree().paused = true
	SoundEffects.play_sfx("bonus", 0.05, 3.0)

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

func _populate_card(item: ItemModifier, t_lbl: Label, tier_lbl: Label, d_lbl: Control, card_panel: Panel = null, player: CharacterBody2D = null) -> void:
	if item == null:
		return
	var glyph = item.get_glyph() if item.has_method("get_glyph") else item.icon_symbol
	t_lbl.text = "%s  %s" % [glyph, item.display_name]
	t_lbl.add_theme_color_override("font_color", item.icon_color)
	
	var border_col = Color(0.2, 0.7, 0.9, 0.7)
	match item.tier:
		ItemModifier.ItemTier.TIER_1_BALLISTIC:
			tier_lbl.text = "TIER 1 - BALLISTIC MODIFIER"
			tier_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
			border_col = Color(0.2, 0.7, 0.9, 0.7)
		ItemModifier.ItemTier.TIER_2_PARADIGM:
			tier_lbl.text = "TIER 2 - WEAPON PARADIGM"
			tier_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.6, 1.0))
			border_col = Color(0.95, 0.35, 0.85, 0.85)
		ItemModifier.ItemTier.TIER_3_EXOTIC:
			tier_lbl.text = "TIER 3 - EXOTIC RELIC"
			tier_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			border_col = Color(1.0, 0.85, 0.2, 1.0)
	
	if d_lbl is RichTextLabel:
		d_lbl.text = ProgressionModel.format_card_bbcode(item, player)
	else:
		d_lbl.text = item.description
	
	# Apply dynamic tier border aura to card panel
	if card_panel != null:
		var sb: StyleBoxFlat
		var orig = card_panel.get_theme_stylebox("panel")
		if orig is StyleBoxFlat:
			sb = orig.duplicate()
		else:
			sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.03, 0.06, 0.12, 0.9)
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_right = 6
			sb.corner_radius_bottom_left = 6
		sb.border_color = border_col
		sb.border_width_left = 2 if item.tier >= ItemModifier.ItemTier.TIER_2_PARADIGM else 1
		sb.border_width_top = 2 if item.tier >= ItemModifier.ItemTier.TIER_2_PARADIGM else 1
		sb.border_width_right = 2 if item.tier >= ItemModifier.ItemTier.TIER_2_PARADIGM else 1
		sb.border_width_bottom = 2 if item.tier >= ItemModifier.ItemTier.TIER_2_PARADIGM else 1
		card_panel.add_theme_stylebox_override("panel", sb)

func _update_modal_visuals() -> void:
	var cyan = Color(0.1, 0.95, 1.0, 1.0)
	var gold = Color(1.0, 0.85, 0.2, 1.0)
	var dim = Color(0.3, 0.4, 0.5, 0.6)
	
	# P1 Visuals
	if p1_confirmed:
		choice_btn_a.disabled = true
		choice_btn_b.disabled = true
		var item_name = p1_chosen_item.display_name if p1_chosen_item else "SYNCHRONIZED"
		p1_status_lbl.text = "[✓] P1 SYNCHRONIZED: %s" % item_name.to_upper()
		p1_status_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.6, 1.0))
	else:
		choice_btn_a.disabled = false
		choice_btn_b.disabled = false
		p1_status_lbl.text = "[●] P1 PENDING SELECTION"
		p1_status_lbl.add_theme_color_override("font_color", cyan)
		if p1_selected_idx == 0:
			choice_btn_a.text = "► EQUIP [SPACE] ◄"
			choice_btn_b.text = "[2] EQUIP"
			MenuStyleHelper.style_button(choice_btn_a, cyan)
			MenuStyleHelper.style_button(choice_btn_b, dim)
		else:
			choice_btn_a.text = "[1] EQUIP"
			choice_btn_b.text = "► EQUIP [SPACE] ◄"
			MenuStyleHelper.style_button(choice_btn_a, dim)
			MenuStyleHelper.style_button(choice_btn_b, cyan)
	
	# P2 Visuals
	if GameManager.is_coop_mode:
		if p2_confirmed:
			p2_choice_btn_a.disabled = true
			p2_choice_btn_b.disabled = true
			var p2_name = p2_chosen_item.display_name if p2_chosen_item else "SYNCHRONIZED"
			p2_status_lbl.text = "[✓] P2 SYNCHRONIZED: %s" % p2_name.to_upper()
			p2_status_lbl.add_theme_color_override("font_color", Color(0.1, 1.0, 0.6, 1.0))
		else:
			p2_choice_btn_a.disabled = false
			p2_choice_btn_b.disabled = false
			p2_status_lbl.text = "[●] P2 PENDING SELECTION"
			p2_status_lbl.add_theme_color_override("font_color", gold)
			if p2_selected_idx == 0:
				p2_choice_btn_a.text = "► EQUIP [ENTER] ◄"
				p2_choice_btn_b.text = "[NUM 2] EQUIP"
				MenuStyleHelper.style_button(p2_choice_btn_a, gold)
				MenuStyleHelper.style_button(p2_choice_btn_b, dim)
			else:
				p2_choice_btn_a.text = "[NUM 1] EQUIP"
				p2_choice_btn_b.text = "► EQUIP [ENTER] ◄"
				MenuStyleHelper.style_button(p2_choice_btn_a, dim)
				MenuStyleHelper.style_button(p2_choice_btn_b, gold)

func _confirm_p1_choice(idx: int) -> void:
	if p1_confirmed:
		return
	p1_selected_idx = idx
	p1_chosen_item = current_choice_a if idx == 0 else current_choice_b
	p1_confirmed = true
	SoundEffects.play_sfx("ui_select", 0.05, 0.0)
	_update_modal_visuals()
	_check_modal_completion()

func _confirm_p2_choice(idx: int) -> void:
	if p2_confirmed:
		return
	p2_selected_idx = idx
	p2_chosen_item = p2_current_choice_a if idx == 0 else p2_current_choice_b
	p2_confirmed = true
	SoundEffects.play_sfx("ui_select", 0.05, 0.0)
	_update_modal_visuals()
	_check_modal_completion()

func _check_modal_completion() -> void:
	if p1_confirmed and p2_confirmed:
		dismiss_item_choice_modal()
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and not p.is_queued_for_deletion():
				if p.player_id == 1 and p1_chosen_item:
					p.add_modifier(p1_chosen_item)
					_on_modifiers_updated(p.active_modifiers)
				elif p.player_id == 2 and p2_chosen_item:
					p.add_modifier(p2_chosen_item)

func _select_choice(item: ItemModifier) -> void:
	_confirm_p1_choice(0 if item == current_choice_a else 1)



# Mobile Touch Button handlers
func _on_fire_button_down() -> void:
	Input.action_press("fire")

func _on_fire_button_up() -> void:
	Input.action_release("fire")

func _on_roll_button_pressed() -> void:
	Input.action_press("barrel_roll")
	get_tree().create_timer(0.05).timeout.connect(func(): Input.action_release("barrel_roll"))

# --- Holographic Cyberpunk HUD Overlay ---

class HoloCyberOverlay extends Control:
	var hud_ref: Node = null
	var active_lock_count: int = 0
	
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchors_preset = Control.PRESET_FULL_RECT
		
	func _process(_delta: float) -> void:
		queue_redraw()

	func get_active_lock_targets() -> Array:
		var targets = []
		var enemies = get_tree().get_nodes_in_group("enemy")
		for en in enemies:
			if is_instance_valid(en) and not en.is_queued_for_deletion():
				if en.get("is_elite") == true or en.get("is_boss") == true or en.get("is_miniboss") == true:
					targets.append(en)
		var bosses = get_tree().get_nodes_in_group("boss")
		for b in bosses:
			if is_instance_valid(b) and not b.is_queued_for_deletion() and not (b in targets):
				targets.append(b)
		return targets

		
	func _draw() -> void:
		var vp = get_viewport_rect().size
		if vp.x <= 0 or vp.y <= 0:
			return
			
		var cyan_dim = Color(0.15, 0.85, 1.0, 0.35)
		var cyan_bright = Color(0.2, 0.95, 1.0, 0.9)
		var amber_warning = Color(1.0, 0.75, 0.15, 0.85)
		var red_warning = Color(1.0, 0.2, 0.35, 0.9)
		
		# 0. Peripheral Red Hull Damage Alert Vignette
		if is_instance_valid(hud_ref) and "hull_vignette_timer" in hud_ref and hud_ref.hull_vignette_timer > 0.0:
			var v_t = clampf(hud_ref.hull_vignette_timer / 0.35, 0.0, 1.0)
			var v_col = Color(1.0, 0.08, 0.15, v_t * 0.45)
			# Perimeter screen hazard bars
			draw_rect(Rect2(0, 0, vp.x, 14.0), v_col)
			draw_rect(Rect2(0, vp.y - 14.0, vp.x, 14.0), v_col)
			draw_rect(Rect2(0, 0, 14.0, vp.y), v_col)
			draw_rect(Rect2(vp.x - 14.0, 0, 14.0, vp.y), v_col)
			# Glowing hazard corner brackets
			var c_size = 45.0
			var c_col = Color(1.0, 0.25, 0.25, v_t * 0.85)
			draw_line(Vector2(0, 0), Vector2(c_size, 0), c_col, 3.0)
			draw_line(Vector2(0, 0), Vector2(0, c_size), c_col, 3.0)
			draw_line(Vector2(vp.x, 0), Vector2(vp.x - c_size, 0), c_col, 3.0)
			draw_line(Vector2(vp.x, 0), Vector2(vp.x, c_size), c_col, 3.0)
			draw_line(Vector2(0, vp.y), Vector2(c_size, vp.y), c_col, 3.0)
			draw_line(Vector2(0, vp.y), Vector2(0, vp.y - c_size), c_col, 3.0)
			draw_line(Vector2(vp.x, vp.y), Vector2(vp.x - c_size, vp.y), c_col, 3.0)
			draw_line(Vector2(vp.x, vp.y), Vector2(vp.x, vp.y - c_size), c_col, 3.0)
		
		# 1. Cyberpunk Corner Telemetry Brackets
		# Top-Left Bracket
		draw_polyline(PackedVector2Array([
			Vector2(10.0, 36.0),
			Vector2(10.0, 10.0),
			Vector2(36.0, 10.0)
		]), cyan_bright, 2.0, true)
		draw_line(Vector2(14.0, 14.0), Vector2(24.0, 14.0), cyan_dim, 1.0)
		
		# Top-Right Bracket
		draw_polyline(PackedVector2Array([
			Vector2(vp.x - 36.0, 10.0),
			Vector2(vp.x - 10.0, 10.0),
			Vector2(vp.x - 10.0, 36.0)
		]), cyan_bright, 2.0, true)
		draw_line(Vector2(vp.x - 24.0, 14.0), Vector2(vp.x - 14.0, 14.0), cyan_dim, 1.0)
		
		# Bottom-Left Bracket
		draw_polyline(PackedVector2Array([
			Vector2(10.0, vp.y - 36.0),
			Vector2(10.0, vp.y - 10.0),
			Vector2(36.0, vp.y - 10.0)
		]), cyan_bright, 2.0, true)
		
		# Bottom-Right Bracket
		draw_polyline(PackedVector2Array([
			Vector2(vp.x - 36.0, vp.y - 10.0),
			Vector2(vp.x - 10.0, vp.y - 10.0),
			Vector2(vp.x - 10.0, vp.y - 36.0)
		]), cyan_bright, 2.0, true)
		
		# Center Horizon Crosshair Reticle
		var center = vp * 0.5
		draw_line(center - Vector2(16, 0), center - Vector2(6, 0), cyan_dim, 1.2)
		draw_line(center + Vector2(6, 0), center + Vector2(16, 0), cyan_dim, 1.2)
		draw_line(center - Vector2(0, 16), center - Vector2(0, 6), cyan_dim, 1.2)
		draw_line(center + Vector2(0, 6), center + Vector2(0, 16), cyan_dim, 1.2)
		draw_arc(center, 4.0, 0, TAU, 16, cyan_dim, 1.0)
		
		# Subtle Scanlines
		var y = 0.0
		var scanline_col = Color(0.1, 0.6, 0.9, 0.015)
		while y <= vp.y:
			draw_line(Vector2(0, y), Vector2(vp.x, y), scanline_col, 1.0)
			y += 4.0
			
		# 2. Dynamic Lock-On Targeting Reticles for Elites & Bosses
		active_lock_count = 0
		var t = Time.get_ticks_msec() * 0.003
		
		var enemies = get_tree().get_nodes_in_group("enemy")
		for en in enemies:
			if not is_instance_valid(en) or en.is_queued_for_deletion():
				continue
			var is_elite = en.get("is_elite") == true
			var is_boss = en.get("is_boss") == true or en.get("is_miniboss") == true
			if is_elite or is_boss:
				var epos = en.global_position
				if epos.x >= -60 and epos.x <= vp.x + 60 and epos.y >= -60 and epos.y <= vp.y + 60:
					active_lock_count += 1
					var r = 60.0 if is_boss else 28.0
					var lock_col = red_warning if is_boss else cyan_bright
					
					# 4 Rotating Arc Segments
					for s in range(4):
						var a = t + float(s) * (TAU / 4.0)
						draw_arc(epos, r + 8.0, a, a + 0.45, 10, lock_col, 2.0, true)
						
					# Corner Bounding Brackets
					var d = r + 4.0
					# Top-left
					draw_line(epos + Vector2(-d, -d), epos + Vector2(-d + 8, -d), lock_col, 1.5)
					draw_line(epos + Vector2(-d, -d), epos + Vector2(-d, -d + 8), lock_col, 1.5)
					# Top-right
					draw_line(epos + Vector2(d, -d), epos + Vector2(d - 8, -d), lock_col, 1.5)
					draw_line(epos + Vector2(d, -d), epos + Vector2(d, -d + 8), lock_col, 1.5)
					# Bottom-left
					draw_line(epos + Vector2(-d, d), epos + Vector2(-d + 8, d), lock_col, 1.5)
					draw_line(epos + Vector2(-d, d), epos + Vector2(-d, d - 8), lock_col, 1.5)
					# Bottom-right
					draw_line(epos + Vector2(d, d), epos + Vector2(d - 8, d), lock_col, 1.5)
					draw_line(epos + Vector2(d, d), epos + Vector2(d, d - 8), lock_col, 1.5)
					
					# Lead Diamond indicator
					if "velocity" in en and en.velocity != Vector2.ZERO:
						var lead_pos = epos + en.velocity * 0.15
						draw_circle(lead_pos, 2.5, lock_col)
						draw_line(epos, lead_pos, Color(lock_col.r, lock_col.g, lock_col.b, 0.35), 1.0)
	
		# Check Boss Group as well
		var bosses = get_tree().get_nodes_in_group("boss")
		for b in bosses:
			if not is_instance_valid(b) or b.is_queued_for_deletion():
				continue
			if not (b in enemies):
				var bpos = b.global_position
				if bpos.x >= -60 and bpos.x <= vp.x + 60:
					active_lock_count += 1
					var r = 70.0
					for s in range(4):
						var a = t + float(s) * (TAU / 4.0)
						draw_arc(bpos, r + 10.0, a, a + 0.45, 12, red_warning, 2.2, true)
