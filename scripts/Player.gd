extends CharacterBody2D

## Player.gd - Dual-Platform Arcade Flight Model with Co-Op Player 1 / Player 2 Support.

signal health_changed(hull: int, shields: int, max_hull: int, max_shields: int)
signal roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float)
signal shield_charges_changed(shields: int, max_shields: int, cooldown_ratio: float)
signal modifiers_updated(modifiers: Array[ItemModifier])
signal weapon_fired(is_left: bool)

var use_3d_model: bool = true

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
var roll_cooldown: float = 9.0
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
var active_projectile_modifiers: Array[ItemModifier] = []
var active_fire_modifiers: Array[ItemModifier] = []
const FIRE_HOOK_ITEM_IDS: Array[String] = [
	"zeeman_splitting", "tachyon_capacitor", "quantum_tunneling",
	"near_field_casimir", "heisenberg_lens", "feynman_propagator",
	"continuous_wave_magnetron", "bell_entanglement", "antimatter_suspension"
]
var scrap_magnet_radius: float = 130.0

# Visuals & Juice
var bank_angle: float = 0.0
var hit_flash_timer: float = 0.0
var hull_hit_flash_timer: float = 0.0
var meissner_fx_timer: float = 0.0
var shield_break_flash_timer: float = 0.0
var shield_reform_timer: float = 0.0
var critical_alarm_timer: float = 0.0
var damage_smoke_accumulator: float = 0.0
var damage_particles: Array[Dictionary] = []
var shield_shards: Array[Dictionary] = []
var hull_sparks: Array[Dictionary] = []
var roll_sparks: Array[Dictionary] = []
var roll_recharge_flash_timer: float = 0.0
var roll_recharge_flash_index: int = -1

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
const ImpactFlashScript = preload("res://scripts/ImpactFlash.gd")
const BulletScript = preload("res://scripts/Bullet.gd")

# Synergy state flags
var fire_charge_time: float = 0.0
var has_tachyon_capacitor: bool = false
var has_carnot_heatsink: bool = false
var has_carnot_precooler: bool = false
var has_carnot_efficiency: bool = false
var has_cw_magnetron: bool = false
var has_casimir_discharge: bool = false

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
var base_roll_cooldown: float = 9.0
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
	_emit_shields()
	_emit_rolls()
	GameAxis.axis_changed.connect(_on_axis_changed)
	
	# Secret Debug Starting Relics / God Build
	if GameManager.debug_give_god_build or not GameManager.debug_starting_relics.is_empty():
		_apply_debug_starting_loadout()

func _apply_debug_starting_loadout() -> void:
	var items = ItemDatabase.get_all_items()
	var item_map = {}
	for it in items:
		item_map[it.id] = it
	
	if GameManager.debug_give_god_build:
		for god_id in ["continuous_wave_magnetron", "casimir_discharge", "feynman_propagator", "target_lock_matrix"]:
			if item_map.has(god_id) and get_modifier_stack_count(god_id) == 0:
				add_modifier(item_map[god_id])
	
	for mod_id in GameManager.debug_starting_relics:
		if item_map.has(mod_id) and get_modifier_stack_count(mod_id) == 0:
			add_modifier(item_map[mod_id])

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
	bullet_scale = maxf(0.2, (1.0 + bonus_bullet_scale_pct) * sqrt(damage_mult))
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
	if mod.id in ["casimir_discharge", "gravitational_lensing", "feynman_propagator", "birefringence_prism"]:
		active_projectile_modifiers.append(mod)
	if mod.id in FIRE_HOOK_ITEM_IDS:
		active_fire_modifiers.append(mod)
	mod.on_ship_init(self)
	modifiers_updated.emit(active_modifiers)
	GameManager.player_modifiers_updated.emit(active_modifiers, player_id)
	if mod.tier == ItemModifier.ItemTier.TIER_3_EXOTIC:
		SoundEffects.play_sfx("bonus", 0.04, 5.0, 1.25)
		GameManager.request_screen_shake(8.0, 0.3)
		var p = get_parent()
		if p:
			var flash = ImpactFlashScript.acquire(p)
			flash.setup(global_position, 55.0, Color(1.0, 0.85, 0.2, 0.95))
	elif mod.tier == ItemModifier.ItemTier.TIER_2_PARADIGM:
		SoundEffects.play_sfx("bonus", 0.05, 4.0, 1.1)
		GameManager.request_screen_shake(5.0, 0.2)
		var p = get_parent()
		if p:
			var flash = ImpactFlashScript.acquire(p)
			flash.setup(global_position, 35.0, Color(1.0, 0.3, 0.7, 0.9))
	else:
		SoundEffects.play_sfx("bonus", 0.05, 3.5, 0.95)
		GameManager.request_screen_shake(4.0, 0.15)

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
	_emit_shields()
	queue_redraw()

