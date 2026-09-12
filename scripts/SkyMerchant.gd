extends CanvasLayer

## SkyMerchant.gd - Super Quarket Station: Orbital centrifuge depot with concentric counter-rotating rings, independent co-op stalls, and escalating reroll terminal.

const ProgressionModel = preload("res://scripts/ProgressionModel.gd")

signal undocked()

class StationCradle extends Control:
	var shop_ref: Node = null
	func _draw() -> void:
		if is_instance_valid(shop_ref):
			if shop_ref.has_method("_draw_station"):
				shop_ref._draw_station(self)
			elif shop_ref.has_method("_draw_zeppelin"):
				shop_ref._draw_zeppelin(self)

# Compatibility alias for legacy scripts/tests
const ZeppelinCradle = StationCradle

@onready var panel: Control = $Panel
@onready var p1_stall: VBoxContainer = $Panel/VBox/HBoxStalls/P1Stall
@onready var p2_stall: VBoxContainer = $Panel/VBox/HBoxStalls/P2Stall
@onready var p1_wallet_lbl: Label = $Panel/VBox/HBoxStalls/P1Stall/P1Wallet
@onready var p2_wallet_lbl: Label = $Panel/VBox/HBoxStalls/P2Stall/P2Wallet
@onready var p1_reroll_btn: Button = $Panel/VBox/HBoxStalls/P1Stall/P1RerollBtn
@onready var p2_reroll_btn: Button = $Panel/VBox/HBoxStalls/P2Stall/P2RerollBtn
@onready var p1_repair_btn: Button = $Panel/VBox/HBoxStalls/P1Stall/P1RepairBtn
@onready var p2_repair_btn: Button = $Panel/VBox/HBoxStalls/P2Stall/P2RepairBtn
@onready var p1_items_grid: GridContainer = $Panel/VBox/HBoxStalls/P1Stall/P1ItemsGrid
@onready var p2_items_grid: GridContainer = $Panel/VBox/HBoxStalls/P2Stall/P2ItemsGrid
@onready var undock_btn: Button = $Panel/VBox/UndockBtn

var p1_shop_items: Array[ItemModifier] = []
var p2_shop_items: Array[ItemModifier] = []

# Super Quarket Station Visuals & Docking Animation
var cradle: Control = null
var station_visible: bool = false
var station_pos: Vector2 = Vector2.ZERO
var tractor_beam_active: bool = false
var tractor_beam_alpha: float = 0.0
var is_docking_anim: bool = false

# Backwards-compatible aliases for tests & legacy references
var zeppelin_visible: bool:
	get: return station_visible
	set(v): station_visible = v
var zeppelin_pos: Vector2:
	get: return station_pos
	set(v): station_pos = v

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	
	# Instantiate Station docking cradle CanvasItem
	cradle = StationCradle.new()
	cradle.name = "StationCradle"
	cradle.shop_ref = self
	cradle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cradle.anchors_preset = Control.PRESET_FULL_RECT
	add_child(cradle)
	move_child(cradle, 0)
	
	undock_btn.pressed.connect(_on_undock_pressed)
	p1_reroll_btn.pressed.connect(func(): _reroll_stall(1))
	p2_reroll_btn.pressed.connect(func(): _reroll_stall(2))
	p1_repair_btn.pressed.connect(func(): _buy_repair(1))
	p2_repair_btn.pressed.connect(func(): _buy_repair(2))
	GameManager.joules_changed.connect(_update_wallets)
	GameManager.game_over_triggered.connect(func(_s, _w, _t):
		panel.visible = false
		station_visible = false
	)

func _process(_delta: float) -> void:
	if station_visible and is_instance_valid(cradle):
		cradle.queue_redraw()

