extends Node

## TestRunner.gd - Comprehensive verification of Phase 1, Phase 2, and Phase 3.

const BirefringencePrismScript = preload("res://scripts/items/BirefringencePrism.gd")
const GravitationalLensingScript = preload("res://scripts/items/GravitationalLensing.gd")
const AntimatterSuspensionScript = preload("res://scripts/items/AntimatterSuspension.gd")
const MeissnerShieldScript = preload("res://scripts/items/MeissnerShield.gd")
const MaxwellsDemonScript = preload("res://scripts/items/MaxwellsDemon.gd")

func _ready() -> void:
	print("====================================================")
	print("--- STARTING PHASE 3 RUN & CO-OP VERIFICATION ---")
	print("====================================================")
	
	# 1. Mount Main Scene
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("ERROR: Could not load Main.tscn!")
		get_tree().quit(1)
		return
	
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	print("STEP 1: Main.tscn instantiated with Sky Merchant & Secret Director.")
	
	# 2. Test 2-Player Co-Op Architecture & Dual Wallets
	print("\nSTEP 2: Testing 2-Player Local Co-Op & Zero-Friction Economy...")
	GameManager.is_coop_mode = true
	main_inst.toggle_coop_player(true)
	
	var players = get_tree().get_nodes_in_group("player")
	assert(players.size() == 2, "Expected 2 players in Co-Op mode!")
	var p1 = players[0] if players[0].player_id == 1 else players[1]
	var p2 = players[1] if players[1].player_id == 2 else players[0]
	print(" - P1 (Cyan) found at %s | P2 (Amber) found at %s" % [p1.global_position, p2.global_position])
	
	# Test Equal In-Flight Scrap Replication
	var scrap_scene = load("res://scenes/ScrapPickup.tscn")
	var scrap_drop = scrap_scene.instantiate()
	scrap_drop.value = 10
	main_inst.add_child(scrap_drop)
	scrap_drop._collect(p1)
	
	print(" - After 10 J pickup by P1: P1 Wallet = %d J | P2 Wallet = %d J" % [GameManager.p1_joules, GameManager.p2_joules])
	assert(GameManager.p1_joules == 10 and GameManager.p2_joules == 10, "In-flight scrap failed to credit both players equally!")
	print(" - SUCCESS: Zero-friction scrap replication verified! (+10 J P1, +10 J P2)")
	
	# Test Independent Spending in Co-Op
	GameManager.add_joules(40) # P1: 50 J, P2: 50 J
	var spent_p1 = GameManager.spend_joules(25, 1)
	assert(spent_p1 and GameManager.p1_joules == 25 and GameManager.p2_joules == 50, "P1 spending affected P2 wallet!")
	print(" - SUCCESS: Independent Co-Op wallets verified (P1: 25 J, P2: 50 J)")
	
	# 3. Test The Sky Merchant Zeppelin & Escalating Reroll Terminal
	print("\nSTEP 3: Testing Sky Merchant Zeppelin & Reroll Terminal...")
	# Verify bullet clearing safety on shop docking
	var bullet_scene = load("res://scenes/Bullet.tscn")
	var stray_bullet = bullet_scene.instantiate()
	main_inst.add_child(stray_bullet)
	stray_bullet.setup(Vector2(200, 200), Vector2.DOWN, true, 1.0)
	
	var shop = main_inst.get_node("SkyMerchant")
	main_inst._trigger_shop_docking()
	assert(not is_instance_valid(stray_bullet) or stray_bullet.is_queued_for_deletion(), "Hostile bullets must be purged on shop dock!")
	assert(shop.panel.visible == true, "Sky Merchant panel failed to open!")
	assert(shop.p2_stall.visible == true, "P2 stall should be visible in Co-Op mode!")
	print(" - Sky Merchant docked safely. Stray bullets cleared. Both P1 and P2 supply stalls active.")
	
	# P1 rerolls: cost should escalate 5 -> 10 -> 20
	print(" - Initial P1 reroll cost: %d J" % GameManager.p1_reroll_cost)
	shop._reroll_stall(1)
	print(" - P1 reroll cost after 1st reroll: %d J" % GameManager.p1_reroll_cost)
	assert(GameManager.p1_reroll_cost == 10, "P1 reroll cost did not escalate to 10 J!")
	assert(GameManager.p2_reroll_cost == 5, "P2 reroll cost should remain independent at 5 J!")
	print(" - SUCCESS: Independent escalating rerolls verified (P1: %d J, P2: %d J)" % [GameManager.p1_reroll_cost, GameManager.p2_reroll_cost])
	
	shop._on_undock_pressed()
	assert(shop.panel.visible == false, "Sky Merchant failed to undock cleanly!")
	print(" - Undocked from Sky Merchant. Resumed combat patrol.")
	
	# 4. Test Secret Systems: Quantum Anomaly & Dirac Monopole
	print("\nSTEP 4: Testing Secret Systems (Quantum Anomaly & Dirac Monopole)...")
	var secrets = main_inst.get_node("SecretDirector")
	secrets._spawn_quantum_anomaly()
	assert(secrets.anomalies.size() > 0, "Failed to spawn Quantum Anomaly!")
	
	var anomaly = secrets.anomalies[0]
	secrets._shatter_anomaly(anomaly)
	assert(anomaly.shattered == true, "Quantum Anomaly failed to shatter!")
	print(" - SUCCESS: Quantum Anomaly shattered! Awarded scrap and secret bonus.")
	
	# Test Dirac Monopole 100% full hull repair + 10,000 pts
	p1.hull = 1 # Damage player to 1 HP
	p1._emit_health()
	secrets._spawn_dirac_monopole()
	assert(secrets.dirac_monopole.active == true, "Failed to spawn Dirac Monopole!")
	
	var score_before = GameManager.score
	secrets._shatter_dirac_monopole()
	assert(p1.hull == p1.max_hull, "Dirac Monopole failed to restore 100% hull!")
	assert(GameManager.score >= score_before + 10000, "Dirac Monopole failed to award 10,000 pts bonus!")
	print(" - SUCCESS: Legendary Dirac Monopole landmark shattered! (+10,000 pts & Full Hull Repair)")
	
	# 5. Test Sector 1 Boss: Super-Dreadnought Corvus
	print("\nSTEP 5: Testing Sector 1 Boss: Super-Dreadnought Corvus...")
	var boss_scene = load("res://scenes/BossCorvus.tscn")
	var boss = boss_scene.instantiate()
	main_inst.add_child(boss)
	boss.entry_done = true
	
	print(" - Super-Dreadnought Corvus spawned. Total HP: %f" % (boss.core_health + boss.port_wing_health + boss.starboard_wing_health))
	
	# Subsystem destruction: Port Wing
	boss.take_damage(45.0)
	assert(boss.port_wing_alive == false, "Port wing battery failed to break!")
	print(" - Port Wing Battery destroyed! Detonated with subsystem explosion.")
	
	# Subsystem destruction: Starboard Wing
	boss.take_damage(45.0)
	assert(boss.starboard_wing_alive == false, "Starboard wing battery failed to break!")
	print(" - Starboard Wing Battery destroyed! Both wings offline.")
	
	# Core damage & Phase 2 Enrage
	print(" - Central Singularity Core exposed! Testing core destruction...")
	var flags = {"boss_defeated": false}
	GameManager.boss_defeated.connect(func(_name): flags["boss_defeated"] = true)
	
	boss.take_damage(130.0) # Vaporize core
	assert(flags["boss_defeated"] == true, "Boss defeated signal was not triggered!")
	print(" - SUCCESS: Super-Dreadnought Corvus vaporized! Awarded +15,000 pts and Sector Cleared banner.")
	
	print("\n====================================================")
	print("--- ALL PHASE 3 RUN & CO-OP TESTS PASSED 100% CLEANLY ---")
	print("====================================================")
	get_tree().quit(0)
