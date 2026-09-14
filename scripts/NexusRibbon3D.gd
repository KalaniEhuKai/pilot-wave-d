extends Node3D
class_name NexusRibbon3D

## NexusRibbon3D.gd - Extradimensional Wave Function Cloud inspired by "The Nexus" (Star Trek Generations).
## Undulates along the forward horizon (right edge in 16:9, top edge in 9:16) during active combat.
## Features 4 twisting iridescent plasma ribbons (Cyan, Magenta, Violet, Gold), crackling electrical arcs,
## drifting quantum embers, and dynamic energy flaring surges when enemy bubbles collapse.

const STRAND_COLORS = [
	Color(0.0, 0.95, 1.0, 0.72),  # Strand 0: Electric Cyan
	Color(1.0, 0.05, 0.6, 0.72),  # Strand 1: Neon Magenta
	Color(0.65, 0.15, 1.0, 0.72), # Strand 2: Cosmic Violet
	Color(1.0, 0.78, 0.15, 0.72)  # Strand 3: Solar Gold
]

var ribbon_instances: Array[MeshInstance3D] = []
var ribbon_imms: Array[ImmediateMesh] = []
var ribbon_mats: Array[StandardMaterial3D] = []

var lightning_instance: MeshInstance3D = null
var lightning_imm: ImmediateMesh = null
var lightning_mat: StandardMaterial3D = null

var time_accum: float = 0.0
var surge_timer: float = 0.0
var surge_duration: float = 0.45
var surge_multiplier: float = 1.0

# Active targeted lightning bridges (e.g. from Nexus to materializing enemy)
var active_targeted_arcs: Array[Dictionary] = []

# Drifting quantum embers
var embers: Array[Dictionary] = []
const MAX_EMBERS = 24

var is_combat_active: bool = true
var visibility_alpha: float = 1.0

func _ready() -> void:
	name = "NexusRibbon3D"
	_setup_ribbon_strands()
	_setup_lightning()
	_init_embers()

func _setup_ribbon_strands() -> void:
	for i in range(4):
		var inst = MeshInstance3D.new()
		inst.name = "RibbonStrand_%d" % i
		var imm = ImmediateMesh.new()
		inst.mesh = imm
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = STRAND_COLORS[i]
		inst.material_override = mat
		
		add_child(inst)
		ribbon_instances.append(inst)
		ribbon_imms.append(imm)
		ribbon_mats.append(mat)

func _setup_lightning() -> void:
	lightning_instance = MeshInstance3D.new()
	lightning_instance.name = "NexusLightning"
	lightning_imm = ImmediateMesh.new()
	lightning_instance.mesh = lightning_imm
	
	lightning_mat = StandardMaterial3D.new()
	lightning_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lightning_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lightning_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lightning_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lightning_mat.albedo_color = Color(0.85, 0.98, 1.0, 0.95)
	lightning_instance.material_override = lightning_mat
	add_child(lightning_instance)

func _init_embers() -> void:
	embers.clear()
	for i in range(MAX_EMBERS):
		embers.append({
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"life": 0.0,
			"max_life": randf_range(1.2, 2.5),
			"color": STRAND_COLORS[i % 4]
		})

func trigger_surge(duration: float = 0.45) -> void:
	surge_duration = maxf(0.1, duration)
	surge_timer = surge_duration
	surge_multiplier = 3.6

func strike_lightning_to(target_pos_3d: Vector3, duration: float = 0.22) -> void:
	active_targeted_arcs.append({
		"target": target_pos_3d,
		"life": duration,
		"max_life": duration,
		"seed": randf() * 100.0
	})

func set_combat_active(active: bool) -> void:
	is_combat_active = active

func _process(delta: float) -> void:
	time_accum += delta
	
	# Update surge decay
	if surge_timer > 0.0:
		surge_timer -= delta
		var t = clampf(surge_timer / surge_duration, 0.0, 1.0)
		surge_multiplier = lerpf(1.0, 3.6, t)
	else:
		surge_multiplier = 1.0
	
	# Combat visibility fade
	var target_alpha = 1.0 if is_combat_active else 0.25
	visibility_alpha = lerpf(visibility_alpha, target_alpha, delta * 3.0)
	
	_render_nexus(delta)