func dock_with_animation(on_complete: Callable = Callable()) -> void:
	if GameManager != null and GameManager.is_game_over:
		return
	
	# Purge hostile bullets for docking safety
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and b.get("is_enemy"):
			b.queue_free()
	
	GameManager.current_phase = GameManager.RunPhase.SHOP_DOCKING
	is_docking_anim = true
	zeppelin_visible = true
	tractor_beam_active = false
	tractor_beam_alpha = 0.0
	
	var vp = get_viewport().get_visible_rect().size
	var target_y = vp.y * 0.22 if GameAxis.is_vertical else vp.y * 0.16
	var start_pos = Vector2(vp.x * 0.5, -180.0)
	var target_pos = Vector2(vp.x * 0.5, target_y)
	zeppelin_pos = start_pos
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_banner"):
		hud._show_banner("[ SUPER QUARKET STATION // RENDEZVOUS ]", Color(0.2, 0.95, 1.0, 1.0))
	
	var tw = create_tween()
	tw.tween_property(self, "zeppelin_pos", target_pos, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Engage tractor beams
	tw.tween_callback(func():
		tractor_beam_active = true
		SoundEffects.play_sfx("docking_clamp", 0.05, 2.0)
	)
	tw.tween_property(self, "tractor_beam_alpha", 1.0, 0.35)
	
	# Open shop panel smoothly
	tw.tween_callback(func():
		is_docking_anim = false
		open_shop()
		panel.modulate.a = 0.0
		var p_tw = create_tween()
		p_tw.tween_property(panel, "modulate:a", 1.0, 0.25)
		if on_complete.is_valid():
			on_complete.call()
	)

func open_shop() -> void:
	if GameManager != null and GameManager.is_game_over:
		return
	zeppelin_visible = true
	panel.visible = true
	panel.modulate.a = 1.0
	get_tree().paused = true
	
	# Show/hide P2 stall depending on Co-Op mode
	p2_stall.visible = GameManager.is_coop_mode
	
	_generate_stall_items(1)
	if GameManager.is_coop_mode:
		_generate_stall_items(2)
	
	_update_wallets(GameManager.p1_joules, GameManager.p2_joules)
	SoundEffects.play_sfx("bonus", 0.05, 3.0)

func _generate_stall_items(player_id: int) -> void:
	var sec = GameManager.current_sector if GameManager != null else 1
	var player: CharacterBody2D = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.player_id == player_id:
			player = p
			break
	
	var items: Array[ItemModifier] = []
	var selected_ids: Array[String] = []
	
	# Slot 1: Guaranteed Offense
	var item_offense = ProgressionModel.select_weighted_item(player, sec, -1, "offense", selected_ids)
	if item_offense:
		items.append(item_offense)
		selected_ids.append(item_offense.id)
	
	# Slot 2: Guaranteed Defense or Utility
	var def_or_util = "defense" if randf() > 0.5 else "utility"
	var item_def = ProgressionModel.select_weighted_item(player, sec, -1, def_or_util, selected_ids)
	if item_def:
		items.append(item_def)
		selected_ids.append(item_def.id)
	
	# Slot 3: Wildcard (Any Category)
	var item_wildcard = ProgressionModel.select_weighted_item(player, sec, -1, "", selected_ids)
	if item_wildcard:
		items.append(item_wildcard)
		selected_ids.append(item_wildcard.id)
	
	# Fallback if catalog filtering returned fewer than 3
	if items.size() < 3:
		var fill = ItemDatabase.get_random_choice(selected_ids, 3 - items.size(), player)
		items.append_array(fill)
	
	if player_id == 1:
		p1_shop_items = items
		_populate_items_grid(p1_items_grid, p1_shop_items, 1)
	else:
		p2_shop_items = items
		_populate_items_grid(p2_items_grid, p2_shop_items, 2)

func _populate_items_grid(grid: GridContainer, items: Array[ItemModifier], player_id: int) -> void:
	for c in grid.get_children():
		c.queue_free()
	
	for it in items:
		var card = PanelContainer.new()
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card.add_child(card_vbox)
		
		# Tier Header Badge
		var tier_badge = Label.new()
		match it.tier:
			ItemModifier.ItemTier.TIER_1_BALLISTIC:
				tier_badge.text = "[TIER 1 - STAT]"
				tier_badge.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 0.8))
			ItemModifier.ItemTier.TIER_2_PARADIGM:
				tier_badge.text = "[TIER 2 - SYNERGY]"
				tier_badge.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7, 0.85))
			ItemModifier.ItemTier.TIER_3_EXOTIC:
				tier_badge.text = "[TIER 3 - EXOTIC]"
				tier_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.9))
		tier_badge.add_theme_font_size_override("font_size", 9)
		card_vbox.add_child(tier_badge)
		
		var title = Label.new()
		title.text = it.display_name
		title.add_theme_color_override("font_color", it.icon_color)
		title.add_theme_font_size_override("font_size", 12)
		card_vbox.add_child(title)
		
		var desc = Label.new()
		desc.text = it.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 10)
		desc.custom_minimum_size = Vector2(160, 48)
		card_vbox.add_child(desc)
		
		var discount = _get_player_discount(player_id)
		var base_price = ProgressionModel.get_tier_price(it.tier)
		var cost = int(base_price * discount)
		var buy_btn = Button.new()
		buy_btn.text = "BUY - %d J" % cost
		buy_btn.focus_mode = Control.FOCUS_NONE
		buy_btn.pressed.connect(func(): _buy_item(it, card, player_id, cost))
		card_vbox.add_child(buy_btn)
		
		grid.add_child(card)

