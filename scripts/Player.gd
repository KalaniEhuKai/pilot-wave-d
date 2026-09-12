extends CharacterBody2D

## Player.gd - Dual-Platform Arcade Flight Model with Co-Op Player 1 / Player 2 Support.

signal health_changed(hull: int, shields: int, max_hull: int, max_shields: int)
signal roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float)
signal modifiers_updated(modifiers: Array[ItemModifier])

@export var player_id: int = 1 # 1 = P1 (Cyan), 2 = P2 (Amber/Gold)

@export var max_hull: int = 4
var hull: int = 4

@export var max_shields: int = 2
var shields: int = 2

var shield_recharge_delay: float = 4.0
var shield_timer: float = 0.0

@export var move_speed: float = 420.0
var current_velocity: Vector2 = Vector2.ZERO

# 1942 Barrel Roll / Quantum Tunneling
@export var max_rolls: int = 3
var rolls: int = 3
var roll_cooldown: float = 3.2
var roll_timer: float = 0.0
var is_rolling: bool = false
var roll_duration: float = 0.7
var roll_elapsed: float = 0.0
var is_invulnerable: bool = false

# Synchrotron Cannon
var fire_rate: float = 3.8
var fire_timer: float = 0.0
var is_firing: bool = false
var auto_fire: bool = false

# Active Roguelite Item Modifiers
var active_modifiers: Array[ItemModifier] = []
var scrap_magnet_radius: float = 130.0

# Visuals & Juice
var bank_angle: float = 0.0
var hit_flash_timer: float = 0.0
var meissner_fx_timer: float = 0.0

# Inter-Wave Quantum Warp & Shard Vacuum Pulse
var warp_charge_ratio: float = 0.0
var warp_charge_timer: float = 0.0
var warp_charge_duration: float = 0.0
var is_warping: bool = false
var warp_leap_timer: float = 0.0
var warp_leap_duration: float = 0.35
var warp_start_pos: Vector2 = Vector2.ZERO
var warp_target_pos: Vector2 = Vector2.ZERO
var vacuum_pulse_active: bool = false
var vacuum_pulse_timer: float = 0.0
var warp_sfx_timer: float = 0.0

# Colors based on player_id
var primary_color: Color = Color(0.1, 0.9, 1.0, 1.0)
var accent_color: Color = Color(0.4, 1.0, 0.9, 1.0)
var thruster_color: Color = Color(0.0, 0.7, 1.0, 0.9)

# Preloaded scenes
var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")

# Synergy state flags
var fire_charge_time: float = 0.0
var has_tachyon_capacitor: bool = false
var has_carnot_heatsink: bool = false
var has_carnot_efficiency: bool = false

# Combat stat scaling & Additive Bonus Pools
var damage_mult: float = 1.0
var bullet_speed_mult: float = 1.0
var bullet_scale: float = 1.0
var crit_chance: float = 0.0
var crit_mult: float = 2.0
var extra_spread_shots: int = 0
var bonus_scrap_val: int = 0
var scrap_bonus_chance: float = 0.0
var elite_bounty_bonus: int = 0
var has_singularity_recovery: bool = false
var wave_dividend_joules: int = 0

# Base ship characteristics (chassis starter values)
var base_max_hull: int = 4
var base_max_shields: int = 2
var base_max_rolls: int = 3
var base_move_speed: float = 420.0
var base_fire_rate: float = 3.8
var base_roll_cooldown: float = 3.2
var base_shield_delay: float = 4.0
var base_scrap_magnet_radius: float = 130.0

# Additive linear stat pools (prevents runaway compounding)
var bonus_damage_pct: float = 0.0
var bonus_fire_rate_pct: float = 0.0
var bonus_move_speed_pct: float = 0.0
var bonus_bullet_speed_pct: float = 0.0
var bonus_bullet_scale_pct: float = 0.0
var bonus_roll_cdr_pct: float = 0.0
var bonus_shield_delay_reduction_pct: float = 0.0
var bonus_max_hull: int = 0
var bonus_max_shields: int = 0
var bonus_max_rolls: int = 0
var bonus_magnet_radius: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_setup_player_identity()
	base_max_hull = max_hull
	base_max_shields = max_shields
	base_max_rolls = max_rolls
	base_move_speed = move_speed
	base_fire_rate = fire_rate
	base_roll_cooldown = roll_cooldown
	base_shield_delay = shield_recharge_delay
	base_scrap_magnet_radius = scrap_magnet_radius
	hull = max_hull
	shields = max_shields
	rolls = max_rolls
	_emit_health()
	_emit_rolls()
	GameAxis.axis_changed.connect(_on_axis_changed)

