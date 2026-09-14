extends RefCounted
class_name VisualBridge3D

const ShipBuilder3D = preload("res://scripts/ShipBuilder3D.gd")

## VisualBridge3D.gd - High-performance adapter bridging 2D gameplay nodes to 3D PBR visuals.
## Drives 3D banking, pitch, 360-degree corkscrew barrel rolls, weapon recoil, and muzzle flash.

class PlayerBridge3D:
	var target_node: CharacterBody2D
	var mesh_root: Node3D
	var entities_parent: Node3D
	
	# Cached animated nodes
	var barrel_l: Node3D
	var barrel_r: Node3D
	var flash_l: OmniLight3D
	var flash_r: OmniLight3D
	var flame_l: MeshInstance3D
	var flame_r: MeshInstance3D
	var engine_light: OmniLight3D
	var distress_light: OmniLight3D
	
	# Animation states
	var recoil_l: float = 0.0
	var recoil_r: float = 0.0
	var flash_timer_l: float = 0.0
	var flash_timer_r: float = 0.0
	var alternate_barrel: bool = false
	var current_bank_roll: float = 0.0
	var current_pitch: float = 0.0
	var last_pos: Vector2 = Vector2.ZERO
	
	func _init(player: CharacterBody2D, p_entities: Node3D) -> void:
		target_node = player
		entities_parent = p_entities
		last_pos = player.global_position
		
		# Build procedural 3D model
		mesh_root = ShipBuilder3D.build_player_ship(player.player_id)
		entities_parent.add_child(mesh_root)
		
		# Cache references
		var mount_l = mesh_root.find_child("CannonMount_Port", true, false)
		if mount_l:
			barrel_l = mount_l.find_child("Barrel", true, false)
			flash_l = mount_l.find_child("MuzzleFlash", true, false)
			
		var mount_r = mesh_root.find_child("CannonMount_Starboard", true, false)
		if mount_r:
			barrel_r = mount_r.find_child("Barrel", true, false)
			flash_r = mount_r.find_child("MuzzleFlash", true, false)
			
		flame_l = mesh_root.find_child("Flame_Port", true, false)
		flame_r = mesh_root.find_child("Flame_Starboard", true, false)
		engine_light = mesh_root.find_child("EngineLight", true, false)
		
		distress_light = OmniLight3D.new()
		distress_light.name = "DistressLight"
		distress_light.light_color = Color(1.0, 0.15, 0.2)
		distress_light.light_energy = 0.0
		distress_light.omni_range = 45.0
		mesh_root.add_child(distress_light)
		
		# Connect weapon firing signal if available
		if target_node.has_signal("weapon_fired"):
			target_node.weapon_fired.connect(_on_weapon_fired)

	func _on_weapon_fired(is_left: bool) -> void:
		trigger_recoil(is_left)

	func trigger_recoil(is_left: bool) -> void:
		if is_left:
			recoil_l = 6.5
			flash_timer_l = 0.08
			if flash_l:
				flash_l.light_energy = 3.5
		else:
			recoil_r = 6.5
			flash_timer_r = 0.08
			if flash_r:
				flash_r.light_energy = 3.5

	func update(delta: float) -> void:
		if not target_node or not is_instance_valid(target_node):
			destroy()
			return
		
		# 1. 1:1 Position Sync (2D x, y -> 3D x, -y, 0)
		var p2d = target_node.global_position
		mesh_root.position = Vector3(p2d.x, -p2d.y, 0.0)
		mesh_root.visible = target_node.visible
		
		# 2. Heading Orientation & Base Axis
		var base_heading = 0.0
		if GameAxis != null:
			base_heading = -GameAxis.ship_base_rotation
		
		# 3. Dynamic 3D Banking & Pitch
		var vel = (p2d - last_pos) / maxf(0.0001, delta)
		last_pos = p2d
		
		var bank_target = target_node.bank_angle * 1.6
		current_bank_roll = lerpf(current_bank_roll, bank_target, 1.0 - exp(-delta / 0.05))
		
		# Forward / reverse pitch tilt
		var fwd_dir = GameAxis.forward if GameAxis != null else Vector2.RIGHT
		var fwd_speed = vel.dot(fwd_dir)
		var pitch_target = clampf(-fwd_speed * 0.0003, -0.15, 0.15)
		current_pitch = lerpf(current_pitch, pitch_target, 1.0 - exp(-delta / 0.08))
		
		# 4. Rotation Construction with 2.5D Top-Down Tilt
		if target_node.is_rolling:
			# True 360-degree helical corkscrew barrel roll around longitudinal axis
			var roll_prog = clampf(target_node.roll_elapsed / maxf(0.001, target_node.roll_duration), 0.0, 1.0)
			var roll_spin = roll_prog * TAU
			mesh_root.transform.basis = ShipBuilder3D.compute_tilted_basis(base_heading, roll_spin, 0.0)
		else:
			mesh_root.transform.basis = ShipBuilder3D.compute_tilted_basis(base_heading, -current_bank_roll, current_pitch)
		
		# 5. Weapon Recoil & Muzzle Flash Decay
		# Spring-damping recovery for recoiling barrels
		recoil_l = lerpf(recoil_l, 0.0, 1.0 - exp(-delta * 22.0))
		recoil_r = lerpf(recoil_r, 0.0, 1.0 - exp(-delta * 22.0))
		
		if barrel_l:
			barrel_l.position.x = -recoil_l
		if barrel_r:
			barrel_r.position.x = -recoil_r
			
		if flash_timer_l > 0.0:
			flash_timer_l -= delta
			if flash_l:
				flash_l.light_energy = (flash_timer_l / 0.08) * 3.5
		elif flash_l and flash_l.light_energy > 0.0:
			flash_l.light_energy = 0.0
			
		if flash_timer_r > 0.0:
			flash_timer_r -= delta
			if flash_r:
				flash_r.light_energy = (flash_timer_r / 0.08) * 3.5
		elif flash_r and flash_r.light_energy > 0.0:
			flash_r.light_energy = 0.0
			
		# Auto-trigger recoil on firing if signal wasn't bound
		if target_node.is_firing and not target_node.is_rolling and target_node.fire_timer > 0.0:
			# Fire cycle pulse
			if recoil_l < 1.0 and recoil_r < 1.0:
				alternate_barrel = not alternate_barrel
				trigger_recoil(alternate_barrel)
		
		# 6. Thruster Exhaust Animations
		var flame_scale = randf_range(0.85, 1.25)
		if target_node.is_rolling:
			flame_scale *= 1.8
		if flame_l:
			flame_l.scale = Vector3(1.0 + (flame_scale - 1.0) * 0.35, flame_scale, 1.0 + (flame_scale - 1.0) * 0.35)
		if flame_r:
			flame_r.scale = Vector3(1.0 + (flame_scale - 1.0) * 0.35, flame_scale, 1.0 + (flame_scale - 1.0) * 0.35)
		if engine_light:
			engine_light.light_energy = 1.4 * flame_scale
		
		# 7. Hull Damage & Low Health Distress Lighting in 3D
		if distress_light:
			var h_flash = target_node.get("hull_hit_flash_timer")
			var is_hull_flashing = (h_flash != null and h_flash > 0.0)
			var cur_hull = target_node.get("hull")
			var m_hull = target_node.get("max_hull")
			var is_critical = (cur_hull != null and m_hull != null and cur_hull <= int(m_hull / 3.0) and cur_hull > 0)
			
			if is_hull_flashing:
				distress_light.light_color = Color(1.0, 0.25, 0.1)
				distress_light.light_energy = (h_flash / 0.22) * 5.0
			elif is_critical:
				var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
				distress_light.light_color = Color(1.0, 0.1, 0.15)
				distress_light.light_energy = pulse * 3.5
			else:
				distress_light.light_energy = 0.0


	func destroy() -> void:
		if mesh_root and is_instance_valid(mesh_root):
			mesh_root.queue_free()
			mesh_root = null

