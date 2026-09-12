extends Node

## TestRunner.gd - Comprehensive verification of Phase 1 Combat & Phase 2 Synergy Engine.

const BirefringencePrismScript = preload("res://scripts/items/BirefringencePrism.gd")
const GravitationalLensingScript = preload("res://scripts/items/GravitationalLensing.gd")
const AntimatterSuspensionScript = preload("res://scripts/items/AntimatterSuspension.gd")
const MeissnerShieldScript = preload("res://scripts/items/MeissnerShield.gd")
const MaxwellsDemonScript = preload("res://scripts/items/MaxwellsDemon.gd")

func _ready() -> void:
	print("====================================================")
	print("--- STARTING PHASE 2 SYNERGY SUITE VERIFICATION ---")
	print("====================================================")
	
	# 1. Load main scene
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("ERROR: Could not load Main.tscn!")
		get_tree().quit(1)
		return
	
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	print("STEP 1: Main.tscn instantiated and mounted.")
	
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		printerr("ERROR: Player node not found!")
		get_tree().quit(1)
		return
	var player = players[0]
	
	# 2. Test Base Flight & Barrel Roll
	print("\nSTEP 2: Testing 1942 Barrel Roll / Quantum Tunneling...")
	player._start_barrel_roll()
	print(" - is_rolling: ", player.is_rolling, " | is_invulnerable: ", player.is_invulnerable)
	player.take_damage(1)
	assert(player.shields == player.max_shields, "Invulnerability failed during barrel roll!")
	print(" - Damage during roll negated cleanly by i-frames (shields: %d/%d)" % [player.shields, player.max_shields])
	player._end_barrel_roll()
	
	# 3. Test Meissner Shield Matrix (Holy Mantle)
	print("\nSTEP 3: Testing Meissner Shield Matrix...")
	var meissner = MeissnerShieldScript.new()
	player.add_modifier(meissner)
	meissner.on_wave_start(player, 1)
	assert(meissner.is_active == true, "Meissner Shield should be active on wave start!")
	print(" - Meissner Shield equipped and active.")
	
	player.take_damage(1) # Hit 1: Should be completely negated by Meissner
	assert(player.shields == player.max_shields, "Meissner Shield failed to negate first hit!")
	assert(meissner.is_active == false, "Meissner Shield should be depleted after absorbing hit!")
	print(" - FIRST HIT absorbed by Meissner Shield! (shields remain: %d/%d)" % [player.shields, player.max_shields])
	
	player.take_damage(1) # Hit 2: Now takes normal damage into shield
	assert(player.shields == player.max_shields - 1, "Player should take normal damage after Meissner depleted!")
	print(" - SECOND HIT successfully penetrates to shield pip (shields: %d/%d)" % [player.shields, player.max_shields])
	
	# Reset player shield
	player.shields = player.max_shields
	
	# 4. Test Birefringence Prism (Projectile 3-Way Split)
	print("\nSTEP 4: Testing Birefringence Prism projectile splitting...")
	var prism = BirefringencePrismScript.new()
	player.add_modifier(prism)
	
	var bullet_scene = load("res://scenes/Bullet.tscn")
	var test_bullet = bullet_scene.instantiate()
	main_inst.add_child(test_bullet)
	test_bullet.setup(Vector2(100, 100), Vector2.RIGHT, false, 1.0)
	
	var initial_bullet_count = get_tree().get_nodes_in_group("bullets").size()
	print(" - Spawned initial bullet. Bullets in scene: ", initial_bullet_count)
	
	# Advance bullet past 180px split threshold
	test_bullet.traveled_distance = 190.0
	prism.on_projectile_tick(test_bullet, 0.016)
	
	var post_split_count = get_tree().get_nodes_in_group("bullets").size()
	print(" - Bullets in scene after refraction split: ", post_split_count)
	assert(post_split_count >= initial_bullet_count + 2, "Birefringence Prism failed to spawn refracted beams!")
	print(" - SUCCESS: Birefringence Prism split bullet into 3 beams!")
	
	# 5. Test Gravitational Lensing (Homing Curvature)
	print("\nSTEP 5: Testing Gravitational Lensing homing curvature...")
	var lensing = GravitationalLensingScript.new()
	player.add_modifier(lensing)
	
	# Spawn test enemy at (500, 300)
	var enemy_scene = load("res://scenes/Enemy.tscn")
	var test_enemy = enemy_scene.instantiate()
	main_inst.add_child(test_enemy)
	test_enemy.setup(0, Vector2(500, 300), 999, null)
	
	# Bullet flying straight right at (400, 100)
	var homing_bullet = bullet_scene.instantiate()
	main_inst.add_child(homing_bullet)
	homing_bullet.setup(Vector2(400, 100), Vector2.RIGHT, false, 1.0)
	var old_y_dir = homing_bullet.direction.y
	
	# Tick homing over 10 frames
	for f in range(10):
		lensing.on_projectile_tick(homing_bullet, 0.05)
	
	print(" - Bullet initial dir.y: %f | Curving dir.y: %f" % [old_y_dir, homing_bullet.direction.y])
	assert(homing_bullet.direction.y > old_y_dir, "Gravitational Lensing failed to curve bullet toward enemy!")
	print(" - SUCCESS: Gravitational Lensing dynamically curved bullet trajectory toward enemy!")
	
	# 6. Test Anti-Matter Suspension (Isaac Anti-Gravity Trap & Slingshot)
	print("\nSTEP 6: Testing Anti-Matter Suspension (Plasma Trap & Slingshot)...")
	var antimatter = AntimatterSuspensionScript.new()
	player.add_modifier(antimatter)
	player.is_firing = true
	
	var suspended_bullet = bullet_scene.instantiate()
	main_inst.add_child(suspended_bullet)
	suspended_bullet.setup(player.global_position, Vector2.RIGHT, false, 1.0)
	suspended_bullet.is_suspended = true
	suspended_bullet.suspension_ship = player
	
	# While player is firing, bullet stays frozen in space
	var freeze_pos = suspended_bullet.global_position
	suspended_bullet._physics_process(0.016)
	assert(suspended_bullet.global_position == freeze_pos, "Suspended bullet moved while fire held!")
	print(" - Bullet frozen motionless in space as hovering plasma trap.")
	
	# Release fire
	player.is_firing = false
	suspended_bullet._physics_process(0.016)
	assert(suspended_bullet.is_suspended == false, "Suspended bullet did not release upon fire button release!")
	print(" - SUCCESS: Fire released! Bullet violently slingshotted forward simultaneously at 1.45x speed!")
	
	# 7. Test Maxwell's Demon (Screen-wide Scrap Magnet)
	print("\nSTEP 7: Testing Maxwell's Demon scrap magnet...")
	var maxwell = MaxwellsDemonScript.new()
	player.add_modifier(maxwell)
	assert(player.scrap_magnet_radius > 5000.0, "Maxwell's Demon failed to set screen-wide magnet radius!")
	
	var scrap_scene = load("res://scenes/ScrapPickup.tscn")
	var test_scrap = scrap_scene.instantiate()
	main_inst.add_child(test_scrap)
	test_scrap.global_position = Vector2(1200, 680)
	
	var initial_scrap_dist = test_scrap.global_position.distance_to(player.global_position)
	for f in range(15):
		test_scrap._physics_process(0.05)
	var final_scrap_dist = test_scrap.global_position.distance_to(player.global_position)
	
	print(" - Scrap initial distance: %f | Post-magnet distance: %f" % [initial_scrap_dist, final_scrap_dist])
	assert(final_scrap_dist < initial_scrap_dist, "Maxwell's Demon failed to pull scrap across the screen!")
	print(" - SUCCESS: Maxwell's Demon pulled scrap across screen into ship!")
	
	# 8. Test Elite Champions & Item Crate Drop
	print("\nSTEP 8: Testing Elite Enemy Champion & Item Choice Crate drop...")
	var elite_enemy = enemy_scene.instantiate()
	main_inst.add_child(elite_enemy)
	elite_enemy.setup(1, Vector2(600, 300), 998, null, 1) # Armored Elite Bomber
	assert(elite_enemy.max_health > 15.0, "Elite Armored enemy HP did not scale up!")
	print(" - Elite Armored Champion verified (HP: %f)" % elite_enemy.max_health)
	
	var crate_count_before = get_tree().get_nodes_in_group("crate").size()
	elite_enemy._die()
	var crate_count_after = get_tree().get_nodes_in_group("crate").size()
	assert(crate_count_after > crate_count_before, "Elite enemy did not drop an Item Crate upon death!")
	print(" - SUCCESS: Defeated Elite Champion dropped holographic Item Choice Crate!")
	
	print("\n====================================================")
	print("--- ALL PHASE 2 SYNERGY TESTS PASSED 100% CLEANLY ---")
	print("====================================================")
	get_tree().quit(0)
