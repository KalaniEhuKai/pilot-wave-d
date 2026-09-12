class_name WaveDirector
extends Node

## WaveDirector.gd - Adaptive Threat Budget Director.
## Calculates real-time threat point budget based on sector difficulty and player synergy power,
## selecting combinatorial flight formations for the Decoherence Spawner.

enum FormationType { V_FORMATION, SINE_DIVE, PINCER_FLANK, ESCORT_COLUMN, ELITE_CHAMPION }

@export var base_sector_budget: float = 50.0

func calculate_wave_budget(sector_idx: int, wave_idx: int, players: Array) -> float:
	var sector_mult = 1.0 + (sector_idx - 1) * 0.45
	var wave_mult = 1.0 + (wave_idx - 1) * 0.22
	
	# Evaluate player DPS scale based on active modifiers
	var total_mods = 0
	for p in players:
		if is_instance_valid(p) and p.get("active_modifiers") != null:
			total_mods += p.active_modifiers.size()
	
	var synergy_scale = 1.0 + clampf(total_mods * 0.08, 0.0, 1.2)
	return base_sector_budget * sector_mult * wave_mult * synergy_scale

func select_formation_for_wave(wave_idx: int, _budget: float) -> FormationType:
	# Wave 4 is guaranteed elite champion encounter
	if wave_idx % 4 == 0:
		return FormationType.ELITE_CHAMPION
	
	# Weighted procedural selection among dynamic formations
	var roll = (wave_idx + randi()) % 4
	match roll:
		0: return FormationType.V_FORMATION
		1: return FormationType.SINE_DIVE
		2: return FormationType.PINCER_FLANK
		3: return FormationType.ESCORT_COLUMN
		_: return FormationType.V_FORMATION