func _emit_shields() -> void:
	var ratio = 0.0
	if shields < max_shields and shield_recharge_delay > 0.0:
		ratio = clampf(1.0 - (shield_timer / shield_recharge_delay), 0.0, 1.0)
	shield_charges_changed.emit(shields, max_shields, ratio)
	GameManager.player_shield_charges_changed.emit(shields, max_shields, ratio, player_id)

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
	if hull_hit_flash_timer > 0.0:
		hull_hit_flash_timer -= delta
	if shield_break_flash_timer > 0.0:
		shield_break_flash_timer -= delta
	if shield_reform_timer > 0.0:
		shield_reform_timer -= delta
	if roll_recharge_flash_timer > 0.0:
		roll_recharge_flash_timer -= delta
	if meissner_fx_timer > 0.0:
		meissner_fx_timer -= delta
	
	if shields < max_shields:
		shield_timer -= delta
		if shield_timer <= 0.0:
			var was_zero = (shields == 0)
			shields += 1
			shield_timer = shield_recharge_delay
			_emit_health()
			_emit_shields()
			if was_zero:
				shield_reform_timer = 0.25
				SoundEffects.play_sfx("shield_recharge", 0.05, -3.0)
			else:
				SoundEffects.play_sfx("bonus", 0.05, -6.0)
		else:
			_emit_shields()
	
	if hull <= int(max_hull / 3.0) and hull > 0 and not GameManager.is_game_over:
		critical_alarm_timer -= delta
		if critical_alarm_timer <= 0.0:
			critical_alarm_timer = 2.4
			SoundEffects.play_sfx("low_hull_alarm", 0.02, -8.0)
	
	# Update shield break shards
	var alive_shards: Array[Dictionary] = []
	for s in shield_shards:
		s.pos += s.vel * delta
		s.rot += s.rot_vel * delta
		s.life -= delta
		if s.life > 0.0:
			alive_shards.append(s)
	shield_shards = alive_shards

	# Update hull impact metal sparks
	var alive_sparks: Array[Dictionary] = []
	for sp in hull_sparks:
		sp.pos += sp.vel * delta
		sp.life -= delta
		if sp.life > 0.0:
			alive_sparks.append(sp)
	hull_sparks = alive_sparks

	# Update roll consumption quantum phase sparks
	var alive_roll_sparks: Array[Dictionary] = []
	for rsp in roll_sparks:
		rsp.pos += rsp.vel * delta
		rsp.life -= delta
		if rsp.life > 0.0:
			alive_roll_sparks.append(rsp)
	roll_sparks = alive_roll_sparks

	# Emit and update damage smoke & fire particles
	if hull < max_hull and not GameManager.is_game_over:
		damage_smoke_accumulator += delta
		var is_critical = (hull <= int(max_hull / 3.0))
		var is_heavy = (hull <= int(max_hull / 2.0))
		var spawn_interval = 0.018 if is_critical else (0.038 if is_heavy else 0.075)
		
		if damage_smoke_accumulator >= spawn_interval:
			damage_smoke_accumulator = 0.0
			var rear_dir = -GameAxis.forward if GameAxis != null else Vector2.LEFT
			var lat_dir = GameAxis.lateral if GameAxis != null else Vector2.DOWN
			var offset_pos = rear_dir * 10.0 + lat_dir * randf_range(-10.0, 10.0)
			var smoke_vel = rear_dir * randf_range(40.0, 100.0) + lat_dir * randf_range(-20.0, 20.0)
			damage_particles.append({
				"type": "smoke",
				"pos": offset_pos,
				"vel": smoke_vel,
				"size": randf_range(3.5, 6.5) if not is_critical else randf_range(5.0, 9.0),
				"max_size": randf_range(12.0, 20.0),
				"life": randf_range(0.35, 0.55),
				"max_life": 0.55,
				"color": Color(0.18, 0.20, 0.24, 0.75) if not is_critical else Color(0.08, 0.09, 0.12, 0.9)
			})
			if is_heavy or is_critical:
				damage_particles.append({
					"type": "fire",
					"pos": offset_pos + lat_dir * randf_range(-4.0, 4.0),
					"vel": rear_dir * randf_range(60.0, 130.0) + lat_dir * randf_range(-30.0, 30.0),
					"size": randf_range(2.5, 5.0),
					"max_size": 1.0,
					"life": randf_range(0.14, 0.24),
					"max_life": 0.24,
					"color": Color(1.0, randf_range(0.4, 0.75), 0.1, 0.95)
				})

	var alive_damage_p: Array[Dictionary] = []
	for dp in damage_particles:
		dp.pos += dp.vel * delta
		dp.life -= delta
		if dp.type == "smoke":
			dp.size = lerpf(dp.size, dp.max_size, 1.0 - (dp.life / dp.max_life))
		if dp.life > 0.0:
			alive_damage_p.append(dp)
	damage_particles = alive_damage_p

	
	if GameManager.debug_infinite_rolls:
		if rolls < max_rolls:
			rolls = max_rolls
			roll_timer = 0.0
			_emit_rolls()
	elif rolls < max_rolls:
		roll_timer += delta
		if roll_timer >= roll_cooldown:
			var rep_idx = rolls
			rolls += 1
			roll_timer = 0.0
			roll_recharge_flash_timer = 0.22
			roll_recharge_flash_index = rep_idx
			SoundEffects.play_sfx("roll_recharge", 0.04, -6.0)
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
		if not mod.id in FIRE_HOOK_ITEM_IDS:
			continue
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
	
	weapon_fired.emit(true)
	weapon_fired.emit(false)
	if has_cw_magnetron:
		SoundEffects.play_sfx("laser", 0.08, -10.0, 1.45)
	else:
		SoundEffects.play_sfx("laser", 0.08, -6.0)

