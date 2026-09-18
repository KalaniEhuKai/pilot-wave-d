extends Control

## MainMenu.gd - Cyberpunk Main Menu Coordinator.
## Supports Mouse/Touch, Keyboard (WASD/Arrows + Enter/Esc), and Gamepad (D-Pad/Stick + A/B/Start).

const MenuStyleHelper = preload("res://scripts/MenuStyleHelper.gd")

# Sub-views
@onready var title_view: Control = $CenterContainer/TitleView
@onready var mission_view: Control = $CenterContainer/MissionView
@onready var scores_view: Control = $CenterContainer/ScoresView
@onready var bestiary_view: Control = $CenterContainer/BestiaryView
@onready var options_view: Control = $CenterContainer/OptionsView
@onready var debug_view: Control = $CenterContainer/DebugView

# Title View Controls
@onready var start_btn: Button = $CenterContainer/TitleView/MenuButtons/StartBtn
@onready var scores_btn: Button = $CenterContainer/TitleView/MenuButtons/ScoresBtn
@onready var bestiary_btn: Button = $CenterContainer/TitleView/MenuButtons/BestiaryBtn
@onready var options_btn: Button = $CenterContainer/TitleView/MenuButtons/OptionsBtn
@onready var quit_btn: Button = $CenterContainer/TitleView/MenuButtons/QuitBtn
@onready var debug_btn: Button = $CenterContainer/TitleView/MenuButtons/DebugBtn
@onready var debug_status_badge: Label = $CenterContainer/TitleView/VBox/DebugStatusBadge

# Mission View Controls
@onready var btn_1p: Button = $CenterContainer/MissionView/VBox/PlayerSelect/Btn1P
@onready var btn_2p: Button = $CenterContainer/MissionView/VBox/PlayerSelect/Btn2P
@onready var player_desc_lbl: Label = $CenterContainer/MissionView/VBox/PlayerDescLbl
@onready var btn_mode_normal: Button = $CenterContainer/MissionView/VBox/ModeSelect/BtnNormal
@onready var btn_mode_endless: Button = $CenterContainer/MissionView/VBox/ModeSelect/BtnEndless
@onready var btn_mode_ascension: Button = $CenterContainer/MissionView/VBox/ModeSelect/BtnAscension
@onready var launch_btn: Button = $CenterContainer/MissionView/VBox/ActionRow/LaunchBtn
@onready var back_mission_btn: Button = $CenterContainer/MissionView/VBox/ActionRow/BackMissionBtn

# High Scores View Controls
@onready var scores_container: VBoxContainer = $CenterContainer/ScoresView/VBox/ScoresTable/Scroll/RowsVBox
@onready var back_scores_btn: Button = $CenterContainer/ScoresView/VBox/BackScoresBtn
@onready var reset_scores_btn: Button = $CenterContainer/ScoresView/VBox/ResetScoresBtn

# Options View Controls
@onready var master_slider: HSlider = $CenterContainer/OptionsView/VBox/SettingsGrid/MasterSlider
@onready var master_val_lbl: Label = $CenterContainer/OptionsView/VBox/SettingsGrid/MasterValLbl
@onready var sfx_slider: HSlider = $CenterContainer/OptionsView/VBox/SettingsGrid/SfxSlider
@onready var sfx_val_lbl: Label = $CenterContainer/OptionsView/VBox/SettingsGrid/SfxValLbl
@onready var orientation_btn: Button = $CenterContainer/OptionsView/VBox/SettingsGrid/OrientationBtn
@onready var back_options_btn: Button = $CenterContainer/OptionsView/VBox/BackOptionsBtn

# Debug View Controls
@onready var btn_god_mode: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/CheatsRow1/BtnGodMode
@onready var btn_infinite_rolls: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/CheatsRow1/BtnInfiniteRolls
@onready var btn_joules_1k: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/CheatsRow2/BtnJoules1k
@onready var btn_joules_10k: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/CheatsRow2/BtnJoules10k