func recalculate_stats() -> void:
	max_hull = maxi(1, base_max_hull + bonus_max_hull)
	max_shields = maxi(0, base_max_shields + bonus_max_shields)
	max_rolls = maxi(1, base_max_rolls + bonus_max_rolls)
	
	hull = mini(max_hull, hull)
	shields = mini(max_shields, shields)
	rolls = mini(max_rolls, rolls)
	
	fire_rate = base_fire_rate * maxf(0.25, 1.0 + bonus_fire_rate_pct)
	damage_mult = maxf(0.1, 1.0 + bonus_damage_pct)
	move_speed = base_move_speed * maxf(0.3, 1.0 + bonus_move_speed_pct)
	bullet_speed_mult = maxf(0.2, 1.0 + bonus_bullet_speed_pct)
	bullet_scale = maxf(0.2, 1.0 + bonus_bullet_scale_pct)
	roll_cooldown = base_roll_cooldown * maxf(0.3, 1.0 - bonus_roll_cdr_pct)
	shield_recharge_delay = base_shield_delay * maxf(0.3, 1.0 - bonus_shield_delay_reduction_pct)
	scrap_magnet_radius = base_scrap_magnet_radius + bonus_magnet_radius

func get_modifier_stack_count(mod_id: String) -> int:
	var count = 0
	for m in active_modifiers:
		if m.id == mod_id:
			count += 1
	return count

func _setup_player_identity() -> void:
	if player_id == 2:
		# Player 2 is high-visibility Amber / Solar Gold
		primary_color = Color(1.0, 0.75, 0.15, 1.0)
		accent_color = Color(1.0, 0.9, 0.4, 1.0)
		thruster_color = Color(1.0, 0.45, 0.1, 0.9)
	else:
		# Player 1 is Electric Cyan / Cherenkov Blue
		primary_color = Color(0.1, 0.9, 1.0, 1.0)
		accent_color = Color(0.4, 1.0, 0.9, 1.0)
		thruster_color = Color(0.0, 0.7, 1.0, 0.9)

func add_modifier(mod: ItemModifier) -> void:
	if not mod:
		return
	active_modifiers.append(mod)
	mod.on_ship_init(self)
	modifiers_updated.emit(active_modifiers)
	GameManager.player_modifiers_updated.emit(active_modifiers, player_id)
	SoundEffects.play_sfx("bonus", 0.05, 4.0)
	GameManager.request_screen_shake(5.0, 0.2)

func has_modifier(id: String) -> bool:
	for m in active_modifiers:
		if m.id == id:
			return true
	return false

func set_scrap_magnet_radius(r: float) -> void:
	scrap_magnet_radius = r

func trigger_wave_start_hooks(wave_idx: int) -> void:
	for m in active_modifiers:
		m.on_wave_start(self, wave_idx)

func trigger_wave_cleared_hooks(wave_idx: int) -> void:
	for m in active_modifiers:
		if m.has_method("on_wave_cleared"):
			m.on_wave_cleared(self, wave_idx)
	if wave_dividend_joules > 0:
		GameManager.add_joules(wave_dividend_joules)
		GameManager.add_score(wave_dividend_joules * 2)
		SoundEffects.play_sfx("bonus", 0.05, 3.0)

func trigger_kill_hooks(victim: Node2D, pos: Vector2) -> void:
	for m in active_modifiers:
		m.on_kill(self, victim, pos)

func spawn_meissner_fx() -> void:
	meissner_fx_timer = 0.28
	queue_redraw()

func start_quantum_charge(duration: float = 5.0) -> void:
	warp_charge_duration = duration
	warp_charge_timer = duration
	warp_charge_ratio = 0.0
	warp_sfx_timer = 0.0
	SoundEffects.play_sfx("warp_charge", 0.05, -3.0)

