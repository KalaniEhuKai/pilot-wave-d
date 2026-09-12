extends CanvasLayer

## ThreatDossier.gd - Cyberpunk holographic flight computer briefing card shown at sector launch.

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
	engage_btn.focus_mode = Control.FOCUS_NONE
	engage_btn.pressed.connect(_on_engage_pressed)

func show_dossier(sector_num: int, boss_name: String) -> void:
	panel.visible = true
	get_tree().paused = true
	
	sector_label.text = "SECTOR 0%d: QUANTUM DECOHERENCE BASIN" % sector_num
	boss_label.text = "FLAGSHIP TARGET: " + boss_name.to_upper()
	
	if "GOLIATH" in boss_name.to_upper():
		hazards_label.text = "HAZARDS: Triple Railgun Sweeps // Carrier Fighter Bays // Heavy Bow Armor"
		directive_label.text = "TACTICAL DIRECTIVE:\nBreak Bow Armor plates to expose the fusion reactor. Evade sweeping railgun targeting lasers."
	else:
		hazards_label.text = "HAZARDS: Subsystem Wing Batteries // Spiral Bullet Vortex // High-Speed Strafing"
		directive_label.text = "TACTICAL DIRECTIVE:\nVaporize Port & Starboard wing batteries to strip armor. Target singularity core during Phase 2 enrage."
	
	SoundEffects.play_sfx("bonus", 0.05, 2.0)

func _on_engage_pressed() -> void:
	panel.visible = false
	get_tree().paused = false
	
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	
	mission_engaged.emit()
	SoundEffects.play_sfx("laser", 0.1, 1.0)
