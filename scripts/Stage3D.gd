extends SubViewportContainer
class_name Stage3D

## Stage3D.gd - High-Fidelity 2.5D Synchronized Viewport & PBR Lighting Stage.
## Maps 2D gameplay coordinates 1:1 to 3D world space using an Orthographic Camera3D.
## Provides HDR Tonemapping, multi-octave bloom, dynamic sunlight, and entity sync.

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera3D
@onready var sun: DirectionalLight3D = $SubViewport/DirectionalLight3D
@onready var world_env: WorldEnvironment = $SubViewport/WorldEnvironment
@onready var entities_node: Node3D = $SubViewport/Entities

# Visual bridges mapped by 2D Node instance ID
var player_bridges: Dictionary = {}
var enemy_bridges: Dictionary = {}
var boss_bridges: Dictionary = {}
var hazard_bridges: Dictionary = {}
var station_bridge = null

# VFX & Debris Simulation Pools
var active_debris: Array[Dictionary] = []
var active_shockwaves: Array[Dictionary] = []
var active_flashes: Array[Dictionary] = []
var active_apertures: Array[Dictionary] = []

# Nexus Wave Function Cloud
var nexus_ribbon: Node3D = null

# Secrets 3D Models
var anomaly_bridges: Array[Dictionary] = []
var monopole_bridge: Dictionary = {}

# 3D Deep-Space Parallax Environment
var bg_node: Node3D = null
var megastructures: Array[Node3D] = []
var nebula_clouds: Array[MeshInstance3D] = []
var warp_tunnel_rings: Array[MeshInstance3D] = []
var warp_tunnel_active: bool = false
var warp_tunnel_timer: float = 0.0
var warp_tunnel_duration: float = 0.45
var current_sector: int = 1

func _ready() -> void:
	add_to_group("stage_3d")
	# Ensure mouse input passes cleanly through to 2D UI and controls
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	
	_setup_environment()
	_update_camera_projection()
	_setup_background_3d()
	
	if get_viewport():
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	if GameAxis != null and GameAxis.has_signal("axis_changed"):
		GameAxis.axis_changed.connect(func(_is_vert): _update_camera_projection())

func _setup_environment() -> void:
	if not world_env.environment:
		var env = Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.0
		
		# Multi-octave Cyberpunk HDR Neon Bloom: calibrated so non-emissive hulls don't wash out
		env.glow_enabled = true
		env.glow_intensity = 0.85
		env.glow_bloom = 0.15
		env.glow_hdr_threshold = 1.05
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		
		# Cinematic space ambient fill: deep rich shadows with clear facet contrast
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.16, 0.22, 0.32)
		env.ambient_light_energy = 0.25
		
		world_env.environment = env
		
	if sun:
		sun.light_color = Color(1.0, 0.98, 0.94)
		sun.light_energy = 1.1
		sun.shadow_enabled = false
		sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)

	var rim_fill = viewport.get_node_or_null("RimFillLight") as DirectionalLight3D
	if rim_fill:
		rim_fill.light_color = Color(0.35, 0.75, 1.0)
		rim_fill.light_energy = 0.25