func activate_vacuum_pulse(duration: float = 1.4) -> void:
	vacuum_pulse_active = true
	vacuum_pulse_timer = duration
	scrap_magnet_radius = maxf(scrap_magnet_radius, 780.0)
	SoundEffects.play_sfx("bonus", 0.08, 1.0)

func trigger_quantum_jump(duration: float = 0.35) -> void:
	is_warping = true
	warp_leap_timer = duration
	warp_leap_duration = duration
	is_invulnerable = true
	warp_start_pos = global_position
	
	# Determine destination: Left-middle of screen (or bottom-middle in vertical mode)
	var vp = get_viewport_rect().size
	if GameAxis.is_vertical:
		var x_ratio = 0.42 if (player_id == 1 and GameManager.is_coop_mode) else (0.58 if player_id == 2 else 0.5)
		warp_target_pos = Vector2(vp.x * x_ratio, vp.y * 0.75)
	else:
		var y_ratio = 0.42 if (player_id == 1 and GameManager.is_coop_mode) else (0.58 if player_id == 2 else 0.5)
		warp_target_pos = Vector2(vp.x * 0.18, vp.y * y_ratio)
	
	SoundEffects.play_sfx("quantum_jump", 0.06, 2.5)
	GameManager.request_screen_shake(8.0, 0.25)

func reset_warp_state() -> void:
	warp_charge_ratio = 0.0
	warp_charge_timer = 0.0
	is_warping = false
	is_invulnerable = false
	vacuum_pulse_active = false
	vacuum_pulse_timer = 0.0
	warp_start_pos = Vector2.ZERO
	warp_target_pos = Vector2.ZERO
	recalculate_stats()

func _on_axis_changed(_is_vertical: bool) -> void:
	global_position = GameAxis.clamp_position(global_position, 40.0)

func _emit_health() -> void:
	health_changed.emit(hull, shields, max_hull, max_shields)
	GameManager.player_health_changed.emit(hull, shields, max_hull, max_shields, player_id)

func recharge_shields_full() -> void:
	shields = max_shields
	_emit_health()
	queue_redraw()

func _emit_rolls() -> void:
	var ratio = 0.0
	if rolls < max_rolls:
		ratio = clampf(roll_timer / roll_cooldown, 0.0, 1.0)
	roll_charges_changed.emit(rolls, max_rolls, ratio)
	GameManager.player_roll_charges_changed.emit(rolls, max_rolls, ratio, player_id)

func _unhandled_input(event: InputEvent) -> void:
	if player_id == 1:
		if event is InputEventScreenDrag:
			global_position += event.relative
			global_position = GameAxis.clamp_position(global_position, 32.0)
		elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and OS.has_feature("mobile"):
			global_position += event.relative
			global_position = GameAxis.clamp_position(global_position, 32.0)

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	
	_handle_timers(delta)
	_handle_movement(delta)
	_handle_shooting(delta)
	_handle_barrel_roll(delta)
	
	global_position = GameAxis.clamp_position(global_position, 32.0)
	queue_redraw()

