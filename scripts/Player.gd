extends CharacterBody2D

## Player.gd - Responsive arcade flight model with 1942 Barrel Roll and Modular Synergy Pipeline.

signal health_changed(hull: int, shields: int, max_hull: int, max_shields: int)
signal roll_charges_changed(charges: int, max_charges: int, cooldown_ratio: float)
signal modifiers_updated(modifiers: Array[ItemModifier])

@export var max_hull: int = 4
var hull: int = 4

@export var max_shields: int = 2
var shields: int = 2

var shield_recharge_delay: float = 4.0
var shield_timer: float = 0.0

@export var move_speed: float = 540.0
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
var fire_rate: float = 9.0 # shots per second
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

# Preloaded scenes
var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/Explosion.tscn")

func _ready() -> void:
	add_to_group("player")
	hull = max_hull
	shields = max_shields
	rolls = max_rolls
	_emit_health()
	_emit_rolls()
	GameAxis.axis_changed.connect(_on_axis_changed)

func add_modifier(mod: ItemModifier) -> void:
	if not mod:
		return
	active_modifiers.append(mod)
	mod.on_ship_init(self)
	modifiers_updated.emit(active_modifiers)
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

func spawn_meissner_fx() -> void:
	meissner_fx_timer = 0.28
	queue_redraw()

func _on_axis_changed(_is_vertical: bool) -> void:
	global_position = GameAxis.clamp_position(global_position, 40.0)

func _emit_health() -> void:
	health_changed.emit(hull, shields, max_hull, max_shields)
	GameManager.player_health_changed.emit(hull, shields, max_hull, max_shields)

func _emit_rolls() -> void:
	var ratio = 0.0
	if rolls < max_rolls:
		ratio = clampf(roll_timer / roll_cooldown, 0.0, 1.0)
	roll_charges_changed.emit(rolls, max_rolls, ratio)

func _unhandled_input(event: InputEvent) -> void:
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

func _handle_movement(delta: float) -> void:
	var input_vec = Vector2.ZERO
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
	is_firing = Input.is_action_pressed("fire") or auto_fire
	
	if is_firing and fire_timer <= 0.0 and not is_rolling:
		fire_timer = 1.0 / fire_rate
		_fire_synchrotron()

func _fire_synchrotron() -> void:
	var fwd = GameAxis.forward
	var lat = GameAxis.lateral
	var m1 = global_position + fwd * 20.0 + lat * 12.0
	var m2 = global_position + fwd * 20.0 - lat * 12.0
	
	var base_params_1 = {"pos": m1, "dir": fwd, "damage": 1.0}
	var base_params_2 = {"pos": m2, "dir": fwd, "damage": 1.0}
	
	var spawn_list: Array[Dictionary] = [base_params_1, base_params_2]
	
	# Apply on_fire synergy hooks
	for mod in active_modifiers:
		var new_list: Array[Dictionary] = []
		for p in spawn_list:
			var results = mod.on_fire(self, p)
			new_list.append_array(results)
		spawn_list = new_list
	
	# Spawn all modified projectiles
	for sp in spawn_list:
		_spawn_bullet_from_params(sp)
	
	SoundEffects.play_sfx("laser", 0.08, -6.0)

func _spawn_bullet_from_params(params: Dictionary) -> void:
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.setup(params.get("pos", global_position), params.get("dir", GameAxis.forward), false, params.get("damage", 1.0))
	
	if params.has("is_suspended") and params["is_suspended"]:
		b.is_suspended = true
		b.suspension_ship = self

func _handle_barrel_roll(delta: float) -> void:
	if Input.is_action_just_pressed("barrel_roll") and not is_rolling and rolls > 0:
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
	
	# Check modifier damage cancel hooks (e.g. Meissner Shield)
	for mod in active_modifiers:
		if mod.on_take_damage(self, amount):
			return # Negated by relic!
	
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
	GameManager.trigger_game_over()
	queue_free()

func _draw() -> void:
	var main_color = Color(0.1, 0.9, 1.0, 1.0)
	var accent_color = Color(0.4, 1.0, 0.9, 1.0)
	var thruster_color = Color(0.0, 0.7, 1.0, 0.9)
	
	if hit_flash_timer > 0.0:
		main_color = Color(1.0, 1.0, 1.0, 1.0)
		accent_color = Color(1.0, 0.8, 0.8, 1.0)
	elif is_rolling:
		main_color = Color(0.3, 1.0, 0.6, 1.0)
		accent_color = Color(0.8, 1.0, 0.9, 1.0)
	
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
	draw_polyline(hull_poly + PackedVector2Array([nose]), main_color, 2.4, true)
	
	var canopy = PackedVector2Array([Vector2(14, 0), Vector2(2, -4), Vector2(-8, 0), Vector2(2, 4)])
	draw_colored_polygon(canopy, accent_color)
	draw_polyline(canopy + PackedVector2Array([Vector2(14, 0)]), Color(1, 1, 1, 0.9), 1.5, true)
	
	var flame_len = randf_range(12.0, 24.0)
	if is_rolling:
		flame_len *= 1.8
	
	var engine_l = Vector2(-18, -6)
	var engine_r = Vector2(-18, 6)
	draw_line(engine_l, engine_l - Vector2(flame_len, 0), thruster_color, 4.0, true)
	draw_line(engine_l, engine_l - Vector2(flame_len * 0.6, 0), Color.WHITE, 2.0, true)
	draw_line(engine_r, engine_r - Vector2(flame_len, 0), thruster_color, 4.0, true)
	draw_line(engine_r, engine_r - Vector2(flame_len * 0.6, 0), Color.WHITE, 2.0, true)
	
	if shields > 0:
		var shield_alpha = 0.25 + (float(shields) / max_shields) * 0.25
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, Color(0.15, 0.8, 1.0, shield_alpha), 2.0, true)
	
	# Meissner Superconducting barrier pulse
	if meissner_fx_timer > 0.0:
		var m_alpha = meissner_fx_timer / 0.28
		draw_arc(Vector2.ZERO, 38.0, 0, TAU, 32, Color(0.2, 1.0, 0.6, m_alpha), 3.5, true)