func _setup_background_3d() -> void:
	if not viewport:
		return
	bg_node = Node3D.new()
	bg_node.name = "Background3D"
	viewport.add_child(bg_node)
	viewport.move_child(bg_node, 0)
	
	var ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	if ShipBuilder3DScript:
		# 1. Parallax Megastructures (Scaled down and pushed deep to serve as distant moody silhouettes)
		for i in range(3):
			var ms = ShipBuilder3DScript.build_megastructure_mesh(i)
			ms.scale = Vector3(0.52, 0.52, 0.52)
			bg_node.add_child(ms)
			megastructures.append(ms)
		
		if megastructures.size() >= 3:
			megastructures[0].position = Vector3(250.0, -220.0, -320.0)
			megastructures[1].position = Vector3(850.0, -360.0, -380.0)
			megastructures[2].position = Vector3(500.0, -560.0, -290.0)
	
	# 2. Volumetric Soft Atmospheric Nebulae
	for i in range(5):
		var cloud = MeshInstance3D.new()
		var q = QuadMesh.new()
		q.size = Vector2(randf_range(500.0, 800.0), randf_range(400.0, 700.0))
		cloud.mesh = q
		
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.06, 0.35, 0.8, 0.08)
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		cloud.material_override = mat
		
		cloud.position = Vector3(randf_range(100.0, 1100.0), randf_range(-650.0, -80.0), randf_range(-250.0, -380.0))
		bg_node.add_child(cloud)
		nebula_clouds.append(cloud)
		
	# 3. Hyperspace Warp Conduit Rings
	for i in range(12):
		var ring = MeshInstance3D.new()
		var tor = TorusMesh.new()
		tor.inner_radius = 280.0
		tor.outer_radius = 295.0
		tor.rings = 16
		tor.ring_segments = 16
		ring.mesh = tor
		
		var ring_mat = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.albedo_color = Color(0.15, 0.85, 1.0, 0.0)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ring.material_override = ring_mat
		
		ring.position = Vector3(640.0, -360.0, -350.0 + float(i) * 60.0)
		bg_node.add_child(ring)
		warp_tunnel_rings.append(ring)
		
	# 4. Wave Function Nexus Ribbon (Star Trek Generations Inspired)
	var NexusRibbonScript = load("res://scripts/NexusRibbon3D.gd")
	if NexusRibbonScript:
		nexus_ribbon = NexusRibbonScript.new()
		bg_node.add_child(nexus_ribbon)

func _update_camera_projection() -> void:
	var vp_size = get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1280, 720)
	
	size = vp_size
	custom_minimum_size = vp_size
	position = Vector2.ZERO
	if viewport and not stretch:
		viewport.size = Vector2i(int(vp_size.x), int(vp_size.y))
	
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = vp_size.y
		camera.position = Vector3(vp_size.x * 0.5, -vp_size.y * 0.5, 400.0)
		camera.rotation_degrees = Vector3.ZERO

func _on_viewport_size_changed() -> void:
	_update_camera_projection()

# Coordinate Transformation: 2D Screen (x, y) -> 3D World (x, -y, 0)
static func to_3d(pos2d: Vector2, z_depth: float = 0.0) -> Vector3:
	return Vector3(pos2d.x, -pos2d.y, z_depth)

# --- Entity Registration ---

func register_player(player: CharacterBody2D) -> void:
	if not player or not is_instance_valid(player):
		return
	var id = player.get_instance_id()
	if player_bridges.has(id):
		return
	
	var VisualBridge3DScript = load("res://scripts/VisualBridge3D.gd")
	var bridge = VisualBridge3DScript.PlayerBridge3D.new(player, entities_node)
	player_bridges[id] = bridge
	player.tree_exiting.connect(func(): unregister_player(player), CONNECT_ONE_SHOT)

func unregister_player(player: CharacterBody2D) -> void:
	if not player:
		return
	var id = player.get_instance_id()
	if player_bridges.has(id):
		var bridge = player_bridges[id]
		bridge.destroy()
		player_bridges.erase(id)

func register_enemy(enemy: Area2D) -> void:
	if not enemy or not is_instance_valid(enemy):
		return
	var id = enemy.get_instance_id()
	if enemy_bridges.has(id):
		var old_bridge = enemy_bridges[id]
		old_bridge.destroy()
		enemy_bridges.erase(id)
	
	var VisualBridge3DScript = load("res://scripts/VisualBridge3D.gd")
	var bridge = VisualBridge3DScript.EnemyBridge3D.new(enemy, entities_node)
	enemy_bridges[id] = bridge
	enemy.tree_exiting.connect(func(): unregister_enemy(enemy), CONNECT_ONE_SHOT)

func unregister_enemy(enemy: Area2D) -> void:
	if not enemy:
		return
	var id = enemy.get_instance_id()
	if enemy_bridges.has(id):
		var bridge = enemy_bridges[id]
		bridge.destroy()
		enemy_bridges.erase(id)

func register_boss(boss: Area2D, boss_id: String) -> void:
	if not boss or not is_instance_valid(boss):
		return
	var id = boss.get_instance_id()
	if boss_bridges.has(id):
		var old = boss_bridges[id]
		old.destroy()
		boss_bridges.erase(id)
	
	var VisualBridge3DScript = load("res://scripts/VisualBridge3D.gd")
	var bridge = VisualBridge3DScript.BossBridge3D.new(boss, entities_node, boss_id)
	boss_bridges[id] = bridge
	boss.tree_exiting.connect(func(): unregister_boss(boss), CONNECT_ONE_SHOT)