@onready var btn_god_build: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/PresetRow/BtnGodBuild
@onready var btn_clear_relics: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/PresetRow/BtnClearRelics
@onready var relic_grid: HFlowContainer = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/RelicGrid

@onready var btn_warp_s1: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/WarpGrid/BtnWarpS1
@onready var btn_warp_s1_miniboss: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/WarpGrid/BtnWarpS1Miniboss
@onready var btn_warp_s1_boss: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/WarpGrid/BtnWarpS1Boss
@onready var btn_warp_s2: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/WarpGrid/BtnWarpS2
@onready var btn_warp_s2_boss: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/WarpGrid/BtnWarpS2Boss
@onready var btn_warp_s3: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/WarpGrid/BtnWarpS3

@onready var btn_unlock_modes: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/SystemRow/BtnUnlockModes
@onready var btn_reset_scores: Button = $CenterContainer/DebugView/VBox/ScrollContent/ItemsVBox/SystemRow/BtnResetScores

@onready var btn_launch_debug: Button = $CenterContainer/DebugView/VBox/ActionRow/BtnLaunchDebug
@onready var btn_back_debug: Button = $CenterContainer/DebugView/VBox/ActionRow/BtnBackDebug

# Secret Code Detection (Up, Up, Down, Down, Left, Right, Left, Right)
const CODE_SEQUENCE: Array[String] = ["up", "up", "down", "down", "left", "right", "left", "right"]
var code_buffer: Array[String] = []
var _stick_latched_up: bool = false
var _stick_latched_down: bool = false
var _stick_latched_left: bool = false
var _stick_latched_right: bool = false
var _relic_buttons: Dictionary = {}

var current_view: Control = null
var selected_players: int = 1

# Background grid animation
var anim_phase: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Apply cyberpunk styling to buttons
	_apply_styles()
	
	# Connect title view buttons
	start_btn.pressed.connect(_on_start_pressed)
	scores_btn.pressed.connect(_on_scores_pressed)
	bestiary_btn.pressed.connect(_on_bestiary_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	debug_btn.pressed.connect(_on_debug_pressed)
	
	if bestiary_view.has_signal("back_pressed"):
		bestiary_view.back_pressed.connect(_show_title_view)
	
	# Connect mission view buttons
	btn_1p.pressed.connect(func(): _select_players(1))
	btn_2p.pressed.connect(func(): _select_players(2))
	btn_mode_normal.pressed.connect(func(): _select_mode(GameManager.GameMode.NORMAL))
	btn_mode_endless.pressed.connect(func():
		if GameManager.force_unlocked_modes:
			_select_mode(GameManager.GameMode.ENDLESS)
		else:
			SoundEffects.play_sfx("hurt", 0.1, -4.0)
	)
	btn_mode_ascension.pressed.connect(func():
		if GameManager.force_unlocked_modes:
			_select_mode(GameManager.GameMode.ASCENSION)
		else:
			SoundEffects.play_sfx("hurt", 0.1, -4.0)
	)
	launch_btn.pressed.connect(_on_launch_mission)
	back_mission_btn.pressed.connect(_show_title_view)
	
	# Connect scores view buttons
	back_scores_btn.pressed.connect(_show_title_view)
	reset_scores_btn.pressed.connect(_on_reset_scores_pressed)
	
	# Connect options view buttons
	master_slider.value_changed.connect(_on_master_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	orientation_btn.pressed.connect(_on_toggle_orientation)
	back_options_btn.pressed.connect(_show_title_view)
	
	# Connect debug view controls & populate relics
	_setup_debug_view()
	_populate_relic_picker()
	
	# Initial view
	_select_players(1)
	_show_title_view()
	
	if GameManager.debug_mode_unlocked:
		_update_debug_ui_state()
	
	# Quit button hidden on web
	if OS.has_feature("web"):
		quit_btn.visible = false

func _process(delta: float) -> void:
	anim_phase += delta
	queue_redraw()

func _draw() -> void:
	var vp = get_viewport_rect().size
	# Draw subtle cyberpunk scanning lines
	var line_spacing = 40.0
	var offset = fmod(anim_phase * 20.0, line_spacing)
	var col = Color(0.1, 0.4, 0.7, 0.08)
	for y in range(-int(line_spacing), int(vp.y + line_spacing), int(line_spacing)):
		var py = float(y) + offset
		draw_line(Vector2(0, py), Vector2(vp.x, py), col, 1.0)
	
	# Radial vignette corners
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.04, 0.08, 0.4), false, 2.0)