class EnemyBridge3D:
	var target_node: Area2D
	var mesh_root: Node3D
	var entities_parent: Node3D
	
	# Cached animated nodes
	var turret_head: Node3D
	var shield_plate_l: Node3D
	var shield_plate_r: Node3D
	var thermal_vanes: MeshInstance3D
	var shield_emitter: MeshInstance3D
	var quantum_core: MeshInstance3D
	
	func _init(enemy: Area2D, p_entities: Node3D) -> void:
		target_node = enemy
		entities_parent = p_entities
		
		var affix = enemy.elite_affix if "elite_affix" in enemy else 0
		var main_c = enemy.get("main_color") if "main_color" in enemy else Color.BLACK
		var accent_c = enemy.get("accent_color") if "accent_color" in enemy else Color.BLACK
		mesh_root = ShipBuilder3D.build_enemy_ship(enemy.enemy_type, affix, main_c, accent_c)
		entities_parent.add_child(mesh_root)
		
		# Cache references for dynamic parts
		turret_head = mesh_root.find_child("TurretHead", true, false)
		shield_plate_l = mesh_root.find_child("ShieldPlate_Port", true, false)
		shield_plate_r = mesh_root.find_child("ShieldPlate_Starboard", true, false)
		thermal_vanes = mesh_root.find_child("ThermalVanes", true, false)
		shield_emitter = mesh_root.find_child("ShieldEmitter", true, false)
		quantum_core = mesh_root.find_child("QuantumCore", true, false)

	func update(delta: float) -> void:
		if not target_node or not is_instance_valid(target_node):
			destroy()
			return
		
		# 1. 1:1 Position Sync
		var p2d = target_node.global_position
		mesh_root.position = Vector3(p2d.x, -p2d.y, 0.0)
		mesh_root.visible = target_node.visible
		
		# 2. Heading Orientation & 2.5D Top-Down Tilt
		var heading_z = -target_node.rotation
		mesh_root.transform.basis = ShipBuilder3D.compute_tilted_basis(heading_z, 0.0, 0.0)
		
		# 3. Turret Platform 360-degree tracking
		if turret_head:
			if "turret_angle" in target_node:
				turret_head.rotation.y = -target_node.turret_angle
		
		# 4. Knight Vanguard Shield Articulation
		if shield_plate_l and shield_plate_r:
			var is_shattered = target_node.get("knight_shield_shattered") == true
			if is_shattered:
				shield_plate_l.visible = false
				shield_plate_r.visible = false
			else:
				shield_plate_l.visible = true
				shield_plate_r.visible = true
				
				var is_salvo = target_node.get("knight_is_firing_salvo") == true
				var target_ang_l = deg_to_rad(-55.0) if is_salvo else 0.0
				var target_ang_r = deg_to_rad(55.0) if is_salvo else 0.0
				shield_plate_l.rotation.y = lerpf(shield_plate_l.rotation.y, target_ang_l, 1.0 - exp(-delta * 12.0))
				shield_plate_r.rotation.y = lerpf(shield_plate_r.rotation.y, target_ang_r, 1.0 - exp(-delta * 12.0))
		
		# Thermal Vane Overload Flickering
		if thermal_vanes and target_node.get("knight_shield_is_venting") == true:
			var flicker = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
			thermal_vanes.scale = Vector3(1.0 + flicker * 0.2, 1.0 + flicker * 0.2, 1.0)
		
		# 5. Shield Frigate Continuous Rotation
		if shield_emitter:
			shield_emitter.rotate_y(delta * 3.5)
			
		# 6. Cargo Hauler Core Pulse
		if quantum_core:
			quantum_core.rotate_y(delta * 2.0)

	func destroy() -> void:
		if mesh_root and is_instance_valid(mesh_root):
			mesh_root.queue_free()
			mesh_root = null