func unregister_boss(boss: Area2D) -> void:
	if not boss:
		return
	var id = boss.get_instance_id()
	if boss_bridges.has(id):
		var bridge = boss_bridges[id]
		bridge.destroy()
		boss_bridges.erase(id)

func register_hazard(hazard: Area2D) -> void:
	if not hazard or not is_instance_valid(hazard):
		return
	var id = hazard.get_instance_id()
	var was_registered = hazard_bridges.has(id)
	var h_type = hazard.hazard_type if "hazard_type" in hazard else 0
	if was_registered:
		var old = hazard_bridges[id]
		if old.hazard_type == h_type:
			return
		old.destroy()
		hazard_bridges.erase(id)
	
	var VisualBridge3DScript = load("res://scripts/VisualBridge3D.gd")
	var bridge = VisualBridge3DScript.HazardBridge3D.new(hazard, entities_node)
	hazard_bridges[id] = bridge
	if not was_registered:
		hazard.tree_exiting.connect(func(): unregister_hazard(hazard), CONNECT_ONE_SHOT)

func unregister_hazard(hazard: Area2D) -> void:
	if not hazard:
		return
	var id = hazard.get_instance_id()
	if hazard_bridges.has(id):
		var bridge = hazard_bridges[id]
		bridge.destroy()
		hazard_bridges.erase(id)

func register_station(shop: Node) -> void:
	if not shop or not is_instance_valid(shop):
		return
	if station_bridge:
		station_bridge.destroy()
		station_bridge = null
	
	var VisualBridge3DScript = load("res://scripts/VisualBridge3D.gd")
	station_bridge = VisualBridge3DScript.StationBridge3D.new(shop, entities_node)
	shop.tree_exiting.connect(func(): unregister_station(shop), CONNECT_ONE_SHOT)

func unregister_station(shop: Node) -> void:
	if station_bridge and station_bridge.target_shop == shop:
		station_bridge.destroy()
		station_bridge = null

# --- Nexus Wave Function & Enemy Spawning VFX ---

func trigger_nexus_surge(duration: float = 0.45) -> void:
	if is_instance_valid(nexus_ribbon):
		nexus_ribbon.trigger_surge(duration)

func spawn_materialization_aperture(pos2d: Vector2, duration: float = 0.4) -> void:
	if not entities_node:
		return
	var aperture_root = Node3D.new()
	aperture_root.position = to_3d(pos2d, 10.0)
	entities_node.add_child(aperture_root)
	
	var ring_mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 28.0
	tor.outer_radius = 30.5
	ring_mesh.mesh = tor
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.2, 0.95, 1.0, 0.85)
	ring_mesh.material_override = mat
	aperture_root.add_child(ring_mesh)
	
	active_apertures.append({
		"root": aperture_root,
		"ring": ring_mesh,
		"mat": mat,
		"life": duration,
		"max_life": duration
	})

func trigger_materialization_flash(pos2d: Vector2) -> void:
	if not entities_node:
		return
	var center_3d = to_3d(pos2d, 0.0)
	
	# Light flash
	var light = OmniLight3D.new()
	light.light_color = Color(0.65, 0.95, 1.0)
	light.light_energy = 6.0
	light.omni_range = 65.0
	light.position = to_3d(pos2d, 15.0)
	entities_node.add_child(light)
	active_flashes.append({
		"light": light,
		"life": 0.16,
		"max_life": 0.16,
		"base_energy": 6.0
	})
	
	# Reality-compression shockwave
	var shockwave_mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 2.0
	tor.outer_radius = 3.5
	shockwave_mesh.mesh = tor
	var sw_mat = StandardMaterial3D.new()
	sw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sw_mat.albedo_color = Color(0.3, 0.9, 1.0, 0.85)
	shockwave_mesh.material_override = sw_mat
	shockwave_mesh.position = center_3d
	entities_node.add_child(shockwave_mesh)
	active_shockwaves.append({
		"mesh": shockwave_mesh,
		"mat": sw_mat,
		"max_r": 38.0,
		"life": 0.22,
		"max_life": 0.22
	})
	
	# Lightning arc leaping from Nexus Ribbon directly to spawn point
	if is_instance_valid(nexus_ribbon):
		nexus_ribbon.strike_lightning_to(center_3d, 0.22)

