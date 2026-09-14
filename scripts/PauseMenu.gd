extends CanvasLayer

## PauseMenu.gd - Cyberpunk Pause Overlay with Integrated Synergy Inspector and Quick Settings.
## Operates under PROCESS_MODE_ALWAYS while the SceneTree is suspended.

const MenuStyleHelper = preload("res://scripts/MenuStyleHelper.gd")
const ItemModifier = preload("res://scripts/ItemModifier.gd")

@onready var panel: Control = $Panel
@onready var header_lbl: Label = $Panel/VBox/HeaderLbl
@onready var stats_sub_lbl: Label = $Panel/VBox/StatsSubLbl

# Command Column Buttons
@onready var resume_btn: Button = $Panel/VBox/HBoxBody/CommandsVBox/ResumeBtn
@onready var synergy_btn: Button = $Panel/VBox/HBoxBody/CommandsVBox/SynergyBtn
@onready var settings_btn: Button = $Panel/VBox/HBoxBody/CommandsVBox/SettingsBtn
@onready var restart_btn: Button = $Panel/VBox/HBoxBody/CommandsVBox/RestartBtn
@onready var main_menu_btn: Button = $Panel/VBox/HBoxBody/CommandsVBox/MainMenuBtn

# Dynamic Panels
@onready var inspector_panel: Control = $Panel/VBox/HBoxBody/ContentPanel/InspectorView
@onready var settings_panel: Control = $Panel/VBox/HBoxBody/ContentPanel/SettingsView

# Inspector Elements
@onready var relics_grid: GridContainer = $Panel/VBox/HBoxBody/ContentPanel/InspectorView/Scroll/RelicsGrid
@onready var item_details_box: VBoxContainer = $Panel/VBox/HBoxBody/ContentPanel/InspectorView/ItemDetails
@onready var item_title_lbl: Label = $Panel/VBox/HBoxBody/ContentPanel/InspectorView/ItemDetails/ItemTitle
@onready var item_tier_lbl: Label = $Panel/VBox/HBoxBody/ContentPanel/InspectorView/ItemDetails/ItemTier
@onready var item_desc_lbl: Label = $Panel/VBox/HBoxBody/ContentPanel/InspectorView/ItemDetails/ItemDesc
@onready var pilot_stats_lbl: Label = $Panel/VBox/HBoxBody/ContentPanel/InspectorView/PilotStatsLbl

# Settings Elements
@onready var pause_master_slider: HSlider = $Panel/VBox/HBoxBody/ContentPanel/SettingsView/Grid/MasterSlider
@onready var pause_master_val: Label = $Panel/VBox/HBoxBody/ContentPanel/SettingsView/Grid/MasterVal
@onready var pause_sfx_slider: HSlider = $Panel/VBox/HBoxBody/ContentPanel/SettingsView/Grid/SfxSlider
@onready var pause_sfx_val: Label = $Panel/VBox/HBoxBody/ContentPanel/SettingsView/Grid/SfxVal
@onready var pause_orient_btn: Button = $Panel/VBox/HBoxBody/ContentPanel/SettingsView/Grid/OrientBtn

var is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	visible = false
	
	_apply_styles()
	
	resume_btn.pressed.connect(close_pause)
	synergy_btn.pressed.connect(_show_inspector)
	settings_btn.pressed.connect(_show_settings)
	restart_btn.pressed.connect(_on_restart_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	
	pause_master_slider.value_changed.connect(_on_master_slider_changed)
	pause_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	pause_orient_btn.pressed.connect(_on_orient_pressed)

func _apply_styles() -> void:
	var cyan = Color(0.2, 0.85, 1.0, 1.0)
	var gold = Color(1.0, 0.85, 0.2, 1.0)
	var magenta = Color(1.0, 0.3, 0.6, 1.0)
	
	MenuStyleHelper.style_button(resume_btn, Color(0.1, 1.0, 0.6, 1.0))
	MenuStyleHelper.style_button(synergy_btn, cyan)
	MenuStyleHelper.style_button(settings_btn, gold)
	MenuStyleHelper.style_button(restart_btn, gold)
	MenuStyleHelper.style_button(main_menu_btn, magenta)
	MenuStyleHelper.style_button(pause_orient_btn, cyan)
	
	pause_master_slider.focus_mode = Control.FOCUS_ALL
	pause_sfx_slider.focus_mode = Control.FOCUS_ALL

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close_pause()
		get_viewport().set_input_as_handled()

func open_pause() -> void:
	if GameManager.is_game_over or GameManager.current_phase == GameManager.RunPhase.SECTOR_VICTORY:
		return
	
	is_open = true
	get_tree().paused = true
	visible = true
	panel.visible = true
	
	_update_header()
	_show_inspector()
	resume_btn.grab_focus()
	SoundEffects.play_sfx("ui_hover", 0.05, -3.0)

func close_pause() -> void:
	if not is_open:
		return
	
	is_open = false
	visible = false
	panel.visible = false
	get_tree().paused = false
	
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	SoundEffects.play_sfx("ui_back", 0.05, -3.0)

func _update_header() -> void:
	header_lbl.text = "SYSTEM SUSPENDED // COHERENCE STABILIZED"
	stats_sub_lbl.text = "SECTOR %02d (WAVE %02d)  |  SCORE: %s  |  TIME: %s  |  JOULES: %d J" % [
		GameManager.current_sector,
		GameManager.current_wave,
		str(GameManager.score).pad_zeros(6),
		HighScoreManager.format_time(GameManager.survival_time),
		GameManager.scrap_joules
	]

func _show_inspector() -> void:
	inspector_panel.visible = true
	settings_panel.visible = false
	_populate_synergy_inspector()

func _show_settings() -> void:
	inspector_panel.visible = false
	settings_panel.visible = true
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var vol = db_to_linear(AudioServer.get_bus_volume_db(master_bus)) * 100.0
		pause_master_slider.set_value_no_signal(vol)
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		var vol = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) * 100.0
		pause_sfx_slider.set_value_no_signal(vol)
	pause_master_val.text = "%d%%" % int(pause_master_slider.value)
	pause_sfx_val.text = "%d%%" % int(pause_sfx_slider.value)
	pause_orient_btn.text = "VERTICAL (9:16)" if GameAxis.is_vertical else "HORIZONTAL (16:9)"
	pause_master_slider.grab_focus()