func _handle_timers(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
	if meissner_fx_timer > 0.0:
		meissner_fx_timer -= delta
	
	if shields < max_shields:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shields += 1
			shield_timer = shield_recharge_delay
			_emit_health()
			SoundEffects.play_sfx("bonus", 0.05, -6.0)
	
	if rolls < max_rolls:
		roll_timer += delta
		if roll_timer >= roll_cooldown:
			rolls += 1
			roll_timer = 0.0
			_emit_rolls()
		else:
			_emit_rolls()
	
	if warp_charge_timer > 0.0:
		warp_charge_timer -= delta
		warp_charge_ratio = 1.0 - clampf(warp_charge_timer / maxf(0.001, warp_charge_duration), 0.0, 1.0)
		warp_sfx_timer -= delta
		if warp_sfx_timer <= 0.0 and warp_charge_timer > 0.15:
			# Accelerating audio spin-up cycle
			warp_sfx_timer = lerpf(0.55, 0.10, warp_charge_ratio)
			var pitch = lerpf(-4.0, 4.0, warp_charge_ratio)
			SoundEffects.play_sfx("warp_charge", 0.04 + warp_charge_ratio * 0.06, pitch)
	
	if vacuum_pulse_timer > 0.0:
		vacuum_pulse_timer -= delta
		if vacuum_pulse_timer <= 0.0:
			vacuum_pulse_active = false
			recalculate_stats()
	
	if is_warping:
		warp_leap_timer -= delta
		var warp_prog = 1.0 - clampf(warp_leap_timer / maxf(0.001, warp_leap_duration), 0.0, 1.0)
		# Smooth quintic ease-in-out (Perlin smootherstep) for snappy, relativistic jump
		var ease_prog = warp_prog * warp_prog * warp_prog * (warp_prog * (warp_prog * 6.0 - 15.0) + 10.0)
		global_position = warp_start_pos.lerp(warp_target_pos, ease_prog)
		
		if warp_leap_timer <= 0.0:
			global_position = warp_target_pos
			reset_warp_state()
			spawn_meissner_fx()
			SoundEffects.play_sfx("bonus", 0.05, 4.0)

func _handle_movement(delta: float) -> void:
	var input_vec = Vector2.ZERO
	if player_id == 2:
		input_vec.x = Input.get_axis("p2_move_left", "p2_move_right")
		input_vec.y = Input.get_axis("p2_move_up", "p2_move_down")
	else:
		input_vec.x = Input.get_axis("move_left", "move_right")
		input_vec.y = Input.get_axis("move_up", "move_down")
	
	if input_vec.length_squared() > 1.0:
		input_vec = input_vec.normalized()
	
	var target_vel = input_vec * move_speed
	var lerp_weight = 1.0 - exp(-delta / 0.04)
	current_velocity = current_velocity.lerp(target_vel, lerp_weight)
	global_position += current_velocity * delta
	
	var lateral_input = input_vec.dot(GameAxis.lateral)
	bank_angle = lerpf(bank_angle, lateral_input * 0.28, 1.0 - exp(-delta / 0.06))

func _handle_shooting(delta: float) -> void:
	fire_timer -= delta
	var fire_action = "p2_fire" if player_id == 2 else "fire"
	is_firing = Input.is_action_pressed(fire_action) or auto_fire
	
	if is_firing:
		fire_charge_time += delta
	else:
		if has_tachyon_capacitor:
			fire_charge_time = minf(fire_charge_time + delta * 1.5, 0.8)
		else:
			fire_charge_time = 0.0
	
	var effective_rate = fire_rate
	if has_carnot_heatsink and shields <= 0:
		effective_rate *= 2.0
	
	if is_firing and fire_timer <= 0.0 and not is_rolling:
		fire_timer = 1.0 / effective_rate
		_fire_synchrotron()

func _fire_synchrotron() -> void:
	var fwd = GameAxis.forward
	var lat = GameAxis.lateral
	var m1 = global_position + fwd * 20.0 + lat * 12.0
	var m2 = global_position + fwd * 20.0 - lat * 12.0
	
	var base_params_1 = {"pos": m1, "dir": fwd, "damage": 1.0}
	var base_params_2 = {"pos": m2, "dir": fwd, "damage": 1.0}
	
	var spawn_list: Array[Dictionary] = [base_params_1, base_params_2]
	
	# Extra spread shot pairs if unlocked
	if extra_spread_shots > 0:
		for i in range(1, extra_spread_shots + 1):
			var angle = deg_to_rad(8.0 * i)
			var d_left = fwd.rotated(-angle)
			var d_right = fwd.rotated(angle)
			spawn_list.append({"pos": m1, "dir": d_left, "damage": 0.85})
			spawn_list.append({"pos": m2, "dir": d_right, "damage": 0.85})
	
	for mod in active_modifiers:
		var new_list: Array[Dictionary] = []
		for p in spawn_list:
			var results = mod.on_fire(self, p)
			new_list.append_array(results)
		spawn_list = new_list
	
	if has_meta("tachyon_discharged") and get_meta("tachyon_discharged"):
		set_meta("tachyon_discharged", false)
		fire_charge_time = 0.0
	
	for sp in spawn_list:
		var dmg = sp.get("damage", sp.get("dmg", 1.0)) * damage_mult
		if crit_chance > 0.0 and randf() < crit_chance:
			dmg *= crit_mult
			sp["is_crit"] = true
		sp["damage"] = dmg
		_spawn_bullet_from_params(sp)
	
	SoundEffects.play_sfx("laser", 0.08, -6.0)

func _spawn_bullet_from_params(params: Dictionary) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(params.get("pos", global_position), params.get("dir", GameAxis.forward), false, params.get("damage", 1.0))
	
	if bullet_speed_mult != 1.0:
		b.speed *= bullet_speed_mult
	
	if bullet_scale != 1.0:
		b.scale *= bullet_scale
	
	if player_id == 2:
		# P2 bullets have amber tint
		b.glow_color = Color(1.0, 0.7, 0.2, 0.9)
	
	if params.has("is_crit") and params["is_crit"]:
		b.glow_color = Color(1.0, 0.95, 0.2, 1.0)
		b.scale *= 1.25
	
	if params.has("is_suspended") and params["is_suspended"]:
		b.is_suspended = true
		b.suspension_ship = self
	
	if params.has("is_tachyon_lance") and params["is_tachyon_lance"]:
		b.scale = Vector2(2.5, 1.4)
		b.glow_color = Color(1.0, 0.2, 0.4, 1.0)
		b.set_meta("pierce_count", 999)
	
	if params.has("pierce_count"):
		b.set_meta("pierce_count", params["pierce_count"])
	
	if params.has("is_spectral") and params["is_spectral"]:
		b.modulate = Color(0.7, 0.4, 1.0, 0.75)

func _handle_barrel_roll(delta: float) -> void:
	var roll_action = "p2_barrel_roll" if player_id == 2 else "barrel_roll"
	if Input.is_action_just_pressed(roll_action) and not is_rolling and rolls > 0:
		_start_barrel_roll()
	
	if is_rolling:
		roll_elapsed += delta
		var progress = clampf(roll_elapsed / roll_duration, 0.0, 1.0)
		rotation = GameAxis.ship_base_rotation + (progress * TAU)
		var squash = 1.0 + sin(progress * PI) * 0.4
		scale = Vector2(squash, 2.0 - squash)
		
		if roll_elapsed >= roll_duration:
			_end_barrel_roll()
	else:
		rotation = GameAxis.ship_base_rotation + bank_angle
		scale = Vector2.ONE

func _start_barrel_roll() -> void:
	if rolls <= 0 or is_rolling:
		return
	is_rolling = true
	is_invulnerable = true
	roll_elapsed = 0.0
	rolls -= 1
	_emit_rolls()
	for m in active_modifiers:
		m.on_roll(self)
	SoundEffects.play_sfx("roll", 0.05, 1.0)
	GameManager.request_screen_shake(4.0, 0.2)

func _end_barrel_roll() -> void:
	is_rolling = false
	is_invulnerable = false
	rotation = GameAxis.ship_base_rotation
	scale = Vector2.ONE

func take_damage(amount: int = 1) -> void:
	if is_invulnerable or is_rolling or GameManager.is_game_over:
		return
	
	for mod in active_modifiers:
		if mod.on_take_damage(self, amount):
			return
	
	hit_flash_timer = 0.12
	
	if shields > 0:
		shields = maxi(0, shields - amount)
		shield_timer = shield_recharge_delay
		SoundEffects.play_sfx("hit", 0.1, 3.0)
		GameManager.request_screen_shake(6.0, 0.2)
	else:
		hull = maxi(0, hull - amount)
		SoundEffects.play_sfx("hurt", 0.1, 4.0)
		GameManager.request_screen_shake(12.0, 0.35)
		
		if hull <= 0:
			_die()
			return
	
	_emit_health()

func _die() -> void:
	var exp_node = explosion_scene.instantiate()
	get_parent().add_child(exp_node)
	exp_node.global_position = global_position
	exp_node.max_radius = 80.0
	exp_node.duration = 0.6
	
	# Check if companion alive in co-op mode
	var remaining_players = 0
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p != self and not p.is_queued_for_deletion() and p.hull > 0:
			remaining_players += 1
	
	if remaining_players == 0:
		GameManager.trigger_game_over()
	queue_free()

func _draw() -> void:
	var draw_col = primary_color
	var core_col = accent_color
	var flame_col = thruster_color
	
	if hit_flash_timer > 0.0:
		draw_col = Color.WHITE
		core_col = Color(1.0, 0.8, 0.8, 1.0)
	elif is_rolling:
		draw_col = Color(0.3, 1.0, 0.6, 1.0)
		core_col = Color(0.8, 1.0, 0.9, 1.0)
	
	var nose = Vector2(26, 0)
	var wing_left = Vector2(-16, -20)
	var wing_right = Vector2(-16, 20)
	var wing_in_l = Vector2(-8, -10)
	var wing_in_r = Vector2(-8, 10)
	var tail = Vector2(-22, 0)
	
	var hull_poly = PackedVector2Array([
		nose, Vector2(6, -8), wing_left, Vector2(-14, -14),
		wing_in_l, Vector2(-18, -6), tail, Vector2(-18, 6),
		wing_in_r, Vector2(-14, 14), wing_right, Vector2(6, 8)
	])
	
	draw_colored_polygon(hull_poly, Color(0.06, 0.12, 0.2, 0.95))
	draw_polyline(hull_poly + PackedVector2Array([nose]), draw_col, 2.4, true)
	
	var canopy = PackedVector2Array([Vector2(14, 0), Vector2(2, -4), Vector2(-8, 0), Vector2(2, 4)])
	draw_colored_polygon(canopy, core_col)
	draw_polyline(canopy + PackedVector2Array([Vector2(14, 0)]), Color(1, 1, 1, 0.9), 1.5, true)
	
	var flame_len = randf_range(12.0, 24.0)
	if is_rolling:
		flame_len *= 1.8
	
	var engine_l = Vector2(-18, -6)
	var engine_r = Vector2(-18, 6)
	draw_line(engine_l, engine_l - Vector2(flame_len, 0), flame_col, 4.0, true)
	draw_line(engine_l, engine_l - Vector2(flame_len * 0.6, 0), Color.WHITE, 2.0, true)
	draw_line(engine_r, engine_r - Vector2(flame_len, 0), flame_col, 4.0, true)
	draw_line(engine_r, engine_r - Vector2(flame_len * 0.6, 0), Color.WHITE, 2.0, true)
	
	if shields > 0:
		var shield_alpha = 0.25 + (float(shields) / max_shields) * 0.25
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, Color(draw_col.r, draw_col.g, draw_col.b, shield_alpha), 2.0, true)
	
	if meissner_fx_timer > 0.0:
		var m_alpha = meissner_fx_timer / 0.28
		draw_arc(Vector2.ZERO, 38.0, 0, TAU, 32, Color(0.2, 1.0, 0.6, m_alpha), 3.5, true)
	
	# Quantum Vacuum Pulse (expanding concentric magnetic rings)
	if vacuum_pulse_active:
		var vac_t = fmod(Time.get_ticks_msec() / 450.0, 1.0)
		var vac_r1 = lerpf(25.0, 120.0, vac_t)
		var vac_r2 = lerpf(25.0, 120.0, fmod(vac_t + 0.5, 1.0))
		draw_arc(Vector2.ZERO, vac_r1, 0, TAU, 32, Color(0.2, 0.9, 1.0, (1.0 - vac_t) * 0.7), 2.2, true)
		draw_arc(Vector2.ZERO, vac_r2, 0, TAU, 32, Color(1.0, 0.85, 0.2, (1.0 - fmod(vac_t + 0.5, 1.0)) * 0.55), 1.6, true)
	
	# Inter-Wave Quantum Warp Charge (Spin-up matter wave harmonics)
	if warp_charge_ratio > 0.0:
		var t_sec = Time.get_ticks_msec() * 0.001
		# Exponential spin-up acceleration
		var spin_speed = lerpf(2.5, 18.0, warp_charge_ratio * warp_charge_ratio)
		var spin_ang = t_sec * spin_speed
		
		# Orbiting quantum phase particles accelerating around the ship
		for i in range(4):
			var o_ang = spin_ang + i * (TAU / 4.0)
			var o_dist = lerpf(54.0, 22.0, warp_charge_ratio)
			var o_pos = Vector2(cos(o_ang), sin(o_ang)) * o_dist
			draw_circle(o_pos, 3.0, Color.WHITE)
			draw_arc(o_pos, 6.0, 0, TAU, 12, Color(0.2, 0.95, 1.0, warp_charge_ratio * 0.9), 1.5, true)
		
		# Converging matter wave arcs
		for i in range(3):
			var phase = fmod(t_sec * 2.5 + float(i) / 3.0, 1.0)
			var r = lerpf(68.0, 16.0, phase)
			var arc_col = Color(0.2, 0.95, 1.0, (1.0 - phase) * warp_charge_ratio * 0.9) if i % 2 == 0 else Color(0.9, 0.35, 1.0, (1.0 - phase) * warp_charge_ratio * 0.8)
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, arc_col, 2.0 + warp_charge_ratio * 2.0, true)
		
		# Inward quantum particle converging vectors
		for i in range(6):
			var ang = (float(i) / 6.0) * TAU + spin_ang * 0.3
			var s_dir = Vector2(cos(ang), sin(ang))
			var s_dist = lerpf(75.0, 20.0, warp_charge_ratio)
			draw_line(s_dir * s_dist, s_dir * (s_dist - 8.0), Color(1.0, 1.0, 1.0, warp_charge_ratio * 0.95), 2.0)
	
	# Relativistic Warp Jump Speed Streaks
	if is_warping:
		var warp_prog = 1.0 - clampf(warp_leap_timer / maxf(0.001, warp_leap_duration), 0.0, 1.0)
		var streak_len = sin(warp_prog * PI) * 140.0
		var move_dir = (warp_target_pos - warp_start_pos).normalized()
		if move_dir == Vector2.ZERO:
			move_dir = GameAxis.forward
		var trail_vec = -move_dir * streak_len
		for off_lat in [-14.0, -7.0, 0.0, 7.0, 14.0]:
			var s_start = GameAxis.lateral * off_lat
			var s_end = s_start + trail_vec * (0.8 + randf() * 0.4)
			draw_line(s_start, s_end, Color(0.2, 0.95, 1.0, 0.85), 3.4, true)
			draw_line(s_start, s_start + trail_vec * 0.5, Color.WHITE, 2.0, true)
		# Quantum teleport distortion ring expanding
		draw_arc(Vector2.ZERO, 32.0 + sin(warp_prog * PI) * 28.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.9), 2.5, true)