# --- Quantum Secrets 3D Models (Anomalies & Dirac Monopole) ---

func register_anomaly(anomaly_dict: Dictionary) -> void:
	if not entities_node:
		return
	var ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	if ShipBuilder3DScript:
		var mesh = ShipBuilder3DScript.build_quantum_anomaly_mesh()
		mesh.position = to_3d(anomaly_dict.pos, 0.0)
		entities_node.add_child(mesh)
		anomaly_bridges.append({
			"dict": anomaly_dict,
			"mesh": mesh
		})

func shatter_anomaly_3d(pos2d: Vector2) -> void:
	if not entities_node:
		return
	var center_3d = to_3d(pos2d, 0.0)
	
	# Cyan-magenta quantum shockwave
	var shockwave_mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 4.0
	tor.outer_radius = 6.5
	shockwave_mesh.mesh = tor
	var sw_mat = StandardMaterial3D.new()
	sw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sw_mat.albedo_color = Color(0.85, 0.2, 1.0, 0.9)
	shockwave_mesh.material_override = sw_mat
	shockwave_mesh.position = center_3d
	entities_node.add_child(shockwave_mesh)
	active_shockwaves.append({
		"mesh": shockwave_mesh,
		"mat": sw_mat,
		"max_r": 70.0,
		"life": 0.35,
		"max_life": 0.35
	})
	
	# Light flash
	var light = OmniLight3D.new()
	light.light_color = Color(0.9, 0.4, 1.0)
	light.light_energy = 7.0
	light.omni_range = 90.0
	light.position = to_3d(pos2d, 15.0)
	entities_node.add_child(light)
	active_flashes.append({
		"light": light,
		"life": 0.25,
		"max_life": 0.25,
		"base_energy": 7.0
	})
	
	# Crystalline neon debris shards
	var ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	if ShipBuilder3DScript:
		for i in range(10):
			var shard = ShipBuilder3DScript.build_debris_mesh(0)
			shard.position = center_3d + Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-4, 4))
			entities_node.add_child(shard)
			var angle = randf() * TAU
			var speed = randf_range(90.0, 220.0)
			active_debris.append({
				"mesh": shard,
				"pos": shard.position,
				"vel": Vector3(cos(angle) * speed, sin(angle) * speed, randf_range(-50, 50)),
				"rot": Vector3(randf() * TAU, randf() * TAU, randf() * TAU),
				"rot_vel": Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)),
				"life": randf_range(0.4, 0.6),
				"max_life": 0.6
			})

func register_monopole(monopole_dict: Dictionary) -> void:
	if not entities_node:
		return
	if monopole_bridge.has("mesh") and is_instance_valid(monopole_bridge.mesh):
		monopole_bridge.mesh.queue_free()
	var ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	if ShipBuilder3DScript:
		var mesh = ShipBuilder3DScript.build_dirac_monopole_mesh()
		mesh.position = to_3d(monopole_dict.pos, 0.0)
		entities_node.add_child(mesh)
		monopole_bridge = {
			"dict": monopole_dict,
			"mesh": mesh
		}

func shatter_monopole_3d(pos2d: Vector2) -> void:
	if not entities_node:
		return
	var center_3d = to_3d(pos2d, 0.0)
	
	# Clean up monopole mesh
	if monopole_bridge.has("mesh") and is_instance_valid(monopole_bridge.mesh):
		monopole_bridge.mesh.queue_free()
		monopole_bridge.clear()
	
	# Massive magnetic supernova shockwave
	var shockwave_mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 8.0
	tor.outer_radius = 12.0
	shockwave_mesh.mesh = tor
	var sw_mat = StandardMaterial3D.new()
	sw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sw_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.95)
	shockwave_mesh.material_override = sw_mat
	shockwave_mesh.position = center_3d
	entities_node.add_child(shockwave_mesh)
	active_shockwaves.append({
		"mesh": shockwave_mesh,
		"mat": sw_mat,
		"max_r": 140.0,
		"life": 0.5,
		"max_life": 0.5
	})
	
	# Supernova light flash
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.8)
	light.light_energy = 9.0
	light.omni_range = 160.0
	light.position = to_3d(pos2d, 20.0)
	entities_node.add_child(light)
	active_flashes.append({
		"light": light,
		"life": 0.35,
		"max_life": 0.35,
		"base_energy": 9.0
	})
	
	# Heavy ancient gold hull shards
	var ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	if ShipBuilder3DScript:
		for i in range(16):
			var shard = ShipBuilder3DScript.build_debris_mesh(2)
			shard.position = center_3d + Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-6, 6))
			entities_node.add_child(shard)
			var angle = randf() * TAU
			var speed = randf_range(110.0, 290.0)
			active_debris.append({
				"mesh": shard,
				"pos": shard.position,
				"vel": Vector3(cos(angle) * speed, sin(angle) * speed, randf_range(-70, 70)),
				"rot": Vector3(randf() * TAU, randf() * TAU, randf() * TAU),
				"rot_vel": Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7)),
				"life": randf_range(0.5, 0.8),
				"max_life": 0.8
			})