func _input(event: InputEvent) -> void:
	var dir = _get_directional_input(event)
	if not dir.is_empty():
		_register_code_input(dir)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if current_view != title_view:
			SoundEffects.play_sfx("ui_back", 0.05, -3.0)
			_show_title_view()
			get_viewport().set_input_as_handled()

func _apply_styles() -> void:
	var cyan = Color(0.2, 0.85, 1.0, 1.0)
	var gold = Color(1.0, 0.85, 0.2, 1.0)
	var magenta = Color(1.0, 0.3, 0.6, 1.0)
	var amber = Color(1.0, 0.45, 0.2, 1.0)
	var emerald = Color(0.1, 1.0, 0.6, 1.0)
	
	# Title Buttons
	MenuStyleHelper.style_button(start_btn, cyan)
	MenuStyleHelper.style_button(scores_btn, gold)
	MenuStyleHelper.style_button(bestiary_btn, cyan)
	MenuStyleHelper.style_button(options_btn, cyan)
	MenuStyleHelper.style_button(debug_btn, amber)
	MenuStyleHelper.style_button(quit_btn, magenta)
	
	# Mission Buttons
	MenuStyleHelper.style_button(btn_1p, cyan)
	MenuStyleHelper.style_button(btn_2p, gold)
	MenuStyleHelper.style_button(btn_mode_normal, cyan)
	if GameManager.force_unlocked_modes:
		MenuStyleHelper.style_button(btn_mode_endless, cyan)
		MenuStyleHelper.style_button(btn_mode_ascension, gold)
	else:
		MenuStyleHelper.style_button(btn_mode_endless, Color(0.5, 0.5, 0.6, 0.6))
		MenuStyleHelper.style_button(btn_mode_ascension, Color(0.5, 0.5, 0.6, 0.6))
	MenuStyleHelper.style_button(launch_btn, emerald)
	MenuStyleHelper.style_button(back_mission_btn, magenta)
	
	# Scores Buttons
	MenuStyleHelper.style_button(back_scores_btn, cyan)
	MenuStyleHelper.style_button(reset_scores_btn, magenta)
	
	# Options Buttons
	MenuStyleHelper.style_button(orientation_btn, cyan)
	MenuStyleHelper.style_button(back_options_btn, cyan)
	
	# Debug View Buttons
	MenuStyleHelper.style_button(btn_god_mode, cyan)
	MenuStyleHelper.style_button(btn_infinite_rolls, cyan)
	MenuStyleHelper.style_button(btn_joules_1k, cyan)
	MenuStyleHelper.style_button(btn_joules_10k, gold)
	MenuStyleHelper.style_button(btn_god_build, gold)
	MenuStyleHelper.style_button(btn_clear_relics, magenta)
	
	MenuStyleHelper.style_button(btn_warp_s1, cyan)
	MenuStyleHelper.style_button(btn_warp_s1_miniboss, cyan)
	MenuStyleHelper.style_button(btn_warp_s1_boss, cyan)
	MenuStyleHelper.style_button(btn_warp_s2, cyan)
	MenuStyleHelper.style_button(btn_warp_s2_boss, cyan)
	MenuStyleHelper.style_button(btn_warp_s3, cyan)
	
	MenuStyleHelper.style_button(btn_unlock_modes, cyan)
	MenuStyleHelper.style_button(btn_reset_scores, magenta)
	MenuStyleHelper.style_button(btn_launch_debug, emerald)
	MenuStyleHelper.style_button(btn_back_debug, magenta)
	
	# Sliders focus mode
	master_slider.focus_mode = Control.FOCUS_ALL
	sfx_slider.focus_mode = Control.FOCUS_ALL

