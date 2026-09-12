class_name ItemDatabase
extends RefCounted

## ItemDatabase.gd - Central catalog of all items, mutators, and relics.

const BirefringencePrismScript = preload("res://scripts/items/BirefringencePrism.gd")
const GravitationalLensingScript = preload("res://scripts/items/GravitationalLensing.gd")
const AntimatterSuspensionScript = preload("res://scripts/items/AntimatterSuspension.gd")
const MeissnerShieldScript = preload("res://scripts/items/MeissnerShield.gd")
const MaxwellsDemonScript = preload("res://scripts/items/MaxwellsDemon.gd")

static func get_all_items() -> Array[ItemModifier]:
	return [
		BirefringencePrismScript.new(),
		GravitationalLensingScript.new(),
		AntimatterSuspensionScript.new(),
		MeissnerShieldScript.new(),
		MaxwellsDemonScript.new()
	]

static func get_item_by_id(id: String) -> ItemModifier:
	match id:
		"birefringence_prism": return BirefringencePrismScript.new()
		"gravitational_lensing": return GravitationalLensingScript.new()
		"antimatter_suspension": return AntimatterSuspensionScript.new()
		"meissner_shield": return MeissnerShieldScript.new()
		"maxwells_demon": return MaxwellsDemonScript.new()
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