# --- 3D Explosions & Shatter Debris ---

func spawn_explosion_3d(pos2d: Vector2, blast_color: Color, max_radius: float = 48.0, is_capital: bool = false) -> void:
	if not entities_node:
		return
		
	var center_3d = to_3d(pos2d, 0.0)
	
	# 1. 3D Shockwave Torus Ring
	var shockwave_mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 2.0
	tor.outer_radius = 4.0
	tor.rings = 16
	tor.ring_segments = 16
	shockwave_mesh.mesh = tor
	
	var sw_mat = StandardMaterial3D.new()
	sw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sw_mat.albedo_color = blast_color
	shockwave_mesh.material_override = sw_mat
	shockwave_mesh.position = center_3d
	entities_node.add_child(shockwave_mesh)
	
	active_shockwaves.append({
		"mesh": shockwave_mesh,
		"mat": sw_mat,
		"max_r": max_radius * 1.5,
		"life": 0.38,
		"max_life": 0.38
	})
	
	# 2. Dynamic Point Light Flash
	var light = OmniLight3D.new()
	light.light_color = blast_color.lerp(Color.WHITE, 0.4)
	light.light_energy = 5.5
	light.omni_range = max_radius * 2.5
	light.position = to_3d(pos2d, 15.0)
	entities_node.add_child(light)
	active_flashes.append({
		"light": light,
		"life": 0.22,
		"max_life": 0.22,
		"base_energy": 5.5
	})
	
	# 3. 3D Hull Fracture Debris Chunks
	var ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	if ShipBuilder3DScript:
		var shard_count = 12 if is_capital else 8
		var size_cat = 2 if is_capital else (1 if max_radius >= 40.0 else 0)
		
		for i in range(shard_count):
			var shard_mesh = ShipBuilder3DScript.build_debris_mesh(size_cat)
			shard_mesh.position = center_3d + Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-5, 5))
			entities_node.add_child(shard_mesh)
			
			var angle = randf() * TAU
			var speed_xy = randf_range(80.0, 260.0)
			var vel_z = randf_range(-70.0, 70.0)
			var vel = Vector3(cos(angle) * speed_xy, sin(angle) * speed_xy, vel_z)
			
			active_debris.append({
				"mesh": shard_mesh,
				"pos": shard_mesh.position,
				"vel": vel,
				"rot": Vector3(randf() * TAU, randf() * TAU, randf() * TAU),
				"rot_vel": Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
				"life": randf_range(0.35, 0.65),
				"max_life": 0.65
			})
			
	# 4. Secondary Cascading Chain Detonations on Capital Craft
	if is_capital:
		for c in range(3):
			var delay = 0.08 * float(c + 1)
			var offset = Vector2(randf_range(-40, 40), randf_range(-30, 30))
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(self):
					spawn_explosion_3d(pos2d + offset, blast_color, max_radius * 0.6, false)
			)

func trigger_warp_tunnel(duration: float = 0.45) -> void:
	warp_tunnel_active = true
	warp_tunnel_timer = duration
	warp_tunnel_duration = duration

func set_sector_theme(sector_num: int) -> void:
	current_sector = sector_num
	var neb_col = Color(0.06, 0.35, 0.8, 0.08)
	if sector_num == 2:
		neb_col = Color(0.85, 0.45, 0.08, 0.09)
	elif sector_num == 3:
		neb_col = Color(0.7, 0.12, 0.75, 0.09)
		
	for cloud in nebula_clouds:
		if is_instance_valid(cloud) and cloud.material_override is StandardMaterial3D:
			cloud.material_override.albedo_color = neb_col