func _render_nexus(delta: float) -> void:
	var vp_size = Vector2(1280, 720)
	var vp = get_viewport()
	if vp and vp.get_visible_rect().size.x > 0:
		vp_size = vp.get_visible_rect().size
		
	var is_vert = GameAxis != null and GameAxis.is_vertical
	var num_segments = 26
	
	var strand_points: Array[Array] = [[], [], [], []]
	
	# Determine forward horizon alignment
	# In horizontal mode: right edge (x approx vp_size.x - 20.0), lateral span y from 20.0 to -vp_size.y - 20.0
	# In vertical mode: top edge (y approx 20.0 in 3D coordinates), lateral span x from -20.0 to vp_size.x + 20.0
	var base_horizon_fwd = (vp_size.x - 22.0) if not is_vert else 22.0
	var lat_start = 30.0 if not is_vert else -30.0
	var lat_end = -(vp_size.y + 30.0) if not is_vert else (vp_size.x + 30.0)
	
	# Compute ribbon vertices for all 4 strands
	for s in range(num_segments + 1):
		var t_seg = float(s) / float(num_segments)
		var lat = lerpf(lat_start, lat_end, t_seg)
		
		for k in range(4):
			var phase_k = float(k) * 1.5708 + float(k) * 0.4
			var undulate_1 = sin(time_accum * 2.1 + float(s) * 0.38 + phase_k) * (20.0 * surge_multiplier)
			var undulate_2 = cos(time_accum * 3.4 - float(s) * 0.52 + phase_k) * (9.0 * surge_multiplier)
			var fwd_offset = undulate_1 + undulate_2
			var depth_z = sin(time_accum * 1.6 + float(s) * 0.45 + phase_k) * 14.0 - 25.0
			
			var pt = Vector3.ZERO
			if not is_vert:
				pt = Vector3(base_horizon_fwd + fwd_offset, lat, depth_z)
			else:
				pt = Vector3(lat, base_horizon_fwd + fwd_offset, depth_z)
				
			strand_points[k].append(pt)
	
	# Draw ribbon triangle strips
	for k in range(4):
		var imm = ribbon_imms[k]
		var mat = ribbon_mats[k]
		
		# Update dynamic material brightness based on surge and alpha
		var col = STRAND_COLORS[k]
		var energy = lerpf(1.0, 3.2, (surge_multiplier - 1.0) / 2.6)
		mat.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, col.a * visibility_alpha)
		
		imm.clear_surfaces()
		imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		
		var pts = strand_points[k]
		var base_w = (16.0 + sin(time_accum * 3.2 + float(k)) * 4.0) * (1.0 + (surge_multiplier - 1.0) * 0.35)
		
		for s in range(pts.size()):
			var p = pts[s] as Vector3
			var half_w = base_w * 0.5
			var v1 = Vector3.ZERO
			var v2 = Vector3.ZERO
			
			if not is_vert:
				# Normal perpendicular to lateral span is along forward axis X and depth Z
				v1 = p + Vector3(half_w, 0.0, 0.0)
				v2 = p - Vector3(half_w, 0.0, 0.0)
			else:
				# Normal perpendicular is along forward axis Y and depth Z
				v1 = p + Vector3(0.0, half_w, 0.0)
				v2 = p - Vector3(0.0, half_w, 0.0)
				
			imm.surface_add_vertex(v1)
			imm.surface_add_vertex(v2)
			
		imm.surface_end()
	
	# Draw electrical arcs and lightning filaments
	_render_lightning(strand_points, is_vert, delta)