func _show_title_view() -> void:
	_switch_view(title_view)
	start_btn.grab_focus()

func _on_start_pressed() -> void:
	_switch_view(mission_view)
	launch_btn.grab_focus()

func _on_scores_pressed() -> void:
	_populate_scores_table()
	_switch_view(scores_view)
	back_scores_btn.grab_focus()

func _on_options_pressed() -> void:
	_update_options_ui()
	_switch_view(options_view)
	master_slider.grab_focus()

func _on_debug_pressed() -> void:
	_update_debug_ui_state()
	_switch_view(debug_view)
	btn_god_mode.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_bestiary_pressed() -> void:
	_switch_view(bestiary_view)

func _switch_view(target: Control) -> void:
	if current_view == bestiary_view and target != bestiary_view:
		if bestiary_view.has_method("on_deactivated"):
			bestiary_view.on_deactivated()
	
	title_view.visible = (target == title_view)
	mission_view.visible = (target == mission_view)
	scores_view.visible = (target == scores_view)
	bestiary_view.visible = (target == bestiary_view)
	options_view.visible = (target == options_view)
	debug_view.visible = (target == debug_view)
	current_view = target

	if target == bestiary_view:
		if bestiary_view.has_method("on_activated"):
			bestiary_view.on_activated()

# --- Mission Deployment Logic ---

func _select_players(count: int) -> void:
	selected_players = count
	GameManager.is_coop_mode = (count == 2)
	
	if count == 1:
		btn_1p.text = "[● 1 PLAYER (SOLO)]"
		btn_2p.text = "[  2 PLAYERS (CO-OP)]"
		player_desc_lbl.text = "SOLO VANGUARD: 1 Pilot. Full scrap vacuum. Keyboard (WASD/Space) or Gamepad."
	else:
		btn_1p.text = "[  1 PLAYER (SOLO)]"
		btn_2p.text = "[● 2 PLAYERS (CO-OP)]"
		player_desc_lbl.text = "DUAL WINGMEN: Shared in-flight scrap. P1 (WASD) + P2 (Arrow Keys) or 2 Gamepads."

func _select_mode(mode: GameManager.GameMode) -> void:
	GameManager.current_game_mode = mode
	btn_mode_normal.text = "[● NORMAL CAMPAIGN]" if mode == GameManager.GameMode.NORMAL else "[  NORMAL CAMPAIGN]"
	if GameManager.force_unlocked_modes:
		btn_mode_endless.text = "[● ENDLESS SURVIVAL]" if mode == GameManager.GameMode.ENDLESS else "[  ENDLESS SURVIVAL]"
		btn_mode_ascension.text = "[● ASCENSION OVERCLOCK]" if mode == GameManager.GameMode.ASCENSION else "[  ASCENSION OVERCLOCK]"
	else:
		btn_mode_endless.text = "[  ENDLESS SURVIVAL (LOCKED)]"
		btn_mode_ascension.text = "[  ASCENSION OVERCLOCK (LOCKED)]"

func _on_launch_mission() -> void:
	GameManager.reset_run_state()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- High Scores Logic ---

