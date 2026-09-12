extends "res://scripts/ItemModifier.gd"

## StatModItem.gd - Versatile data-driven item modifier for core stat upgrades and enhancements.

var add_max_hull: int = 0
var add_max_shields: int = 0
var add_max_rolls: int = 0
var mult_fire_rate: float = 1.0
var mult_damage: float = 1.0
var mult_move_speed: float = 1.0
var mult_roll_cooldown: float = 1.0
var mult_bullet_speed: float = 1.0
var mult_bullet_scale: float = 1.0
var add_magnet_radius: float = 0.0
var add_crit_chance: float = 0.0
var mult_shield_delay: float = 1.0
var bonus_scrap_value: int = 0
var scrap_bonus_chance: float = 0.0
var elite_bounty_bonus: int = 0
var has_singularity_recovery: bool = false
var wave_dividend_joules: int = 0
var add_spread_shots: int = 0
var instant_heal_hull: int = 0
var instant_recharge_shields: int = 0

func setup_stats(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_tier: ItemTier,
	p_color: Color,
	p_symbol: String,
	config: Dictionary = {}
) -> ItemModifier:
	id = p_id
	display_name = p_name
	description = p_desc
	tier = p_tier
	icon_color = p_color
	icon_symbol = p_symbol
	
	add_max_hull = config.get("add_max_hull", 0)
	add_max_shields = config.get("add_max_shields", 0)
	add_max_rolls = config.get("add_max_rolls", 0)
	mult_fire_rate = config.get("mult_fire_rate", 1.0)
	mult_damage = config.get("mult_damage", 1.0)
	mult_move_speed = config.get("mult_move_speed", 1.0)
	mult_roll_cooldown = config.get("mult_roll_cooldown", 1.0)
	mult_bullet_speed = config.get("mult_bullet_speed", 1.0)
	mult_bullet_scale = config.get("mult_bullet_scale", 1.0)
	add_magnet_radius = config.get("add_magnet_radius", 0.0)
	add_crit_chance = config.get("add_crit_chance", 0.0)
	mult_shield_delay = config.get("mult_shield_delay", 1.0)
	bonus_scrap_value = config.get("bonus_scrap_value", 0)
	scrap_bonus_chance = config.get("scrap_bonus_chance", 0.0)
	elite_bounty_bonus = config.get("elite_bounty_bonus", 0)
	has_singularity_recovery = config.get("has_singularity_recovery", false)
	wave_dividend_joules = config.get("wave_dividend_joules", 0)
	add_spread_shots = config.get("add_spread_shots", 0)
	instant_heal_hull = config.get("instant_heal_hull", 0)
	instant_recharge_shields = config.get("instant_recharge_shields", 0)
	
	max_stacks = config.get("max_stacks", 2)
	category = config.get("category", "general")
	
	return self