func _populate_synergy_inspector() -> void:
	for child in relics_grid.get_children():
		relics_grid.remove_child(child)
		child.queue_free()
	
	var players = get_tree().get_nodes_in_group("player")
	var p1: Node = null
	for p in players:
		if is_instance_valid(p) and p.get("player_id") == 1:
			p1 = p
			break
	
	# Update ship telemetry
	if is_instance_valid(p1):
		var hp = int(p1.get("health")) if "health" in p1 else 3
		var mhp = int(p1.get("max_health")) if "max_health" in p1 else 3
		var sh = int(p1.get("shield")) if "shield" in p1 else 0
		var msh = int(p1.get("max_shield")) if "max_shield" in p1 else 2
		var fr = float(p1.get("fire_rate")) if "fire_rate" in p1 else 3.8
		var bs = float(p1.get("bullet_speed")) if "bullet_speed" in p1 else 540.0
		var rc = int(p1.get("roll_charges")) if "roll_charges" in p1 else 3
		
		pilot_stats_lbl.text = "HULL: %d/%d  |  SHIELDS: %d/%d  |  FIRING RATE: %.1f/s  |  BALLISTIC VELOCITY: %.0f px/s  |  ROLL CHARGES: %d" % [
			hp, mhp, sh, msh, fr, bs, rc
		]
	else:
		pilot_stats_lbl.text = "PILOT TELEMETRY OFFLINE"
	
	var active_mods: Array = []
	if is_instance_valid(p1) and "active_modifiers" in p1:
		active_mods = p1.active_modifiers
	
	if active_mods.is_empty():
		item_title_lbl.text = "NO SYNCHRONIZED RELICS"
		item_tier_lbl.text = "SECTOR 1 STOCK CHASSIS LOADOUT"
		item_desc_lbl.text = "Collect Quantum Item Crates or dock with the Super Quarket Station to build synergies."
		return
	
	# Populate item buttons in grid
	for i in range(active_mods.size()):
		var mod = active_mods[i]
		var item_btn = Button.new()
		item_btn.custom_minimum_size = Vector2(50, 44)
		item_btn.focus_mode = Control.FOCUS_ALL
		
		var glyph = mod.get_glyph() if mod.has_method("get_glyph") else mod.icon_symbol
		item_btn.text = glyph
		
		var tier_col = Color(0.2, 0.85, 1.0, 1.0)
		if mod.tier == ItemModifier.ItemTier.TIER_2_PARADIGM:
			tier_col = Color(1.0, 0.85, 0.2, 1.0)
		elif mod.tier == ItemModifier.ItemTier.TIER_3_EXOTIC:
			tier_col = Color(1.0, 0.3, 0.8, 1.0)
		
		MenuStyleHelper.style_button(item_btn, tier_col)
		
		item_btn.focus_entered.connect(func(): _display_item_details(mod))
		item_btn.mouse_entered.connect(func(): _display_item_details(mod))
		relics_grid.add_child(item_btn)
	
	# Show first item by default
	_display_item_details(active_mods[0])

func _display_item_details(item: ItemModifier) -> void:
	if not item:
		return
	
	var glyph = item.get_glyph() if item.has_method("get_glyph") else item.icon_symbol
	item_title_lbl.text = "%s  %s" % [glyph, item.display_name]
	item_title_lbl.add_theme_color_override("font_color", item.icon_color)
	
	var tier_name = "TIER 1 // BALLISTIC UPGRADE"
	if item.tier == ItemModifier.ItemTier.TIER_2_PARADIGM:
		tier_name = "TIER 2 // PARADIGM SHIFT"
	elif item.tier == ItemModifier.ItemTier.TIER_3_EXOTIC:
		tier_name = "TIER 3 // EXOTIC QUANTUM RELIC"
	item_tier_lbl.text = tier_name
	item_tier_lbl.add_theme_color_override("font_color", item.icon_color)
	
	item_desc_lbl.text = item.description

func _on_master_slider_changed(val: float) -> void:
	pause_master_val.text = "%d%%" % int(val)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db = linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_sfx_slider_changed(val: float) -> void:
	pause_sfx_val.text = "%d%%" % int(val)
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		var db = linear_to_db(val / 100.0) if val > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_orient_pressed() -> void:
	GameAxis.toggle_axis()
	pause_orient_btn.text = "VERTICAL (9:16)" if GameAxis.is_vertical else "HORIZONTAL (16:9)"
	SoundEffects.play_sfx("bonus", 0.05, -4.0)

func _on_restart_pressed() -> void:
	close_pause()
	GameManager.restart_game()

func _on_main_menu_pressed() -> void:
	close_pause()
	GameManager.return_to_main_menu()
