class_name ItemDatabase
extends RefCounted

## ItemDatabase.gd - Central catalog of all items, mutators, and relics (60 total items).

# Bespoke item scripts
const BirefringencePrismScript = preload("res://scripts/items/BirefringencePrism.gd")
const GravitationalLensingScript = preload("res://scripts/items/GravitationalLensing.gd")
const ElasticMomentumScript = preload("res://scripts/items/ElasticMomentum.gd")
const FeynmanPropagatorScript = preload("res://scripts/items/FeynmanPropagator.gd")
const ZeemanSplittingScript = preload("res://scripts/items/ZeemanSplitting.gd")
const CherenkovRadiatorScript = preload("res://scripts/items/CherenkovRadiator.gd")
const HeisenbergLensScript = preload("res://scripts/items/HeisenbergLens.gd")
const AntimatterSuspensionScript = preload("res://scripts/items/AntimatterSuspension.gd")
const TachyonCapacitorScript = preload("res://scripts/items/TachyonCapacitor.gd")
const CarnotHeatsinkScript = preload("res://scripts/items/CarnotHeatsink.gd")
const QuantumTunnelingScript = preload("res://scripts/items/QuantumTunneling.gd")
const MeissnerShieldScript = preload("res://scripts/items/MeissnerShield.gd")
const MaxwellsDemonScript = preload("res://scripts/items/MaxwellsDemon.gd")
const LagrangeSatellitesScript = preload("res://scripts/items/LagrangeSatellites.gd")
const CarnotEfficiencyScript = preload("res://scripts/items/CarnotEfficiency.gd")
const DiracInversionScript = preload("res://scripts/items/DiracInversion.gd")
const BellEntanglementScript = preload("res://scripts/items/BellEntanglement.gd")
const StatModItem = preload("res://scripts/items/StatModItem.gd")

static func _make_stat(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_tier: ItemModifier.ItemTier,
	p_col: Color,
	p_sym: String,
	config: Dictionary
) -> ItemModifier:
	var item = StatModItem.new()
	return item.setup_stats(p_id, p_name, p_desc, p_tier, p_col, p_sym, config)