func _populate_scores_table() -> void:
	for child in scores_container.get_children():
		scores_container.remove_child(child)
		child.queue_free()
	
	var scores = HighScoreManager.get_scores()
	if scores.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "NO FLIGHT RECORDS RECORDED"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 1))
		scores_container.add_child(empty_lbl)
		return
	
	for entry in scores:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		
		var rank = int(entry.get("rank", 0))
		var score = int(entry.get("score", 0))
		var sec = int(entry.get("sector", 1))
		var wave = int(entry.get("wave", 1))
		var mode = str(entry.get("mode", "1P"))
		var time_s = float(entry.get("time_seconds", 0.0))
		var date = str(entry.get("date", ""))
		
		var rank_lbl = Label.new()
		rank_lbl.custom_minimum_size = Vector2(40, 0)
		rank_lbl.text = "#%d" % rank
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0) if rank <= 3 else Color(0.7, 0.8, 0.9, 1))
		row.add_child(rank_lbl)
		
		var score_lbl = Label.new()
		score_lbl.custom_minimum_size = Vector2(100, 0)
		score_lbl.text = str(score).pad_zeros(6)
		score_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1))
		row.add_child(score_lbl)
		
		var sec_lbl = Label.new()
		sec_lbl.custom_minimum_size = Vector2(110, 0)
		sec_lbl.text = "SEC %d (W%d)" % [sec, wave]
		sec_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 1))
		row.add_child(sec_lbl)
		
		var mode_lbl = Label.new()
		mode_lbl.custom_minimum_size = Vector2(90, 0)
		mode_lbl.text = mode
		mode_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.9))
		row.add_child(mode_lbl)
		
		var time_lbl = Label.new()
		time_lbl.custom_minimum_size = Vector2(70, 0)
		time_lbl.text = HighScoreManager.format_time(time_s)
		time_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
		row.add_child(time_lbl)
		
		var date_lbl = Label.new()
		date_lbl.custom_minimum_size = Vector2(90, 0)
		date_lbl.text = date
		date_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))
		row.add_child(date_lbl)
		
		scores_container.add_child(row)

func _on_reset_scores_pressed() -> void:
	HighScoreManager.reset_to_defaults()
	_populate_scores_table()
	SoundEffects.play_sfx("explosion", 0.1, -6.0)

# --- Options Logic ---

func _update_options_ui() -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var vol = db_to_linear(AudioServer.get_bus_volume_db(master_bus)) * 100.0
		master_slider.set_value_no_signal(vol)
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		var vol = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) * 100.0
		sfx_slider.set_value_no_signal(vol)
	master_val_lbl.text = "%d%%" % int(master_slider.value)
	sfx_val_lbl.text = "%d%%" % int(sfx_slider.value)
	orientation_btn.text = "VERTICAL (9:16)" if GameAxis.is_vertical else "HORIZONTAL (16:9)"

func _on_master_slider_changed(val: float) -> void:
	master_val_lbl.text = "%d%%" % int(val)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db = linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_sfx_slider_changed(val: float) -> void:
	sfx_val_lbl.text = "%d%%" % int(val)
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		var db = linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_toggle_orientation() -> void:
	GameAxis.toggle_axis()
	_update_options_ui()
	SoundEffects.play_sfx("bonus", 0.05, -4.0)

# --- Secret Debug Menu & Input Code Implementation ---

func _get_directional_input(event: InputEvent) -> String:
	# 1. Keyboard Key (Arrows or WASD)
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return ""
		var code = event.keycode if event.keycode != 0 else event.physical_keycode
		match code:
			KEY_UP, KEY_W:
				return "up"
			KEY_DOWN, KEY_S:
				return "down"
			KEY_LEFT, KEY_A:
				return "left"
			KEY_RIGHT, KEY_D:
				return "right"
		return ""
	
	# 2. Gamepad D-Pad Button
	if event is InputEventJoypadButton:
		if not event.pressed:
			return ""
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				return "up"
			JOY_BUTTON_DPAD_DOWN:
				return "down"
			JOY_BUTTON_DPAD_LEFT:
				return "left"
			JOY_BUTTON_DPAD_RIGHT:
				return "right"
		return ""
	
	# 3. Gamepad Analog Sticks (debounced with latch)
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]:
			if event.axis_value < -0.55:
				if not _stick_latched_up:
					_stick_latched_up = true
					return "up"
			elif event.axis_value > -0.2:
				_stick_latched_up = false
			
			if event.axis_value > 0.55:
				if not _stick_latched_down:
					_stick_latched_down = true
					return "down"
			elif event.axis_value < 0.2:
				_stick_latched_down = false
		
		elif event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]:
			if event.axis_value < -0.55:
				if not _stick_latched_left:
					_stick_latched_left = true
					return "left"
			elif event.axis_value > -0.2:
				_stick_latched_left = false
			
			if event.axis_value > 0.55:
				if not _stick_latched_right:
					_stick_latched_right = true
					return "right"
			elif event.axis_value < 0.2:
				_stick_latched_right = false
		return ""
	
	return ""

