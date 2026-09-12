class_name ItemModifier
extends Resource

## ItemModifier.gd - Modular Isaac-style synergy hook resource.
## All items, mutators, and systemic relics inherit from this class.

enum ItemTier { TIER_1_BALLISTIC, TIER_2_PARADIGM, TIER_3_EXOTIC }

@export var id: String = "item_id"
@export var display_name: String = "Item Name"
@export_multiline var description: String = "Item mechanics description."
@export var tier: ItemTier = ItemTier.TIER_1_BALLISTIC
@export var icon_color: Color = Color(0.2, 0.9, 1.0, 1.0)
@export var icon_symbol: String = "[*]"
@export var max_stacks: int = 1
@export var category: String = "general"

# --- Synergy Hook Pipeline ---

func on_ship_init(_ship: CharacterBody2D) -> void:
	pass

func on_fire(_ship: CharacterBody2D, _spawn_params: Dictionary) -> Array[Dictionary]:
	# Returns an array of spawn parameter dictionaries (allows splitting, multishot, etc.)
	# Default: returns the single original param unchanged
	return [_spawn_params]

func on_projectile_tick(_bullet: Area2D, _delta: float) -> void:
	pass

func on_hit(_bullet: Area2D, _victim: Node2D, _hit_info: Dictionary) -> void:
	pass

func on_kill(_ship: CharacterBody2D, _victim: Node2D, _pos: Vector2) -> void:
	pass

func on_roll(_ship: CharacterBody2D) -> void:
	pass

func on_wave_start(_ship: CharacterBody2D, _wave_index: int) -> void:
	pass

func on_take_damage(_ship: CharacterBody2D, _amount: int) -> bool:
	# Return true to cancel / negate damage (e.g. Meissner Shield)
	return false