func _get_player_discount(player_id: int) -> float:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.player_id == player_id:
			if p.get("has_carnot_efficiency") == true:
				return 0.5
	return 1.0

func _buy_item(item: ItemModifier, card_node: Node, player_id: int, cost: int = 25) -> void:
	if GameManager.spend_joules(cost, player_id):
		SoundEffects.play_sfx("bonus", 0.08, 4.0)
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.player_id == player_id:
				p.add_modifier(item)
		card_node.queue_free()

func _buy_repair(player_id: int) -> void:
	var cost = int(20 * _get_player_discount(player_id))
	if GameManager.spend_joules(cost, player_id):
		SoundEffects.play_sfx("bonus", 0.05, 1.0)
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.player_id == player_id:
				p.hull = mini(p.max_hull, p.hull + 2)
				p._emit_health()

func _reroll_stall(player_id: int) -> void:
	var base_cost = GameManager.p1_reroll_cost if player_id == 1 else GameManager.p2_reroll_cost
	var cost = int(base_cost * _get_player_discount(player_id))
	if GameManager.spend_joules(cost, player_id):
		SoundEffects.play_sfx("roll", 0.08, 2.0)
		_generate_stall_items(player_id)
		
		# Escalate reroll cost: 5 -> 10 -> 20 -> 35
		if player_id == 1:
			GameManager.p1_reroll_cost = _next_cost(GameManager.p1_reroll_cost)
		else:
			GameManager.p2_reroll_cost = _next_cost(GameManager.p2_reroll_cost)
		_update_wallets(GameManager.p1_joules, GameManager.p2_joules)

func _next_cost(current: int) -> int:
	match current:
		5: return 10
		10: return 20
		20: return 35
		35: return 55
		_: return current + 25

func _update_wallets(p1_j: int, p2_j: int) -> void:
	p1_wallet_lbl.text = "P1 WALLET: %d J" % p1_j
	p1_reroll_btn.text = "REROLL WARES - %d J" % GameManager.p1_reroll_cost
	p1_repair_btn.text = "NANO REPAIR (+2 HULL) - 20 J"
	
	if GameManager.is_coop_mode:
		p2_wallet_lbl.text = "P2 WALLET: %d J" % p2_j
		p2_reroll_btn.text = "REROLL WARES - %d J" % GameManager.p2_reroll_cost
		p2_repair_btn.text = "NANO REPAIR (+2 HULL) - 20 J"

func _on_undock_pressed() -> void:
	panel.visible = false
	get_tree().paused = false
	
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	
	SoundEffects.play_sfx("docking_clamp", 0.08, -2.0)
	tractor_beam_active = false
	tractor_beam_alpha = 0.0
	
	# Forward afterburner launch impulse on player ships
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			p.global_position += GameAxis.forward * 50.0
			if p.has_method("spawn_meissner_fx"):
				p.spawn_meissner_fx()
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_show_banner"):
		hud._show_banner("[ UNDOCKED FROM SUPER QUARKET // RESUMING COMBAT ]", Color(0.2, 0.95, 1.0, 1.0))
	
	# Animate station departure
	var vp = get_viewport().get_visible_rect().size
	var exit_pos = Vector2(vp.x * 0.5, -280.0)
	var tw = create_tween()
	tw.tween_property(self, "station_pos", exit_pos, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		station_visible = false
		if is_instance_valid(cradle):
			cradle.queue_redraw()
	)
	
	undocked.emit()
	GameManager.current_phase = GameManager.RunPhase.COMBAT_WAVES

func _draw_zeppelin(cradle_node: Control) -> void:
	_draw_station(cradle_node)

