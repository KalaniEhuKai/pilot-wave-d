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
const CARGO_HAULER = 15

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

# Canonical Archetype Threat Point Costs
const ARCHETYPE_THREAT_COSTS: Dictionary = {
	SCOUT: 1.0,           # Baseline light skirmisher (shoots 2 basic shots)
	BOMBER: 3.0,          # Heavy artillery / mortar bomber
	INTERCEPTOR: 2.0,     # Agile curving flanker
	SNIPER: 3.5,          # High-velocity railgun sentry
	SHIELD_FRIGATE: 4.5,  # Area forcefield projection
	HEAVY_CRUISER: 8.0,   # Capital warship
	KNIGHT_VANGUARD: 3.5, # Armored mirror shield
	PHANTOM: 3.5,         # Cloaking phase assassin
	DRONE_CARRIER: 6.0,   # Deployer platform
	MICRO_DRONE: 0.4,     # Swarm popcorn drone (non-shooting)
	TURRET_PLATFORM: 3.5, # Heavy stationary emplacement
	WARP_STALKER: 3.5,    # Teleporting ambush raider
	DRAINER_LEECH: 2.5,   # Lateral homing energy siphon
	MISSILE_CORVETTE: 4.0,# Heavy homing salvo
	MINE_TETHER: 2.0,     # Spatial area denial
	CARGO_HAULER: 2.0,    # Valuable convoy transport
}

static func get_archetype_threat(type: int) -> float:
	return ARCHETYPE_THREAT_COSTS.get(type, 2.0)

static func calculate_batch_threat(type: int, count: int, affix: int = 0) -> float:
	var base_threat = get_archetype_threat(type) * float(count)
	return base_threat * (1.5 if affix != 0 else 1.0)