func _render_lightning(strand_points: Array[Array], is_vert: bool, delta: float) -> void:
	lightning_imm.clear_surfaces()
	lightning_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# 1. Crackling lightning filaments between intertwining strands
	var arc_count = int(lerpf(4.0, 10.0, (surge_multiplier - 1.0) / 2.6))
	for a in range(arc_count):
		var s_idx = randi_range(2, 24)
		var k1 = randi_range(0, 3)
		var k2 = (k1 + randi_range(1, 2)) % 4
		
		if s_idx < strand_points[k1].size() and s_idx < strand_points[k2].size():
			var p1 = strand_points[k1][s_idx] as Vector3
			var p2 = strand_points[k2][s_idx] as Vector3
			_draw_jagged_arc(p1, p2, 3, 9.0 * surge_multiplier)
	
	# 2. Forward branching tendrils into space
	var branch_count = int(lerpf(2.0, 6.0, (surge_multiplier - 1.0) / 2.6))
	for b in range(branch_count):
		var s_idx = randi_range(3, 23)
		var k = randi_range(0, 3)
		if s_idx < strand_points[k].size():
			var origin = strand_points[k][s_idx] as Vector3
			var branch_dir = Vector3(-1.0, 0.0, 0.0) if not is_vert else Vector3(0.0, -1.0, 0.0)
			var branch_reach = randf_range(35.0, 85.0) * surge_multiplier
			var branch_end = origin + branch_dir * branch_reach + Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-8, 8))
			_draw_jagged_arc(origin, branch_end, 4, 12.0)
	
	# 3. Targeted lightning strikes leaping to collapsing enemy coordinates
	var surviving_arcs: Array[Dictionary] = []
	for arc in active_targeted_arcs:
		arc.life -= delta
		if arc.life > 0.0:
			var target = arc.target as Vector3
			# Find closest point on strand 0 or 1
			var best_pt = strand_points[0][12] as Vector3
			var min_dist = 99999.0
			for s in range(strand_points[0].size()):
				var cand = strand_points[0][s] as Vector3
				var dist = cand.distance_to(target)
				if dist < min_dist:
					min_dist = dist
					best_pt = cand
			
			_draw_jagged_arc(best_pt, target, 7, 24.0)
			surviving_arcs.append(arc)
	active_targeted_arcs = surviving_arcs
	
	# 4. Drifting quantum embers
	var scroll_3d = Vector3(-1.0, 0.0, 0.0)
	if GameAxis != null:
		scroll_3d = Vector3(GameAxis.scroll_dir.x, -GameAxis.scroll_dir.y, 0.0)
		
	for ember in embers:
		ember.life -= delta
		if ember.life <= 0.0:
			# Respawn on random ribbon point
			var k = randi_range(0, 3)
			var s = randi_range(0, strand_points[k].size() - 1)
			ember.pos = strand_points[k][s] + Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
			ember.vel = scroll_3d * randf_range(60.0, 140.0) + Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-10, 10))
			ember.max_life = randf_range(0.8, 2.0)
			ember.life = ember.max_life
		else:
			ember.pos += ember.vel * delta
			var p = ember.pos as Vector3
			# Draw small crosshair spark
			var sz = 2.5
			lightning_imm.surface_add_vertex(p - Vector3(sz, 0, 0))
			lightning_imm.surface_add_vertex(p + Vector3(sz, 0, 0))
			lightning_imm.surface_add_vertex(p - Vector3(0, sz, 0))
			lightning_imm.surface_add_vertex(p + Vector3(0, sz, 0))
	
	lightning_imm.surface_end()

func _draw_jagged_arc(p_from: Vector3, p_to: Vector3, subdivisions: int, jitter_mag: float) -> void:
	var prev = p_from
	for step in range(1, subdivisions + 1):
		var t = float(step) / float(subdivisions)
		var next_pt = p_from.lerp(p_to, t)
		if step < subdivisions:
			next_pt += Vector3(randf_range(-jitter_mag, jitter_mag), randf_range(-jitter_mag, jitter_mag), randf_range(-jitter_mag * 0.5, jitter_mag * 0.5))
		lightning_imm.surface_add_vertex(prev)
		lightning_imm.surface_add_vertex(next_pt)
		prev = next_pt
