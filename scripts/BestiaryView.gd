extends Panel

## BestiaryView.gd - Hostile Archive & Bestiary interface for Main Menu.
## Provides simple ship selection, real-time live firing simulation, and tactical behavior dossiers.

const MenuStyleHelper = preload("res://scripts/MenuStyleHelper.gd")
const BestiaryDataScript = preload("res://scripts/BestiaryData.gd")

signal back_pressed()

@onready var ship_list_vbox: VBoxContainer = $VBox/MainHBox/LeftPanel/Scroll/ShipListVBox
@onready var simulation = $VBox/MainHBox/RightPanel/SimContainer/BestiarySimulation
@onready var ship_title_lbl: Label = $VBox/MainHBox/RightPanel/DescPanel/VBox/TitleRow/ShipTitleLbl
@onready var sector_badge_lbl: Label = $VBox/MainHBox/RightPanel/DescPanel/VBox/TitleRow/SectorBadgeLbl
@onready var desc_text: RichTextLabel = $VBox/MainHBox/RightPanel/DescPanel/VBox/DescText
@onready var btn_prev: Button = $VBox/BottomRow/BtnPrev
@onready var btn_next: Button = $VBox/BottomRow/BtnNext
@onready var index_lbl: Label = $VBox/BottomRow/IndexLbl
@onready var btn_back: Button = $VBox/BottomRow/BtnBack

var entries: Array[Dictionary] = []
var current_index: int = 0
var ship_buttons: Array[Button] = []

func _ready() -> void:
	entries = BestiaryDataScript.get_all_entries()
	_apply_styles()
	_populate_ship_list()
	
	btn_prev.pressed.connect(_on_prev_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	if entries.size() > 0:
		current_index = 0
		var entry = entries[0]
		ship_title_lbl.text = "THREAT DOSSIER // " + entry.get("name", "")
		sector_badge_lbl.text = "ENCOUNTER: " + entry.get("sector_spawn", "Sector 1+")
		desc_text.text = entry.get("description", "")
		index_lbl.text = "CRAFT 1 / %d" % entries.size()
		_update_button_highlights()

func _apply_styles() -> void:
	var cyan = Color(0.2, 0.85, 1.0, 1.0)
	var magenta = Color(1.0, 0.3, 0.6, 1.0)
	MenuStyleHelper.style_button(btn_prev, cyan)
	MenuStyleHelper.style_button(btn_next, cyan)
	MenuStyleHelper.style_button(btn_back, magenta)

func _populate_ship_list() -> void:
	for child in ship_list_vbox.get_children():
		ship_list_vbox.remove_child(child)
		child.queue_free()
	ship_buttons.clear()
	
	for i in range(entries.size()):
		var entry = entries[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 32)
		btn.text = entry.get("name", "UNKNOWN")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		
		var idx = i
		btn.pressed.connect(func():
			select_ship(idx)
			SoundEffects.play_sfx("ui_select", 0.02, -3.0)
		)
		
		ship_list_vbox.add_child(btn)
		ship_buttons.append(btn)
	
	_update_button_highlights()

func select_ship(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	current_index = index
	var entry = entries[index]
	
	# Update Title & Description
	ship_title_lbl.text = "THREAT DOSSIER // " + entry.get("name", "")
	sector_badge_lbl.text = "ENCOUNTER: " + entry.get("sector_spawn", "Sector 1+").to_upper()
	desc_text.text = entry.get("description", "")
	index_lbl.text = "CRAFT %d / %d" % [index + 1, entries.size()]
	
	# Update Simulation
	if is_instance_valid(simulation):
		simulation.load_entry(entry)
	
	_update_button_highlights()

func _update_button_highlights() -> void:
	var active_cyan = Color(0.2, 0.95, 1.0, 1.0)
	var inactive_slate = Color(0.4, 0.48, 0.58, 0.75)
	
	for i in range(ship_buttons.size()):
		var btn = ship_buttons[i]
		if i == current_index:
			btn.text = "► " + entries[i].get("name", "")
			MenuStyleHelper.style_button(btn, active_cyan)
		else:
			btn.text = "  " + entries[i].get("name", "")
			MenuStyleHelper.style_button(btn, inactive_slate)

func _on_prev_pressed() -> void:
	var new_idx = current_index - 1
	if new_idx < 0:
		new_idx = entries.size() - 1
	select_ship(new_idx)
	if new_idx < ship_buttons.size():
		ship_buttons[new_idx].grab_focus()
	SoundEffects.play_sfx("ui_select", 0.02, -3.0)

func _on_next_pressed() -> void:
	var new_idx = current_index + 1
	if new_idx >= entries.size():
		new_idx = 0
	select_ship(new_idx)
	if new_idx < ship_buttons.size():
		ship_buttons[new_idx].grab_focus()
	SoundEffects.play_sfx("ui_select", 0.02, -3.0)

func _on_back_pressed() -> void:
	SoundEffects.play_sfx("ui_back", 0.05, -3.0)
	back_pressed.emit()

func on_activated() -> void:
	if is_instance_valid(simulation):
		simulation.activate_simulation()
	if current_index >= 0 and current_index < ship_buttons.size():
		ship_buttons[current_index].grab_focus()
		select_ship(current_index)

func on_deactivated() -> void:
	if is_instance_valid(simulation):
		simulation.deactivate_simulation()