func _spawn_bullet_from_params(params: Dictionary) -> void:
	var b = BulletScript.acquire(get_parent(), false)
	b.setup(params.get("pos", global_position), params.get("dir", GameAxis.forward), false, params.get("damage", 1.0))
	
	b.shooter = self
	b.projectile_modifiers = active_projectile_modifiers.duplicate()
	b.set_meta("shooter", self)
	
	if bullet_speed_mult != 1.0:
		b.speed *= bullet_speed_mult
	
	if bullet_scale != 1.0:
		b.scale *= bullet_scale
	
	if player_id == 2:
		# P2 bullets have amber tint
		b.glow_color = Color(1.0, 0.7, 0.2, 0.9)
	
	var is_bullet_crit = params.has("is_crit") and params["is_crit"]
	b.is_crit = is_bullet_crit
	if is_bullet_crit:
		b.glow_color = Color(1.0, 0.95, 0.2, 1.0)
		b.scale *= 1.25
		b.set_meta("is_crit", true)
	
	if params.has("is_cw_dart") and params["is_cw_dart"]:
		b.is_cw_dart = true
		b.set_meta("is_cw_dart", true)
		if not is_bullet_crit and player_id != 2:
			b.glow_color = Color(0.2, 1.0, 0.75, 0.95)
	
	if params.has("is_casimir") and params["is_casimir"]:
		b.is_casimir = true
		b.set_meta("is_casimir", true)
		b.damage *= 2.2
		b.scale *= 1.6
		b.set_meta("casimir_base_damage", b.damage / 2.2)
		b.set_meta("casimir_base_scale", b.scale / 1.6)
		if not is_bullet_crit and player_id != 2:
			b.glow_color = Color(1.0, 0.5, 0.15, 1.0)
	
	if params.has("has_feynman") and params["has_feynman"]:
		b.has_feynman = true
		b.set_meta("has_feynman", true)
	
	if params.has("is_suspended") and params["is_suspended"]:
		b.is_suspended = true
		b.monitorable = false
		b.suspension_ship = self
	
	if params.has("is_tachyon_lance") and params["is_tachyon_lance"]:
		b.scale = Vector2(2.5, 1.4)
		b.glow_color = Color(1.0, 0.2, 0.4, 1.0)
		b.pierce_count = 999
		b.set_meta("pierce_count", 999)
	
	if params.has("pierce_count"):
		b.pierce_count = params["pierce_count"]
		b.set_meta("pierce_count", params["pierce_count"])
	
	var is_spectral_shot = (params.has("is_spectral") and params["is_spectral"]) or (params.has("pierce_count") and params["pierce_count"] > 0 and not params.get("is_tachyon_lance", false))
	if is_spectral_shot:
		b.is_spectral = true
		if not is_bullet_crit and not params.get("is_tachyon_lance", false) and player_id != 2:
			b.glow_color = Color(0.76, 0.34, 1.0, 0.95)
	b.queue_redraw()

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
	_spawn_roll_sparks()
	for m in active_modifiers:
		m.on_roll(self)
	SoundEffects.play_sfx("roll", 0.05, 1.0)
	GameManager.request_screen_shake(4.0, 0.2)