func get_estimated_dps() -> float:
	var shots_per_sec = fire_rate
	# Ship fires dual parallel synchrotron cannons (2.0 base projectiles).
	# Each extra spread shot adds a pair of angled bolts at 0.85 damage (1.7 equivalent).
	var projectiles_per_shot = 2.0 + float(extra_spread_shots) * 1.7
	var avg_crit_factor = 1.0 + crit_chance * (crit_mult - 1.0)
	var est = shots_per_sec * projectiles_per_shot * damage_mult * avg_crit_factor
	
	# Bespoke offensive item modifiers
	var mod_factor = 1.0
	if has_tachyon_capacitor:
		# Tachyon lance triggers every ~0.8s, dealing 5.5x damage on that shot
		# Average damage boost across fire cycle is ~+45%
		mod_factor += 0.45
	if has_modifier("heisenberg_lens"):
		# 25% chance of 2.5x damage spike (+37.5% expected value)
		mod_factor += 0.375
	if has_modifier("zeeman_splitting"):
		# Twin rear counter-bolts (2 x 0.6 = +1.2 relative damage)
		mod_factor += 0.30
	
	return est * mod_factor

func get_relic_counts_by_tier() -> Dictionary:
	var counts = {
		ItemModifier.ItemTier.TIER_1_BALLISTIC: 0,
		ItemModifier.ItemTier.TIER_2_PARADIGM: 0,
		ItemModifier.ItemTier.TIER_3_EXOTIC: 0,
		"total": active_modifiers.size()
	}
	for mod in active_modifiers:
		if counts.has(mod.tier):
			counts[mod.tier] += 1
	return counts
