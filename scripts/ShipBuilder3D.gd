extends RefCounted
class_name ShipBuilder3D

## ShipBuilder3D.gd - Procedural 3D Sci-Fi Hull & Greeble Builder for Cyberpunk Shmup.
## Constructs high-detail, faceted stealth geometry with PBR metallic/roughness materials,
## tinted canopies, exposed conduit routing, RCS thrusters, and articulating recoiling weapons.

# --- PBR Material Factory & 2.5D Camera Projection ---

const BASE_TILT_DEG: float = 72.0 # 18-degree dorsal pitch tilt toward camera for 2.5D top-down view
const BASE_TILT_RAD: float = deg_to_rad(BASE_TILT_DEG)

static func compute_tilted_basis(heading_angle: float, bank_angle: float = 0.0, pitch_angle: float = 0.0) -> Basis:
	# 1. Forward flight vector in the 2D XY combat plane
	var forward = Vector3(cos(heading_angle), sin(heading_angle), 0.0).normalized()
	if forward.is_zero_approx():
		forward = Vector3.RIGHT
		
	# 2. Base dorsal normal pointing toward camera (+Z) with 18 deg upward tilt (+Y)
	var base_up = Vector3(0.0, cos(BASE_TILT_RAD), sin(BASE_TILT_RAD)).normalized()
	
	# 3. Dynamic banking around forward flight vector
	if absf(bank_angle) > 0.0001:
		var rot_bank = Basis(forward, bank_angle)
		base_up = rot_bank * base_up
		
	# 4. Wingspan lateral vector perpendicular to forward and up
	var wings = forward.cross(base_up).normalized()
	var final_up = wings.cross(forward).normalized()
	
	# 5. Forward/reverse pitch along wingspan axis
	if absf(pitch_angle) > 0.0001:
		var rot_pitch = Basis(wings, pitch_angle)
		forward = rot_pitch * forward
		final_up = rot_pitch * final_up
		
	return Basis(forward, final_up, wings)

static func create_hull_material(base_color: Color, metallic: float = 0.20, roughness: float = 0.48) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	
	# Calibrated Cyberpunk Rim Lighting: subtle silhouette edge definition without washing out facet faces
	mat.rim_enabled = true
	mat.rim = 0.20
	mat.rim_tint = 0.4
	return mat

static func create_neon_material(neon_color: Color, emission_mult: float = 2.4) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = neon_color
	mat.emission_enabled = true
	mat.emission = neon_color
	mat.emission_energy_multiplier = emission_mult
	mat.metallic = 0.3
	mat.roughness = 0.2
	return mat

static func create_canopy_material(tint_color: Color = Color(0.08, 0.18, 0.28, 0.75)) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = tint_color
	mat.metallic = 0.95
	mat.roughness = 0.08
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

# --- Mesh Helper Utilities ---