func _spawn_roll_sparks() -> void:
	var count = 8
	for i in range(count):
		var ang = PI + randf_range(-0.35, 0.35)
		var spd = randf_range(40.0, 110.0)
		var s_dir = Vector2(cos(ang), sin(ang))
		roll_sparks.append({
			"pos": s_dir * 32.0,
			"vel": s_dir * spd,
			"size": randf_range(1.5, 2.8),
			"life": randf_range(0.18, 0.30),
			"max_life": 0.30,
			"color": primary_color.lerp(Color.WHITE, 0.55)
		})

func _end_barrel_roll() -> void:
	is_rolling = false
	is_invulnerable = false
	rotation = GameAxis.ship_base_rotation
	scale = Vector2.ONE

func take_damage(amount: int = 1) -> void:
	if is_invulnerable or is_rolling or GameManager.is_game_over or GameManager.debug_god_mode:
		return
	
	for mod in active_modifiers:
		if mod.on_take_damage(self, amount):
			return
	
	hit_flash_timer = 0.12
	
	var imp_dir = -velocity.normalized() if velocity != Vector2.ZERO else (-GameAxis.forward if GameAxis != null else Vector2.LEFT)
	if shields > 0:
		shields = maxi(0, shields - amount)
		shield_timer = shield_recharge_delay
		SoundEffects.play_sfx("shield_hit", 0.08, -3.0)
		if GameManager.has_signal("custom_shake_requested"):
			GameManager.custom_shake_requested.emit(imp_dir, 7.0, 0.16, 55.0)
		else:
			GameManager.request_directional_shake(imp_dir, 7.0, 0.16)
		GameManager.trigger_hit_stop(0.03)
		if shields == 0:
			_trigger_shield_break(imp_dir)
	else:
		hull = maxi(0, hull - amount)
		SoundEffects.play_sfx("hull_hit", 0.08, -2.0)
		if GameManager.has_signal("custom_shake_requested"):
			GameManager.custom_shake_requested.emit(imp_dir, 18.0, 0.38, 28.0)
		else:
			GameManager.request_directional_shake(imp_dir, 18.0, 0.38)
		GameManager.trigger_hit_stop(0.055)
		hull_hit_flash_timer = 0.22
		_spawn_hull_damage_sparks(imp_dir)
		if GameManager.has_signal("player_hull_damaged"):
			GameManager.player_hull_damaged.emit(player_id, hull, max_hull)
		
		if hull <= 0:
			_die()
			return
		elif hull <= int(max_hull / 3.0):
			SoundEffects.play_sfx("low_hull_alarm", 0.02, -2.0)
	
	_emit_health()
	_emit_shields()