func _register_code_input(dir: String) -> void:
	code_buffer.append(dir)
	if code_buffer.size() > CODE_SEQUENCE.size():
		code_buffer.pop_front()
	
	if code_buffer == CODE_SEQUENCE:
		code_buffer.clear()
		_access_debug_menu()

func _access_debug_menu() -> void:
	GameManager.disable_scores_and_telemetry()
	SoundEffects.play_sfx("secret", 0.05, 0.0)
	_update_debug_ui_state()
	_switch_view(debug_view)
	btn_god_mode.grab_focus()

func _update_debug_ui_state() -> void:
	if GameManager.debug_mode_unlocked:
		debug_status_badge.visible = true
		debug_btn.visible = true
		_update_god_mode_ui()
		_update_infinite_rolls_ui()
		_update_warp_buttons_ui()
		_update_relic_picker_ui()
		if GameManager.force_unlocked_modes:
			btn_unlock_modes.text = "[ALL GAME MODES UNLOCKED]"
			MenuStyleHelper.style_button(btn_unlock_modes, Color(0.1, 1.0, 0.6, 1.0))
			btn_mode_endless.text = "[  ENDLESS SURVIVAL]"
			btn_mode_ascension.text = "[  ASCENSION OVERCLOCK]"
			MenuStyleHelper.style_button(btn_mode_endless, Color(0.2, 0.85, 1.0, 1.0))
			MenuStyleHelper.style_button(btn_mode_ascension, Color(1.0, 0.85, 0.2, 1.0))

func _setup_debug_view() -> void:
	btn_god_mode.pressed.connect(_on_god_mode_toggle)
	btn_infinite_rolls.pressed.connect(_on_infinite_rolls_toggle)
	btn_joules_1k.pressed.connect(func(): _add_debug_joules(1000))
	btn_joules_10k.pressed.connect(func(): _add_debug_joules(10000))
	btn_god_build.pressed.connect(_on_god_build_toggle)
	btn_clear_relics.pressed.connect(_on_clear_relics_pressed)
	
	btn_warp_s1.pressed.connect(func(): _set_debug_warp(1, 1))
	btn_warp_s1_miniboss.pressed.connect(func(): _set_debug_warp(1, 6))
	btn_warp_s1_boss.pressed.connect(func(): _set_debug_warp(1, 12))
	btn_warp_s2.pressed.connect(func(): _set_debug_warp(2, 13))
	btn_warp_s2_boss.pressed.connect(func(): _set_debug_warp(2, 24))
	btn_warp_s3.pressed.connect(func(): _set_debug_warp(3, 25))
	
	btn_unlock_modes.pressed.connect(_on_unlock_all_modes_pressed)
	btn_reset_scores.pressed.connect(_on_reset_scores_pressed)
	btn_launch_debug.pressed.connect(_on_launch_debug_mission)
	btn_back_debug.pressed.connect(_show_title_view)
	
	_update_god_mode_ui()
	_update_infinite_rolls_ui()
	_update_warp_buttons_ui()

