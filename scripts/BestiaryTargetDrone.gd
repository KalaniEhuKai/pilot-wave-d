extends Area2D

## BestiaryTargetDrone.gd - Safe mock target drone for Bestiary firing diorama.
## Implements player duck-typing so any system querying group "player" will not crash.

var player_id: int = 999
var hull: float = 0.0
var max_hull: float = 100.0
var has_carnot_precooler: bool = false
var has_carnot_efficiency: bool = false
var active_modifiers: Array = []
var active_projectile_modifiers: Array = []
var current_velocity: Vector2 = Vector2.ZERO

func add_modifier(_mod) -> void:
	pass

func take_damage(_dmg: float, _attacker = null) -> void:
	pass