func _trigger_shield_break(dir: Vector2) -> void:
	SoundEffects.play_sfx("shield_break", 0.08, -2.0)
	if GameManager.has_signal("player_shield_broken"):
		GameManager.player_shield_broken.emit(player_id)
	shield_break_flash_timer = 0.35
	
	var shard_count = 14
	for i in range(shard_count):
		var ang = (float(i) / float(shard_count)) * TAU + randf_range(-0.15, 0.15)
		var spd = randf_range(110.0, 260.0)
		var s_dir = Vector2(cos(ang), sin(ang))
		shield_shards.append({
			"pos": s_dir * 30.0,
			"vel": s_dir * spd + dir * 50.0,
			"rot": randf() * TAU,
			"rot_vel": randf_range(-14.0, 14.0),
			"radius": randf_range(26.0, 34.0),
			"arc_len": randf_range(0.25, 0.5),
			"life": randf_range(0.32, 0.46),
			"max_life": 0.46,
			"color": primary_color.lerp(Color.WHITE, 0.45)
		})

func _spawn_hull_damage_sparks(dir: Vector2) -> void:
	var count = 12
	for i in range(count):
		var ang = randf() * TAU
		var spd = randf_range(120.0, 310.0)
		var s_vel = (dir.normalized() * 0.4 + Vector2(cos(ang), sin(ang)) * 0.6).normalized() * spd
		hull_sparks.append({
			"pos": Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			"vel": s_vel,
			"size": randf_range(2.0, 4.0),
			"life": randf_range(0.18, 0.32),
			"max_life": 0.32,
			"color": Color(1.0, randf_range(0.5, 0.95), 0.15, 1.0)
		})


	
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
	
	if not use_3d_model:
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
	
	# 1. Damage Smoke and Fire Particles
	for dp in damage_particles:
		var p_t = clampf(dp.life / dp.max_life, 0.0, 1.0)
		var c = dp.color
		c.a *= p_t
		if dp.type == "smoke":
			draw_circle(dp.pos, dp.size, c)
		else:
			draw_circle(dp.pos, dp.size * p_t, c)
			draw_circle(dp.pos, dp.size * p_t * 0.5, Color.WHITE)

	# 2. Hull Impact Metal Sparks
	for sp in hull_sparks:
		var s_t = clampf(sp.life / sp.max_life, 0.0, 1.0)
		var c = sp.color
		c.a *= s_t
		draw_circle(sp.pos, sp.size * s_t, c)
		draw_line(sp.pos, sp.pos - sp.vel * 0.025, c, 1.8)

	# 3. Bursting Shield Shatter Shards
	for sh in shield_shards:
		var sh_t = clampf(sh.life / sh.max_life, 0.0, 1.0)
		var c = sh.color
		c.a *= sh_t
		draw_arc(sh.pos, sh.radius * (1.0 + (1.0 - sh_t) * 0.2), sh.rot, sh.rot + sh.arc_len, 8, c, 2.2 * sh_t, true)
		draw_circle(sh.pos, 2.0 * sh_t, Color(1.0, 1.0, 1.0, sh_t * 0.8))

	# 4. Inward Shield Reform Wave
	if shield_reform_timer > 0.0:
		var rf_prog = 1.0 - (shield_reform_timer / 0.25)
		var cur_r = lerpf(55.0, 30.0, rf_prog)
		draw_arc(Vector2.ZERO, cur_r, 0, TAU, 36, Color(primary_color.r, primary_color.g, primary_color.b, (1.0 - rf_prog) * 0.95), 2.8, true)
		draw_circle(Vector2.ZERO, 3.0, Color.WHITE)

	# 5. Segmented In-Combat Shield Circle
	if shields > 0:
		var shield_base_alpha = 0.35 + (float(shields) / max_shields) * 0.45
		var s_col = Color(draw_col.r, draw_col.g, draw_col.b, shield_base_alpha)
		
		# Full shield extra harmonic overcharge glow
		if shields == max_shields:
			var full_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			var aura_col = Color(accent_color.r, accent_color.g, accent_color.b, 0.22 + full_pulse * 0.28)
			draw_arc(Vector2.ZERO, 34.5, 0, TAU, 40, aura_col, 2.0, true)
		
		if shields == 1:
			# Solid continuous circle for the final remaining shield layer
			draw_arc(Vector2.ZERO, 30.0, 0, TAU, 40, s_col, 2.6, true)
		else:
			# Sliced into 'shields' distinct arc segments rotating slowly
			var seg_count = shields
			var span = TAU / float(seg_count)
			var gap = 0.16 # ~9.2 degrees gap
			var rot_offset = fmod(Time.get_ticks_msec() * 0.0006, TAU)
			for i in range(seg_count):
				var a_start = i * span + gap * 0.5 + rot_offset
				var a_end = (i + 1) * span - gap * 0.5 + rot_offset
				draw_arc(Vector2.ZERO, 30.0, a_start, a_end, 18, s_col, 2.6, true)
	else:
		# Shields are 0: faint intermittent electrical sputtering
		var off_phase = fmod(Time.get_ticks_msec() * 0.001, 1.1)
		if off_phase < 0.09:
			var sp_ang = randf() * TAU
			draw_arc(Vector2.ZERO, 30.0, sp_ang, sp_ang + 0.35, 6, Color(primary_color.r, primary_color.g, primary_color.b, 0.4), 1.6, true)

	# 6. Critical Hull Emergency Distress Beacon Pulse (Under 1/3 health)
	if hull <= int(max_hull / 3.0) and hull > 0 and not GameManager.is_game_over:
		var beacon_t = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012) # ~1.9 Hz strobe pulse
		var beacon_inner = 20.0 + beacon_t * 6.0
		var beacon_col = Color(1.0, 0.15, 0.22, 0.3 + beacon_t * 0.55)
		draw_arc(Vector2.ZERO, beacon_inner, 0, TAU, 32, beacon_col, 2.8, true)
		draw_arc(Vector2.ZERO, beacon_inner + 8.0, 0, TAU, 32, Color(1.0, 0.2, 0.1, beacon_t * 0.35), 1.6, true)
		# Flashing central cockpit distress cross/pip
		draw_circle(Vector2.ZERO, 3.5 * beacon_t, Color(1.0, 0.8, 0.8, beacon_t * 0.9))

	# 7. Intense Hull Damage Flash
	if hull_hit_flash_timer > 0.0:
		var h_t = hull_hit_flash_timer / 0.22
		var flash_col = Color(1.0, 0.25, 0.1, h_t * 0.6)
		draw_circle(Vector2.ZERO, 26.0, flash_col)

	# 8. Roll Consumption Quantum Phase Sparks
	for rsp in roll_sparks:
		var s_t = clampf(rsp.life / rsp.max_life, 0.0, 1.0)
		var c = rsp.color
		c.a *= s_t
		draw_circle(rsp.pos, rsp.size * s_t, c)

	# 9. Compact Aft Quantum Thruster Drive Indicator (Available Rolls & Cooldown)
	var pip_radius = 36.5
	var arc_len = 0.16 # ~9.2 degrees per pip
	var gap = 0.10     # ~5.7 degrees gap
	var step = arc_len + gap
	var span_total = step * float(max_rolls - 1)
	
	# Slipstream glow during active roll
	if is_rolling:
		var roll_half_span = span_total * 0.5 + 0.10
		draw_arc(Vector2.ZERO, pip_radius, PI - roll_half_span, PI + roll_half_span, 14, Color(0.3, 1.0, 0.65, 0.75), 2.4, true)
	
	for i in range(max_rolls):
		var slot_ang = PI + (float(i) - float(max_rolls - 1) * 0.5) * step
		var a_start = slot_ang - arc_len * 0.5
		var a_end = slot_ang + arc_len * 0.5
		
		# Backing slot wireframe (capacity indicator)
		var backing_col = Color(primary_color.r, primary_color.g, primary_color.b, 0.30)
		if rolls == 0:
			var w_t = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			backing_col = Color(1.0, 0.3, 0.2, 0.25 + w_t * 0.25)
		draw_arc(Vector2.ZERO, pip_radius, a_start, a_end, 6, backing_col, 1.8, true)
		
		if i < rolls:
			# Available / Ready charge: Snaps to full brightness vivid cyan/primary with pure white core
			var ready_alpha = 0.90
			if rolls == max_rolls:
				var breath = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005 + i * 0.7)
				ready_alpha = 0.85 + breath * 0.15
			var cell_col = Color(primary_color.r, primary_color.g, primary_color.b, ready_alpha)
			draw_arc(Vector2.ZERO, pip_radius, a_start, a_end, 6, cell_col, 2.2, true)
			draw_arc(Vector2.ZERO, pip_radius, slot_ang - arc_len * 0.28, slot_ang + arc_len * 0.28, 4, Color(1.0, 1.0, 1.0, ready_alpha * 0.95), 1.0, true)
			
			var center_pos = Vector2(cos(slot_ang), sin(slot_ang)) * pip_radius
			draw_circle(center_pos, 1.3, Color.WHITE)
			
			# Recharge completion flash
			if roll_recharge_flash_timer > 0.0 and roll_recharge_flash_index == i:
				var rf = roll_recharge_flash_timer / 0.22
				draw_circle(center_pos, 3.2 * rf, Color(1.0, 1.0, 1.0, rf * 0.95))
				draw_arc(Vector2.ZERO, pip_radius, slot_ang - arc_len * 0.7, slot_ang + arc_len * 0.7, 8, Color.WHITE, 2.8 * rf, true)
		elif i == rolls and rolls < max_rolls:
			# Actively recharging charge: Subdued quantum green with steady flat brightness (no alpha ramp)
			var c_ratio = clampf(roll_timer / roll_cooldown, 0.0, 1.0)
			var fill_end = lerpf(a_start, a_end, c_ratio)
			if fill_end > a_start:
				var charge_col = Color(0.2, 0.88, 0.45, 0.55)
				var charge_core = Color(0.65, 1.0, 0.75, 0.55)
				draw_arc(Vector2.ZERO, pip_radius, a_start, fill_end, 6, charge_col, 2.0, true)
				draw_arc(Vector2.ZERO, pip_radius, a_start, fill_end, 4, charge_core, 1.0, true)
			
			var head_pos = Vector2(cos(fill_end), sin(fill_end)) * pip_radius
			draw_circle(head_pos, 1.3, Color(0.25, 0.92, 0.5, 0.75))
			draw_circle(head_pos, 0.6, Color.WHITE)

	
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
