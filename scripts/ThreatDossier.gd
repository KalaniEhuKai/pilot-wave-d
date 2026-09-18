extends CanvasLayer

## ThreatDossier.gd - Cyberpunk holographic flight computer briefing card shown at sector launch.

const MenuStyleHelper = preload("res://scripts/MenuStyleHelper.gd")

signal mission_engaged()

@onready var panel: Control = $Panel
@onready var sector_label: Label = $Panel/VBox/HeaderBox/SectorLabel
@onready var boss_label: Label = $Panel/VBox/BossLabel
@onready var hazards_label: Label = $Panel/VBox/HazardsLabel
@onready var directive_label: Label = $Panel/VBox/DirectiveLabel
@onready var engage_btn: Button = $Panel/VBox/EngageBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	engage_btn.focus_mode = Control.FOCUS_ALL
	MenuStyleHelper.style_button(engage_btn, Color(0.1, 0.95, 1.0, 1.0))
	engage_btn.pressed.connect(_on_engage_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("fire") or event.is_action_pressed("p2_fire") or event.is_action_pressed("ui_accept"):
		_on_engage_pressed()
		get_viewport().set_input_as_handled()

func show_dossier(sector_num: int, boss_name: String) -> void:
	panel.visible = true
	get_tree().paused = true
	engage_btn.grab_focus()
	
	sector_label.text = "SECTOR 0%d: QUANTUM DECOHERENCE BASIN" % sector_num
	boss_label.text = "FLAGSHIP TARGET: " + boss_name.to_upper()
	
	if "GOLIATH" in boss_name.to_upper():
		hazards_label.text = "HAZARDS: Triple Railgun Sweeps // Carrier Fighter Bays // Heavy Bow Armor"
		directive_label.text = "TACTICAL DIRECTIVE:\nBreak Bow Armor plates to expose the fusion reactor. Evade sweeping railgun targeting lasers."
	else:
		hazards_label.text = "HAZARDS: Alternating Wing Batteries // Wing Fracture Flak // Phase 2 Dorsal Missiles"
		directive_label.text = "TACTICAL DIRECTIVE:\nVaporize Port & Starboard wings to break sweeping crossfire. Evade fracture flak and roll through Phase 2 homing missiles."
	
	SoundEffects.play_sfx("bonus", 0.05, 2.0)

func _on_engage_pressed() -> void:
	panel.visible = false
	get_tree().paused = false
	
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	
	mission_engaged.emit()
	SoundEffects.play_sfx("laser", 0.1, 1.0)
