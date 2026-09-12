class_name WaveDirector
extends Node

## WaveDirector.gd - Isaac-Style Procedural Encounter Director with 25+ Sector-Gated Wave Templates.
## Gated by Sector (1 = Perimeter, 2 = Asteroid Belt, 3 = Decoherence Core), dynamically scaling threat budgets.

# EnemyType constants (matching Enemy.gd)
const SCOUT = 0
const BOMBER = 1
const INTERCEPTOR = 2
const SNIPER = 3
const SHIELD_FRIGATE = 4
const HEAVY_CRUISER = 5
const KNIGHT_VANGUARD = 6
const PHANTOM = 7
const DRONE_CARRIER = 8
const MICRO_DRONE = 9
const TURRET_PLATFORM = 10
const WARP_STALKER = 11
const DRAINER_LEECH = 12
const MISSILE_CORVETTE = 13
const MINE_TETHER = 14
const ORBITAL_REFLECTOR = 15

# HazardType constants (matching HazardObject.gd)
const HZ_ASTEROID = 0
const HZ_PLASMA_BARREL = 1
const HZ_STORM_CELL = 2

# EliteAffix constants
const AFFIX_NONE = 0
const AFFIX_ARMORED = 1
const AFFIX_VOLATILE = 2
const AFFIX_SWIFT = 3
const AFFIX_SHIELDED = 4

enum FormationType { V_FORMATION, SINE_DIVE, PINCER_FLANK, ESCORT_COLUMN, ELITE_CHAMPION }

func select_formation_for_wave(_wave_idx: int, _budget: float = 50.0) -> FormationType:
	return FormationType.ELITE_CHAMPION

var recent_templates: Array[String] = []

