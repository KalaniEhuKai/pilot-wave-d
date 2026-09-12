class_name ProgressionModel
extends RefCounted

## ProgressionModel.gd - Centralized Systemic Balance & Economy Engine for PilotWave-D.
## Manages dynamic tier probability curves, target player DPS, enemy HP scaling, and tiered scrap economy.

# --- 1. SECTOR TIER PROBABILITY CURVES ---
# Gradually shifts power upwards so players see exciting high-tier relics in late sectors,
# without ever hard-locking items to single sectors.
const S1_TIER_PROBS = {
	ItemModifier.ItemTier.TIER_1_BALLISTIC: 0.75,
	ItemModifier.ItemTier.TIER_2_PARADIGM: 0.20,
	ItemModifier.ItemTier.TIER_3_EXOTIC: 0.05
}

const S2_TIER_PROBS = {
	ItemModifier.ItemTier.TIER_1_BALLISTIC: 0.45,
	ItemModifier.ItemTier.TIER_2_PARADIGM: 0.40,
	ItemModifier.ItemTier.TIER_3_EXOTIC: 0.15
}

const S3_TIER_PROBS = {
	ItemModifier.ItemTier.TIER_1_BALLISTIC: 0.25,
	ItemModifier.ItemTier.TIER_2_PARADIGM: 0.45,
	ItemModifier.ItemTier.TIER_3_EXOTIC: 0.30
}

static func get_tier_probabilities(sector_idx: int) -> Dictionary:
	match sector_idx:
		1:
			return S1_TIER_PROBS
		2:
			return S2_TIER_PROBS
		_:
			return S3_TIER_PROBS

static func roll_tier(sector_idx: int) -> ItemModifier.ItemTier:
	var probs = get_tier_probabilities(sector_idx)
	var roll = randf()
	var cum_t1 = probs[ItemModifier.ItemTier.TIER_1_BALLISTIC]
	var cum_t2 = cum_t1 + probs[ItemModifier.ItemTier.TIER_2_PARADIGM]
	
	if roll < cum_t1:
		return ItemModifier.ItemTier.TIER_1_BALLISTIC
	elif roll < cum_t2:
		return ItemModifier.ItemTier.TIER_2_PARADIGM
	else:
		return ItemModifier.ItemTier.TIER_3_EXOTIC

# --- 2. TIERED SHOP PRICING ---
# Tier 1 (Common/Stat): 35 J
# Tier 2 (Uncommon/Synergy): 65 J
# Tier 3 (Exotic/Relic): 95 J
const TIER_PRICES = {
	ItemModifier.ItemTier.TIER_1_BALLISTIC: 35,
	ItemModifier.ItemTier.TIER_2_PARADIGM: 65,
	ItemModifier.ItemTier.TIER_3_EXOTIC: 95
}

static func get_tier_price(tier: ItemModifier.ItemTier) -> int:
	return TIER_PRICES.get(tier, 35)

# --- 3. ENEMY HP SCALING FORMULA ---
# Base Scout HP = 2.0 * get_enemy_hp_multiplier(sec, wave)
# Wave 1: 1.0 (Scout = 2.0 HP, exactly 2 shots)
# Wave 12: 1.33 (Scout = 2.66 HP, smooth early arc)
# Wave 13: 1.45 (Smooth bridge into Sector 2 without a 100% cliff jump)
# Wave 36: 2.23 (Calibrated for high action density & realistic Applied DPS)
static func get_enemy_hp_multiplier(sector: int, wave: int) -> float:
	var wave_in_sec = ((wave - 1) % 12) + 1
	return 1.0 + (sector - 1) * 0.45 + (wave_in_sec - 1) * 0.03

# --- 4. TARGET DPS TARGETS ACROSS RUN ---
static func get_target_dps(sector: int, wave: int) -> float:
	var wave_in_sec = ((wave - 1) % 12) + 1
	match sector:
		1:
			return lerpf(7.6, 14.0, float(wave_in_sec - 1) / 12.0)
		2:
			return lerpf(14.5, 28.0, float(wave_in_sec - 1) / 12.0)
		_:
			return lerpf(28.5, 55.0, float(wave_in_sec - 1) / 12.0)

# --- 5. CALIBRATED SCRAP DROP YIELDS & CURRENCY VALUE ---
# Single source of truth: 1 scrap diamond pellet = 1 Joule
const BASE_SCRAP_VALUE: int = 1

static func get_base_scrap_value() -> int:
	return BASE_SCRAP_VALUE

# Baseline target Joules delivered per wave across run sectors
static func get_target_wave_joules(sector: int, _wave: int = 1) -> float:
	match sector:
		1:
			return 22.0
		2:
			return 24.0
		_:
			return 26.0