class BossBridge3D:
	var target_node: Area2D
	var mesh_root: Node3D
	var entities_parent: Node3D
	
	# Cached subsystem nodes
	var wing_p: Node3D
	var wing_s: Node3D
	var bow_armor: Node3D
	var rg_p: Node3D
	var rg_s: Node3D
	var fusion_core: Node3D
	var shield_gate: Node3D
	var singularity_core: Node3D
	
	func _init(boss: Area2D, p_entities: Node3D, boss_id: String) -> void:
		target_node = boss
		entities_parent = p_entities
		
		mesh_root = ShipBuilder3D.build_boss_ship(boss_id)
		entities_parent.add_child(mesh_root)
		
		wing_p = mesh_root.find_child("Wing_Port", true, false)
		wing_s = mesh_root.find_child("Wing_Starboard", true, false)
		bow_armor = mesh_root.find_child("BowArmor", true, false)
		rg_p = mesh_root.find_child("Railgun_Port", true, false)
		rg_s = mesh_root.find_child("Railgun_Starboard", true, false)
		fusion_core = mesh_root.find_child("FusionCore", true, false)
		shield_gate = mesh_root.find_child("ShieldGate", true, false)
		singularity_core = mesh_root.find_child("SingularityCore", true, false)

	func update(delta: float) -> void:
		if not target_node or not is_instance_valid(target_node):
			destroy()
			return
		
		var p2d = target_node.global_position
		mesh_root.position = Vector3(p2d.x, -p2d.y, -12.0)
		mesh_root.visible = target_node.visible
		mesh_root.transform.basis = ShipBuilder3D.compute_tilted_basis(-target_node.rotation, 0.0, 0.0)
		
		# Corvus Wings Subsystems
		if wing_p:
			wing_p.visible = target_node.get("port_wing_alive") != false
		if wing_s:
			wing_s.visible = target_node.get("starboard_wing_alive") != false
			
		# Goliath Bow Armor & Railguns
		if bow_armor:
			bow_armor.visible = target_node.get("bow_armor_alive") != false
		if rg_p and "railgun_aim_dir" in target_node:
			rg_p.rotation.y = -target_node.railgun_aim_dir.angle()
		if rg_s and "railgun_aim_dir" in target_node:
			rg_s.rotation.y = -target_node.railgun_aim_dir.angle()
			
		# Fusion Core Pulsing
		if fusion_core:
			var enrage = target_node.get("enrage_burst_active") == true
			var speed = 0.025 if enrage else 0.006
			var pulse = 1.0 + sin(Time.get_ticks_msec() * speed) * (0.35 if enrage else 0.12)
			fusion_core.scale = Vector3(pulse, pulse, pulse)
			
		# Ouroboros Singularity & Barrier Gate
		if shield_gate and "shield_angle" in target_node:
			shield_gate.rotation.y = -target_node.shield_angle
		if singularity_core:
			var p2 = target_node.get("phase") == 2
			singularity_core.rotate_y(delta * (8.5 if p2 else 2.5))

	func destroy() -> void:
		if mesh_root and is_instance_valid(mesh_root):
			mesh_root.queue_free()
			mesh_root = null