static func get_all_templates() -> Array[Dictionary]:
	return [
		# ==========================================
		# --- SECTOR 1 TEMPLATES (Min Sector 1) ---
		# ==========================================
		{
			"id": "WAVE_ASTEROID_AMBUSH",
			"name": "ASTEROID AMBUSH",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 4},
				{"type": HZ_PLASMA_BARREL, "count": 1}
			],
			"spawns": [
				{"type": SCOUT, "count": 5, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "RANDOM_TOP", "delay": 2.5, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_TNT_CHAIN_REACTION",
			"name": "PLASMA BOMB SURGE",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 3},
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": MICRO_DRONE, "count": 10, "pattern": "HORIZON_SPREAD", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 4, "pattern": "RANDOM_TOP", "delay": 2.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_CAVALRY_CHARGE",
			"name": "CAVALRY CHARGE",
			"min_sector": 1,
			"hazards": [],
			"spawns": [
				{"type": INTERCEPTOR, "count": 4, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "ROW", "delay": 1.5, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "ROW", "delay": 3.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_TURRET_BASTION",
			"name": "ORBITAL BASTION",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 3}
			],
			"spawns": [
				{"type": TURRET_PLATFORM, "count": 2, "pattern": "FLANK_SPLIT", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SCOUT, "count": 6, "pattern": "RANDOM_TOP", "delay": 1.8, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_SWARM_FLASH_MOB",
			"name": "DECOHERENCE FLASH MOB",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": SCOUT, "count": 12, "pattern": "SWEEP_ROW", "delay": 0.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_INTERCEPTOR_FLANK",
			"name": "PINCER DIVE SQUAD",
			"min_sector": 1,
			"hazards": [],
			"spawns": [
				{"type": INTERCEPTOR, "count": 4, "pattern": "FLANK_LEFT", "delay": 0.0, "affix": AFFIX_SWIFT},
				{"type": INTERCEPTOR, "count": 4, "pattern": "FLANK_RIGHT", "delay": 0.0, "affix": AFFIX_SWIFT},
				{"type": BOMBER, "count": 2, "pattern": "RANDOM_TOP", "delay": 2.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_V_FORMATION_CLASSIC",
			"name": "STRIKE ECHELON",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": SCOUT, "count": 5, "pattern": "V_SHAPE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "RANDOM_TOP", "delay": 2.0, "affix": AFFIX_ARMORED}
			]
		},
		{
			"id": "WAVE_BOMBER_SIEGE",
			"name": "HEAVY BOMBER BARRAGE",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 1}
			],
			"spawns": [
				{"type": BOMBER, "count": 4, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 6, "pattern": "RANDOM_TOP", "delay": 2.0, "affix": AFFIX_NONE}
			]
		},

		# ==========================================
		# --- SECTOR 2 TEMPLATES (Min Sector 2) ---
		# ==========================================
		{
			"id": "WAVE_KNIGHT_WALL",
			"name": "AEGIS KNIGHT WALL",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 3}
			],
			"spawns": [
				{"type": KNIGHT_VANGUARD, "count": 3, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 5, "pattern": "RANDOM_TOP", "delay": 2.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_SNIPER_ALLEY",
			"name": "RAILGUN CROSSFIRE",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 5},
				{"type": HZ_STORM_CELL, "count": 1}
			],
			"spawns": [
				{"type": SNIPER, "count": 3, "pattern": "FLANK_SPLIT", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "ROW", "delay": 2.0, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_SHIELD_CONVOY",
			"name": "SHIELDED CONVOY",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": SHIELD_FRIGATE, "count": 2, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 2, "pattern": "FLANK_SPLIT", "delay": 2.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "RANDOM_TOP", "delay": 3.5, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_MISSILE_BARRAGE",
			"name": "ORDNANCE CORVETTES",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 3}
			],
			"spawns": [
				{"type": MISSILE_CORVETTE, "count": 3, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 6, "pattern": "RANDOM_TOP", "delay": 2.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_DRAINER_TRAP",
			"name": "TETHER SIPHON TRAP",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 2}
			],
			"spawns": [
				{"type": DRAINER_LEECH, "count": 2, "pattern": "FLANK_SPLIT", "delay": 0.0, "affix": AFFIX_SWIFT},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 2.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 3, "pattern": "RANDOM_TOP", "delay": 3.8, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_KNIGHT_SNIPER_PINCER",
			"name": "PHALANX & RAILGUNS",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": KNIGHT_VANGUARD, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SNIPER, "count": 2, "pattern": "FLANK_SPLIT", "delay": 1.5, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 6, "pattern": "RANDOM_TOP", "delay": 3.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_STORM_CORVETTE_FLOTILLA",
			"name": "NEBULA FLOTILLA",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 2},
				{"type": HZ_ASTEROID, "count": 4}
			],
			"spawns": [
				{"type": MISSILE_CORVETTE, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": TURRET_PLATFORM, "count": 1, "pattern": "CENTER", "delay": 1.5, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 5, "pattern": "RANDOM_TOP", "delay": 3.0, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_SHIELD_DRAINER_MATRIX",
			"name": "SIPHON SHIELD MATRIX",
			"min_sector": 2,
			"hazards": [],
			"spawns": [
				{"type": SHIELD_FRIGATE, "count": 2, "pattern": "FLANK_SPLIT", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": DRAINER_LEECH, "count": 2, "pattern": "CENTER", "delay": 2.0, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 3.5, "affix": AFFIX_VOLATILE}
			]
		},

		# ==========================================
		# --- SECTOR 3 TEMPLATES (Min Sector 3) ---
		# ==========================================
		{
			"id": "WAVE_HIVE_QUEEN",
			"name": "HIVE CARRIER SWARM",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 3}
			],
			"spawns": [
				{"type": DRONE_CARRIER, "count": 2, "pattern": "FLANK_SPLIT", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SHIELD_FRIGATE, "count": 1, "pattern": "CENTER", "delay": 1.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "RANDOM_TOP", "delay": 3.0, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_GHOST_CIRCLE",
			"name": "PHANTOM CLOAK AMBUSH",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 2}
			],
			"spawns": [
				{"type": PHANTOM, "count": 6, "pattern": "HORIZON_SPREAD", "delay": 0.0, "affix": AFFIX_SWIFT},
				{"type": SNIPER, "count": 2, "pattern": "FLANK_SPLIT", "delay": 2.5, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_DUAL_CRUISER_ESCORT",
			"name": "BATTLECRUISER ARMADA",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 4}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 2, "pattern": "FLANK_SPLIT", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SHIELD_FRIGATE, "count": 1, "pattern": "CENTER", "delay": 1.5, "affix": AFFIX_NONE},
				{"type": KNIGHT_VANGUARD, "count": 2, "pattern": "ROW", "delay": 3.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_WARP_STORM",
			"name": "QUANTUM WARP STORM",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 3}
			],
			"spawns": [
				{"type": WARP_STALKER, "count": 4, "pattern": "SWEEP_ROW", "delay": 0.0, "affix": AFFIX_VOLATILE},
				{"type": INTERCEPTOR, "count": 6, "pattern": "ROW", "delay": 2.0, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_DECOHERENCE_SINGULARITY",
			"name": "EVENT HORIZON GAUNTLET",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 3},
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 1, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": DRONE_CARRIER, "count": 1, "pattern": "FLANK_LEFT", "delay": 1.5, "affix": AFFIX_NONE},
				{"type": PHANTOM, "count": 4, "pattern": "HORIZON_SPREAD", "delay": 3.0, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 2, "pattern": "FLANK_RIGHT", "delay": 4.5, "affix": AFFIX_VOLATILE}
			]
		},
		{
			"id": "WAVE_MINEFIELD_PHALANX",
			"name": "ELECTRO-MINE PHALANX",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 5}
			],
			"spawns": [
				{"type": MINE_TETHER, "count": 4, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_VOLATILE},
				{"type": KNIGHT_VANGUARD, "count": 3, "pattern": "ROW", "delay": 2.0, "affix": AFFIX_ARMORED},
				{"type": DRAINER_LEECH, "count": 2, "pattern": "FLANK_SPLIT", "delay": 3.5, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_TITAN_VANGUARD",
			"name": "OUROBOROS VANGUARD",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 3}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 2, "pattern": "FLANK_SPLIT", "delay": 0.0, "affix": AFFIX_VOLATILE},
				{"type": MISSILE_CORVETTE, "count": 2, "pattern": "ROW", "delay": 2.0, "affix": AFFIX_ARMORED},
				{"type": WARP_STALKER, "count": 3, "pattern": "SWEEP_ROW", "delay": 4.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_HIVE_DRAINER_INFERNO",
			"name": "DEEP VOID INFERNO",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 2},
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": DRONE_CARRIER, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": DRAINER_LEECH, "count": 2, "pattern": "FLANK_SPLIT", "delay": 2.0, "affix": AFFIX_SWIFT},
				{"type": PHANTOM, "count": 4, "pattern": "HORIZON_SPREAD", "delay": 3.5, "affix": AFFIX_VOLATILE}
			]
		},
		{
			"id": "WAVE_ANOMALY_NEXUS",
			"name": "QUANTUM ANOMALY NEXUS",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 2},
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 1, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": MINE_TETHER, "count": 3, "pattern": "ROW", "delay": 2.0, "affix": AFFIX_VOLATILE},
				{"type": WARP_STALKER, "count": 3, "pattern": "SWEEP_ROW", "delay": 3.5, "affix": AFFIX_SWIFT}
			]
		}
	]