# Relative economic weights of enemy archetypes and hazards.
# Higher-threat craft receive a proportionately larger share of the wave's Joules budget.
const ARCHETYPE_SCRAP_WEIGHTS: Dictionary = {
	0: 1.0,   # SCOUT
	1: 1.8,   # BOMBER
	2: 1.8,   # INTERCEPTOR
	3: 2.2,   # SNIPER
	4: 3.0,   # SHIELD_FRIGATE
	5: 5.0,   # HEAVY_CRUISER
	6: 3.0,   # KNIGHT_VANGUARD
	7: 2.5,   # PHANTOM
	8: 5.0,   # DRONE_CARRIER
	9: 0.4,   # MICRO_DRONE
	10: 3.0,  # TURRET_PLATFORM
	11: 2.5,  # WARP_STALKER
	12: 2.0,  # DRAINER_LEECH
	13: 3.2,  # MISSILE_CORVETTE
	14: 1.5,  # MINE_TETHER
	15: 2.0,  # ORBITAL_REFLECTOR
	16: 1.5,  # CARGO_HAULER
}

const HAZARD_SCRAP_WEIGHTS: Dictionary = {
	0: 0.8,   # HZ_ASTEROID (Destructible rock, modest scrap fraction)
	1: 0.0,   # HZ_PLASMA_BARREL (Explosive utility hazard, no direct scrap)
	2: 0.0    # HZ_STORM_CELL (Hazard zone, no scrap)
}

## Dynamically calculates scrap drop probabilities for all enemies and hazards in a wave.
## Normalizes against the wave's exact composition and the sector's target Joules budget,
## mathematically guaranteeing the wave's expected scrap yield equals target_wave_joules.
static func calculate_wave_drop_distribution(spawns: Array, hazards: Array, sector: int, wave: int) -> Dictionary:
	var target_budget = get_target_wave_joules(sector, wave)
	var elite_bounty_total = 0.0
	var elite_bounty_val = 10.0 if sector == 1 else (15.0 if sector == 2 else 20.0)

	# 1. Tally economic weights and account for any fixed elite bounties
	var total_weight = 0.0
	for batch in spawns:
		var e_type = batch.get("type", 0)
		var count = batch.get("count", 1)
		var has_elite = batch.get("affix", 0) != 0
		var standard_count = (count - 1) if (has_elite and count > 0) else count
		if has_elite:
			elite_bounty_total += elite_bounty_val
		var w = ARCHETYPE_SCRAP_WEIGHTS.get(e_type, 1.0)
		total_weight += standard_count * w

	for hz in hazards:
		var h_type = hz.get("type", 0)
		var h_count = hz.get("count", 0)
		var hw = HAZARD_SCRAP_WEIGHTS.get(h_type, 0.0)
		total_weight += h_count * hw

	# Reserve a healthy minimum for loose pellets even in elite-heavy waves
	var loose_budget = maxf(target_budget - elite_bounty_total, target_budget * 0.45)
	var distribution: Dictionary = {}

	if total_weight <= 0.0:
		total_weight = 1.0

	# 2. Compute dynamic drop profile per archetype
	for type_key in ARCHETYPE_SCRAP_WEIGHTS:
		var w = ARCHETYPE_SCRAP_WEIGHTS[type_key]
		var target_j = (w / total_weight) * loose_budget
		var guaranteed = int(floor(target_j))
		var chance = clampf(target_j - float(guaranteed), 0.0, 1.0)
		distribution[type_key] = {
			"guaranteed": guaranteed,
			"chance": chance,
			"expected_value": target_j
		}

	# 3. Compute dynamic drop profile for hazards
	for h_key in HAZARD_SCRAP_WEIGHTS:
		var hw = HAZARD_SCRAP_WEIGHTS[h_key]
		if hw > 0.0:
			var target_hj = (hw / total_weight) * loose_budget
			var guaranteed_h = int(floor(target_hj))
			var chance_h = clampf(target_hj - float(guaranteed_h), 0.0, 1.0)
			distribution["hazard_%d" % h_key] = {
				"guaranteed": guaranteed_h,
				"chance": chance_h,
				"expected_value": target_hj
			}
		else:
			distribution["hazard_%d" % h_key] = {
				"guaranteed": 0,
				"chance": 0.0,
				"expected_value": 0.0
			}

	return distribution

static func get_default_drop_profile(enemy_type: int) -> Dictionary:
	var w = ARCHETYPE_SCRAP_WEIGHTS.get(enemy_type, 1.0)
	var approx_j = w * 0.9
	var g = int(floor(approx_j))
	return {
		"guaranteed": g,
		"chance": clampf(approx_j - float(g), 0.0, 1.0),
		"expected_value": approx_j
	}

# Legacy integer fallback (for static checks and backwards compatibility)
static func get_enemy_scrap_yield(enemy_type: int, is_elite: bool) -> int:
	if is_elite:
		return 0

	match enemy_type:
		0, 9: # Scout, Micro Drone
			return 1
		1, 2, 3: # Bomber, Interceptor, Sniper
			return 1
		4, 6, 10, 13: # Shield Frigate, Knight Vanguard, Turret, Missile Corvette
			return 2
		5, 8: # Heavy Cruiser, Drone Carrier
			return 3
		16: # Cargo Hauler
			return 1
		_:
			return 1