func _update_background_3d(delta: float) -> void:
	var scroll_vector = Vector2.DOWN
	if GameAxis != null:
		scroll_vector = GameAxis.scroll_dir
		
	var speed_mult = 6.5 if warp_tunnel_active else 1.0
	var drift_3d = Vector3(scroll_vector.x, -scroll_vector.y, 0.0) * (5.5 * delta * speed_mult)
	
	# Update megastructures parallax drift
	for ms in megastructures:
		if is_instance_valid(ms):
			ms.position += drift_3d
			# Bounds wrapping
			if ms.position.x < -100.0:
				ms.position.x = 1380.0
			elif ms.position.x > 1380.0:
				ms.position.x = -100.0
			if ms.position.y > 100.0:
				ms.position.y = -820.0
			elif ms.position.y < -820.0:
				ms.position.y = 100.0
				
	# Update warp tunnel rings
	if warp_tunnel_active:
		warp_tunnel_timer -= delta
		var t = clampf(1.0 - (warp_tunnel_timer / warp_tunnel_duration), 0.0, 1.0)
		var ring_alpha = sin(t * PI) * 0.85
		
		for ring in warp_tunnel_rings:
			if is_instance_valid(ring):
				ring.position.z += 1600.0 * delta
				if ring.position.z > 350.0:
					ring.position.z -= 720.0
				if ring.material_override is StandardMaterial3D:
					var c = ring.material_override.albedo_color
					c.a = ring_alpha
					ring.material_override.albedo_color = c
					
		if warp_tunnel_timer <= 0.0:
			warp_tunnel_active = false
			for ring in warp_tunnel_rings:
				if is_instance_valid(ring) and ring.material_override is StandardMaterial3D:
					var c = ring.material_override.albedo_color
					c.a = 0.0
					ring.material_override.albedo_color = c

func _update_debris_and_vfx(delta: float) -> void:
	# Update active debris shards
	var surviving_debris: Array[Dictionary] = []
	for d in active_debris:
		d.life -= delta
		if d.life > 0.0 and is_instance_valid(d.mesh):
			d.pos += d.vel * delta
			d.vel *= 0.95
			d.rot += d.rot_vel * delta
			d.mesh.position = d.pos
			d.mesh.rotation = d.rot
			var scale_f = clampf(d.life / d.max_life, 0.01, 1.0)
			d.mesh.scale = Vector3(scale_f, scale_f, scale_f)
			surviving_debris.append(d)
		else:
			if is_instance_valid(d.mesh):
				d.mesh.queue_free()
	active_debris = surviving_debris
	
	# Update active shockwaves
	var surviving_sw: Array[Dictionary] = []
	for sw in active_shockwaves:
		sw.life -= delta
		if sw.life > 0.0 and is_instance_valid(sw.mesh):
			var t = 1.0 - (sw.life / sw.max_life)
			var current_r = sw.max_r * (1.0 - pow(1.0 - t, 3.0))
			sw.mesh.scale = Vector3(current_r * 0.25, current_r * 0.25, 1.0)
			if sw.mat is StandardMaterial3D:
				var c = sw.mat.albedo_color
				c.a = (1.0 - t) * 0.85
				sw.mat.albedo_color = c
			surviving_sw.append(sw)
		else:
			if is_instance_valid(sw.mesh):
				sw.mesh.queue_free()
	active_shockwaves = surviving_sw
	
	# Update active light flashes
	var surviving_flashes: Array[Dictionary] = []
	for f in active_flashes:
		f.life -= delta
		if f.life > 0.0 and is_instance_valid(f.light):
			var t = f.life / f.max_life
			f.light.light_energy = f.base_energy * t
			surviving_flashes.append(f)
		else:
			if is_instance_valid(f.light):
				f.light.queue_free()
	active_flashes = surviving_flashes
	
	# Update active materialization apertures
	var surviving_ap: Array[Dictionary] = []
	for ap in active_apertures:
		ap.life -= delta
		if ap.life > 0.0 and is_instance_valid(ap.root):
			var t = 1.0 - (ap.life / ap.max_life)
			var scale_f = lerpf(1.0, 0.05, pow(t, 2.0))
			ap.root.scale = Vector3(scale_f, scale_f, scale_f)
			ap.root.rotate_z(delta * 8.0)
			if ap.mat is StandardMaterial3D:
				var c = ap.mat.albedo_color
				c.a = (1.0 - t) * 0.85
				ap.mat.albedo_color = c
			surviving_ap.append(ap)
		else:
			if is_instance_valid(ap.root):
				ap.root.queue_free()
	active_apertures = surviving_ap