func on_ship_init(ship: CharacterBody2D) -> void:
	if "bonus_damage_pct" in ship:
		# Additive linear stat pooling model
		ship.bonus_damage_pct += (mult_damage - 1.0)
		ship.bonus_fire_rate_pct += (mult_fire_rate - 1.0)
		ship.bonus_move_speed_pct += (mult_move_speed - 1.0)
		ship.bonus_bullet_speed_pct += (mult_bullet_speed - 1.0)
		ship.bonus_bullet_scale_pct += (mult_bullet_scale - 1.0)
		ship.bonus_roll_cdr_pct += (1.0 - mult_roll_cooldown)
		ship.bonus_shield_delay_reduction_pct += (1.0 - mult_shield_delay)
		ship.bonus_max_hull += add_max_hull
		ship.bonus_max_shields += add_max_shields
		ship.bonus_max_rolls += add_max_rolls
		ship.bonus_magnet_radius += add_magnet_radius
		
		if add_max_hull > 0:
			ship.hull += add_max_hull
		if add_max_shields > 0:
			ship.shields += add_max_shields
		if add_max_rolls > 0:
			ship.rolls += add_max_rolls
		if instant_heal_hull > 0:
			ship.hull += instant_heal_hull
		if instant_recharge_shields > 0:
			ship.shields += instant_recharge_shields
		
		if add_crit_chance > 0.0:
			ship.crit_chance = clampf(ship.crit_chance + add_crit_chance, 0.0, 1.0)
		if add_spread_shots > 0:
			ship.extra_spread_shots += add_spread_shots
		if bonus_scrap_value > 0:
			ship.bonus_scrap_val += bonus_scrap_value
		if scrap_bonus_chance > 0.0 and "scrap_bonus_chance" in ship:
			ship.scrap_bonus_chance = clampf(ship.scrap_bonus_chance + scrap_bonus_chance, 0.0, 1.0)
		if elite_bounty_bonus > 0 and "elite_bounty_bonus" in ship:
			ship.elite_bounty_bonus += elite_bounty_bonus
		if has_singularity_recovery and "has_singularity_recovery" in ship:
			ship.has_singularity_recovery = true
		if wave_dividend_joules > 0 and "wave_dividend_joules" in ship:
			ship.wave_dividend_joules += wave_dividend_joules
		
		if ship.has_method("recalculate_stats"):
			ship.recalculate_stats()
	else:
		# Direct fallback for mock / legacy objects
		if add_max_hull != 0:
			ship.max_hull = maxi(1, ship.max_hull + add_max_hull)
			ship.hull = mini(ship.max_hull, ship.hull + maxi(0, add_max_hull))
		
		if add_max_shields != 0:
			ship.max_shields = maxi(0, ship.max_shields + add_max_shields)
			ship.shields = mini(ship.max_shields, ship.shields + maxi(0, add_max_shields))
		
		if add_max_rolls != 0:
			ship.max_rolls = maxi(1, ship.max_rolls + add_max_rolls)
			ship.rolls = mini(ship.max_rolls, ship.rolls + maxi(0, add_max_rolls))
		
		if instant_heal_hull > 0:
			ship.hull = mini(ship.max_hull, ship.hull + instant_heal_hull)
		
		if instant_recharge_shields > 0:
			ship.shields = mini(ship.max_shields, ship.shields + instant_recharge_shields)
		
		ship.fire_rate *= mult_fire_rate
		ship.move_speed *= mult_move_speed
		ship.roll_cooldown *= mult_roll_cooldown
		ship.scrap_magnet_radius += add_magnet_radius
		ship.shield_recharge_delay *= mult_shield_delay
		
		var cur_dmg = ship.get("damage_mult")
		if cur_dmg != null:
			ship.damage_mult = cur_dmg * mult_damage
		
		var cur_bspeed = ship.get("bullet_speed_mult")
		if cur_bspeed != null:
			ship.bullet_speed_mult = cur_bspeed * mult_bullet_speed
		
		var cur_bscale = ship.get("bullet_scale")
		if cur_bscale != null:
			ship.bullet_scale = cur_bscale * mult_bullet_scale
		
		var cur_crit = ship.get("crit_chance")
		if cur_crit != null:
			ship.crit_chance = clampf(cur_crit + add_crit_chance, 0.0, 1.0)
		
		var cur_spread = ship.get("extra_spread_shots")
		if cur_spread != null:
			ship.extra_spread_shots += add_spread_shots
		
		var cur_bonus_scrap = ship.get("bonus_scrap_val")
		if cur_bonus_scrap != null:
			ship.bonus_scrap_val += bonus_scrap_value
		
		var cur_sbc = ship.get("scrap_bonus_chance")
		if cur_sbc != null:
			ship.scrap_bonus_chance = clampf(cur_sbc + scrap_bonus_chance, 0.0, 1.0)
		var cur_ebb = ship.get("elite_bounty_bonus")
		if cur_ebb != null:
			ship.elite_bounty_bonus += elite_bounty_bonus
		if has_singularity_recovery and "has_singularity_recovery" in ship:
			ship.has_singularity_recovery = true
		var cur_wdj = ship.get("wave_dividend_joules")
		if cur_wdj != null:
			ship.wave_dividend_joules += wave_dividend_joules
	
	if ship.has_method("_emit_health"):
		ship._emit_health()
	if ship.has_method("_emit_rolls"):
		ship._emit_rolls()
