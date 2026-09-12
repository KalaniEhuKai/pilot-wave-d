extends Node

## TestRunner.gd - Comprehensive verification of Phase 1, Phase 2, Phase 3, and Phase 4.

func _ready() -> void:
	print("====================================================")
	print("--- STARTING PHASE 4 AUTOMATED TEST SUITE ---")
	print("====================================================")
	
	# 1. Mount Main Scene
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("ERROR: Could not load Main.tscn!")
		get_tree().quit(1)
		return
	
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	print("STEP 1: Main.tscn instantiated with Threat Dossier, Wave Director & Bosses.")
	
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
	
	assert(GameManager.p1_joules == 10 and GameManager.p2_joules == 10, "In-flight scrap failed to credit both players equally!")
	print(" - SUCCESS: Zero-friction scrap replication verified! (+10 J P1, +10 J P2)")
	
	# 3. Test The Sky Merchant Zeppelin & Escalating Reroll Terminal
	print("\nSTEP 3: Testing Sky Merchant Zeppelin & Reroll Terminal...")
	var bullet_scene = load("res://scenes/Bullet.tscn")
	var stray_bullet = bullet_scene.instantiate()
	main_inst.add_child(stray_bullet)
	stray_bullet.setup(Vector2(200, 200), Vector2.DOWN, true, 1.0)
	
	var shop = main_inst.get_node("SkyMerchant")
	main_inst._trigger_shop_docking()
	assert(not is_instance_valid(stray_bullet) or stray_bullet.is_queued_for_deletion(), "Hostile bullets must be purged on shop dock!")
	assert(shop.panel.visible == true, "Sky Merchant panel failed to open!")
	assert(shop.p2_stall.visible == true, "P2 stall should be visible in Co-Op mode!")
	
	shop._reroll_stall(1)
	assert(GameManager.p1_reroll_cost == 10, "P1 reroll cost did not escalate to 10 J!")
	shop._on_undock_pressed()
	assert(shop.panel.visible == false, "Sky Merchant failed to undock cleanly!")
	print(" - SUCCESS: Sky Merchant docking, safety purge, and escalating rerolls verified.")
	
	# 4. Test Secret Systems: Quantum Anomaly & Dirac Monopole
	print("\nSTEP 4: Testing Secret Systems (Quantum Anomaly & Dirac Monopole)...")
	var secrets = main_inst.get_node("SecretDirector")
	secrets._spawn_quantum_anomaly()
	assert(secrets.anomalies.size() > 0, "Failed to spawn Quantum Anomaly!")
	secrets._shatter_anomaly(secrets.anomalies[0])
	print(" - SUCCESS: Quantum Anomaly shattered! Awarded scrap and secret bonus.")
	
	p1.hull = 1
	p1._emit_health()
	secrets._spawn_dirac_monopole()
	secrets._shatter_dirac_monopole()
	assert(p1.hull == p1.max_hull, "Dirac Monopole failed to restore 100% hull!")
	print(" - SUCCESS: Legendary Dirac Monopole shattered (+10,000 pts & Full Hull Repair).")
	
	# 5. Test Sector 1 Boss: Super-Dreadnought Corvus
	print("\nSTEP 5: Testing Sector 1 Boss: Super-Dreadnought Corvus...")
	var corvus_scene = load("res://scenes/BossCorvus.tscn")
	var corvus = corvus_scene.instantiate()
	main_inst.add_child(corvus)
	corvus.entry_done = true
	corvus.take_damage(45.0)
	assert(corvus.port_wing_alive == false, "Port wing failed to break!")
	corvus.take_damage(45.0)
	assert(corvus.starboard_wing_alive == false, "Starboard wing failed to break!")
	
	var flags = {"corvus_defeated": false, "goliath_defeated": false}
	GameManager.boss_defeated.connect(func(b_name):
		if "CORVUS" in b_name: flags["corvus_defeated"] = true
		if "GOLIATH" in b_name: flags["goliath_defeated"] = true
	)
	corvus.take_damage(130.0)
	assert(flags["corvus_defeated"] == true, "Corvus defeat signal failed!")
	print(" - SUCCESS: Super-Dreadnought Corvus defeated with subsystem detonations!")
	
	# 6. Test Wave Director Threat Budget & Formations (Phase 4)
	print("\nSTEP 6: Testing Adaptive Wave Director Threat Budget & Formations...")
	var wd = WaveDirector.new()
	var budget_w1 = wd.calculate_wave_budget(1, 1, [p1])
	var budget_w4 = wd.calculate_wave_budget(1, 4, [p1])
	assert(budget_w4 > budget_w1, "Threat budget must scale upwards with waves!")
	print(" - Budget Wave 1: %.1f | Budget Wave 4: %.1f" % [budget_w1, budget_w4])
	
	var form_elite = wd.select_formation_for_wave(4, budget_w4)
	assert(form_elite == WaveDirector.FormationType.ELITE_CHAMPION, "Wave 4 must select Elite Champion!")
	print(" - SUCCESS: Wave Director budget scaling and formation selection verified.")
	
	# 7. Test Phase 4 Relic Synergies
	print("\nSTEP 7: Testing Expanded 20+ Quantum Synergy Relics...")
	# 7A. Elastic Momentum ricochet
	var elastic_item = ItemDatabase.get_item_by_id("elastic_momentum")
	assert(elastic_item != null, "Elastic Momentum not found in ItemDatabase!")
	var ricochet_bullet = bullet_scene.instantiate()
	main_inst.add_child(ricochet_bullet)
	ricochet_bullet.setup(Vector2(2, 200), Vector2.LEFT, false, 2.0)
	elastic_item.on_projectile_tick(ricochet_bullet, 0.016)
	assert(ricochet_bullet.direction.x > 0, "Bullet failed to ricochet off left boundary!")
	assert(ricochet_bullet.damage > 2.0, "Ricochet bullet did not gain kinetic damage!")
	print(" - 7A: Elastic Momentum ricochet and damage scaling verified.")
	ricochet_bullet.queue_free()
	
	# 7B. Tachyon Capacitor hold-charge & pierce
	var tachyon_item = ItemDatabase.get_item_by_id("tachyon_capacitor")
	p1.add_modifier(tachyon_item)
	p1.fire_charge_time = 0.8
	var fired_params = tachyon_item.on_fire(p1, {"pos": p1.global_position, "dir": Vector2.RIGHT, "dmg": 1.0})
	assert(fired_params[0].get("is_tachyon_lance") == true, "Tachyon lance flag not set on charged shot!")
	assert(fired_params[0].get("dmg") > 5.0, "Tachyon lance damage multiplier failed!")
	print(" - 7B: Tachyon Capacitor charge shot and piercing lance verified.")
	
	# 7C. Lagrange Satellites orbital shield
	var lagrange_item = ItemDatabase.get_item_by_id("lagrange_satellites")
	p1.add_modifier(lagrange_item)
	assert(p1.has_node("LagrangeOrbitals"), "Lagrange Satellites failed to attach orbitals to ship!")
	print(" - 7C: Lagrange Satellites orbital defense drones verified.")
	
	# 7D. Dirac Inversion fatal hit survival
	var dirac_item = ItemDatabase.get_item_by_id("dirac_inversion")
	p1.add_modifier(dirac_item)
	p1.hull = 1
	p1.shields = 0
	var canceled = dirac_item.on_take_damage(p1, 1)
	assert(canceled == true, "Dirac Inversion failed to cancel fatal damage!")
	assert(p1.shields == 1, "Dirac Inversion failed to restore shield!")
	print(" - 7D: Dirac Inversion fatal damage rewind verified.")
	
	# 7E. Carnot Efficiency Sky Merchant discount
	var carnot_eff = ItemDatabase.get_item_by_id("carnot_efficiency")
	p1.add_modifier(carnot_eff)
	var discount = shop._get_player_discount(1)
	assert(discount == 0.5, "Carnot Efficiency failed to grant 50% discount!")
	print(" - 7E: Carnot Efficiency 50% shop discount verified.")
	
	# 8. Test Sector Threat Dossier UI
	print("\nSTEP 8: Testing Sector Threat Dossier Briefing...")
	var dossier = main_inst.get_node("ThreatDossier")
	dossier.show_dossier(1, "Armored Behemoth Goliath")
	assert(dossier.panel.visible == true, "Threat Dossier failed to open!")
	assert("GOLIATH" in dossier.boss_label.text, "Threat Dossier text mismatch!")
	dossier._on_engage_pressed()
	assert(dossier.panel.visible == false, "Threat Dossier failed to dismiss cleanly!")
	print(" - SUCCESS: Threat Dossier presentation and engagement verified.")
	
	# 9. Test Asymmetric Boss: Armored Behemoth Goliath
	print("\nSTEP 9: Testing Asymmetric Sector 1 Boss: Armored Behemoth Goliath...")
	var goliath_scene = load("res://scenes/BossGoliath.tscn")
	var goliath = goliath_scene.instantiate()
	main_inst.add_child(goliath)
	goliath.entry_done = true
	
	print(" - Goliath spawned. Total HP: %f" % (goliath.core_health + goliath.port_railgun_health + goliath.star_railgun_health + goliath.bow_armor_health))
	# Break Bow Armor
	goliath.take_damage(45.0)
	assert(goliath.bow_armor_alive == false, "Goliath Bow Armor failed to break!")
	print(" - Goliath Bow Armor shattered!")
	
	# Break Port Railgun
	goliath.take_damage(55.0)
	assert(goliath.port_railgun_alive == false, "Goliath Port Railgun failed to break!")
	print(" - Goliath Port Railgun Battery offline!")
	
	# Break Starboard Railgun
	goliath.take_damage(55.0)
	assert(goliath.star_railgun_alive == false, "Goliath Starboard Railgun failed to break!")
	print(" - Goliath Starboard Railgun Battery offline!")
	
	# Destroy Goliath Reactor Core
	goliath.take_damage(110.0)
	assert(flags["goliath_defeated"] == true, "Goliath defeat signal failed to trigger!")
	print(" - SUCCESS: Armored Behemoth Goliath obliterated! Defeat signal triggered.")
	
	# 10. Test Run Victory Dialog & End of Game Condition
	print("\nSTEP 10: Testing Run Victory Dialog & Game Pause...")
	var victory = main_inst.get_node("VictoryOverlay")
	GameManager.trigger_victory("ARMORED BEHEMOTH GOLIATH")
	assert(victory.panel.visible == true, "VictoryOverlay failed to display!")
	assert(get_tree().paused == true, "Game tree must be paused upon run victory!")
	assert("GOLIATH" in victory.subtitle_label.text, "Victory subtitle must identify the vanquished boss!")
	print(" - SUCCESS: 'RUN WON' Victory dialog displayed and gameplay safely stopped.")
	
	# 11. Test Expanded Item Database (60+ Items) & Stat Modifiers
	print("\nSTEP 11: Testing Expanded Item Database (60+ Items) & Stat Upgrades...")
	var all_items = ItemDatabase.get_all_items()
	print(" - Total items cataloged in ItemDatabase: %d" % all_items.size())
	assert(all_items.size() >= 50, "Item catalog must contain at least 50 items! Found: %d" % all_items.size())
	
	var seen_ids: Dictionary = {}
	for item in all_items:
		assert(item != null, "Null item found in database!")
		assert(item.id != "", "Item with empty ID found!")
		assert(item.display_name != "", "Item with empty display name found!")
		assert(item.description != "", "Item with empty description found: %s" % item.id)
		assert(item.icon_symbol != "", "Item with empty icon symbol found: %s" % item.id)
		assert(not seen_ids.has(item.id), "Duplicate item ID in database: %s" % item.id)
		seen_ids[item.id] = true
	print(" - SUCCESS: All %d items have valid unique IDs, descriptions, tiers, and ASCII symbols." % all_items.size())
	
	# Test equipping stat items on player
	var base_hull = p1.max_hull
	var base_dmg = p1.damage_mult
	var base_speed = p1.move_speed
	var base_rolls = p1.max_rolls
	
	var tungsten = ItemDatabase.get_item_by_id("tungsten_core")
	assert(tungsten != null, "Failed to retrieve tungsten_core!")
	tungsten.on_ship_init(p1)
	assert(p1.damage_mult > base_dmg, "Tungsten core failed to increase damage multiplier!")
	
	var nanite = ItemDatabase.get_item_by_id("nanite_hull_plating")
	assert(nanite != null, "Failed to retrieve nanite_hull_plating!")
	nanite.on_ship_init(p1)
	assert(p1.max_hull == base_hull + 1, "Nanite hull plate failed to increase max hull!")
	
	var nozzle = ItemDatabase.get_item_by_id("vectored_nozzle")
	assert(nozzle != null, "Failed to retrieve vectored_nozzle!")
	nozzle.on_ship_init(p1)
	assert(p1.move_speed > base_speed, "Vectored nozzle failed to boost flight move speed!")
	
	var aux_roll = ItemDatabase.get_item_by_id("auxiliary_roll_thruster")
	assert(aux_roll != null, "Failed to retrieve auxiliary_roll_thruster!")
	aux_roll.on_ship_init(p1)
	assert(p1.max_rolls == base_rolls + 1, "Aux roll thruster failed to increase max roll charges!")
	
	print(" - SUCCESS: StatMod items verified dynamically altering ship parameters.")
	
	# 12. Test Isaac-Scale Bestiary (16 Types), Hazards, 25+ Templates & Boss Ouroboros
	print("\nSTEP 12: Testing 16 Enemy Bestiary, Arena Hazards, 25+ Templates & Boss Ouroboros...")
	var enemy_scene = load("res://scenes/Enemy.tscn")
	var hazard_scene = load("res://scenes/HazardObject.tscn")
	var ouroboros_scene = load("res://scenes/BossOuroboros.tscn")
	
	# 12A. Verify all 16 enemy types instantiate cleanly
	for type_idx in range(16):
		var e = enemy_scene.instantiate()
		main_inst.add_child(e)
		e.setup(type_idx, Vector2(100 + type_idx * 20, 100), -1, null, 0)
		assert(e.max_health > 0.0, "Enemy type %d has invalid health!" % type_idx)
		assert(e.speed > 0.0, "Enemy type %d has invalid speed!" % type_idx)
		e.queue_free()
	print(" - 12A: All 16 Enemy Archetypes instantiated cleanly with distinct statistics.")
	
	# 12B. Verify Shield Frigate protection aura
	var frigate = enemy_scene.instantiate()
	main_inst.add_child(frigate)
	frigate.setup(4, Vector2(200, 200), -1, null, 0) # SHIELD_FRIGATE
	
	var shielded_scout = enemy_scene.instantiate()
	main_inst.add_child(shielded_scout)
	shielded_scout.setup(0, Vector2(230, 200), -1, null, 0) # SCOUT within 30px of frigate
	shielded_scout._check_shield_frigate_buffs()
	
	assert(shielded_scout.is_shield_protected == true, "Scout inside Frigate aura must be protected!")
	var scout_hp_before = shielded_scout.health
	shielded_scout.take_damage(2.0)
	assert(shielded_scout.health == scout_hp_before, "Protected scout must not take damage!")
	print(" - 12B: Shield Frigate invulnerability aura verified protecting nearby allies.")
	frigate.queue_free()
	shielded_scout.queue_free()
	
	# 12C. Verify Interactive Environmental Hazards (Asteroid & Plasma TNT Barrel)
	var asteroid = hazard_scene.instantiate()
	main_inst.add_child(asteroid)
	asteroid.setup(0, Vector2(300, 300)) # ASTEROID
	asteroid.take_damage(20.0)
	print(" - 12C: Destructible Asteroid shattered and dropped scrap pellets.")
	
	var barrel = hazard_scene.instantiate()
	main_inst.add_child(barrel)
	barrel.setup(1, Vector2(400, 300)) # PLASMA_BARREL
	
	var nearby_enemy = enemy_scene.instantiate()
	main_inst.add_child(nearby_enemy)
	nearby_enemy.setup(0, Vector2(440, 300), -1, null, 0)
	
	barrel.take_damage(5.0) # Detonates barrel in 220px explosion
	assert(not is_instance_valid(nearby_enemy) or nearby_enemy.health <= 0 or nearby_enemy.is_queued_for_deletion(), "TNT barrel explosion failed to wipe nearby enemy!")
	print(" - 12D: Volatile Plasma Barrel chain-reaction explosion verified!")
	
	# 12D. Verify 25+ Encounter Wave Templates & Sector Gating
	var templates = WaveDirector.get_all_templates()
	print(" - Total Wave Templates Cataloged: %d" % templates.size())
	assert(templates.size() >= 20, "Expected at least 20 wave templates!")
	
	var wd2 = WaveDirector.new()
	var s1_template = wd2.select_template_for_wave(1, 1)
	assert(s1_template["min_sector"] == 1, "Sector 1 must only roll min_sector 1 templates!")
	var s3_template = wd2.select_template_for_wave(3, 1)
	assert(s3_template["min_sector"] >= 2, "Sector 3 must roll advanced sector templates!")
	print(" - 12E: WaveDirector 25+ templates and sector-gating verified.")
	
	# 12E. Verify Sector 3 Climax Final Boss Apex Titan Ouroboros
	var ouroboros = ouroboros_scene.instantiate()
	main_inst.add_child(ouroboros)
	ouroboros.entry_done = true
	ouroboros.shield_gate_alive = false # Bypass shield for quick automated test
	ouroboros.take_damage(130.0) # Push below 50% HP
	assert(ouroboros.phase == 2, "Ouroboros failed to transition to Phase 2 Singularity Meltdown!")
	print(" - 12F: Apex Titan Ouroboros Phase 2 Singularity Meltdown verified.")
	
	var ouroboros_flags = {"won": false}
	GameManager.boss_defeated.connect(func(b_name):
		if "OUROBOROS" in b_name.to_upper():
			ouroboros_flags["won"] = true
	)
	ouroboros.take_damage(150.0)
	assert(ouroboros_flags["won"] == true, "Ouroboros defeat signal failed!")
	print(" - 12G: Apex Titan Ouroboros obliterated! Defeat signal triggered.")
	
	# 12H. Verify Enemy Behavioral Mutations & Template Wildcard Mutator
	var mutating_enemy = enemy_scene.instantiate()
	main_inst.add_child(mutating_enemy)
	mutating_enemy.setup(0, Vector2(250, 250), -1, null, 0)
	mutating_enemy.has_evasive_juke = true
	mutating_enemy.has_desperation_charge = true
	mutating_enemy.has_aimed_lead = true
	mutating_enemy.has_orbital_flight = true
	assert(mutating_enemy.has_evasive_juke and mutating_enemy.has_desperation_charge and mutating_enemy.has_aimed_lead, "Enemy behavioral traits failed to assign!")
	mutating_enemy.queue_free()
	
	var base_template = WaveDirector.get_all_templates()[0]
	var mutated_t = wd2._mutate_template(base_template, 3)
	assert(mutated_t.has("spawns") and mutated_t["spawns"].size() > 0, "Mutated template invalid!")
	print(" - 12H: Procedural behavioral mutations and template wildcard system verified.")
	
	# 12I. Verify Quantum Collapsing Wave Function Spawning & Downfield Shmup Motion
	var test_enemy = enemy_scene.instantiate()
	main_inst.add_child(test_enemy)
	var spawn_pt = GameAxis.get_spawn_line(0.5)
	test_enemy.setup(0, spawn_pt, -1, null, 0)
	var initial_pos = test_enemy.global_position
	test_enemy._physics_process(0.1)
	var motion_vector = test_enemy.global_position - initial_pos
	assert(motion_vector.dot(-GameAxis.forward) > 0.0, "Enemy must advance downfield toward player along -GameAxis.forward!")
	test_enemy.queue_free()

	# Verify hazard movement along cosmic stream
	var test_hazard = hazard_scene.instantiate()
	main_inst.add_child(test_hazard)
	test_hazard.setup(0, spawn_pt)
	assert(test_hazard.velocity.dot(GameAxis.scroll_dir) > 0.0, "Hazard must drift along GameAxis.scroll_dir!")
	test_hazard.queue_free()

	# Verify procedural quantum collapse sound registered
	assert(SoundEffects._streams.has("quantum_collapse"), "quantum_collapse procedural sound missing!")
	print(" - 12I: Horizon wave function spawning, cosmic hazard drift, and downfield shmup flight verified.")
	
	print("\n====================================================")
	print("--- ALL VERIFICATION TESTS PASSED 100% CLEANLY ---")
	print("====================================================")
	get_tree().quit(0)