func select_template_for_wave(sector_idx: int, wave_idx: int) -> Dictionary:
	var all = get_all_templates()
	var eligible: Array[Dictionary] = []

	# Filter templates matching sector difficulty
	for t in all:
		var min_s = t.get("min_sector", 1)
		# Sector 1 only plays min_sector 1
		# Sector 2 plays min_sector 1 and 2
		# Sector 3 plays min_sector 2 and 3
		if sector_idx == 1 and min_s == 1:
			eligible.append(t)
		elif sector_idx == 2 and (min_s == 1 or min_s == 2):
			eligible.append(t)
		elif sector_idx >= 3 and (min_s == 2 or min_s == 3):
			eligible.append(t)

	# Avoid recently played templates to guarantee fresh encounters
	var unplayed: Array[Dictionary] = []
	for t in eligible:
		if not recent_templates.has(t["id"]):
			unplayed.append(t)

	if unplayed.is_empty():
		recent_templates.clear()
		unplayed = eligible

	unplayed.shuffle()
	var chosen = unplayed[0]
	recent_templates.append(chosen["id"])
	if recent_templates.size() > 6:
		recent_templates.pop_front()

	return _mutate_template(chosen, sector_idx)

func _mutate_template(template: Dictionary, sector_idx: int) -> Dictionary:
	var mutated = template.duplicate(true)
	
	# Sector-appropriate enemy pools for wildcard swaps
	var s1_pool = [SCOUT, BOMBER, INTERCEPTOR, TURRET_PLATFORM, MICRO_DRONE]
	var s2_pool = [SCOUT, BOMBER, INTERCEPTOR, TURRET_PLATFORM, MICRO_DRONE, SNIPER, SHIELD_FRIGATE, KNIGHT_VANGUARD, MISSILE_CORVETTE, DRAINER_LEECH]
	var s3_pool = [SCOUT, BOMBER, INTERCEPTOR, TURRET_PLATFORM, MICRO_DRONE, SNIPER, SHIELD_FRIGATE, KNIGHT_VANGUARD, MISSILE_CORVETTE, DRAINER_LEECH, HEAVY_CRUISER, PHANTOM, DRONE_CARRIER, WARP_STALKER, MINE_TETHER]
	var current_pool = s1_pool if sector_idx == 1 else (s2_pool if sector_idx == 2 else s3_pool)
	
	var elite_chance = 0.10 if sector_idx == 1 else (0.30 if sector_idx == 2 else 0.55)
	var possible_affixes = [AFFIX_ARMORED, AFFIX_VOLATILE, AFFIX_SWIFT, AFFIX_SHIELDED]
	
	# 1. Procedural Spawn Batch Mutation (Wildcards & Elite Promotions)
	var spawns = mutated.get("spawns", [])
	for batch in spawns:
		# Wildcard swap (35% chance)
		if randf() < 0.35 and not current_pool.is_empty():
			current_pool.shuffle()
			batch["type"] = current_pool[0]
		
		# Elite Affix Promotion
		if randf() < elite_chance and batch.get("affix", 0) == 0 and batch["type"] != MICRO_DRONE:
			possible_affixes.shuffle()
			batch["affix"] = possible_affixes[0]
		
		# Timing jitter
		if batch.has("delay"):
			batch["delay"] = maxf(0.0, batch["delay"] + randf_range(-0.3, 0.3))
	
	# 2. Procedural Hazard Mutation
	var hazards = mutated.get("hazards", [])
	if randf() < 0.35:
		var bonus_hazard = HZ_ASTEROID if randf() > 0.5 else HZ_PLASMA_BARREL
		hazards.append({"type": bonus_hazard, "count": randi_range(1, 2)})
		mutated["hazards"] = hazards
	
	return mutated

func calculate_wave_budget(sector_idx: int, wave_idx: int, players: Array) -> float:
	var base_budget = 45.0
	var sector_mult = 1.0 + (sector_idx - 1) * 0.85
	var wave_mult = 1.0 + (wave_idx - 1) * 0.18

	var total_mods = 0
	for p in players:
		if is_instance_valid(p) and p.get("active_modifiers") != null:
			total_mods += p.active_modifiers.size()

	var synergy_scale = 1.0 + clampf(total_mods * 0.06, 0.0, 1.5)
	return base_budget * sector_mult * wave_mult * synergy_scale
