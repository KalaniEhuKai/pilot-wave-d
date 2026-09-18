extends Node2D

## BestiaryCanvas.gd - High-tech holographic vector graphics renderer for Bestiary diorama.

@onready var sim = get_parent().get_parent() # BestiarySimulation root

func _draw() -> void:
	if not sim:
		return
	
	var w = sim.ARENA_WIDTH
	var h = sim.ARENA_HEIGHT
	
	# 1. Subtle Holographic Grid
	var grid_color = Color(0.12, 0.35, 0.55, 0.12)
	var step = 40.0
	for x in range(0, int(w), int(step)):
		draw_line(Vector2(x, 0), Vector2(x, h), grid_color, 1.0)
	for y in range(0, int(h), int(step)):
		draw_line(Vector2(0, y), Vector2(w, y), grid_color, 1.0)
	
	# Range boundary lines
	draw_line(Vector2(0, 0), Vector2(w, 0), Color(0.2, 0.8, 1.0, 0.4), 1.0)
	draw_line(Vector2(0, h), Vector2(w, h), Color(0.2, 0.8, 1.0, 0.4), 1.0)
	
	# 2. Nexus Cloud Aura at Right Horizon
	var nexus_col = Color(0.65, 0.25, 0.95, 0.18)
	draw_rect(Rect2(w - 60.0, 0, 60.0, h), nexus_col, true)
	draw_line(Vector2(w - 60.0, 0), Vector2(w - 60.0, h), Color(0.85, 0.45, 1.0, 0.6), 2.0)
	
	# 3. Nexus Lightning Arc Bridge
	if sim.nexus_lightning_timer > 0.0 and sim.nexus_lightning_points.size() >= 2:
		var pts = sim.nexus_lightning_points
		var alpha = clampf(sim.nexus_lightning_timer / 0.28, 0.0, 1.0)
		for i in range(pts.size() - 1):
			# Core white bolt
			draw_line(pts[i], pts[i+1], Color(1.0, 1.0, 1.0, alpha), 2.5)
			# Outer magenta / cyan corona
			draw_line(pts[i], pts[i+1], Color(0.4, 0.85, 1.0, alpha * 0.7), 6.0)
	
	# 4. Quantum Materialization Shockwave Aperture
	if sim.shockwave_alpha > 0.0:
		var col = Color(0.3, 0.95, 1.0, sim.shockwave_alpha * 0.85)
		draw_arc(sim.enemy_pos, sim.shockwave_radius, 0.0, TAU, 32, col, 2.0)
		draw_arc(sim.enemy_pos, sim.shockwave_radius * 0.6, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, sim.shockwave_alpha * 0.6), 1.5)
	
	# 5. Target Drone Shield Bubble & Impact Ripple
	if is_instance_valid(sim.target_drone):
		var dp = sim.target_drone.position
		var base_shield_col = Color(0.1, 0.85, 1.0, 0.25)
		if sim.shield_hit_flash > 0.0:
			base_shield_col = Color(0.9, 0.98, 1.0, 0.25 + sim.shield_hit_flash * 0.6)
			# Outer impact ripples
			var rip_r = 22.0 + (1.0 - sim.shield_hit_flash) * 16.0
			draw_arc(dp, rip_r, 0.0, TAU, 24, Color(0.2, 0.95, 1.0, sim.shield_hit_flash * 0.8), 2.0)
		
		# Shield circumference
		draw_arc(dp, 20.0, 0.0, TAU, 24, base_shield_col, 1.5)
		# Shield interior fill
		draw_circle(dp, 19.0, Color(base_shield_col.r, base_shield_col.g, base_shield_col.b, base_shield_col.a * 0.3))

	# 6. Enemy Craft Shields & Auras (Knight Vanguard & Shield Frigate)
	var et = sim.current_entry.get("enemy_type", -1)
	if sim.enemy_mesh_root and sim.enemy_mesh_root.visible:
		var ep = sim.enemy_pos
		var er = sim.enemy_rot
		
		# Knight Vanguard Mirror Shield
		if et == 6: # KNIGHT_VANGUARD
			var arc_center = ep + Vector2(cos(er), sin(er)) * 6.0
			var is_salvo = (sim.current_state == sim.State.SALVO_1 or sim.current_state == sim.State.SALVO_2)
			if is_salvo:
				draw_arc(arc_center, 24.0, er - PI * 0.52, er - PI * 0.18, 8, Color(1.0, 0.82, 0.2, 0.95), 3.2)
				draw_arc(arc_center, 24.0, er + PI * 0.18, er + PI * 0.52, 8, Color(1.0, 0.82, 0.2, 0.95), 3.2)
			else:
				var s_col = Color(0.25, 0.88, 1.0, 0.95)
				draw_arc(arc_center, 24.0, er - PI * 0.45, er + PI * 0.45, 18, s_col, 3.5)
				var shimmer = 0.5 + 0.5 * sin(sim.flight_time * 10.0)
				draw_arc(arc_center + Vector2(cos(er), sin(er)) * 3.0, 20.0, er - PI * 0.38, er + PI * 0.38, 12, Color(1.0, 1.0, 1.0, 0.4 + shimmer * 0.4), 1.6)
		
		# Shield Frigate Aegis Aura & Personal Shield
		elif et == 4: # SHIELD_FRIGATE
			# Personal Hex Shield
			var hex_pts = PackedVector2Array()
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.06
			var rot = Time.get_ticks_msec() * 0.001
			for i in range(6):
				var a = rot + (float(i) / 6.0) * TAU
				hex_pts.append(ep + Vector2(cos(a), sin(a)) * 28.0 * pulse)
			var fill_col = Color(0.35, 0.85, 1.0, 0.18)
			draw_colored_polygon(hex_pts, fill_col)
			draw_polyline(hex_pts + PackedVector2Array([hex_pts[0]]), Color(0.35, 0.85, 1.0, 0.95), 2.0, true)
			
			# 140px Aegis Perimeter
			var aura_r = 140.0 + sin(sim.flight_time * 3.2) * 3.5
			draw_circle(ep, aura_r, Color(0.08, 0.72, 1.0, 0.05))
			draw_arc(ep, aura_r, 0.0, TAU, 48, Color(0.18, 0.88, 1.0, 0.55), 2.0)
			var orb_rot = sim.flight_time * 0.75
			for i in range(4):
				var a_center = orb_rot + float(i) * (TAU / 4.0)
				draw_arc(ep, aura_r, a_center - 0.22, a_center + 0.22, 8, Color(0.7, 0.95, 1.0, 0.9), 3.0)
			var ripple_r = fmod(sim.flight_time * 55.0, 140.0)
			var ripple_a = (1.0 - ripple_r / 140.0) * 0.40
			draw_arc(ep, ripple_r, 0.0, TAU, 36, Color(0.25, 0.92, 1.0, ripple_a), 1.5)