func _draw_station(cradle_node: Control) -> void:
	if not station_visible:
		return
	
	var pos = station_pos
	var t = Time.get_ticks_msec() * 0.001
	var ang_outer = t * 0.40       # Outer ring: clockwise rotation
	var ang_inner = -t * 0.70      # Inner ring: counter-clockwise rotation
	
	# 1. Tractor Beams to living players (Active during docking)
	if tractor_beam_active and tractor_beam_alpha > 0.0:
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and not p.is_queued_for_deletion():
				var p_pos = p.global_position
				for pylon_x in [pos.x - 110, pos.x + 110]:
					var emit_pos = Vector2(pylon_x, pos.y + 34)
					var beam_poly = PackedVector2Array([
						emit_pos,
						p_pos + Vector2(-32, -8),
						p_pos + Vector2(32, -8)
					])
					cradle_node.draw_colored_polygon(beam_poly, Color(0.15, 0.85, 1.0, tractor_beam_alpha * 0.22))
					cradle_node.draw_line(emit_pos, p_pos, Color(1.0, 1.0, 1.0, tractor_beam_alpha * 0.65), 2.0, true)
				# Concentric Meissner containment rings around the player ship
				cradle_node.draw_arc(p_pos, 32.0, 0, TAU, 32, Color(0.2, 0.95, 1.0, tractor_beam_alpha * 0.9), 2.5, true)
				var pulse_ring_r = 42.0 + sin(t * 6.0) * 4.0
				cradle_node.draw_arc(p_pos, pulse_ring_r, 0, TAU, 32, Color(1.0, 0.85, 0.2, tractor_beam_alpha * 0.55), 1.5, true)
	
	# 2. Outer Ring: Habitat & Logistics Centrifuge (Clockwise Rotation)
	var segs = 36
	var outer_band_pts = PackedVector2Array()
	for i in range(segs):
		var ang = (float(i) / segs) * TAU
		outer_band_pts.append(pos + Vector2(cos(ang) * 200.0, sin(ang) * 60.0))
	for i in range(segs - 1, -1, -1):
		var ang = (float(i) / segs) * TAU
		outer_band_pts.append(pos + Vector2(cos(ang) * 170.0, sin(ang) * 51.0))
	cradle_node.draw_colored_polygon(outer_band_pts, Color(0.04, 0.08, 0.14, 0.96))
	
	var rim_outer = PackedVector2Array()
	var rim_inner = PackedVector2Array()
	for i in range(segs + 1):
		var ang = (float(i % segs) / segs) * TAU
		rim_outer.append(pos + Vector2(cos(ang) * 200.0, sin(ang) * 60.0))
		rim_inner.append(pos + Vector2(cos(ang) * 170.0, sin(ang) * 51.0))
	cradle_node.draw_polyline(rim_outer, Color(0.18, 0.88, 1.0, 0.95), 2.4, true)
	cradle_node.draw_polyline(rim_inner, Color(0.12, 0.65, 0.85, 0.6), 1.6, true)
	
	# 3. Outer Structural Spokes (Connecting Hub to Outer Ring, Rotating with Outer Ring)
	for s in range(4):
		var spoke_ang = ang_outer + s * (TAU / 4.0)
		var hub_pt = pos + Vector2(cos(spoke_ang) * 44.0, sin(spoke_ang) * 18.0)
		var ring_pt = pos + Vector2(cos(spoke_ang) * 170.0, sin(spoke_ang) * 51.0)
		cradle_node.draw_line(hub_pt, ring_pt, Color(0.2, 0.6, 0.8, 0.7), 2.2, true)
		cradle_node.draw_line(hub_pt + Vector2(0, -2), ring_pt + Vector2(0, -2), Color(1.0, 0.85, 0.2, 0.35), 1.0, true)
	
	# 4. Outer Ring Habitat Pods & Solar Panels (Rotating Clockwise)
	for k in range(8):
		var p_ang = ang_outer + k * (TAU / 8.0)
		var pod_pos = pos + Vector2(cos(p_ang) * 185.0, sin(p_ang) * 55.5)
		cradle_node.draw_circle(pod_pos, 5.5, Color(0.06, 0.12, 0.20, 1.0))
		cradle_node.draw_arc(pod_pos, 5.5, 0, TAU, 14, Color(0.2, 0.9, 1.0, 0.9), 1.4, true)
		var mod_color = Color(1.0, 0.88, 0.35, 0.95) if (k % 2 == 0) else Color(0.25, 0.95, 1.0, 0.95)
		cradle_node.draw_circle(pod_pos, 2.5, mod_color)
		if k % 2 == 1:
			var wing_dir = Vector2(cos(p_ang), sin(p_ang) * 0.35).normalized()
			var wing_tip = pod_pos + wing_dir * 14.0
			cradle_node.draw_line(pod_pos, wing_tip, Color(0.2, 0.85, 1.0, 0.8), 2.0, true)
	
	# 5. Inner Ring: Quantum Flux Accelerator (Counter-Clockwise Rotation)
	var inner_band_pts = PackedVector2Array()
	for i in range(segs):
		var ang = (float(i) / segs) * TAU
		inner_band_pts.append(pos + Vector2(cos(ang) * 120.0, sin(ang) * 36.0))
	for i in range(segs - 1, -1, -1):
		var ang = (float(i) / segs) * TAU
		inner_band_pts.append(pos + Vector2(cos(ang) * 94.0, sin(ang) * 28.0))
	cradle_node.draw_colored_polygon(inner_band_pts, Color(0.09, 0.07, 0.03, 0.92))
	
	var inner_rim_out = PackedVector2Array()
	var inner_rim_in = PackedVector2Array()
	for i in range(segs + 1):
		var ang = (float(i % segs) / segs) * TAU
		inner_rim_out.append(pos + Vector2(cos(ang) * 120.0, sin(ang) * 36.0))
		inner_rim_in.append(pos + Vector2(cos(ang) * 94.0, sin(ang) * 28.0))
	cradle_node.draw_polyline(inner_rim_out, Color(1.0, 0.82, 0.25, 0.95), 2.0, true)
	cradle_node.draw_polyline(inner_rim_in, Color(1.0, 0.6, 0.15, 0.65), 1.5, true)
	
	# Inner Ring Spokes (3 spokes rotating counter-clockwise)
	for m in range(3):
		var in_spoke_ang = ang_inner + m * (TAU / 3.0)
		var in_hub_pt = pos + Vector2(cos(in_spoke_ang) * 36.0, sin(in_spoke_ang) * 15.0)
		var in_ring_pt = pos + Vector2(cos(in_spoke_ang) * 94.0, sin(in_spoke_ang) * 28.0)
		cradle_node.draw_line(in_hub_pt, in_ring_pt, Color(1.0, 0.75, 0.2, 0.55), 1.8, true)
	
	# Inner Ring Quantum Flux Nodes (6 high-energy plasma points racing counter-clockwise)
	for m in range(6):
		var flux_ang = ang_inner + m * (TAU / 6.0)
		var flux_pos = pos + Vector2(cos(flux_ang) * 107.0, sin(flux_ang) * 32.0)
		cradle_node.draw_circle(flux_pos, 4.0, Color(1.0, 0.95, 0.55, 0.95))
		cradle_node.draw_arc(flux_pos, 7.0, 0, TAU, 12, Color(1.0, 0.55, 0.15, 0.75), 1.5, true)
	
	# 6. Central Station Core (Command Hub & Singularity Reactor)
	var hub_pts = PackedVector2Array()
	for i in range(8):
		var ang = (float(i) / 8.0) * TAU
		hub_pts.append(pos + Vector2(cos(ang) * 44.0, sin(ang) * 18.0))
	cradle_node.draw_colored_polygon(hub_pts, Color(0.04, 0.08, 0.14, 0.98))
	cradle_node.draw_polyline(hub_pts + PackedVector2Array([hub_pts[0]]), Color(0.25, 0.92, 1.0, 0.9), 2.0, true)
	
	var pulse_r = 10.0 + sin(t * 5.0) * 2.5
	cradle_node.draw_circle(pos, pulse_r, Color(0.2, 0.95, 1.0, 0.35))
	cradle_node.draw_circle(pos, 5.0, Color.WHITE)
	
	# Sensor Spire & Warning Beacon
	cradle_node.draw_line(pos + Vector2(0, -18), pos + Vector2(0, -42), Color(0.8, 0.9, 1.0, 0.85), 2.0, true)
	cradle_node.draw_line(pos + Vector2(-10, -34), pos + Vector2(10, -34), Color(0.3, 0.9, 1.0, 0.8), 1.5, true)
	var beacon_lit = fmod(t, 0.8) < 0.4
	cradle_node.draw_circle(pos + Vector2(0, -42), 3.0, Color(1.0, 0.25, 0.2, 1.0) if beacon_lit else Color(0.4, 0.1, 0.1, 0.6))
	
	# 7. Ventral Docking Pylons (Tractor Emitters)
	for pylon_x in [pos.x - 110, pos.x + 110]:
		var pylon_base = Vector2(pylon_x, pos.y + 20)
		var pylon_tip = Vector2(pylon_x, pos.y + 34)
		cradle_node.draw_line(pylon_base, pylon_tip, Color(0.2, 0.6, 0.8, 0.9), 3.0, true)
		cradle_node.draw_circle(pylon_tip, 8.0, Color(0.06, 0.12, 0.2, 1.0))
		cradle_node.draw_arc(pylon_tip, 8.0, 0, TAU, 16, Color(1.0, 0.85, 0.25, 0.9), 1.8, true)
		cradle_node.draw_circle(pylon_tip, 4.0, Color(0.2, 0.95, 1.0, 0.95) if tractor_beam_active else Color(1.0, 0.4, 0.2, 0.8))
