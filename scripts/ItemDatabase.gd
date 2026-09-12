class_name ItemDatabase
extends RefCounted

## ItemDatabase.gd - Central catalog of all items, mutators, and relics.

# Tier 1 - Ballistic Modifiers
const BirefringencePrismScript = preload("res://scripts/items/BirefringencePrism.gd")
const GravitationalLensingScript = preload("res://scripts/items/GravitationalLensing.gd")
const ElasticMomentumScript = preload("res://scripts/items/ElasticMomentum.gd")
const FeynmanPropagatorScript = preload("res://scripts/items/FeynmanPropagator.gd")
const ZeemanSplittingScript = preload("res://scripts/items/ZeemanSplitting.gd")
const CherenkovRadiatorScript = preload("res://scripts/items/CherenkovRadiator.gd")
const HeisenbergLensScript = preload("res://scripts/items/HeisenbergLens.gd")

# Tier 2 - Weapon Paradigm Mutators
const AntimatterSuspensionScript = preload("res://scripts/items/AntimatterSuspension.gd")
const TachyonCapacitorScript = preload("res://scripts/items/TachyonCapacitor.gd")
const CarnotHeatsinkScript = preload("res://scripts/items/CarnotHeatsink.gd")
const QuantumTunnelingScript = preload("res://scripts/items/QuantumTunneling.gd")

# Tier 3 - Exotic Quantum Relics
const MeissnerShieldScript = preload("res://scripts/items/MeissnerShield.gd")
const MaxwellsDemonScript = preload("res://scripts/items/MaxwellsDemon.gd")
const LagrangeSatellitesScript = preload("res://scripts/items/LagrangeSatellites.gd")
const CarnotEfficiencyScript = preload("res://scripts/items/CarnotEfficiency.gd")
const DiracInversionScript = preload("res://scripts/items/DiracInversion.gd")
const BellEntanglementScript = preload("res://scripts/items/BellEntanglement.gd")

static func get_all_items() -> Array[ItemModifier]:
	return [
		BirefringencePrismScript.new(),
		GravitationalLensingScript.new(),
		ElasticMomentumScript.new(),
		FeynmanPropagatorScript.new(),
		ZeemanSplittingScript.new(),
		CherenkovRadiatorScript.new(),
		HeisenbergLensScript.new(),
		AntimatterSuspensionScript.new(),
		TachyonCapacitorScript.new(),
		CarnotHeatsinkScript.new(),
		QuantumTunnelingScript.new(),
		MeissnerShieldScript.new(),
		MaxwellsDemonScript.new(),
		LagrangeSatellitesScript.new(),
		CarnotEfficiencyScript.new(),
		DiracInversionScript.new(),
		BellEntanglementScript.new()
	]

static func get_item_by_id(id: String) -> ItemModifier:
	match id:
		"birefringence_prism": return BirefringencePrismScript.new()
		"gravitational_lensing": return GravitationalLensingScript.new()
		"elastic_momentum": return ElasticMomentumScript.new()
		"feynman_propagator": return FeynmanPropagatorScript.new()
		"zeeman_splitting": return ZeemanSplittingScript.new()
		"cherenkov_radiator": return CherenkovRadiatorScript.new()
		"heisenberg_lens": return HeisenbergLensScript.new()
		"antimatter_suspension": return AntimatterSuspensionScript.new()
		"tachyon_capacitor": return TachyonCapacitorScript.new()
		"carnot_heatsink": return CarnotHeatsinkScript.new()
		"quantum_tunneling": return QuantumTunnelingScript.new()
		"meissner_shield": return MeissnerShieldScript.new()
		"maxwells_demon": return MaxwellsDemonScript.new()
		"lagrange_satellites": return LagrangeSatellitesScript.new()
		"carnot_efficiency": return CarnotEfficiencyScript.new()
		"dirac_inversion": return DiracInversionScript.new()
		"bell_entanglement": return BellEntanglementScript.new()
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