static func add_box(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	inst.mesh = box
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = rot_deg
	parent.add_child(inst)
	return inst

static func add_cylinder(parent: Node3D, top_r: float, bot_r: float, height: float, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.height = height
	cyl.radial_segments = 12
	inst.mesh = cyl
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = rot_deg
	parent.add_child(inst)
	return inst

static func add_prism(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = size
	inst.mesh = prism
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = rot_deg
	parent.add_child(inst)
	return inst

# --- Imported 3D Model Cache & Loader ---

static var _enemy_mesh_cache: Dictionary = {}

static func get_enemy_mesh(ship_num: int) -> ArrayMesh:
	if _enemy_mesh_cache.has(ship_num):
		return _enemy_mesh_cache[ship_num]
	var path = "res://assets/models/enemies/ship%d.obj" % ship_num
	if ResourceLoader.exists(path):
		var mesh = ResourceLoader.load(path) as ArrayMesh
		if mesh:
			_enemy_mesh_cache[ship_num] = mesh
			return mesh
	return null

static func add_imported_ship_mesh(parent: Node3D, ship_num: int, scale_factor: float, rot_y_deg: float, mats: Array, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh = get_enemy_mesh(ship_num)
	if not mesh:
		return null
	var inst = MeshInstance3D.new()
	inst.name = "ShipMesh_%d" % ship_num
	inst.mesh = mesh
	for s in range(min(mesh.get_surface_count(), mats.size())):
		if mats[s] != null:
			inst.set_surface_override_material(s, mats[s])
	inst.scale = Vector3(scale_factor, scale_factor, scale_factor)
	inst.rotation_degrees = Vector3(0.0, rot_y_deg, 0.0)
	inst.position = offset
	parent.add_child(inst)
	return inst

# --- Advanced Futuristic Jet Thruster VFX ---

static var _thruster_shader: Shader = null

static func get_thruster_shader() -> Shader:
	if _thruster_shader:
		return _thruster_shader
	if ResourceLoader.exists("res://shaders/thruster_plume.gdshader"):
		_thruster_shader = ResourceLoader.load("res://shaders/thruster_plume.gdshader") as Shader
	return _thruster_shader

static func add_thruster_plume(parent: Node3D, nozzle_exit_pos: Vector3, length: float, base_r: float, tip_r: float, flame_col: Color, core_col: Color = Color(1.0, 0.98, 0.9, 1.0)) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = base_r     # Nozzle base (at UV.y = 0.0)
	cyl.bottom_radius = tip_r   # Exhaust tip (at UV.y = 1.0)
	cyl.height = length
	cyl.radial_segments = 16
	cyl.rings = 4
	cyl.cap_top = false
	cyl.cap_bottom = false
	inst.mesh = cyl
	
	var shader = get_thruster_shader()
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("flame_color", flame_col)
		mat.set_shader_parameter("core_color", core_col)
		inst.material_override = mat
	else:
		var fallback_mat = StandardMaterial3D.new()
		fallback_mat.albedo_color = flame_col
		fallback_mat.emission_enabled = true
		fallback_mat.emission = flame_col
		fallback_mat.emission_energy_multiplier = 2.4
		inst.material_override = fallback_mat
		
	# Rot Z = -90 maps top (+Y, base) to +X, and bottom (-Y, tip) to -X
	inst.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	# Nozzle exit is at nozzle_exit_pos.x; center of cylinder is at nozzle_exit_pos.x - length * 0.5
	inst.position = Vector3(nozzle_exit_pos.x - length * 0.5, nozzle_exit_pos.y, nozzle_exit_pos.z)
	parent.add_child(inst)
	return inst


# --- Player Ship: Viper-IV Interceptor ---

static func build_player_ship(player_id: int = 1) -> Node3D:
	var root = Node3D.new()
	root.name = "Player3D_P%d" % player_id
	
	# Primary palette
	var is_p1 = (player_id == 1)
	var neon_col = Color(0.0, 0.94, 1.0) if is_p1 else Color(1.0, 0.65, 0.0) # Cyan or Amber
	var dark_chassis_col = Color(0.24, 0.28, 0.38) # Sleek Gunmetal Titanium
	var armor_plate_col = Color(0.52, 0.60, 0.72) # Beveled Aerodynamic Armor Plating
	var conduit_col = Color(0.72, 0.80, 0.88) # Light Metallic Trim / Conduit Piping
	
	var mat_chassis = create_hull_material(dark_chassis_col, 0.85, 0.25)
	var mat_armor = create_hull_material(armor_plate_col, 0.85, 0.2)
	var mat_neon = create_neon_material(neon_col, 4.0)
	var mat_conduit = create_hull_material(conduit_col, 0.95, 0.3)
	var mat_canopy = create_canopy_material(Color(neon_col.r * 0.3, neon_col.g * 0.3 + 0.1, neon_col.b * 0.3 + 0.2, 0.75))
	var mat_hot_flame = create_neon_material(Color(0.2, 0.85, 1.0) if is_p1 else Color(1.0, 0.45, 0.1), 4.5)
	
	# Scaling: 1 3D unit = ~1 2D pixel for 1:1 orthographic match
	# Craft is ~52px long and ~44px wide
	
	# 1. Main Fuselage Backbone (Chiseled multi-faceted stealth core)
	# Center ridge
	add_box(root, Vector3(44.0, 10.0, 14.0), Vector3(2.0, 0.0, 0.0), Vector3.ZERO, mat_chassis)
	# Glowing dorsal centerline power spine
	add_box(root, Vector3(36.0, 1.5, 2.0), Vector3(0.0, 5.2, 0.0), Vector3.ZERO, mat_neon)
	# Tapered nose wedge (Prism pointing forward in +X)
	# Prism default: base on X-Z, peak along +Y. Rotated -90 around Z points forward (+X).
	add_prism(root, Vector3(12.0, 18.0, 12.0), Vector3(27.0, 0.0, 0.0), Vector3(0.0, 0.0, -90.0), mat_armor)
	
	# 2. Forward Sensor Pitot Probes (twin razor needles at nose tip)
	add_cylinder(root, 0.4, 0.8, 12.0, Vector3(36.0, 0.0, 3.5), Vector3(0.0, 0.0, 90.0), mat_conduit)
	add_cylinder(root, 0.4, 0.8, 12.0, Vector3(36.0, 0.0, -3.5), Vector3(0.0, 0.0, 90.0), mat_conduit)
	# Glowing sensor tips
	add_box(root, Vector3(1.5, 1.5, 1.5), Vector3(42.0, 0.0, 3.5), Vector3.ZERO, mat_neon)
	add_box(root, Vector3(1.5, 1.5, 1.5), Vector3(42.0, 0.0, -3.5), Vector3.ZERO, mat_neon)
	
	# 3. Cockpit Canopy & Holographic Dashboard Interior
	# Interior cockpit seat/dashboard
	add_box(root, Vector3(12.0, 4.0, 6.0), Vector3(4.0, 4.0, 0.0), Vector3.ZERO, mat_chassis)
	add_box(root, Vector3(2.0, 2.0, 4.0), Vector3(9.0, 5.0, 0.0), Vector3.ZERO, mat_neon) # Emissive HUD console
	# Faceted Glass Canopy shell
	add_prism(root, Vector3(9.0, 18.0, 9.0), Vector3(4.0, 6.5, 0.0), Vector3(0.0, 0.0, -90.0), mat_canopy)
	
	# 4. Forward-Swept Delta Wings with Beveled Edge Plates
	# Port Wing (Z positive)
	var wing_p = add_prism(root, Vector3(26.0, 28.0, 4.5), Vector3(-4.0, 0.0, 16.0), Vector3(90.0, 20.0, 0.0), mat_armor)
	# Starboard Wing (Z negative)
	var wing_s = add_prism(root, Vector3(26.0, 28.0, 4.5), Vector3(-4.0, 0.0, -16.0), Vector3(-90.0, -20.0, 0.0), mat_armor)
	
	# Wing leading-edge neon circuit conduits
	add_box(root, Vector3(24.0, 1.5, 2.0), Vector3(-2.0, 1.5, 18.0), Vector3(0.0, 25.0, 0.0), mat_neon)
	add_box(root, Vector3(24.0, 1.5, 2.0), Vector3(-2.0, 1.5, -18.0), Vector3(0.0, -25.0, 0.0), mat_neon)
	
	# Vertical Aerodynamic Winglets at Wingtips
	add_prism(root, Vector3(7.0, 14.0, 2.5), Vector3(-10.0, 5.5, 26.0), Vector3(0.0, 0.0, -90.0), mat_armor)
	add_prism(root, Vector3(7.0, 14.0, 2.5), Vector3(-10.0, 5.5, -26.0), Vector3(0.0, 0.0, -90.0), mat_armor)
	# Winglet tip formation lights
	add_box(root, Vector3(4.0, 2.0, 1.0), Vector3(-10.0, 8.5, 26.0), Vector3.ZERO, mat_neon)
	add_box(root, Vector3(4.0, 2.0, 1.0), Vector3(-10.0, 8.5, -26.0), Vector3.ZERO, mat_neon)
	
	# 5. Mechanical Greeblies
	# A. Exposed hydraulic/power conduits along fuselage roots
	add_cylinder(root, 1.0, 1.0, 28.0, Vector3(-2.0, 3.5, 6.5), Vector3(0.0, 0.0, 90.0), mat_conduit)
	add_cylinder(root, 1.0, 1.0, 28.0, Vector3(-2.0, 3.5, -6.5), Vector3(0.0, 0.0, 90.0), mat_conduit)
	
	# B. Dorsal Thermal Heat-Sink Radiator Louvers (4x angled slats on rear fuselage)
	for i in range(4):
		var x_pos = -4.0 - float(i) * 3.5
		var louver = add_box(root, Vector3(1.8, 2.0, 8.0), Vector3(x_pos, 5.5, 0.0), Vector3(20.0, 0.0, 0.0), mat_neon)
		louver.name = "HeatLouver_%d" % i
	
	# C. 4x RCS Attitude Thruster Quads (beveled blocks with micro-nozzles)
	add_box(root, Vector3(4.0, 3.0, 3.0), Vector3(14.0, 1.0, 6.0), Vector3.ZERO, mat_armor) # Forward Port
	add_box(root, Vector3(4.0, 3.0, 3.0), Vector3(14.0, 1.0, -6.0), Vector3.ZERO, mat_armor) # Forward Starboard
	add_box(root, Vector3(4.0, 3.0, 3.0), Vector3(-16.0, 1.0, 18.0), Vector3.ZERO, mat_armor) # Aft Port
	add_box(root, Vector3(4.0, 3.0, 3.0), Vector3(-16.0, 1.0, -18.0), Vector3.ZERO, mat_armor) # Aft Starboard
	
	# 6. Twin Articulated Autocannon Assemblies with Recoiling Barrels
	# Port Weapon Mount
	var cannon_mount_l = Node3D.new()
	cannon_mount_l.name = "CannonMount_Port"
	cannon_mount_l.position = Vector3(8.0, -2.5, 10.0)
	root.add_child(cannon_mount_l)
	# Starboard Weapon Mount
	var cannon_mount_r = Node3D.new()
	cannon_mount_r.name = "CannonMount_Starboard"
	cannon_mount_r.position = Vector3(8.0, -2.5, -10.0)
	root.add_child(cannon_mount_r)
	
	# Weapon Housing Housings (Stationary)
	add_box(cannon_mount_l, Vector3(14.0, 4.5, 4.0), Vector3.ZERO, Vector3.ZERO, mat_armor)
	add_box(cannon_mount_r, Vector3(14.0, 4.5, 4.0), Vector3.ZERO, Vector3.ZERO, mat_armor)
	
	# Recoiling Barrels (Kinematic nodes that kick back on firing)
	var barrel_l = Node3D.new()
	barrel_l.name = "Barrel"
	cannon_mount_l.add_child(barrel_l)
	add_cylinder(barrel_l, 1.4, 1.6, 16.0, Vector3(12.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
	add_cylinder(barrel_l, 1.8, 1.8, 3.5, Vector3(20.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_armor) # Muzzle brake
	
	var barrel_r = Node3D.new()
	barrel_r.name = "Barrel"
	cannon_mount_r.add_child(barrel_r)
	add_cylinder(barrel_r, 1.4, 1.6, 16.0, Vector3(12.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
	add_cylinder(barrel_r, 1.8, 1.8, 3.5, Vector3(20.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_armor) # Muzzle brake
	
	# Muzzle Flash Point Lights (instant dynamic hull lighting on fire)
	var flash_l = OmniLight3D.new()
	flash_l.name = "MuzzleFlash"
	flash_l.light_color = neon_col
	flash_l.light_energy = 0.0
	flash_l.omni_range = 75.0
	flash_l.position = Vector3(22.0, 0.0, 0.0)
	cannon_mount_l.add_child(flash_l)
	
	var flash_r = OmniLight3D.new()
	flash_r.name = "MuzzleFlash"
	flash_r.light_color = neon_col
	flash_r.light_energy = 0.0
	flash_r.omni_range = 75.0
	flash_r.position = Vector3(22.0, 0.0, 0.0)
	cannon_mount_r.add_child(flash_r)
	
	# 7. Twin Engine Exhaust Cowlings & Pulsing Plasma Bells
	add_cylinder(root, 3.2, 4.0, 10.0, Vector3(-20.0, 0.0, 6.0), Vector3(0.0, 0.0, 90.0), mat_armor)
	add_cylinder(root, 3.2, 4.0, 10.0, Vector3(-20.0, 0.0, -6.0), Vector3(0.0, 0.0, 90.0), mat_armor)
	
	# Engine Glow Cores inside exhaust bells
	add_box(root, Vector3(1.0, 5.0, 5.0), Vector3(-22.0, 0.0, 6.0), Vector3.ZERO, mat_hot_flame)
	add_box(root, Vector3(1.0, 5.0, 5.0), Vector3(-22.0, 0.0, -6.0), Vector3.ZERO, mat_hot_flame)
	
	# 3D Plasma Exhaust Flame Plumes
	var flame_p_col = Color(0.2, 0.85, 1.0) if is_p1 else Color(1.0, 0.45, 0.1)
	var flame_l = add_thruster_plume(root, Vector3(-25.0, 0.0, 6.0), 24.0, 2.8, 0.35, flame_p_col, Color(1.0, 1.0, 1.0))
	flame_l.name = "Flame_Port"
	var flame_r = add_thruster_plume(root, Vector3(-25.0, 0.0, -6.0), 24.0, 2.8, 0.35, flame_p_col, Color(1.0, 1.0, 1.0))
	flame_r.name = "Flame_Starboard"
	
	# Engine afterburner light
	var engine_light = OmniLight3D.new()
	engine_light.name = "EngineLight"
	engine_light.light_color = neon_col
	engine_light.light_energy = 1.8
	engine_light.omni_range = 80.0
	engine_light.position = Vector3(-28.0, 0.0, 0.0)
	root.add_child(engine_light)
	
	# Ventral Plasma Underglow (Crisp glowing silhouette against deep space)
	var under_light = OmniLight3D.new()
	under_light.name = "UnderglowLight"
	under_light.light_color = neon_col
	under_light.light_energy = 0.6
	under_light.omni_range = 45.0
	under_light.position = Vector3(0.0, -3.0, 0.0)
	root.add_child(under_light)
	
	return root

# --- Enemy Bestiary 3D Models ---

static func build_enemy_ship(enemy_type: int, elite_affix: int = 0, custom_main_color: Color = Color.BLACK, custom_accent_color: Color = Color.BLACK) -> Node3D:
	var root = Node3D.new()
	root.name = "Enemy3D_%d" % enemy_type
	
	# Archetype-specific vibrant Cyberpunk Hostile Palette (matching 2D art color identities)
	var dark_hull_col = Color(0.28, 0.34, 0.44)
	var armor_col = Color(0.54, 0.62, 0.74)
	var conduit_col = Color(0.74, 0.80, 0.88)
	var neon_col = Color(1.0, 0.08, 0.55)

	match enemy_type:
		0: # SCOUT: Coral Crimson / Rose-Red with Amber Gold
			armor_col = Color(0.96, 0.24, 0.42)
			dark_hull_col = Color(0.38, 0.12, 0.20)
			conduit_col = Color(0.85, 0.65, 0.35)
			neon_col = Color(1.0, 0.72, 0.18)
		1: # BOMBER: Vivid Purple / Magenta with Electric Cyan
			armor_col = Color(0.88, 0.16, 0.82)
			dark_hull_col = Color(0.32, 0.10, 0.38)
			conduit_col = Color(0.65, 0.75, 0.90)
			neon_col = Color(0.25, 0.92, 1.0)
		2: # INTERCEPTOR: Blazing Orange with Voltage Gold
			armor_col = Color(1.0, 0.52, 0.10)
			dark_hull_col = Color(0.42, 0.18, 0.08)
			conduit_col = Color(0.90, 0.75, 0.35)
			neon_col = Color(1.0, 0.90, 0.20)
		3: # SNIPER: High-Vis Yellow / Gold with Ruby Red
			armor_col = Color(0.98, 0.82, 0.18)
			dark_hull_col = Color(0.38, 0.30, 0.08)
			conduit_col = Color(0.60, 0.65, 0.70)
			neon_col = Color(1.0, 0.15, 0.18)
		4: # SHIELD_FRIGATE: Cherenkov Cyan with Radiant Aqua
			armor_col = Color(0.12, 0.82, 0.98)
			dark_hull_col = Color(0.08, 0.28, 0.42)
			conduit_col = Color(0.70, 0.90, 0.95)
			neon_col = Color(0.35, 1.0, 0.90)
		5: # HEAVY_CRUISER: Royal Imperial Violet with Hot Pink
			armor_col = Color(0.68, 0.22, 0.88)
			dark_hull_col = Color(0.28, 0.10, 0.38)
			conduit_col = Color(0.80, 0.50, 0.85)
			neon_col = Color(1.0, 0.30, 0.55)
		6: # KNIGHT_VANGUARD: Steel Azure / Ice Blue with Platinum
			armor_col = Color(0.38, 0.78, 0.92)
			dark_hull_col = Color(0.14, 0.26, 0.40)
			conduit_col = Color(0.85, 0.92, 1.0)
			neon_col = Color(0.85, 0.95, 1.0)
		7: # PHANTOM: Twilight Indigo / Purple with Lavender
			armor_col = Color(0.52, 0.22, 0.82)
			dark_hull_col = Color(0.20, 0.10, 0.34)
			conduit_col = Color(0.70, 0.50, 0.85)
			neon_col = Color(0.85, 0.45, 1.0)
		8: # DRONE_CARRIER: Ochre Bronze / Desert Gold with Warm Gold
			armor_col = Color(0.88, 0.58, 0.14)
			dark_hull_col = Color(0.36, 0.22, 0.08)
			conduit_col = Color(0.95, 0.78, 0.40)
			neon_col = Color(1.0, 0.82, 0.30)
		9: # MICRO_DRONE: Bright Solar Yellow with Orange
			armor_col = Color(1.0, 0.90, 0.25)
			dark_hull_col = Color(0.42, 0.32, 0.08)
			conduit_col = Color(0.90, 0.60, 0.20)
			neon_col = Color(1.0, 0.45, 0.12)
		10: # TURRET_PLATFORM: Industrial Emerald Green with Mint Neon
			armor_col = Color(0.25, 0.72, 0.48)
			dark_hull_col = Color(0.12, 0.32, 0.20)
			conduit_col = Color(0.70, 0.85, 0.75)
			neon_col = Color(0.20, 1.0, 0.60)
		11: # WARP_STALKER: Cobalt Blue with Sky Blue
			armor_col = Color(0.22, 0.42, 0.98)
			dark_hull_col = Color(0.10, 0.18, 0.42)
			conduit_col = Color(0.65, 0.80, 0.98)
			neon_col = Color(0.60, 0.85, 1.0)
		12: # DRAINER_LEECH: Blood Crimson / Vermilion with Rose Pink
			armor_col = Color(0.85, 0.12, 0.28)
			dark_hull_col = Color(0.34, 0.08, 0.12)
			conduit_col = Color(0.90, 0.45, 0.55)
			neon_col = Color(1.0, 0.42, 0.62)
		13: # MISSILE_CORVETTE: Military Lime / Olive with Chartreuse
			armor_col = Color(0.24, 0.80, 0.38)
			dark_hull_col = Color(0.12, 0.34, 0.18)
			conduit_col = Color(0.70, 0.88, 0.50)
			neon_col = Color(0.82, 1.0, 0.28)
		14: # MINE_TETHER: Magenta Pink with Soft Pink
			armor_col = Color(0.96, 0.28, 0.70)
			dark_hull_col = Color(0.38, 0.12, 0.28)
			conduit_col = Color(0.95, 0.65, 0.85)
			neon_col = Color(1.0, 0.80, 0.90)
		15: # ORBITAL_REFLECTOR: Gleaming Silver / Light Blue with White
			armor_col = Color(0.82, 0.88, 0.98)
			dark_hull_col = Color(0.24, 0.32, 0.44)
			conduit_col = Color(0.90, 0.95, 1.0)
			neon_col = Color(1.0, 1.0, 1.0)
		16: # CARGO_HAULER: Bright Burnished Gold with Holographic Cyan
			armor_col = Color(1.0, 0.82, 0.20)
			dark_hull_col = Color(0.52, 0.40, 0.12)
			conduit_col = Color(0.88, 0.75, 0.35)
			neon_col = Color(0.15, 1.0, 0.90)
	
	# Apply optional custom color overrides if specified by caller
	if custom_main_color != Color.BLACK:
		armor_col = custom_main_color
		dark_hull_col = custom_main_color.darkened(0.55)
	if custom_accent_color != Color.BLACK:
		neon_col = custom_accent_color

	# Elite Affix Enhancements
	match elite_affix:
		1: # ARMORED: Heavy gilded gold alloy plating reinforcement
			armor_col = armor_col.lerp(Color(1.0, 0.85, 0.2), 0.45)
			conduit_col = Color(1.0, 0.9, 0.4)
		2: # VOLATILE: Unstable crimson core flare
			neon_col = Color(1.0, 0.1, 0.1)
		3: # SWIFT: Hyper-frequency cyan glow
			neon_col = Color(0.0, 0.95, 1.0)
		4: # SHIELDED: Hexagonal plasma blue barrier
			neon_col = Color(0.2, 0.8, 1.0)
			
	var mat_hull = create_hull_material(dark_hull_col, 0.25, 0.50)
	var mat_armor = create_hull_material(armor_col, 0.20, 0.45)
	var mat_conduit = create_hull_material(conduit_col, 0.35, 0.40)
	var mat_neon = create_neon_material(neon_col, 2.4)
	var flame_col = Color(neon_col.r, neon_col.g * 0.75 + 0.1, neon_col.b * 0.6)
	var mat_flame = create_neon_material(flame_col, 2.2)

	match enemy_type:
		0: # SCOUT: Sleek razor catamaran claw craft (Coral Crimson / Rose-Red)
			add_imported_ship_mesh(root, 1, 11.0, -90.0, [mat_armor])
			# Cockpit canopy dome on center bridge
			add_box(root, Vector3(6.5, 1.8, 2.6), Vector3(-4.0, 2.5, 0.0), Vector3.ZERO, mat_neon)
			# Central engine exhaust nozzle collar in rear fuselage notch
			add_cylinder(root, 1.6, 1.8, 2.0, Vector3(-9.2, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_hull)
			# Single central jet thruster plume coming straight out the back middle of the ship
			var flame = add_thruster_plume(root, Vector3(-9.5, 0.0, 0.0), 18.0, 1.6, 0.25, flame_col, Color(1.0, 0.98, 0.88))
			flame.name = "Flame"

		1: # BOMBER: Heavy faceted hex-armored assault wing (Vivid Purple with Cyan)
			add_imported_ship_mesh(root, 4, 15.0, -90.0, [mat_armor, mat_hull, mat_conduit])
			add_box(root, Vector3(4.0, 2.2, 4.0), Vector3(0.0, 2.8, 0.0), Vector3.ZERO, mat_neon)
			var fl1 = add_thruster_plume(root, Vector3(-16.0, 0.0, 7.5), 18.0, 1.8, 0.3, flame_col)
			fl1.name = "Flame_L"
			var fl2 = add_thruster_plume(root, Vector3(-16.0, 0.0, -7.5), 18.0, 1.8, 0.3, flame_col)
			fl2.name = "Flame_R"

		2: # INTERCEPTOR: Sleek twin-afterburner delta (Blazing Orange with Gold)
			add_imported_ship_mesh(root, 2, 17.0, -90.0, [mat_armor])
			# High-visibility neon cockpit canopy visor
			add_box(root, Vector3(7.0, 2.8, 3.8), Vector3(3.5, 3.0, 0.0), Vector3.ZERO, mat_neon)
			var f1 = add_thruster_plume(root, Vector3(-18.0, 0.0, 5.5), 18.0, 1.6, 0.25, flame_col)
			f1.name = "Flame_L"
			var f2 = add_thruster_plume(root, Vector3(-18.0, 0.0, -5.5), 18.0, 1.6, 0.25, flame_col)
			f2.name = "Flame_R"

		3: # SNIPER: Extended needle-hull railgun accelerator (Industrial Yellow with Ruby)
			add_imported_ship_mesh(root, 7, 19.0, -90.0, [mat_armor, mat_hull])
			# Extended railgun accelerator barrel
			add_cylinder(root, 1.6, 2.2, 36.0, Vector3(32.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
			# 3x Accelerator Magnetic Rings
			for i in range(3):
				add_cylinder(root, 3.2, 3.2, 2.5, Vector3(20.0 + float(i) * 9.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_neon)
			var flame = add_thruster_plume(root, Vector3(-26.0, 0.0, 0.0), 22.0, 1.8, 0.3, flame_col)
			flame.name = "Flame"

		4: # SHIELD_FRIGATE: Broad command hull with rotating shield emitter (Cherenkov Cyan with Aqua)
			add_imported_ship_mesh(root, 5, 15.0, -90.0, [mat_armor, mat_conduit, mat_hull])
			# Central Rotating Shield Emitter Dome
			var emitter = add_cylinder(root, 6.0, 7.0, 5.0, Vector3(0.0, 7.0, 0.0), Vector3.ZERO, mat_neon)
			emitter.name = "ShieldEmitter"
			var fl1 = add_thruster_plume(root, Vector3(-15.0, 0.0, 6.0), 16.0, 1.6, 0.25, flame_col)
			fl1.name = "Flame_L"
			var fl2 = add_thruster_plume(root, Vector3(-15.0, 0.0, -6.0), 16.0, 1.6, 0.25, flame_col)
			fl2.name = "Flame_R"

		5: # HEAVY_CRUISER: Battleship prow with articulated secondary turrets (Royal Imperial Violet)
			add_imported_ship_mesh(root, 6, 18.0, -90.0, [mat_armor, mat_hull, mat_conduit, mat_conduit])
			# 2x Articulated Secondary Turrets
			for i in range(2):
				var t_mount = Node3D.new()
				t_mount.name = "Turret_%d" % i
				var z_pos = 10.0 if i == 0 else -10.0
				t_mount.position = Vector3(4.0, 6.0, z_pos)
				root.add_child(t_mount)
				add_cylinder(t_mount, 3.5, 4.0, 2.5, Vector3.ZERO, Vector3.ZERO, mat_armor)
				add_cylinder(t_mount, 1.2, 1.2, 10.0, Vector3(6.0, 0.5, 0.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
			var fl1 = add_thruster_plume(root, Vector3(-19.0, 0.0, 8.0), 20.0, 2.0, 0.35, flame_col)
			fl1.name = "Flame_L"
			var fl2 = add_thruster_plume(root, Vector3(-19.0, 0.0, -8.0), 20.0, 2.0, 0.35, flame_col)
			fl2.name = "Flame_R"

		6: # KNIGHT_VANGUARD: Heavy assault frame with articulated mirror shield plates (Steel Azure with Platinum)
			add_imported_ship_mesh(root, 3, 15.0, -90.0, [mat_armor])
			# Cockpit canopy visor
			add_box(root, Vector3(6.5, 2.6, 3.6), Vector3(2.5, 2.6, 0.0), Vector3.ZERO, mat_neon)
			# Twin heavy forward salvo cannons
			add_cylinder(root, 2.0, 2.0, 18.0, Vector3(18.0, -2.0, 6.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
			add_cylinder(root, 2.0, 2.0, 18.0, Vector3(18.0, -2.0, -6.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
			# Articulated Shield Plates (Port & Starboard)
			var shield_l = Node3D.new()
			shield_l.name = "ShieldPlate_Port"
			shield_l.position = Vector3(16.0, 0.0, 8.0)
			root.add_child(shield_l)
			add_box(shield_l, Vector3(4.0, 16.0, 10.0), Vector3(4.0, 0.0, 2.0), Vector3(0.0, -20.0, 0.0), mat_neon)
			
			var shield_r = Node3D.new()
			shield_r.name = "ShieldPlate_Starboard"
			shield_r.position = Vector3(16.0, 0.0, -8.0)
			root.add_child(shield_r)
			add_box(shield_r, Vector3(4.0, 16.0, 10.0), Vector3(4.0, 0.0, -2.0), Vector3.ZERO, mat_neon)
			# Thermal Venting Vanes
			var vent_vanes = add_box(root, Vector3(8.0, 4.0, 12.0), Vector3(-6.0, 7.0, 0.0), Vector3.ZERO, mat_neon)
			vent_vanes.name = "ThermalVanes"
			var flame = add_thruster_plume(root, Vector3(-13.0, 0.0, 0.0), 18.0, 1.8, 0.3, flame_col)
			flame.name = "Flame"

		7: # PHANTOM: Ethereal twilight indigo stealth wing
			add_imported_ship_mesh(root, 9, 20.0, -90.0, [mat_armor, mat_hull])
			add_box(root, Vector3(5.0, 1.8, 2.4), Vector3(2.0, 1.8, 0.0), Vector3.ZERO, mat_neon)
			var flame = add_thruster_plume(root, Vector3(-11.0, 0.0, 0.0), 16.0, 1.6, 0.25, flame_col)
			flame.name = "Flame"

		8: # DRONE_CARRIER: Heavy claw carrier dreadnought (Ochre Bronze / Gold)
			add_imported_ship_mesh(root, 1, 14.0, -90.0, [mat_armor])
			# Raised bridge tower
			add_box(root, Vector3(8.0, 4.0, 5.0), Vector3(-5.0, 3.5, 0.0), Vector3.ZERO, mat_neon)
			# Dual outrigger drone hangar bays
			add_box(root, Vector3(18.0, 6.0, 3.0), Vector3(-5.0, 0.0, 22.0), Vector3.ZERO, mat_neon)
			add_box(root, Vector3(18.0, 6.0, 3.0), Vector3(-5.0, 0.0, -22.0), Vector3.ZERO, mat_neon)
			var flame = add_thruster_plume(root, Vector3(-12.0, 0.0, 0.0), 24.0, 2.5, 0.4, flame_col)
			flame.name = "Flame"

		9: # MICRO_DRONE: Agile yellow triangular micro-dart
			add_imported_ship_mesh(root, 8, 18.0, -90.0, [mat_armor, mat_hull])
			add_box(root, Vector3(3.0, 1.4, 2.0), Vector3(1.0, 1.4, 0.0), Vector3.ZERO, mat_neon)
			var m_flame = add_thruster_plume(root, Vector3(-6.5, 0.0, 0.0), 12.0, 1.2, 0.2, flame_col)
			m_flame.name = "Flame"

		10: # TURRET_PLATFORM: Hexagonal bunker with 360-degree rotating turret (Industrial Emerald with Mint)
			# Hexagonal bunker base
			add_cylinder(root, 18.0, 22.0, 8.0, Vector3(0.0, -2.0, 0.0), Vector3.ZERO, mat_armor)
			add_cylinder(root, 14.0, 18.0, 4.0, Vector3(0.0, 3.0, 0.0), Vector3.ZERO, mat_hull)
			# Rotating Turret Barbette Head
			var turret_head = Node3D.new()
			turret_head.name = "TurretHead"
			turret_head.position = Vector3(0.0, 5.0, 0.0)
			root.add_child(turret_head)
			add_cylinder(turret_head, 8.0, 9.0, 6.0, Vector3.ZERO, Vector3.ZERO, mat_armor)
			add_box(turret_head, Vector3(6.0, 4.0, 8.0), Vector3(4.0, 0.0, 0.0), Vector3.ZERO, mat_neon)
			# Dual Heavy Autocannon Barrels
			add_cylinder(turret_head, 1.6, 1.8, 22.0, Vector3(14.0, 0.0, 3.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
			add_cylinder(turret_head, 1.6, 1.8, 22.0, Vector3(14.0, 0.0, -3.0), Vector3(0.0, 0.0, 90.0), mat_conduit)

		11: # WARP_STALKER: Forked cobalt-blue hunter prongs
			add_imported_ship_mesh(root, 3, 14.0, -90.0, [mat_armor])
			add_box(root, Vector3(5.5, 2.4, 3.2), Vector3(2.0, 2.4, 0.0), Vector3.ZERO, mat_neon)
			add_cylinder(root, 3.0, 3.0, 6.0, Vector3(-2.0, 4.0, 0.0), Vector3.ZERO, mat_neon)
			var flame = add_thruster_plume(root, Vector3(-12.0, 0.0, 0.0), 16.0, 1.6, 0.25, flame_col)
			flame.name = "Flame"

		12: # DRAINER_LEECH: Segmented crimson predator with rose siphon spikes
			add_box(root, Vector3(28.0, 10.0, 12.0), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, mat_hull)
			add_prism(root, Vector3(10.0, 14.0, 10.0), Vector3(16.0, 0.0, 0.0), Vector3.ZERO, mat_armor)
			add_prism(root, Vector3(8.0, 6.0, 3.0), Vector3(18.0, -2.0, 6.0), Vector3(0.0, 0.0, -90.0), mat_neon)
			add_prism(root, Vector3(8.0, 6.0, 3.0), Vector3(18.0, -2.0, -6.0), Vector3(0.0, 0.0, -90.0), mat_neon)
			for s in range(3):
				add_box(root, Vector3(3.0, 4.0, 3.0), Vector3(-6.0 + float(s) * 6.0, 6.0, 0.0), Vector3.ZERO, mat_neon)

		13: # MISSILE_CORVETTE: Tactical olive gunship with chartreuse missile silos
			add_imported_ship_mesh(root, 5, 15.0, -90.0, [mat_armor, mat_conduit, mat_hull])
			add_box(root, Vector3(2.0, 5.0, 6.0), Vector3(8.5, 4.0, 12.0), Vector3.ZERO, mat_neon)
			add_box(root, Vector3(2.0, 5.0, 6.0), Vector3(8.5, 4.0, -12.0), Vector3.ZERO, mat_neon)
			var fl1 = add_thruster_plume(root, Vector3(-15.0, 0.0, 6.0), 16.0, 1.6, 0.25, flame_col)
			fl1.name = "Flame_L"
			var fl2 = add_thruster_plume(root, Vector3(-15.0, 0.0, -6.0), 16.0, 1.6, 0.25, flame_col)
			fl2.name = "Flame_R"

		14: # MINE_TETHER: Vivid magenta-pink floating naval mine
			add_box(root, Vector3(18.0, 18.0, 18.0), Vector3.ZERO, Vector3(45.0, 45.0, 0.0), mat_armor)
			add_cylinder(root, 2.0, 2.0, 26.0, Vector3.ZERO, Vector3.ZERO, mat_hull)
			add_cylinder(root, 2.0, 2.0, 26.0, Vector3.ZERO, Vector3(0.0, 0.0, 90.0), mat_hull)
			add_cylinder(root, 2.0, 2.0, 26.0, Vector3(90.0, 0.0, 0.0), Vector3.ZERO, mat_hull)
			add_box(root, Vector3(6.0, 6.0, 6.0), Vector3.ZERO, Vector3.ZERO, mat_neon)

		15: # ORBITAL_REFLECTOR: Silver mirror satellite array
			add_cylinder(root, 15.0, 15.0, 3.0, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), mat_armor)
			add_cylinder(root, 5.0, 5.0, 6.0, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), mat_hull)
			add_cylinder(root, 1.2, 1.2, 22.0, Vector3(0.0, 0.0, 8.0), Vector3.ZERO, mat_conduit)
			add_box(root, Vector3(4.0, 4.0, 4.0), Vector3(0.0, 0.0, 18.0), Vector3.ZERO, mat_neon)

		16: # CARGO_HAULER: Industrial transport with glowing cargo pods (Bright Burnished Gold with Cyan)
			add_imported_ship_mesh(root, 6, 18.0, -90.0, [mat_armor, mat_hull, mat_conduit, mat_conduit])
			# Twin glowing magnetic cargo pods
			var pod_l = add_box(root, Vector3(24.0, 10.0, 8.0), Vector3(-2.0, 0.0, 16.0), Vector3.ZERO, mat_neon)
			pod_l.name = "CargoPod_L"
			var pod_r = add_box(root, Vector3(24.0, 10.0, 8.0), Vector3(-2.0, 0.0, -16.0), Vector3.ZERO, mat_neon)
			pod_r.name = "CargoPod_R"
			# Central pulsating quantum core
			var core = add_cylinder(root, 4.0, 4.0, 6.0, Vector3(0.0, 12.0, 0.0), Vector3.ZERO, mat_flame)
			core.name = "QuantumCore"

		_: # Generic/Swarm Craft Fallback
			add_imported_ship_mesh(root, 1, 11.0, -90.0, [mat_armor])
			var flame = add_prism(root, Vector3(1.2, 5.5, 1.2), Vector3(-24.5, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_flame)
			flame.name = "Flame"
	
	# Elite Affix Visual Embellishments
	if elite_affix != 0:
		var elite_ring = add_cylinder(root, 18.0, 19.0, 1.5, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), mat_neon)
		elite_ring.name = "EliteAuraRing"

	# Hostile Plasma Underglow: subtle localized thruster afterglow, zeroed so directional sun facet shadows stay crisp
	var under_light = OmniLight3D.new()
	under_light.name = "UnderglowLight"
	under_light.light_color = neon_col.lerp(armor_col, 0.35)
	under_light.light_energy = 0.0
	under_light.omni_range = 28.0
	under_light.position = Vector3(-10.0, -2.5, 0.0)
	root.add_child(under_light)

	return root

# --- Capital Boss 3D Models ---

static func build_boss_ship(boss_id: String) -> Node3D:
	var root = Node3D.new()
	root.name = "Boss3D_%s" % boss_id
	
	var mat_hull = create_hull_material(Color(0.28, 0.34, 0.44), 0.85, 0.25)
	var mat_armor = create_hull_material(Color(0.54, 0.62, 0.74), 0.85, 0.2)
	var mat_conduit = create_hull_material(Color(0.72, 0.78, 0.86), 0.9, 0.3)
	var mat_neon_red = create_neon_material(Color(1.0, 0.1, 0.2), 4.2)
	var mat_neon_orange = create_neon_material(Color(1.0, 0.5, 0.05), 4.5)
	var mat_neon_purple = create_neon_material(Color(0.85, 0.1, 1.0), 4.2)
	
	var id_lower = boss_id.to_lower()
	if "corvus" in id_lower:
		# Super-Dreadnought Corvus: Colossal multi-deck battleship
		add_box(root, Vector3(120.0, 28.0, 52.0), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, mat_hull)
		add_prism(root, Vector3(28.0, 36.0, 48.0), Vector3(74.0, 0.0, 0.0), Vector3(0.0, 0.0, -90.0), mat_armor)
		
		# Breakable Armor Wings
		var wing_p = Node3D.new()
		wing_p.name = "Wing_Port"
		wing_p.position = Vector3(-10.0, 0.0, 44.0)
		root.add_child(wing_p)
		add_prism(wing_p, Vector3(45.0, 38.0, 10.0), Vector3.ZERO, Vector3(90.0, 15.0, 0.0), mat_armor)
		add_box(wing_p, Vector3(30.0, 6.0, 4.0), Vector3(0.0, 0.0, 18.0), Vector3.ZERO, mat_neon_orange)
		
		var wing_s = Node3D.new()
		wing_s.name = "Wing_Starboard"
		wing_s.position = Vector3(-10.0, 0.0, -44.0)
		root.add_child(wing_s)
		add_prism(wing_s, Vector3(45.0, 38.0, 10.0), Vector3.ZERO, Vector3(-90.0, -15.0, 0.0), mat_armor)
		add_box(wing_s, Vector3(30.0, 6.0, 4.0), Vector3(0.0, 0.0, -18.0), Vector3.ZERO, mat_neon_orange)
		
		# Central Overheating Singularity Fusion Core
		var core = add_cylinder(root, 9.0, 10.0, 8.0, Vector3(10.0, 12.0, 0.0), Vector3.ZERO, mat_neon_red)
		core.name = "FusionCore"
		
		# 2x Heavy Bow Railgun Turrets
		for i in range(2):
			var z_off = 18.0 if i == 0 else -18.0
			var rail = add_cylinder(root, 2.8, 3.2, 32.0, Vector3(48.0, 6.0, z_off), Vector3(0.0, 0.0, 90.0), mat_conduit)
			rail.name = "Railgun_%d" % i

	elif "goliath" in id_lower:
		# Armored Behemoth Goliath: Asymmetric fortress carrier
		add_box(root, Vector3(140.0, 32.0, 64.0), Vector3(0.0, 0.0, 0.0), Vector3.ZERO, mat_hull)
		
		# Breakable Heavy Bow Armor Wedge
		var bow_armor = Node3D.new()
		bow_armor.name = "BowArmor"
		bow_armor.position = Vector3(70.0, 0.0, 0.0)
		root.add_child(bow_armor)
		add_prism(bow_armor, Vector3(32.0, 38.0, 58.0), Vector3(14.0, 0.0, 0.0), Vector3(0.0, 0.0, -90.0), mat_armor)
		add_box(bow_armor, Vector3(12.0, 24.0, 54.0), Vector3.ZERO, Vector3.ZERO, mat_armor)
		
		# Articulating Port & Starboard Tracking Railgun Batteries
		var rg_p = Node3D.new()
		rg_p.name = "Railgun_Port"
		rg_p.position = Vector3(25.0, 10.0, 36.0)
		root.add_child(rg_p)
		add_cylinder(rg_p, 6.0, 7.0, 6.0, Vector3.ZERO, Vector3.ZERO, mat_armor)
		add_cylinder(rg_p, 2.0, 2.2, 42.0, Vector3(18.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
		
		var rg_s = Node3D.new()
		rg_s.name = "Railgun_Starboard"
		rg_s.position = Vector3(25.0, 10.0, -36.0)
		root.add_child(rg_s)
		add_cylinder(rg_s, 6.0, 7.0, 6.0, Vector3.ZERO, Vector3.ZERO, mat_armor)
		add_cylinder(rg_s, 2.0, 2.2, 42.0, Vector3(18.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), mat_conduit)
		
		# Overdrive Core
		var core = add_cylinder(root, 10.0, 11.0, 10.0, Vector3(-20.0, 14.0, 0.0), Vector3.ZERO, mat_neon_orange)
		core.name = "FusionCore"

	else: # Ouroboros / Apex Titan
		add_cylinder(root, 36.0, 42.0, 24.0, Vector3.ZERO, Vector3.ZERO, mat_hull)
		# Central Singularity Aperture
		var aperture = add_cylinder(root, 14.0, 14.0, 26.0, Vector3.ZERO, Vector3.ZERO, mat_neon_purple)
		aperture.name = "SingularityCore"
		
		# Rotating Directional Shield Gate Armatures
		var gate = Node3D.new()
		gate.name = "ShieldGate"
		root.add_child(gate)
		for i in range(4):
			var a = float(i) * (PI * 0.5)
			var arm = add_box(gate, Vector3(8.0, 18.0, 32.0), Vector3(cos(a) * 44.0, 0.0, sin(a) * 44.0), Vector3(0.0, -rad_to_deg(a), 0.0), mat_neon_purple)

	return root

# --- Environmental Hazards 3D Models ---

static func build_hazard_mesh(hazard_type: int) -> Node3D:
	var root = Node3D.new()
	root.name = "Hazard3D_%d" % hazard_type
	
	match hazard_type:
		0: # ASTEROID: Faceted rock polyhedron with metallic ore veins
			var mat_rock = create_hull_material(Color(0.24, 0.22, 0.22), 0.2, 0.85)
			var mat_ore = create_neon_material(Color(0.2, 0.9, 1.0), 2.5) # Glowing quantum ore vein
			# Faceted irregular boulder
			add_box(root, Vector3(32.0, 30.0, 32.0), Vector3.ZERO, Vector3(15.0, 25.0, 10.0), mat_rock)
			add_box(root, Vector3(26.0, 34.0, 26.0), Vector3.ZERO, Vector3(-35.0, 45.0, 20.0), mat_rock)
			add_prism(root, Vector3(20.0, 24.0, 18.0), Vector3(8.0, 4.0, 6.0), Vector3(40.0, 10.0, -30.0), mat_rock)
			# Metallic ore vein
			add_box(root, Vector3(4.0, 14.0, 22.0), Vector3(2.0, 0.0, 0.0), Vector3(25.0, 15.0, 0.0), mat_ore)

		1: # PLASMA_BARREL: Explosive containment drum with hazard striping
			var mat_drum = create_hull_material(Color(0.12, 0.14, 0.18), 0.85, 0.3)
			var mat_hazard = create_neon_material(Color(1.0, 0.45, 0.05), 4.2)
			# Main cylinder drum
			add_cylinder(root, 14.0, 14.0, 28.0, Vector3.ZERO, Vector3.ZERO, mat_drum)
			# Hazard glowing bands
			add_cylinder(root, 14.8, 14.8, 4.0, Vector3(0.0, 8.0, 0.0), Vector3.ZERO, mat_hazard)
			add_cylinder(root, 14.8, 14.8, 4.0, Vector3(0.0, -8.0, 0.0), Vector3.ZERO, mat_hazard)
			# Top pressure cap
			add_cylinder(root, 8.0, 9.0, 3.0, Vector3(0.0, 15.0, 0.0), Vector3.ZERO, mat_hazard)

		_: # STORM_CELL / ANOMALY: Hyper-dimensional geometric polyhedra
			var mat_anomaly = create_neon_material(Color(0.85, 0.15, 1.0), 4.5)
			add_box(root, Vector3(24.0, 24.0, 24.0), Vector3.ZERO, Vector3(45.0, 45.0, 0.0), mat_anomaly)
			add_box(root, Vector3(18.0, 18.0, 18.0), Vector3.ZERO, Vector3(0.0, 45.0, 45.0), mat_anomaly)
	
	return root

# --- Orbital Trade Station (Super Quarket Station) 3D Model ---

static func build_station_mesh() -> Node3D:
	var root = Node3D.new()
	root.name = "SuperQuarketStation3D"
	
	var mat_titanium = create_hull_material(Color(0.06, 0.09, 0.14), 0.88, 0.22)
	var mat_armor = create_hull_material(Color(0.12, 0.16, 0.22), 0.9, 0.2)
	var mat_neon_cyan = create_neon_material(Color(0.18, 0.88, 1.0), 3.8)
	var mat_neon_amber = create_neon_material(Color(1.0, 0.75, 0.15), 3.8)
	var mat_neon_red = create_neon_material(Color(1.0, 0.2, 0.2), 3.0)
	
	# 1. Central Command Hub
	add_cylinder(root, 36.0, 42.0, 24.0, Vector3.ZERO, Vector3.ZERO, mat_titanium)
	add_cylinder(root, 22.0, 24.0, 8.0, Vector3(0.0, 0.0, 14.0), Vector3.ZERO, mat_neon_cyan)
	
	var reactor = add_cylinder(root, 14.0, 14.0, 30.0, Vector3.ZERO, Vector3.ZERO, mat_neon_cyan)
	reactor.name = "SingularityReactor"
	
	# Sensor Spire & Warning Beacon
	add_box(root, Vector3(3.0, 52.0, 3.0), Vector3(0.0, 32.0, 0.0), Vector3.ZERO, mat_armor)
	var beacon = add_box(root, Vector3(5.0, 5.0, 5.0), Vector3(0.0, 58.0, 0.0), Vector3.ZERO, mat_neon_red)
	beacon.name = "WarningBeacon"
	
	# 2. Outer Habitat Ring (Rotates Clockwise)
	var outer_ring = Node3D.new()
	outer_ring.name = "OuterRing"
	root.add_child(outer_ring)
	
	var outer_segs = 16
	var outer_r = 185.0
	for i in range(outer_segs):
		var a = (float(i) / outer_segs) * TAU
		var pos = Vector3(cos(a) * outer_r, sin(a) * outer_r, 0.0)
		var rot = Vector3(0.0, 0.0, rad_to_deg(a) + 90.0)
		add_box(outer_ring, Vector3(72.0, 14.0, 18.0), pos, rot, mat_armor)
		
		# 8 Habitat Pods & 4 Solar Wings
		if i % 2 == 0:
			add_cylinder(outer_ring, 9.0, 9.0, 22.0, pos + Vector3(0.0, 0.0, 4.0), rot, mat_titanium)
			add_cylinder(outer_ring, 4.0, 4.0, 24.0, pos + Vector3(0.0, 0.0, 4.0), rot, mat_neon_cyan)
		else:
			var wing_dir = Vector3(cos(a), sin(a), 0.0)
			add_box(outer_ring, Vector3(28.0, 12.0, 2.0), pos + wing_dir * 18.0, rot, mat_neon_amber)
			
	# 4 Heavy Structural Spokes
	for s in range(4):
		var a = float(s) * (TAU / 4.0)
		var spoke_center = Vector3(cos(a) * 110.0, sin(a) * 110.0, 0.0)
		var spoke_rot = Vector3(0.0, 0.0, rad_to_deg(a))
		add_box(outer_ring, Vector3(150.0, 6.0, 8.0), spoke_center, spoke_rot, mat_armor)
		add_box(outer_ring, Vector3(150.0, 2.0, 2.0), spoke_center + Vector3(0.0, 0.0, 4.0), spoke_rot, mat_neon_cyan)
	
	# 3. Inner Quantum Flux Ring (Rotates Counter-Clockwise)
	var inner_ring = Node3D.new()
	inner_ring.name = "InnerRing"
	root.add_child(inner_ring)
	
	var inner_segs = 12
	var inner_r = 108.0
	for i in range(inner_segs):
		var a = (float(i) / inner_segs) * TAU
		var pos = Vector3(cos(a) * inner_r, sin(a) * inner_r, 0.0)
		var rot = Vector3(0.0, 0.0, rad_to_deg(a) + 90.0)
		add_box(inner_ring, Vector3(56.0, 10.0, 12.0), pos, rot, mat_titanium)
		
		# 6 Quantum Flux Nodes
		if i % 2 == 0:
			var node_mesh = add_cylinder(inner_ring, 7.0, 7.0, 16.0, pos, rot, mat_neon_amber)
			node_mesh.name = "FluxNode_%d" % i
	
	# 3 Spokes for Inner Ring
	for s in range(3):
		var a = float(s) * (TAU / 3.0)
		var spoke_center = Vector3(cos(a) * 70.0, sin(a) * 70.0, 0.0)
		var spoke_rot = Vector3(0.0, 0.0, rad_to_deg(a))
		add_box(inner_ring, Vector3(72.0, 5.0, 6.0), spoke_center, spoke_rot, mat_titanium)
	
	# 4. Ventral Docking Pylons & Tractor Emitters
	for pylon_x in [-110.0, 110.0]:
		add_box(root, Vector3(14.0, 38.0, 14.0), Vector3(pylon_x, -32.0, 0.0), Vector3.ZERO, mat_titanium)
		var emitter = add_cylinder(root, 10.0, 12.0, 10.0, Vector3(pylon_x, -52.0, 0.0), Vector3.ZERO, mat_neon_cyan)
		if pylon_x < 0:
			emitter.name = "TractorEmitterLeft"
		else:
			emitter.name = "TractorEmitterRight"
			
	# 5. Holographic Market Marquee
	var holo = add_box(root, Vector3(130.0, 24.0, 2.0), Vector3(0.0, -72.0, 10.0), Vector3.ZERO, mat_neon_cyan)
	holo.name = "HoloSign"
	
	return root

# --- Hull Fracture Debris 3D Shards ---

static func build_debris_mesh(size_cat: int = 1) -> Node3D:
	var root = Node3D.new()
	root.name = "DebrisShard3D"
	
	var mat_armor = create_hull_material(Color(0.1, 0.12, 0.16), 0.9, 0.25)
	var mat_seam = create_neon_material(Color(1.0, 0.5, 0.08), 4.2)
	
	var base_scale = 8.0
	if size_cat == 0:
		base_scale = 5.0
	elif size_cat == 2:
		base_scale = 16.0
		
	var w = randf_range(base_scale * 0.8, base_scale * 2.2)
	var h = randf_range(base_scale * 0.5, base_scale * 1.5)
	var d = randf_range(base_scale * 0.3, base_scale * 0.8)
	
	# Metallic shard plate
	add_prism(root, Vector3(w, h, d), Vector3.ZERO, Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(0, 180)), mat_armor)
	# Glowing jagged fracture seam
	add_box(root, Vector3(w * 0.8, h * 0.2, d * 1.2), Vector3(0.0, -h * 0.3, 0.0), Vector3.ZERO, mat_seam)
	
	return root

# --- Deep-Space Parallax Megastructures 3D Models ---

static func create_background_structure_material(base_color: Color, alpha: float = 0.32) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(base_color.r, base_color.g, base_color.b, alpha)
	mat.metallic = 0.05
	mat.roughness = 0.95
	mat.rim_enabled = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat

static func create_background_accent_material(accent_color: Color, alpha: float = 0.28) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)
	mat.emission_enabled = false # Completely non-blooming so it never mimics bullets or pickups
	mat.metallic = 0.08
	mat.roughness = 0.92
	mat.rim_enabled = false
	return mat

static func build_megastructure_mesh(structure_type: int) -> Node3D:
	var root = Node3D.new()
	root.name = "Megastructure3D_%d" % structure_type
	
	# Atmospheric, muted deep-space silhouette palette (never competes with foreground action)
	var mat_hull = create_background_structure_material(Color(0.07, 0.09, 0.14), 0.32)
	var mat_truss = create_background_structure_material(Color(0.09, 0.12, 0.18), 0.26)
	var mat_solar = create_background_accent_material(Color(0.24, 0.18, 0.08), 0.28) # Muted dark bronze solar array
	var mat_beacon = create_background_accent_material(Color(0.30, 0.12, 0.08), 0.25) # Soft non-glowing amber/rust marker
	var mat_cyan = create_background_accent_material(Color(0.08, 0.20, 0.26), 0.26) # Faint deep slate-teal conduit
	
	match structure_type:
		0: # DYSON SWARM COLLECTOR: Solar honeycomb ring array
			var segs = 12
			var radius = 220.0
			for i in range(segs):
				var a = (float(i) / segs) * TAU
				var p = Vector3(cos(a) * radius, sin(a) * radius, 0.0)
				var rot = Vector3(0.0, 0.0, rad_to_deg(a) + 90.0)
				add_box(root, Vector3(110.0, 24.0, 24.0), p, rot, mat_hull)
				# Muted bronze solar collector panel
				add_box(root, Vector3(90.0, 16.0, 4.0), p + Vector3(0.0, 0.0, 12.0), rot, mat_solar)
				# Truss strut
				add_box(root, Vector3(140.0, 6.0, 6.0), p * 0.5, Vector3(0.0, 0.0, rad_to_deg(a)), mat_truss)
				
		1: # ORBITAL SKYHOOK: Towering vertical tether lattice spine
			# Center main spine column
			add_box(root, Vector3(28.0, 680.0, 28.0), Vector3.ZERO, Vector3.ZERO, mat_hull)
			# Cross-bracing lattice girders
			for y in range(-300, 310, 60):
				add_box(root, Vector3(90.0, 8.0, 14.0), Vector3(0.0, float(y), 0.0), Vector3.ZERO, mat_truss)
				add_box(root, Vector3(70.0, 6.0, 6.0), Vector3(0.0, float(y) + 30.0, 0.0), Vector3(0.0, 0.0, 45.0), mat_truss)
				add_box(root, Vector3(70.0, 6.0, 6.0), Vector3(0.0, float(y) + 30.0, 0.0), Vector3(0.0, 0.0, -45.0), mat_truss)
				# Subdued distant aviation markers
				add_box(root, Vector3(6.0, 6.0, 6.0), Vector3(46.0, float(y), 15.0), Vector3.ZERO, mat_beacon)
				add_box(root, Vector3(6.0, 6.0, 6.0), Vector3(-46.0, float(y), 15.0), Vector3.ZERO, mat_beacon)
				
		_: # DERELICT CAPITAL SHIP HULK: Abandoned titan hull with ripped armor
			# Main cracked spine
			add_box(root, Vector3(260.0, 55.0, 42.0), Vector3.ZERO, Vector3(5.0, 8.0, -12.0), mat_hull)
			# Fractured bow wedge
			add_prism(root, Vector3(90.0, 60.0, 40.0), Vector3(140.0, 0.0, 0.0), Vector3(10.0, 0.0, -90.0), mat_hull)
			# Exposed internal hangar decks with faint conduit
			add_box(root, Vector3(70.0, 22.0, 28.0), Vector3(-40.0, 8.0, 6.0), Vector3.ZERO, mat_truss)
			add_box(root, Vector3(65.0, 3.0, 3.0), Vector3(-40.0, 16.0, 18.0), Vector3.ZERO, mat_cyan)
			# Torn port armor plate drifting slightly
			add_box(root, Vector3(110.0, 28.0, 8.0), Vector3(20.0, 42.0, 22.0), Vector3(15.0, 22.0, -25.0), mat_hull)
	
	return root

# --- Quantum Secrets 3D Models ---

static func build_quantum_anomaly_mesh() -> Node3D:
	var root = Node3D.new()
	root.name = "QuantumAnomaly3D"
	
	var mat_core = create_neon_material(Color(0.2, 0.95, 1.0), 4.5)
	var mat_ring_outer = create_neon_material(Color(0.85, 0.2, 1.0), 3.5)
	var mat_ring_inner = create_neon_material(Color(1.0, 0.85, 0.2), 3.5)
	
	# Hyper-dimensional core
	var core = add_box(root, Vector3(14.0, 14.0, 14.0), Vector3.ZERO, Vector3(45.0, 45.0, 0.0), mat_core)
	core.name = "AnomalyCore"
	
	# Gimbal ring 1 (Outer)
	var ring_out = Node3D.new()
	ring_out.name = "GimbalOuter"
	root.add_child(ring_out)
	var tor1 = TorusMesh.new()
	tor1.inner_radius = 22.0
	tor1.outer_radius = 24.5
	var inst1 = MeshInstance3D.new()
	inst1.mesh = tor1
	inst1.material_override = mat_ring_outer
	ring_out.add_child(inst1)
	
	# Gimbal ring 2 (Inner)
	var ring_in = Node3D.new()
	ring_in.name = "GimbalInner"
	root.add_child(ring_in)
	var tor2 = TorusMesh.new()
	tor2.inner_radius = 16.0
	tor2.outer_radius = 18.0
	var inst2 = MeshInstance3D.new()
	inst2.mesh = tor2
	inst2.material_override = mat_ring_inner
	ring_in.add_child(inst2)
	
	return root

static func build_dirac_monopole_mesh() -> Node3D:
	var root = Node3D.new()
	root.name = "DiracMonopole3D"
	
	var mat_gold = create_hull_material(Color(0.85, 0.65, 0.15), 0.95, 0.18)
	var mat_ancient = create_hull_material(Color(0.08, 0.1, 0.14), 0.9, 0.25)
	var mat_north = create_neon_material(Color(0.1, 0.85, 1.0), 4.5)
	var mat_south = create_neon_material(Color(1.0, 0.25, 0.15), 4.5)
	var mat_singularity = create_neon_material(Color(1.0, 0.95, 0.8), 5.5)
	
	# 1. Ancient Monolithic Pillar Core
	add_cylinder(root, 16.0, 18.0, 68.0, Vector3.ZERO, Vector3.ZERO, mat_ancient)
	add_cylinder(root, 19.0, 19.0, 12.0, Vector3.ZERO, Vector3.ZERO, mat_gold)
	
	# 2. Central Magnetic Singularity
	var sing = add_cylinder(root, 8.0, 8.0, 16.0, Vector3.ZERO, Vector3.ZERO, mat_singularity)
	sing.name = "MonopoleSingularity"
	
	# 3. North Pole Emitter (Cyan)
	var north_cap = add_cylinder(root, 12.0, 16.0, 8.0, Vector3(0.0, 36.0, 0.0), Vector3.ZERO, mat_north)
	north_cap.name = "NorthPole"
	
	# 4. South Pole Emitter (Amber/Red)
	var south_cap = add_cylinder(root, 16.0, 12.0, 8.0, Vector3(0.0, -36.0, 0.0), Vector3.ZERO, mat_south)
	south_cap.name = "SouthPole"
	
	# 5. Polar Magnetic Containment Rings
	var ring_north = Node3D.new()
	ring_north.name = "PolarRingNorth"
	ring_north.position = Vector3(0.0, 20.0, 0.0)
	root.add_child(ring_north)
	var tn = TorusMesh.new()
	tn.inner_radius = 28.0
	tn.outer_radius = 31.0
	var inst_n = MeshInstance3D.new()
	inst_n.mesh = tn
	inst_n.material_override = mat_gold
	ring_north.add_child(inst_n)
	
	var ring_south = Node3D.new()
	ring_south.name = "PolarRingSouth"
	ring_south.position = Vector3(0.0, -20.0, 0.0)
	root.add_child(ring_south)
	var ts = TorusMesh.new()
	ts.inner_radius = 28.0
	ts.outer_radius = 31.0
	var inst_s = MeshInstance3D.new()
	inst_s.mesh = ts
	inst_s.material_override = mat_ancient
	ring_south.add_child(inst_s)
	
	return root