static func get_all_items() -> Array[ItemModifier]:
	var list: Array[ItemModifier] = [
		# --- Bespoke Ballistic Modifiers (Tier 1) ---
		BirefringencePrismScript.new(),
		GravitationalLensingScript.new(),
		ElasticMomentumScript.new(),
		FeynmanPropagatorScript.new(),
		ZeemanSplittingScript.new(),
		CherenkovRadiatorScript.new(),
		HeisenbergLensScript.new(),
		
		# --- Bespoke Weapon Paradigms (Tier 2) ---
		AntimatterSuspensionScript.new(),
		TachyonCapacitorScript.new(),
		CarnotHeatsinkScript.new(),
		QuantumTunnelingScript.new(),
		
		# --- Bespoke Exotic Relics (Tier 3) ---
		MeissnerShieldScript.new(),
		MaxwellsDemonScript.new(),
		LagrangeSatellitesScript.new(),
		CarnotEfficiencyScript.new(),
		DiracInversionScript.new(),
		BellEntanglementScript.new(),
		
		# --- Common Avionics & Stat Boosters (Tier 1) ---
		_make_stat("tungsten_core", "Tungsten Core", "Dense slugs increase synchrotron damage by +25% at minor cost to fire rate (-10%).", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.8, 0.8, 0.9), "[DMG+]", {"mult_damage": 1.25, "mult_fire_rate": 0.90}),
		_make_stat("depleted_uranium", "Depleted Uranium Tips", "Dense alloy cores deliver +35% damage with -15% bolt velocity.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.8, 0.7, 0.9), "[HEAVY]", {"mult_damage": 1.35, "mult_bullet_speed": 0.85}),
		_make_stat("pulse_synchronizer", "Pulse Synchronizer", "Harmonic timing circuits push firing cadence up by +20%.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.3, 1.0, 0.5), "[RATE+]", {"mult_fire_rate": 1.20}),
		_make_stat("rapid_cycler", "Rapid Cycler", "Over-pressurized feeder increases cyclic fire rate by +35% (-10% damage).", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.3, 0.9, 0.6), "[CYCLE]", {"mult_fire_rate": 1.35, "mult_damage": 0.90}),
		_make_stat("hypergolic_propellant", "Hypergolic Fuel", "High-energy propellant accelerates synchrotron bolts by +35%.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.2, 0.9, 1.0), "[VEL+]", {"mult_bullet_speed": 1.35}),
		_make_stat("heavy_bore_barrel", "Heavy Bore Barrel", "Enlarged rifling magnifies plasma bolt caliber by +40% with +15% damage.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(1.0, 0.5, 0.2), "[SIZE+]", {"mult_bullet_scale": 1.40, "mult_damage": 1.15}),
		_make_stat("collimating_optic", "Collimating Optic", "Tightens beam coherence: +25% bolt velocity and +10% damage.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.5, 0.8, 1.0), "[OPTIC]", {"mult_bullet_speed": 1.25, "mult_damage": 1.10}),
		_make_stat("nanite_hull_plating", "Nanite Hull Plate", "Self-assembling carbon-nanotube weave increases Max Hull by +1 and restores 1 Hull.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.1, 0.9, 0.5), "[HULL+]", {"add_max_hull": 1, "instant_heal_hull": 1}),
		_make_stat("composite_armor", "Composite Bulkhead", "Layered titanium-ceramic honeycomb increases Max Hull by +2.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.4, 0.7, 0.6), "[HULL+2]", {"add_max_hull": 2}),
		_make_stat("aegis_capacitor", "Aegis Capacitor", "High-permittivity dielectric banks provide +1 Max Shield.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.3, 0.6, 1.0), "[SHLD+]", {"add_max_shields": 1, "instant_recharge_shields": 1}),
		_make_stat("plasma_mesh_screen", "Plasma Mesh", "Secondary field grid adds +2 Max Shields (+20% shield delay).", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.2, 0.7, 0.9), "[SHLD+2]", {"add_max_shields": 2, "mult_shield_delay": 1.20}),
		_make_stat("quick_charge_diode", "Fast Recovery Diode", "Gallium-nitride rectifiers reduce shield recharge delay by 30%.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.4, 0.9, 1.0), "[RECHG]", {"mult_shield_delay": 0.70}),
		_make_stat("vectored_nozzle", "Vectored Nozzle", "Articulated magnetic exhaust vanes boost ship flight speed by +20%.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.9, 0.9, 0.3), "[SPD+]", {"mult_move_speed": 1.20}),
		_make_stat("afterburner_manifold", "Afterburner Manifold", "Direct fuel injection supercharges flight speed by +35%.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(1.0, 0.7, 0.1), "[SPD++]", {"mult_move_speed": 1.35}),
		_make_stat("micro_gyroscope", "Micro Gyroscope", "Miniaturized flywheels reduce barrel roll cooldown by 25%.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.2, 0.8, 0.9), "[ROLL-CD]", {"mult_roll_cooldown": 0.75}),
		_make_stat("auxiliary_roll_thruster", "Aux Roll Thruster", "Secondary cold-gas RCS thrusters grant +1 Max Barrel Roll charge.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.5, 0.9, 1.0), "[ROLL+]", {"add_max_rolls": 1}),
		_make_stat("high_flux_magnet", "Neodymium Collector", "Powerful static field draws energy scrap from +120px further away.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(1.0, 0.8, 0.3), "[MAG+]", {"add_magnet_radius": 120.0}),
		_make_stat("superconducting_coil", "Superconducting Loop", "Zero-resistance loop extends scrap collection reach by +200px.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.9, 0.7, 0.2), "[MAG++]", {"add_magnet_radius": 200.0}),
		_make_stat("joule_refiner", "Joule Concentrator", "Catalytic converter yields +2 extra Joules from every collected scrap cluster.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(1.0, 0.9, 0.1), "[JOULE+]", {"bonus_scrap_value": 2}),
		_make_stat("plasma_sifter", "Plasma Sifter", "Extracts energetic isotopes: +4 bonus Joules per scrap pickup.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(1.0, 0.85, 0.2), "[JOULE++]", {"bonus_scrap_value": 4}),
		_make_stat("critical_resonator", "Critical Resonator", "Phased focal cavity adds +12% Critical Strike chance for 200% damage.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(1.0, 0.3, 0.3), "[CRIT+]", {"add_crit_chance": 0.12}),
		_make_stat("target_lock_matrix", "Targeting Matrix", "Automated optical telemetry adds +20% Critical Strike chance.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(1.0, 0.4, 0.2), "[CRIT++]", {"add_crit_chance": 0.20}),
		_make_stat("split_manifold", "Split Manifold", "Supplementary conduits fire +1 extra angled spread shot pair (-15% damage).", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.7, 0.5, 1.0), "[FLAK]", {"add_spread_shots": 1, "mult_damage": 0.85}),
		_make_stat("reinforced_cockpit", "Reinforced Canopy", "Armored canopy adds +1 Max Hull and +1 Max Barrel Roll charge.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.2, 0.9, 0.7), "[SURV]", {"add_max_hull": 1, "add_max_rolls": 1}),
		_make_stat("emergency_cells", "Emergency Battery Cells", "Emergency capacitor reserves: instantly heals +2 Hull and recharges shields.", ItemModifier.ItemTier.TIER_1_BALLISTIC, Color(0.2, 1.0, 0.8), "[CELLS]", {"instant_heal_hull": 2, "instant_recharge_shields": 2}),
		
		# --- Uncommon Weapon Paradigms & Enhancers (Tier 2) ---
		_make_stat("overclocked_dynamo", "Overclocked Dynamo", "Unrestricted generator governor: +25% Fire Rate and +15% Flight Speed.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(1.0, 0.6, 0.1), "[DYNAMO]", {"mult_fire_rate": 1.25, "mult_move_speed": 1.15}),
		_make_stat("dreadnought_plating", "Dreadnought Plating", "Massive layered armored plates: +3 Max Hull (-15% flight speed).", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.6, 0.8, 0.6), "[DREAD]", {"add_max_hull": 3, "mult_move_speed": 0.85}),
		_make_stat("singularity_siphon", "Singularity Siphon", "Gravitational eddy: +250px Scrap Magnet Radius and +3 bonus Joules per pickup.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.9, 0.4, 1.0), "[SIPHON]", {"add_magnet_radius": 250.0, "bonus_scrap_value": 3}),
		_make_stat("precision_rail", "Precision Monopole Rail", "Magnetic accelerator rail: +50% Bolt Speed, +25% Damage, +10% Crit Chance.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.4, 0.8, 1.0), "[RAIL]", {"mult_bullet_speed": 1.50, "mult_damage": 1.25, "add_crit_chance": 0.10}),
		_make_stat("kinetic_amplifier", "Kinetic Amplifier", "Shockwave resonant field: +50% Bolt Size and +30% Synchrotron Damage.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(1.0, 0.5, 0.3), "[KINETIC]", {"mult_bullet_scale": 1.50, "mult_damage": 1.30}),
		_make_stat("flux_overdrive", "Flux Overdrive", "Saturates emission coils: +50% Fire Rate with -20% Bolt Velocity.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.3, 1.0, 0.4), "[OVERDRIVE]", {"mult_fire_rate": 1.50, "mult_bullet_speed": 0.80}),
		_make_stat("nanite_repair_rig", "Nanite Auto-Rig", "Autonomous repair suite: +2 Max Hull and immediately restores 2 Hull.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.2, 0.9, 0.6), "[AUTORIG]", {"add_max_hull": 2, "instant_heal_hull": 2}),
		_make_stat("shield_booster_array", "Barrier Array", "Interlocking deflector nodes: +2 Max Shields and 25% faster shield recovery.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.3, 0.7, 1.0), "[BARRIER]", {"add_max_shields": 2, "mult_shield_delay": 0.75}),
		_make_stat("aerobatic_gyro", "Aerobatic Gyro", "Precision attitude thrusters: +2 Max Barrel Rolls and 20% faster roll cooldown.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.4, 0.9, 0.9), "[GYRO+]", {"add_max_rolls": 2, "mult_roll_cooldown": 0.80}),
		_make_stat("assault_stabilizer", "Assault Stabilizer", "Heavy weapon gyros: +1 Spread Shot pair and +20% Fire Rate.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.8, 0.6, 1.0), "[ASSAULT]", {"add_spread_shots": 1, "mult_fire_rate": 1.20}),
		_make_stat("plasma_focus_lens", "High-Density Lens", "Extreme optical focus: +45% Synchrotron Damage and +15% Crit Chance.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(1.0, 0.3, 0.6), "[FOCUS]", {"mult_damage": 1.45, "add_crit_chance": 0.15}),
		_make_stat("phase_inverter", "Phase Inverter", "Sub-space phase coils: +1 Max Shield, +1 Max Roll, and +15% Flight Speed.", ItemModifier.ItemTier.TIER_2_PARADIGM, Color(0.7, 0.7, 1.0), "[INVERT]", {"add_max_shields": 1, "add_max_rolls": 1, "mult_move_speed": 1.15}),
		
		# --- Rare Exotic Quantum Relics (Tier 3) ---
		_make_stat("dark_energy_core", "Dark Energy Core", "Zero-point vacuum siphon: +40% Damage, +30% Velocity, +150px Magnet Range.", ItemModifier.ItemTier.TIER_3_EXOTIC, Color(0.8, 0.2, 1.0), "[DARK-CORE]", {"mult_damage": 1.40, "mult_bullet_speed": 1.30, "add_magnet_radius": 150.0}),
		_make_stat("chronos_regulator", "Chronos Regulator", "Temporal dialer: +40% Fire Rate, 35% faster Barrel Roll recharge, +20% Flight Speed.", ItemModifier.ItemTier.TIER_3_EXOTIC, Color(1.0, 0.85, 0.2), "[CHRONOS]", {"mult_fire_rate": 1.40, "mult_roll_cooldown": 0.65, "mult_move_speed": 1.20}),
		_make_stat("hyper_dimensional_hull", "Hyper-Dimensional Hull", "Folds ship structure across 4D hyperspace: +3 Max Hull, +2 Max Shields, +1 Max Roll.", ItemModifier.ItemTier.TIER_3_EXOTIC, Color(0.3, 1.0, 0.9), "[4D-HULL]", {"add_max_hull": 3, "add_max_shields": 2, "add_max_rolls": 1}),
		_make_stat("supernova_catalyst", "Supernova Catalyst", "Exotic starstuff reactor: +60% Damage, +25% Crit Chance, +50% Bolt Size.", ItemModifier.ItemTier.TIER_3_EXOTIC, Color(1.0, 0.4, 0.1), "[SUPERNOVA]", {"mult_damage": 1.60, "add_crit_chance": 0.25, "mult_bullet_scale": 1.50}),
		_make_stat("quantum_omniprocessor", "Quantum Omniprocessor", "Neural quantum core: +20% Fire Rate, +20% Damage, +20% Speed, +1 Shield, +1 Roll.", ItemModifier.ItemTier.TIER_3_EXOTIC, Color(0.2, 0.9, 1.0), "[OMNI]", {"mult_fire_rate": 1.20, "mult_damage": 1.20, "mult_move_speed": 1.20, "add_max_shields": 1, "add_max_rolls": 1}),
		_make_stat("entropy_annihilator", "Entropy Annihilator", "Violates thermodynamic law: +80% Damage and +2 Spread Shot pairs (-20% fire rate).", ItemModifier.ItemTier.TIER_3_EXOTIC, Color(1.0, 0.2, 0.4), "[ENTROPY]", {"mult_damage": 1.80, "add_spread_shots": 2, "mult_fire_rate": 0.80})
	]
	return list

static func get_item_by_id(id: String) -> ItemModifier:
	for it in get_all_items():
		if it.id == id:
			return it
	return null

static func get_random_choice(exclude_ids: Array[String] = [], count: int = 2) -> Array[ItemModifier]:
	var available: Array[ItemModifier] = []
	for it in get_all_items():
		if not exclude_ids.has(it.id):
			available.append(it)
	
	available.shuffle()
	var result: Array[ItemModifier] = []
	for i in range(mini(count, available.size())):
		result.append(available[i])
	return result