func _process(delta: float) -> void:
	var vp_size = get_viewport_rect().size
	if vp_size.x > 0 and vp_size.y > 0 and size != vp_size:
		_update_camera_projection()
		
	_update_background_3d(delta)
	_update_debris_and_vfx(delta)
	
	# Sync Nexus Wave Function Cloud with combat state
	if is_instance_valid(nexus_ribbon):
		var in_combat = (GameManager != null and GameManager.current_phase == GameManager.RunPhase.COMBAT_WAVES)
		nexus_ribbon.set_combat_active(in_combat)
	
	# Update Quantum Anomaly 3D models
	var surviving_anomalies: Array[Dictionary] = []
	for a_bridge in anomaly_bridges:
		var d = a_bridge.dict
		var mesh = a_bridge.mesh
		if is_instance_valid(mesh) and not d.get("shattered", false):
			mesh.position = to_3d(d.pos, 0.0)
			var g_out = mesh.get_node_or_null("GimbalOuter")
			if g_out: g_out.rotate_x(delta * 2.4)
			var g_in = mesh.get_node_or_null("GimbalInner")
			if g_in: g_in.rotate_y(delta * 3.6)
			var core = mesh.get_node_or_null("AnomalyCore")
			if core:
				core.rotate_z(delta * 1.8)
				var pulse = 1.0 + sin(d.get("elapsed", 0.0) * 4.0) * 0.12
				core.scale = Vector3(pulse, pulse, pulse)
			surviving_anomalies.append(a_bridge)
		else:
			if is_instance_valid(mesh):
				mesh.queue_free()
	anomaly_bridges = surviving_anomalies
	
	# Update Dirac Monopole 3D model
	if monopole_bridge.has("mesh") and is_instance_valid(monopole_bridge.mesh):
		var m_dict = monopole_bridge.dict
		var m_mesh = monopole_bridge.mesh
		if m_dict.get("active", false):
			m_mesh.position = to_3d(m_dict.pos, 0.0)
			var ring_n = m_mesh.get_node_or_null("PolarRingNorth")
			if ring_n: ring_n.rotate_y(delta * 2.2)
			var ring_s = m_mesh.get_node_or_null("PolarRingSouth")
			if ring_s: ring_s.rotate_y(-delta * 2.2)
			var sing = m_mesh.get_node_or_null("MonopoleSingularity")
			if sing:
				var spulse = 1.0 + sin(m_dict.get("elapsed", 0.0) * 6.0) * 0.15
				sing.scale = Vector3(spulse, spulse, spulse)
		else:
			m_mesh.queue_free()
			monopole_bridge.clear()
	
	# Update all player 3D visual bridges
	for id in player_bridges.keys():
		var bridge = player_bridges[id]
		if is_instance_valid(bridge.target_node):
			bridge.update(delta)
		else:
			bridge.destroy()
			player_bridges.erase(id)
	
	# Update all enemy 3D visual bridges
	for id in enemy_bridges.keys():
		var bridge = enemy_bridges[id]
		if is_instance_valid(bridge.target_node):
			bridge.update(delta)
		else:
			bridge.destroy()
			enemy_bridges.erase(id)
	
	# Update all boss 3D visual bridges
	for id in boss_bridges.keys():
		var bridge = boss_bridges[id]
		if is_instance_valid(bridge.target_node):
			bridge.update(delta)
		else:
			bridge.destroy()
			boss_bridges.erase(id)
			
	# Update all hazard 3D visual bridges
	for id in hazard_bridges.keys():
		var bridge = hazard_bridges[id]
		if is_instance_valid(bridge.target_node):
			bridge.update(delta)
		else:
			bridge.destroy()
			hazard_bridges.erase(id)
			
	# Update station 3D visual bridge
	if station_bridge:
		if is_instance_valid(station_bridge.target_shop):
			station_bridge.update(delta)
		else:
			station_bridge.destroy()
			station_bridge = null