# --- 6. WEIGHTED ITEM SELECTION WITH MAX_STACKS FILTERING ---
static func select_weighted_item(
	player: CharacterBody2D,
	sector_idx: int,
	forced_tier: int = -1,
	required_category: String = "",
	exclude_ids: Array[String] = []
) -> ItemModifier:
	var tier = forced_tier if forced_tier >= 0 else roll_tier(sector_idx)
	var all_items = ItemDatabase.get_all_items()
	var candidates: Array[ItemModifier] = []
	
	for it in all_items:
		if it.tier != tier:
			continue
		if exclude_ids.has(it.id):
			continue
		if required_category != "" and it.category != required_category:
			continue
		
		# Check max_stacks on player
		if is_instance_valid(player) and player.has_method("get_modifier_stack_count"):
			var held_count = player.get_modifier_stack_count(it.id)
			if held_count >= it.max_stacks:
				continue
		elif is_instance_valid(player) and player.has_method("has_modifier"):
			if it.max_stacks <= 1 and player.has_modifier(it.id):
				continue
		
		candidates.append(it)
	
	# Fallback if category or tier is exhausted
	if candidates.is_empty():
		for it in all_items:
			if exclude_ids.has(it.id):
				continue
			if is_instance_valid(player) and player.has_method("get_modifier_stack_count"):
				if player.get_modifier_stack_count(it.id) >= it.max_stacks:
					continue
			candidates.append(it)
	
	if candidates.is_empty():
		return null
	
	candidates.shuffle()
	return candidates[0]

# --- 7. EXPECTED PROGRESSION & RUN TELEMETRY CURVES ---
static func get_expected_relics_range(sector: int, wave: int) -> Vector2i:
	var wave_in_sec = ((wave - 1) % 12) + 1
	match sector:
		1:
			if wave_in_sec <= 1:
				return Vector2i(0, 0)
			elif wave_in_sec <= 3:
				return Vector2i(1, 1) # Wave 2 starter crate
			elif wave_in_sec == 4:
				return Vector2i(2, 2) # Wave 4 Milestone Elite crate
			elif wave_in_sec == 5:
				return Vector2i(3, 4) # Wave 5 Shop 1 (buys 1-2 items)
			elif wave_in_sec <= 7:
				return Vector2i(4, 5) # Wave 6 Miniboss Goliath crate
			elif wave_in_sec <= 9:
				return Vector2i(5, 6) # Wave 8 Milestone Elite crate
			elif wave_in_sec <= 11:
				return Vector2i(6, 7) # Wave 10 Deep Space Supply crate
			else:
				return Vector2i(7, 8) # Wave 12 Flagship Boss Corvus crate
		2:
			if wave_in_sec <= 1:
				return Vector2i(7, 8)
			elif wave_in_sec <= 3:
				return Vector2i(8, 9) # Wave 14 starter crate
			elif wave_in_sec == 4:
				return Vector2i(9, 10) # Wave 16 Milestone Elite crate
			elif wave_in_sec == 5:
				return Vector2i(11, 13) # Wave 17 Shop 2 (buys 2-3 items)
			elif wave_in_sec <= 7:
				return Vector2i(12, 14) # Wave 18 Miniboss crate
			elif wave_in_sec <= 9:
				return Vector2i(13, 15) # Wave 20 Milestone Elite crate
			elif wave_in_sec <= 11:
				return Vector2i(14, 16) # Wave 22 Deep Space Supply crate
			else:
				return Vector2i(15, 17) # Wave 24 Boss Goliath crate
		_:
			if wave_in_sec <= 1:
				return Vector2i(15, 17)
			elif wave_in_sec <= 3:
				return Vector2i(16, 18) # Wave 26 starter crate
			elif wave_in_sec == 4:
				return Vector2i(17, 19) # Wave 28 Milestone Elite crate
			elif wave_in_sec == 5:
				return Vector2i(19, 22) # Wave 29 Shop 3 (buys 2-3 items)
			elif wave_in_sec <= 7:
				return Vector2i(20, 23) # Wave 30 Miniboss crate
			elif wave_in_sec <= 9:
				return Vector2i(21, 24) # Wave 32 Milestone Elite crate
			elif wave_in_sec <= 11:
				return Vector2i(22, 25) # Wave 34 Deep Space Supply crate
			else:
				return Vector2i(24, 27) # Finale Titan Ouroboros (2 crates)

static func get_next_shop_wave(sector: int, wave: int) -> int:
	var total_wave = (sector - 1) * 12 + ((wave - 1) % 12) + 1
	if total_wave < 5:
		return 5
	elif total_wave < 17:
		return 17
	elif total_wave < 29:
		return 29
	else:
		return -1

static func get_expected_total_joules_range(sector: int, wave: int) -> Vector2i:
	var total_wave = (sector - 1) * 12 + ((wave - 1) % 12) + 1
	var base_min = maxi(0, (total_wave - 1) * 20)
	var base_max = total_wave * 25
	var boss_bonus = 0
	if total_wave > 6:
		boss_bonus += 18
	if total_wave > 12:
		boss_bonus += 40
	if total_wave > 18:
		boss_bonus += 25
	if total_wave > 24:
		boss_bonus += 50
	if total_wave > 30:
		boss_bonus += 30
	return Vector2i(base_min + boss_bonus, base_max + boss_bonus)