func _populate_relic_picker() -> void:
	for child in relic_grid.get_children():
		relic_grid.remove_child(child)
		child.queue_free()
	_relic_buttons.clear()
	
	var items = ItemDatabase.get_all_items()
	for item in items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 28)
		btn.focus_mode = Control.FOCUS_ALL
		var item_id = item.id
		var item_name = item.display_name
		var is_selected = (item_id in GameManager.debug_starting_relics)
		btn.text = ("[✓ %s]" if is_selected else "[  %s]") % item_name
		
		if is_selected:
			MenuStyleHelper.style_button(btn, Color(0.2, 0.95, 1.0, 1.0))
		else:
			MenuStyleHelper.style_button(btn, Color(0.4, 0.45, 0.55, 0.7))
		
		btn.pressed.connect(func():
			_toggle_debug_relic(item_id, btn, item_name)
		)
		relic_grid.add_child(btn)
		_relic_buttons[item_id] = btn

func _toggle_debug_relic(item_id: String, btn: Button, item_name: String) -> void:
	if item_id in GameManager.debug_starting_relics:
		GameManager.debug_starting_relics.erase(item_id)
		btn.text = "[  %s]" % item_name
		MenuStyleHelper.style_button(btn, Color(0.4, 0.45, 0.55, 0.7))
		SoundEffects.play_sfx("ui_back", 0.02, -5.0)
	else:
		GameManager.debug_starting_relics.append(item_id)
		btn.text = "[✓ %s]" % item_name
		MenuStyleHelper.style_button(btn, Color(0.2, 0.95, 1.0, 1.0))
		SoundEffects.play_sfx("ui_select", 0.02, -4.0)

func _update_relic_picker_ui() -> void:
	var items = ItemDatabase.get_all_items()
	for item in items:
		if _relic_buttons.has(item.id):
			var btn = _relic_buttons[item.id]
			var is_sel = (item.id in GameManager.debug_starting_relics)
			btn.text = ("[✓ %s]" if is_sel else "[  %s]") % item.display_name
			if is_sel:
				MenuStyleHelper.style_button(btn, Color(0.2, 0.95, 1.0, 1.0))
			else:
				MenuStyleHelper.style_button(btn, Color(0.4, 0.45, 0.55, 0.7))

func _on_god_build_toggle() -> void:
	GameManager.debug_give_god_build = not GameManager.debug_give_god_build
	if GameManager.debug_give_god_build:
		btn_god_build.text = "[GOD-BUILD ARMED (CW MAGNETRON + CASIMIR)]"
		MenuStyleHelper.style_button(btn_god_build, Color(1.0, 0.85, 0.2, 1.0))
		for rid in ["continuous_wave_magnetron", "casimir_discharge", "feynman_propagator", "target_lock_matrix"]:
			if not (rid in GameManager.debug_starting_relics):
				GameManager.debug_starting_relics.append(rid)
		SoundEffects.play_sfx("secret", 0.05, -2.0)
	else:
		btn_god_build.text = "[LOAD GOD-BUILD (CW MAGNETRON + CASIMIR)]"
		MenuStyleHelper.style_button(btn_god_build, Color(0.2, 0.85, 1.0, 1.0))
		SoundEffects.play_sfx("ui_back", 0.05, -2.0)
	_update_relic_picker_ui()

func _on_clear_relics_pressed() -> void:
	GameManager.debug_give_god_build = false
	GameManager.debug_starting_relics.clear()
	btn_god_build.text = "[LOAD GOD-BUILD (CW MAGNETRON + CASIMIR)]"
	MenuStyleHelper.style_button(btn_god_build, Color(0.2, 0.85, 1.0, 1.0))
	_update_relic_picker_ui()
	SoundEffects.play_sfx("ui_back", 0.05, -2.0)

func _on_god_mode_toggle() -> void:
	GameManager.debug_god_mode = not GameManager.debug_god_mode
	_update_god_mode_ui()
	SoundEffects.play_sfx("bonus" if GameManager.debug_god_mode else "ui_back", 0.04, -3.0)

