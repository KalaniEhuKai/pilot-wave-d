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

# --- 6. STAT CARD UX & GLOWING BBCODE FORMATTING ---

static func format_stat_value_bbcode(val: float, is_pct: bool = true) -> String:
	var formatted_str = ("%+d%%" if is_pct else "%+d") % int(round(val * 100.0 if is_pct else val))
	if val >= 0.48:
		# Colossal buff (+50%+): Radiant Solar Gold
		return "[color=#facc15]%s[/color]" % formatted_str
	elif val >= 0.22:
		# Substantial buff (+25% to +45%): Electric Magenta
		return "[color=#f0abfc]%s[/color]" % formatted_str
	elif val > 0.0:
		# Moderate buff (+10% to +20%): Crisp Cyan
		return "[color=#22d3ee]%s[/color]" % formatted_str
	elif val <= -0.18:
		# Severe penalty (-20% to -80%): Vivid Crimson
		return "[color=#ff2a5f]%s[/color]" % formatted_str
	else:
		# Minor penalty (-5% to -15%): Warm Orange
		return "[color=#fb923c]%s[/color]" % formatted_str

static func format_card_bbcode(item: ItemModifier, player: CharacterBody2D = null) -> String:
	if item == null:
		return ""
	
	var desc = item.description
	
	# Regex highlight numbers / percentages in the base description (preserving uniform font size)
	var regex = RegEx.new()
	if regex.compile("([+-]\\d+%)") == OK:
		var matches = regex.search_all(desc)
		for i in range(matches.size() - 1, -1, -1):
			var m = matches[i]
			var raw = m.get_string(1)
			var val = float(raw.trim_suffix("%")) / 100.0
			var colored = format_stat_value_bbcode(val, true)
			desc = desc.substr(0, m.get_start(1)) + colored + desc.substr(m.get_end(1))
	
	# If player reference is available, compute and append concrete stat deltas
	if player != null and item.get("category") != null:
		var deltas: Array[String] = []
		
		# 1. Damage Multiplier
		var mult_dmg = item.get("mult_damage")
		if mult_dmg != null and mult_dmg != 1.0:
			var cur_d = player.damage_mult
			var bonus_d = player.bonus_damage_pct if "bonus_damage_pct" in player else (cur_d - 1.0)
			var next_d = maxf(0.1, 1.0 + bonus_d + (mult_dmg - 1.0))
			var diff = mult_dmg - 1.0
			deltas.append("[color=#94a3b8]DMG:[/color] %.1fx ──► %.1fx  %s" % [cur_d, next_d, format_stat_value_bbcode(diff, true)])
		
		# 2. Cyclic Fire Rate
		var mult_fr = item.get("mult_fire_rate")
		if mult_fr != null and mult_fr != 1.0:
			var cur_fr = player.fire_rate
			var base_fr = player.base_fire_rate if "base_fire_rate" in player else 3.8
			var bonus_fr = player.bonus_fire_rate_pct if "bonus_fire_rate_pct" in player else (cur_fr / base_fr - 1.0)
			var next_fr = base_fr * maxf(0.25, 1.0 + bonus_fr + (mult_fr - 1.0))
			var diff = mult_fr - 1.0
			deltas.append("[color=#94a3b8]RATE:[/color] %.1f/s ──► %.1f/s  %s" % [cur_fr, next_fr, format_stat_value_bbcode(diff, true)])
		
		# 3. Critical Strike Chance
		var add_crit = item.get("add_crit_chance")
		if add_crit != null and add_crit > 0.0:
			var cur_crit = int(player.crit_chance * 100.0)
			var next_crit = int(clampf(player.crit_chance + add_crit, 0.0, 1.0) * 100.0)
			deltas.append("[color=#94a3b8]CRIT:[/color] %d%% ──► %d%%  %s" % [cur_crit, next_crit, format_stat_value_bbcode(add_crit, true)])
		
		# 4. Projectile Velocity
		var mult_bspd = item.get("mult_bullet_speed")
		if mult_bspd != null and mult_bspd != 1.0:
			var cur_bs = int(540.0 * (player.bullet_speed_mult if "bullet_speed_mult" in player else 1.0))
			var next_bs = int(cur_bs * mult_bspd)
			var diff_bs = mult_bspd - 1.0
			deltas.append("[color=#94a3b8]BOLT SPEED:[/color] %d ──► %d  %s" % [cur_bs, next_bs, format_stat_value_bbcode(diff_bs, true)])
		
		# 5. Barrel Roll Cooldown (Recharge Time)
		var mult_rcd = item.get("mult_roll_cooldown")
		if mult_rcd != null and mult_rcd != 1.0:
			var cur_rcd = player.roll_cooldown if "roll_cooldown" in player else 3.2
			var next_rcd = cur_rcd * mult_rcd
			var diff_rcd = 1.0 - mult_rcd
			deltas.append("[color=#94a3b8]ROLL CD:[/color] %.1fs ──► %.1fs  %s" % [cur_rcd, next_rcd, format_stat_value_bbcode(diff_rcd, true)])
		
		# 6. Shield Recharge Delay
		var mult_sdel = item.get("mult_shield_delay")
		if mult_sdel != null and mult_sdel != 1.0:
			var cur_sd = player.shield_recharge_delay if "shield_recharge_delay" in player else 4.0
			var next_sd = cur_sd * mult_sdel
			var diff_sd = 1.0 - mult_sdel
			deltas.append("[color=#94a3b8]SHIELD RECHARGE:[/color] %.1fs ──► %.1fs  %s" % [cur_sd, next_sd, format_stat_value_bbcode(diff_sd, true)])
		
		# 7. Flight Speed
		var mult_spd = item.get("mult_move_speed")
		if mult_spd != null and mult_spd != 1.0:
			var cur_spd = int(player.move_speed)
			var base_spd = player.base_move_speed if "base_move_speed" in player else 420.0
			var bonus_spd = player.bonus_move_speed_pct if "bonus_move_speed_pct" in player else 0.0
			var next_spd = int(base_spd * maxf(0.3, 1.0 + bonus_spd + (mult_spd - 1.0)))
			var diff = mult_spd - 1.0
			deltas.append("[color=#94a3b8]SPEED:[/color] %d ──► %d  %s" % [cur_spd, next_spd, format_stat_value_bbcode(diff, true)])
		
		# 8. Scrap Magnet Reach
		var add_mag = item.get("add_magnet_radius")
		if add_mag != null and add_mag > 0.0:
			var cur_mag = int(player.scrap_magnet_radius if "scrap_magnet_radius" in player else 130.0)
			var next_mag = int(cur_mag + add_mag)
			deltas.append("[color=#94a3b8]MAGNET RANGE:[/color] %dpx ──► %dpx  [color=#22d3ee]+%dpx[/color]" % [cur_mag, next_mag, int(add_mag)])
		
		# 9. Extra Spread Shot Pairs
		var add_spr = item.get("add_spread_shots")
		if add_spr != null and add_spr > 0:
			var cur_spr = player.extra_spread_shots if "extra_spread_shots" in player else 0
			var next_spr = cur_spr + add_spr
			deltas.append("[color=#94a3b8]SPREAD SHOTS:[/color] %d ──► %d  [color=#f0abfc]+%d pair%s[/color]" % [cur_spr, next_spr, add_spr, "s" if add_spr > 1 else ""])
		
		# 10. Max Hull / Shields / Rolls
		var add_h = item.get("add_max_hull")
		if add_h != null and add_h > 0:
			deltas.append("[color=#94a3b8]MAX HULL:[/color] %d ──► %d  %s" % [player.max_hull, player.max_hull + add_h, format_stat_value_bbcode(float(add_h), false)])
		var add_s = item.get("add_max_shields")
		if add_s != null and add_s > 0:
			deltas.append("[color=#94a3b8]MAX SHIELDS:[/color] %d ──► %d  %s" % [player.max_shields, player.max_shields + add_s, format_stat_value_bbcode(float(add_s), false)])
		var add_r = item.get("add_max_rolls")
		if add_r != null and add_r > 0:
			deltas.append("[color=#94a3b8]MAX ROLLS:[/color] %d ──► %d  %s" % [player.max_rolls, player.max_rolls + add_r, format_stat_value_bbcode(float(add_r), false)])
		
		# 11. Economy Perks (Joule chance, dividends, bounties, singularity recovery)
		var scrap_chance = item.get("scrap_bonus_chance")
		if scrap_chance != null and scrap_chance > 0.0:
			var cur_sc = int((player.scrap_bonus_chance if "scrap_bonus_chance" in player else 0.0) * 100.0)
			var next_sc = int(clampf((player.scrap_bonus_chance if "scrap_bonus_chance" in player else 0.0) + scrap_chance, 0.0, 1.0) * 100.0)
			deltas.append("[color=#94a3b8]JOULE SCRAP:[/color] %d%% ──► %d%%  %s" % [cur_sc, next_sc, format_stat_value_bbcode(scrap_chance, true)])
		
		var wave_div = item.get("wave_dividend_joules")
		if wave_div != null and wave_div > 0:
			var cur_wd = player.wave_dividend_joules if "wave_dividend_joules" in player else 0
			var next_wd = cur_wd + wave_div
			deltas.append("[color=#94a3b8]WAVE DIVIDEND:[/color] %d J ──► %d J  [color=#facc15]+%d J[/color]" % [cur_wd, next_wd, wave_div])
		
		var elite_bonus = item.get("elite_bounty_bonus")
		if elite_bonus != null and elite_bonus > 0:
			var cur_ebb = player.elite_bounty_bonus if "elite_bounty_bonus" in player else 0
			var next_ebb = cur_ebb + elite_bonus
			deltas.append("[color=#94a3b8]ELITE BOUNTY:[/color] %d J ──► %d J  [color=#facc15]+%d J[/color]" % [cur_ebb, next_ebb, elite_bonus])
		
		var has_sing = item.get("has_singularity_recovery")
		if has_sing != null and has_sing and ("has_singularity_recovery" in player) and not player.has_singularity_recovery:
			deltas.append("[color=#94a3b8]VOID RECOVERY:[/color] [color=#22d3ee]100% Scrap Recovery[/color]")
		
		if not deltas.is_empty():
			desc += "\n[color=#475569]────────────────────────[/color]\n" + "\n".join(deltas)
	
	return desc


