extends "res://scripts/ItemModifier.gd"

## LagrangeSatellites.gd - Spawns 2 quantum orbital satellites that erase hostile bullets and fire micro-lasers.

func _init() -> void:
	id = "lagrange_satellites"
	display_name = "Lagrange Satellites"
	description = "Spawns 2 quantum orbital drones that orbit your ship, absorbing hostile bullets and firing micro-lasers."
	tier = ItemTier.TIER_3_EXOTIC
	icon_color = Color(0.2, 0.8, 1.0, 1.0)
	icon_symbol = "[OO]"

func on_ship_init(ship: CharacterBody2D) -> void:
	# Attach orbital manager if not already present
	if not ship.has_node("LagrangeOrbitals"):
		var orb_mgr = Node2D.new()
		orb_mgr.name = "LagrangeOrbitals"
		ship.add_child(orb_mgr)
		_create_orbital(orb_mgr, 0.0)
		_create_orbital(orb_mgr, PI)

func _create_orbital(mgr: Node2D, start_angle: float) -> void:
	var orb = Area2D.new()
	orb.collision_layer = 1
	orb.collision_mask = 8 # Collides with enemy bullets (layer 8)
	mgr.add_child(orb)
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	orb.add_child(col)
	
	var orb_data = {"angle": start_angle, "radius": 48.0, "timer": 0.0}
	
	orb.area_entered.connect(func(area):
		if area.is_in_group("bullet") and area.get("is_enemy") == true:
			area.queue_free()
			SoundEffects.play_sfx("hit", 0.1, 4.0)
	)
	
	orb.set_script(load("res://scripts/items/OrbitalDroneScript.gd"))