func _update_god_mode_ui() -> void:
	if GameManager.debug_god_mode:
		btn_god_mode.text = "[GOD MODE: ACTIVE (INVULNERABLE)]"
		MenuStyleHelper.style_button(btn_god_mode, Color(1.0, 0.85, 0.2, 1.0))
	else:
		btn_god_mode.text = "[GOD MODE: OFF]"
		MenuStyleHelper.style_button(btn_god_mode, Color(0.2, 0.85, 1.0, 1.0))

func _on_infinite_rolls_toggle() -> void:
	GameManager.debug_infinite_rolls = not GameManager.debug_infinite_rolls
	_update_infinite_rolls_ui()
	SoundEffects.play_sfx("bonus" if GameManager.debug_infinite_rolls else "ui_back", 0.04, -3.0)

func _update_infinite_rolls_ui() -> void:
	if GameManager.debug_infinite_rolls:
		btn_infinite_rolls.text = "[INFINITE ROLLS: ACTIVE]"
		MenuStyleHelper.style_button(btn_infinite_rolls, Color(1.0, 0.85, 0.2, 1.0))
	else:
		btn_infinite_rolls.text = "[INFINITE ROLLS: OFF]"
		MenuStyleHelper.style_button(btn_infinite_rolls, Color(0.2, 0.85, 1.0, 1.0))

func _add_debug_joules(amount: int) -> void:
	GameManager.add_joules(amount)
	SoundEffects.play_sfx("bonus", 0.05, -2.0)

func _set_debug_warp(sec: int, wave: int) -> void:
	GameManager.start_sector = sec
	GameManager.start_wave = wave
	_update_warp_buttons_ui()
	SoundEffects.play_sfx("ui_select", 0.03, -2.0)

func _update_warp_buttons_ui() -> void:
	var active_gold = Color(1.0, 0.85, 0.2, 1.0)
	var inactive_cyan = Color(0.2, 0.85, 1.0, 1.0)
	
	MenuStyleHelper.style_button(btn_warp_s1, active_gold if GameManager.start_sector == 1 and GameManager.start_wave == 1 else inactive_cyan)
	MenuStyleHelper.style_button(btn_warp_s1_miniboss, active_gold if GameManager.start_sector == 1 and GameManager.start_wave == 6 else inactive_cyan)
	MenuStyleHelper.style_button(btn_warp_s1_boss, active_gold if GameManager.start_sector == 1 and GameManager.start_wave == 12 else inactive_cyan)
	MenuStyleHelper.style_button(btn_warp_s2, active_gold if GameManager.start_sector == 2 and GameManager.start_wave == 13 else inactive_cyan)
	MenuStyleHelper.style_button(btn_warp_s2_boss, active_gold if GameManager.start_sector == 2 and GameManager.start_wave == 24 else inactive_cyan)
	MenuStyleHelper.style_button(btn_warp_s3, active_gold if GameManager.start_sector == 3 and GameManager.start_wave == 25 else inactive_cyan)

func _on_unlock_all_modes_pressed() -> void:
	GameManager.force_unlocked_modes = true
	btn_unlock_modes.text = "[ALL GAME MODES UNLOCKED]"
	MenuStyleHelper.style_button(btn_unlock_modes, Color(0.1, 1.0, 0.6, 1.0))
	btn_mode_endless.text = "[  ENDLESS SURVIVAL]"
	btn_mode_ascension.text = "[  ASCENSION OVERCLOCK]"
	MenuStyleHelper.style_button(btn_mode_endless, Color(0.2, 0.85, 1.0, 1.0))
	MenuStyleHelper.style_button(btn_mode_ascension, Color(1.0, 0.85, 0.2, 1.0))
	SoundEffects.play_sfx("secret", 0.05, -2.0)

func _on_launch_debug_mission() -> void:
	GameManager.reset_run_state()
	SoundEffects.play_sfx("ui_select", 0.05, 0.0)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