static func calculate_template_threat(template: Dictionary) -> float:
	var total = 0.0
	for batch in template.get("spawns", []):
		total += calculate_batch_threat(batch.get("type", 0), batch.get("count", 1), batch.get("affix", 0))
	return total

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
			"id": "WAVE_FIRST_CONTACT",
			"name": "FIRST CONTACT",
			"min_sector": 1,
			"hazards": [],
			"spawns": [
				{"type": SCOUT, "count": 4, "pattern": "V_SHAPE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 4, "pattern": "ROW", "delay": 2.2, "affix": AFFIX_NONE},
				{"type": MICRO_DRONE, "count": 6, "pattern": "HORIZON_SPREAD", "delay": 4.2, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 4, "pattern": "SWEEP_ROW", "delay": 5.8, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_ASTEROID_AMBUSH",
			"name": "ASTEROID AMBUSH",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 3},
				{"type": HZ_PLASMA_BARREL, "count": 1}
			],
			"spawns": [
				{"type": SCOUT, "count": 7, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 4.8, "affix": AFFIX_NONE},
				{"type": MICRO_DRONE, "count": 12, "pattern": "HORIZON_SPREAD", "delay": 6.6, "affix": AFFIX_NONE}
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
				{"type": MICRO_DRONE, "count": 12, "pattern": "HORIZON_SPREAD", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 7, "pattern": "V_SHAPE", "delay": 1.8, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 4.4, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 6.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_CAVALRY_CHARGE",
			"name": "CAVALRY CHARGE",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": INTERCEPTOR, "count": 3, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "SWEEP_ROW", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 7, "pattern": "V_SHAPE", "delay": 4.5, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_TURRET_BASTION",
			"name": "ORBITAL BASTION",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 2},
				{"type": HZ_PLASMA_BARREL, "count": 1}
			],
			"spawns": [
				{"type": TURRET_PLATFORM, "count": 1, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 8, "pattern": "ROW", "delay": 1.6, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 4.6, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "HORIZON_SPREAD", "delay": 6.6, "affix": AFFIX_NONE}
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
				{"type": SCOUT, "count": 8, "pattern": "SWEEP_ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": MICRO_DRONE, "count": 16, "pattern": "HORIZON_SPREAD", "delay": 3.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "PINCER_CONVERGE", "delay": 4.8, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 6.6, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_INTERCEPTOR_FLANK",
			"name": "PINCER DIVE SQUAD",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": INTERCEPTOR, "count": 3, "pattern": "UPPER_CORRIDOR", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 3, "pattern": "LOWER_CORRIDOR", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 7, "pattern": "V_SHAPE", "delay": 1.8, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 4.4, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 3, "pattern": "ROW", "delay": 6.2, "affix": AFFIX_NONE}
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
				{"type": SCOUT, "count": 7, "pattern": "V_SHAPE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 2.6, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "SWEEP_ROW", "delay": 4.4, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 8, "pattern": "HORIZON_SPREAD", "delay": 6.6, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_BOMBER_SIEGE",
			"name": "HEAVY BOMBER BARRAGE",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 2},
				{"type": HZ_ASTEROID, "count": 1}
			],
			"spawns": [
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 8, "pattern": "HORIZON_SPREAD", "delay": 1.6, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 4.6, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "SWEEP_ROW", "delay": 6.6, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_SNIPER_PERIMETER",
			"name": "RAILGUN OUTPOST",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": SNIPER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "SWEEP_ROW", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 7, "pattern": "V_SHAPE", "delay": 4.6, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_AEGIS_PHALANX",
			"name": "AEGIS STRIKE PHALANX",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 1},
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": KNIGHT_VANGUARD, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "PINCER_CONVERGE", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 7, "pattern": "HORIZON_SPREAD", "delay": 4.6, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_CORVETTE_PATROL",
			"name": "ORDNANCE PATROL",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": MISSILE_CORVETTE, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "SWEEP_ROW", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "HORIZON_SPREAD", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 7, "pattern": "ROW", "delay": 4.6, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_CORVUS_VANGUARD",
			"name": "DREADNOUGHT VANGUARD",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 2},
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": KNIGHT_VANGUARD, "count": 1, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SNIPER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 1.3, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 2.6, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 5, "pattern": "SWEEP_ROW", "delay": 4.0, "affix": AFFIX_SWIFT}
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
				{"type": HZ_ASTEROID, "count": 4}
			],
			"spawns": [
				{"type": KNIGHT_VANGUARD, "count": 3, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SCOUT, "count": 9, "pattern": "HORIZON_SPREAD", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": KNIGHT_VANGUARD, "count": 2, "pattern": "CENTER", "delay": 4.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "ROW", "delay": 4.4, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_SNIPER_ALLEY",
			"name": "RAILGUN CROSSFIRE",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 5},
				{"type": HZ_STORM_CELL, "count": 2}
			],
			"spawns": [
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 5, "pattern": "SWEEP_ROW", "delay": 1.3, "affix": AFFIX_SWIFT},
				{"type": SNIPER, "count": 2, "pattern": "CENTER", "delay": 2.6, "affix": AFFIX_ARMORED},
				{"type": SCOUT, "count": 9, "pattern": "V_SHAPE", "delay": 3.9, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 4.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_SHIELD_CONVOY",
			"name": "SHIELDED CONVOY",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 3},
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": SHIELD_FRIGATE, "count": 2, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 1.3, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 6, "pattern": "ROW", "delay": 2.6, "affix": AFFIX_SWIFT},
				{"type": SHIELD_FRIGATE, "count": 1, "pattern": "CENTER", "delay": 3.9, "affix": AFFIX_ARMORED},
				{"type": BOMBER, "count": 4, "pattern": "ROW", "delay": 4.3, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_MISSILE_BARRAGE",
			"name": "ORDNANCE CORVETTES",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 4}
			],
			"spawns": [
				{"type": MISSILE_CORVETTE, "count": 3, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 9, "pattern": "HORIZON_SPREAD", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": MISSILE_CORVETTE, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 2.8, "affix": AFFIX_ARMORED},
				{"type": INTERCEPTOR, "count": 6, "pattern": "SWEEP_ROW", "delay": 4.2, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_DRAINER_TRAP",
			"name": "TETHER SIPHON TRAP",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 2},
				{"type": HZ_ASTEROID, "count": 3}
			],
			"spawns": [
				{"type": DRAINER_LEECH, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 0.0, "affix": AFFIX_SWIFT},
				{"type": BOMBER, "count": 4, "pattern": "ROW", "delay": 1.3, "affix": AFFIX_NONE},
				{"type": DRAINER_LEECH, "count": 2, "pattern": "CENTER", "delay": 2.6, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 5, "pattern": "ROW", "delay": 2.9, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 4.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_KNIGHT_SNIPER_PINCER",
			"name": "PHALANX & RAILGUNS",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 3}
			],
			"spawns": [
				{"type": KNIGHT_VANGUARD, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 1.3, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 9, "pattern": "V_SHAPE", "delay": 2.6, "affix": AFFIX_NONE},
				{"type": KNIGHT_VANGUARD, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 3.9, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "ROW", "delay": 4.2, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_STORM_CORVETTE_FLOTILLA",
			"name": "NEBULA FLOTILLA",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 3},
				{"type": HZ_ASTEROID, "count": 4}
			],
			"spawns": [
				{"type": MISSILE_CORVETTE, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": TURRET_PLATFORM, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 1.3, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 6, "pattern": "HORIZON_SPREAD", "delay": 2.6, "affix": AFFIX_SWIFT},
				{"type": MISSILE_CORVETTE, "count": 2, "pattern": "CENTER", "delay": 3.9, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 4.3, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_SHIELD_DRAINER_MATRIX",
			"name": "SIPHON SHIELD MATRIX",
			"min_sector": 2,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 2},
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": SHIELD_FRIGATE, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": DRAINER_LEECH, "count": 2, "pattern": "CENTER", "delay": 1.3, "affix": AFFIX_SWIFT},
				{"type": BOMBER, "count": 4, "pattern": "ROW", "delay": 2.6, "affix": AFFIX_VOLATILE},
				{"type": INTERCEPTOR, "count": 6, "pattern": "SWEEP_ROW", "delay": 4.2, "affix": AFFIX_NONE}
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
				{"type": HZ_PLASMA_BARREL, "count": 3},
				{"type": HZ_STORM_CELL, "count": 2}
			],
			"spawns": [
				{"type": DRONE_CARRIER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SHIELD_FRIGATE, "count": 2, "pattern": "CENTER", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 6, "pattern": "HORIZON_SPREAD", "delay": 2.8, "affix": AFFIX_SWIFT},
				{"type": DRONE_CARRIER, "count": 1, "pattern": "CENTER", "delay": 4.2, "affix": AFFIX_NONE},
				{"type": PHANTOM, "count": 4, "pattern": "ROW", "delay": 4.5, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_GHOST_CIRCLE",
			"name": "PHANTOM CLOAK AMBUSH",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 3}
			],
			"spawns": [
				{"type": PHANTOM, "count": 6, "pattern": "HORIZON_SPREAD", "delay": 0.0, "affix": AFFIX_SWIFT},
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 1.3, "affix": AFFIX_NONE},
				{"type": PHANTOM, "count": 6, "pattern": "SWEEP_ROW", "delay": 2.6, "affix": AFFIX_NONE},
				{"type": WARP_STALKER, "count": 3, "pattern": "CENTER", "delay": 3.9, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 5, "pattern": "ROW", "delay": 4.2, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_DUAL_CRUISER_ESCORT",
			"name": "BATTLECRUISER ARMADA",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 4},
				{"type": HZ_PLASMA_BARREL, "count": 2}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": SHIELD_FRIGATE, "count": 2, "pattern": "CENTER", "delay": 1.4, "affix": AFFIX_NONE},
				{"type": KNIGHT_VANGUARD, "count": 3, "pattern": "ROW", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 6, "pattern": "SWEEP_ROW", "delay": 4.3, "affix": AFFIX_SWIFT}
			]
		},
		{
			"id": "WAVE_WARP_STORM",
			"name": "QUANTUM WARP STORM",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 4},
				{"type": HZ_STORM_CELL, "count": 2}
			],
			"spawns": [
				{"type": WARP_STALKER, "count": 4, "pattern": "SWEEP_ROW", "delay": 0.0, "affix": AFFIX_VOLATILE},
				{"type": INTERCEPTOR, "count": 6, "pattern": "ROW", "delay": 1.3, "affix": AFFIX_SWIFT},
				{"type": WARP_STALKER, "count": 4, "pattern": "PINCER_CONVERGE", "delay": 2.6, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 4, "pattern": "ROW", "delay": 3.9, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 4.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_DECOHERENCE_SINGULARITY",
			"name": "EVENT HORIZON GAUNTLET",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 3},
				{"type": HZ_PLASMA_BARREL, "count": 3}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 1, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": DRONE_CARRIER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 1.3, "affix": AFFIX_NONE},
				{"type": PHANTOM, "count": 5, "pattern": "HORIZON_SPREAD", "delay": 2.6, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 3.9, "affix": AFFIX_VOLATILE},
				{"type": WARP_STALKER, "count": 3, "pattern": "ROW", "delay": 4.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_MINEFIELD_PHALANX",
			"name": "ELECTRO-MINE PHALANX",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 5},
				{"type": HZ_STORM_CELL, "count": 2}
			],
			"spawns": [
				{"type": MINE_TETHER, "count": 4, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_VOLATILE},
				{"type": KNIGHT_VANGUARD, "count": 3, "pattern": "ROW", "delay": 1.3, "affix": AFFIX_ARMORED},
				{"type": DRAINER_LEECH, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 2.6, "affix": AFFIX_SWIFT},
				{"type": MISSILE_CORVETTE, "count": 4, "pattern": "ROW", "delay": 4.2, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_TITAN_VANGUARD",
			"name": "OUROBOROS VANGUARD",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 3},
				{"type": HZ_ASTEROID, "count": 3}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 0.0, "affix": AFFIX_VOLATILE},
				{"type": MISSILE_CORVETTE, "count": 3, "pattern": "ROW", "delay": 1.4, "affix": AFFIX_ARMORED},
				{"type": WARP_STALKER, "count": 4, "pattern": "SWEEP_ROW", "delay": 2.8, "affix": AFFIX_NONE},
				{"type": SHIELD_FRIGATE, "count": 2, "pattern": "CENTER", "delay": 4.2, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "ROW", "delay": 4.5, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_HIVE_DRAINER_INFERNO",
			"name": "DEEP VOID INFERNO",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 3},
				{"type": HZ_PLASMA_BARREL, "count": 3}
			],
			"spawns": [
				{"type": DRONE_CARRIER, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": DRAINER_LEECH, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 1.3, "affix": AFFIX_SWIFT},
				{"type": PHANTOM, "count": 6, "pattern": "HORIZON_SPREAD", "delay": 2.6, "affix": AFFIX_VOLATILE},
				{"type": HEAVY_CRUISER, "count": 1, "pattern": "CENTER", "delay": 4.2, "affix": AFFIX_ARMORED}
			]
		},
		{
			"id": "WAVE_ANOMALY_NEXUS",
			"name": "QUANTUM ANOMALY NEXUS",
			"min_sector": 3,
			"hazards": [
				{"type": HZ_STORM_CELL, "count": 3},
				{"type": HZ_PLASMA_BARREL, "count": 3}
			],
			"spawns": [
				{"type": HEAVY_CRUISER, "count": 1, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_ARMORED},
				{"type": MINE_TETHER, "count": 4, "pattern": "ROW", "delay": 1.3, "affix": AFFIX_VOLATILE},
				{"type": WARP_STALKER, "count": 4, "pattern": "SWEEP_ROW", "delay": 2.6, "affix": AFFIX_SWIFT},
				{"type": DRONE_CARRIER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 4.2, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 3, "pattern": "PINCER_CONVERGE", "delay": 4.5, "affix": AFFIX_NONE}
			]
		},
		# --- MILESTONE CARGO HAULER TEMPLATES ---
		{
			"id": "WAVE_CARGO_RECON",
			"name": "CARGO RECONNAISSANCE",
			"min_sector": 1,
			"hazards": [],
			"spawns": [
				{"type": SCOUT, "count": 7, "pattern": "V_SHAPE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": CARGO_HAULER, "count": 1, "pattern": "CENTER", "delay": 2.2, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 3.8, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 8, "pattern": "SWEEP_ROW", "delay": 5.4, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_CARGO_CONVOY_1",
			"name": "RELIC CONVOY INTERCEPTION",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 2}
			],
			"spawns": [
				{"type": SCOUT, "count": 7, "pattern": "V_SHAPE", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": CARGO_HAULER, "count": 1, "pattern": "CENTER", "delay": 2.2, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "PINCER_CONVERGE", "delay": 3.6, "affix": AFFIX_SWIFT},
				{"type": BOMBER, "count": 2, "pattern": "ROW", "delay": 5.0, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 7, "pattern": "ROW", "delay": 6.6, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_CARGO_CONVOY_2",
			"name": "ARMORED RELIC CONVOY",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_PLASMA_BARREL, "count": 1}
			],
			"spawns": [
				{"type": SHIELD_FRIGATE, "count": 1, "pattern": "CENTER", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": CARGO_HAULER, "count": 1, "pattern": "CENTER", "delay": 0.8, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 5, "pattern": "ROW", "delay": 1.8, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "SWEEP_ROW", "delay": 3.0, "affix": AFFIX_NONE},
				{"type": SNIPER, "count": 2, "pattern": "PINCER_CONVERGE", "delay": 4.0, "affix": AFFIX_NONE}
			]
		},
		{
			"id": "WAVE_CARGO_SUPPLY",
			"name": "DEEP SPACE SUPPLY RUN",
			"min_sector": 1,
			"hazards": [
				{"type": HZ_ASTEROID, "count": 3}
			],
			"spawns": [
				{"type": TURRET_PLATFORM, "count": 2, "pattern": "ROW", "delay": 0.0, "affix": AFFIX_NONE},
				{"type": CARGO_HAULER, "count": 1, "pattern": "CENTER", "delay": 1.0, "affix": AFFIX_NONE},
				{"type": BOMBER, "count": 3, "pattern": "ROW", "delay": 2.2, "affix": AFFIX_NONE},
				{"type": INTERCEPTOR, "count": 4, "pattern": "PINCER_CONVERGE", "delay": 3.6, "affix": AFFIX_NONE},
				{"type": SCOUT, "count": 8, "pattern": "SWEEP_ROW", "delay": 5.2, "affix": AFFIX_NONE}
			]
		}
	]

func select_template_for_wave(sector_idx: int, wave_idx: int) -> Dictionary:
	var all = get_all_templates()
	var wave_in_sec = ((wave_idx - 1) % 12) + 1

	# Dedicated gentle introductory wave for Sector 1, Wave 1
	if sector_idx == 1 and wave_in_sec == 1:
		for t in all:
			if t.get("id") == "WAVE_FIRST_CONTACT":
				return t.duplicate(true)

	# Dedicated milestone Quantum Cargo Hauler encounters
	if sector_idx == 1:
		if wave_in_sec == 2:
			for t in all:
				if t.get("id") == "WAVE_CARGO_RECON":
					return _mutate_template(t, sector_idx, wave_idx)
		elif wave_in_sec == 4:
			for t in all:
				if t.get("id") == "WAVE_CARGO_CONVOY_1":
					return _mutate_template(t, sector_idx, wave_idx)
		elif wave_in_sec == 8:
			for t in all:
				if t.get("id") == "WAVE_CARGO_CONVOY_2":
					return _mutate_template(t, sector_idx, wave_idx)
		elif wave_in_sec == 10:
			for t in all:
				if t.get("id") == "WAVE_CARGO_SUPPLY":
					return _mutate_template(t, sector_idx, wave_idx)
	elif sector_idx == 2:
		# Sector 2 milestone cargo encounters feature advanced escorts
		if wave_in_sec == 2:
			for t in all:
				if t.get("id") == "WAVE_CARGO_CONVOY_2":
					return _mutate_template(t, sector_idx, wave_idx)
		elif wave_in_sec in [4, 8, 10]:
			for t in all:
				if t.get("id") == "WAVE_CARGO_SUPPLY":
					return _mutate_template(t, sector_idx, wave_idx)

	var s1_early_ids = [
		"WAVE_ASTEROID_AMBUSH", "WAVE_TNT_CHAIN_REACTION", "WAVE_CAVALRY_CHARGE",
		"WAVE_TURRET_BASTION", "WAVE_SWARM_FLASH_MOB", "WAVE_INTERCEPTOR_FLANK",
		"WAVE_V_FORMATION_CLASSIC", "WAVE_BOMBER_SIEGE"
	]
	var s1_late_ids = [
		"WAVE_SNIPER_PERIMETER", "WAVE_AEGIS_PHALANX", "WAVE_CORVETTE_PATROL",
		"WAVE_CORVUS_VANGUARD", "WAVE_BOMBER_SIEGE", "WAVE_TURRET_BASTION"
	]

	var eligible: Array[Dictionary] = []

	# Filter templates matching sector difficulty (excluding tutorial & dedicated milestone haulers from random pool)
	for t in all:
		var min_s = t.get("min_sector", 1)
		var t_id = t.get("id", "")
		if t_id in ["WAVE_FIRST_CONTACT", "WAVE_CARGO_RECON", "WAVE_CARGO_CONVOY_1", "WAVE_CARGO_CONVOY_2", "WAVE_CARGO_SUPPLY"]:
			continue
		if sector_idx == 1 and min_s == 1:
			if wave_in_sec >= 7:
				if t_id in s1_late_ids:
					eligible.append(t)
			else:
				if t_id in s1_early_ids:
					eligible.append(t)
		elif sector_idx == 2 and min_s == 2:
			eligible.append(t)
		elif sector_idx >= 3 and min_s >= 2:
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

	return _mutate_template(chosen, sector_idx, wave_idx)

static func get_spawn_pool(sector_idx: int, wave_idx: int = 1) -> Array:
	var s1_w1_pool = [SCOUT, MICRO_DRONE]
	var s1_w2_pool = [SCOUT, INTERCEPTOR, MICRO_DRONE]
	var s1_w3_pool = [SCOUT, BOMBER, INTERCEPTOR, MICRO_DRONE]
	var s1_early_pool = [SCOUT, BOMBER, INTERCEPTOR, TURRET_PLATFORM, MICRO_DRONE]
	var s1_late_pool = [SCOUT, BOMBER, INTERCEPTOR, TURRET_PLATFORM, SNIPER, KNIGHT_VANGUARD, MISSILE_CORVETTE]
	var s2_pool = [SCOUT, BOMBER, INTERCEPTOR, TURRET_PLATFORM, MICRO_DRONE, SNIPER, SHIELD_FRIGATE, KNIGHT_VANGUARD, MISSILE_CORVETTE, DRAINER_LEECH]
	var s3_pool = [SCOUT, BOMBER, INTERCEPTOR, TURRET_PLATFORM, MICRO_DRONE, SNIPER, SHIELD_FRIGATE, KNIGHT_VANGUARD, MISSILE_CORVETTE, DRAINER_LEECH, HEAVY_CRUISER, PHANTOM, DRONE_CARRIER, WARP_STALKER, MINE_TETHER]
	
	var wave_in_sec = ((wave_idx - 1) % 12) + 1
	if sector_idx == 1:
		if wave_in_sec == 1:
			return s1_w1_pool.duplicate()
		elif wave_in_sec == 2:
			return s1_w2_pool.duplicate()
		elif wave_in_sec == 3:
			return s1_w3_pool.duplicate()
		elif wave_in_sec < 7:
			return s1_early_pool.duplicate()
		else:
			return s1_late_pool.duplicate()
	elif sector_idx == 2:
		return s2_pool.duplicate()
	else:
		return s3_pool.duplicate()

func _mutate_template(template: Dictionary, sector_idx: int, wave_idx: int = 1) -> Dictionary:
	var mutated = template.duplicate(true)
	var current_pool: Array = get_spawn_pool(sector_idx, wave_idx)
	var wave_in_sec = ((wave_idx - 1) % 12) + 1
	
	# No elites in Sector 1 Waves 1-3. First elite is guaranteed on Wave 4 to drop an item crate before Wave 5 shop!
	var elite_chance = 0.0
	if sector_idx == 1:
		if wave_in_sec >= 7:
			elite_chance = 0.25
		elif wave_in_sec >= 4:
			elite_chance = 0.15
		else:
			elite_chance = 0.0
	elif sector_idx == 2:
		elite_chance = 0.30
	else:
		elite_chance = 0.55

	var possible_affixes = [AFFIX_ARMORED, AFFIX_VOLATILE, AFFIX_SWIFT, AFFIX_SHIELDED]
	
	# 1. Procedural Spawn Batch Mutation (Wildcards & Elite Promotions)
	var spawns = mutated.get("spawns", [])
	
	# Track if an elite is already present in the wave template
	var has_elite = false
	for batch in spawns:
		if batch.get("affix", 0) != 0:
			has_elite = true
			break

	for batch in spawns:
		# Never mutate or promote dedicated Cargo Haulers or signature Bomber escorts in supply convoys
		if batch.get("type", 0) == CARGO_HAULER:
			continue
		if (template.get("id") in ["WAVE_CARGO_CONVOY_2", "WAVE_CARGO_SUPPLY"]) and batch.get("type") == BOMBER:
			continue

		# Wildcard swap (20% chance in Sector 1, 35% in later sectors)
		var swap_chance = 0.20 if sector_idx == 1 else 0.35
		if randf() < swap_chance and not current_pool.is_empty():
			current_pool.shuffle()
			var old_type = batch.get("type", 0)
			var new_type = current_pool[0]
			batch["type"] = new_type
			var old_count = batch.get("count", 1)
			var old_threat = get_archetype_threat(old_type)
			var new_threat = get_archetype_threat(new_type)
			var equiv_count = int(round((old_count * old_threat) / new_threat))
			if new_type == MICRO_DRONE:
				batch["count"] = maxi(12, equiv_count)
			elif new_type == SCOUT:
				batch["count"] = maxi(7, equiv_count)
			else:
				batch["count"] = maxi(2, equiv_count)
		elif template.get("id") != "WAVE_FIRST_CONTACT":
			# Swarm floor enforcement for Scout and Micro Drone outside Wave 1
			if batch.get("type") == MICRO_DRONE and batch.get("count", 1) < 12:
				batch["count"] = 12
			elif batch.get("type") == SCOUT and batch.get("count", 1) < 7:
				batch["count"] = 7
		
		# Elite Affix Promotion (Strict max 1 elite per standard wave)
		if not has_elite and randf() < elite_chance and batch.get("affix", 0) == 0 and batch["type"] != MICRO_DRONE:
			possible_affixes.shuffle()
			batch["affix"] = possible_affixes[0]
			has_elite = true
		
		# Timing jitter
		if batch.has("delay"):
			batch["delay"] = maxf(0.0, batch["delay"] + randf_range(-0.25, 0.25))
	
	# 2. Procedural Hazard Mutation (Sector 1 Waves 1-3 have no extra bonus hazards)
	var hazards = mutated.get("hazards", [])
	if (sector_idx > 1 or wave_idx >= 4) and randf() < 0.30:
		var bonus_hazard = HZ_ASTEROID if randf() > 0.5 else HZ_PLASMA_BARREL
		hazards.append({"type": bonus_hazard, "count": 1})
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