class HazardBridge3D:
	var target_node: Area2D
	var mesh_root: Node3D
	var entities_parent: Node3D
	var tumble_axis: Vector3
	var tumble_speed: float
	var hazard_type: int = 0
	
	func _init(hazard: Area2D, p_entities: Node3D) -> void:
		target_node = hazard
		entities_parent = p_entities
		
		hazard_type = hazard.hazard_type if "hazard_type" in hazard else 0
		mesh_root = ShipBuilder3D.build_hazard_mesh(hazard_type)
		entities_parent.add_child(mesh_root)
		
		tumble_axis = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		tumble_speed = randf_range(0.6, 2.2)

	func update(delta: float) -> void:
		if not target_node or not is_instance_valid(target_node):
			destroy()
			return
		
		var p2d = target_node.global_position
		mesh_root.position = Vector3(p2d.x, -p2d.y, 0.0)
		mesh_root.visible = target_node.visible
		mesh_root.rotate(tumble_axis, tumble_speed * delta)

	func destroy() -> void:
		if mesh_root and is_instance_valid(mesh_root):
			if mesh_root.get_parent():
				mesh_root.get_parent().remove_child(mesh_root)
			mesh_root.queue_free()
			mesh_root = null

class StationBridge3D:
	var target_shop: Node
	var mesh_root: Node3D
	var entities_parent: Node3D
	var outer_ring: Node3D
	var inner_ring: Node3D
	var beacon: Node3D
	var reactor: Node3D
	var tractor_l: Node3D
	var tractor_r: Node3D
	var beacon_timer: float = 0.0
	
	func _init(shop: Node, p_entities: Node3D) -> void:
		target_shop = shop
		entities_parent = p_entities
		
		mesh_root = ShipBuilder3D.build_station_mesh()
		entities_parent.add_child(mesh_root)
		
		outer_ring = mesh_root.find_child("OuterRing", true, false)
		inner_ring = mesh_root.find_child("InnerRing", true, false)
		beacon = mesh_root.find_child("WarningBeacon", true, false)
		reactor = mesh_root.find_child("SingularityReactor", true, false)
		tractor_l = mesh_root.find_child("TractorEmitterLeft", true, false)
		tractor_r = mesh_root.find_child("TractorEmitterRight", true, false)

	func update(delta: float) -> void:
		if not target_shop or not is_instance_valid(target_shop):
			destroy()
			return
		
		var pos2d = target_shop.station_pos if "station_pos" in target_shop else Vector2.ZERO
		var is_vis = target_shop.station_visible if "station_visible" in target_shop else false
		
		mesh_root.position = Vector3(pos2d.x, -pos2d.y, -15.0)
		mesh_root.visible = is_vis
		
		if not is_vis:
			return
			
		# Counter-rotating habitat rings
		if outer_ring:
			outer_ring.rotate_z(0.35 * delta)
		if inner_ring:
			inner_ring.rotate_z(-0.65 * delta)
			
		# Singularity reactor pulsing
		if reactor:
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.15
			reactor.scale = Vector3(pulse, pulse, 1.0)
			
		# Blinking warning beacon
		beacon_timer += delta
		if beacon:
			beacon.visible = fmod(beacon_timer, 0.8) < 0.4
			
		# Tractor beam emitter pulse during docking
		var beam_active = target_shop.get("tractor_beam_active") == true
		if tractor_l and tractor_r:
			var target_s = 1.3 if beam_active else 1.0
			tractor_l.scale = tractor_l.scale.lerp(Vector3(target_s, target_s, target_s), delta * 8.0)
			tractor_r.scale = tractor_r.scale.lerp(Vector3(target_s, target_s, target_s), delta * 8.0)

	func destroy() -> void:
		if mesh_root and is_instance_valid(mesh_root):
			mesh_root.queue_free()
			mesh_root = null



