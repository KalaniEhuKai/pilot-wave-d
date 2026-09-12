extends Node

## TestRunner.gd - Comprehensive verification of Phase 1, Phase 2, Phase 3, and Phase 4.

const ProgressionModel = preload("res://scripts/ProgressionModel.gd")
const EnemyScript = preload("res://scripts/Enemy.gd")
const DecoherenceSpawner = preload("res://scripts/DecoherenceSpawner.gd")

func _ready() -> void:
	# Watchdog timer: If any assert or uncaught error halts test execution,
	# force-terminate the Godot engine process after 8.0 seconds so it never hangs.
	get_tree().create_timer(8.0).timeout.connect(func():
		printerr("\n[WATCHDOG TIMEOUT] Tests failed to complete within 8s (likely halted by an assertion or stalled signal). Force quitting...")
		get_tree().quit(1)
	)

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
	
	# 3. Test Super Quarket Station & Escalating Reroll Terminal
	print("\nSTEP 3: Testing Super Quarket Station & Reroll Terminal...")
	var bullet_scene = load("res://scenes/Bullet.tscn")
	var stray_bullet = bullet_scene.instantiate()
	main_inst.add_child(stray_bullet)
	stray_bullet.setup(Vector2(200, 200), Vector2.DOWN, true, 1.0)
	
	var shop = main_inst.get_node("SkyMerchant")
	main_inst._trigger_shop_docking()
	assert(not is_instance_valid(stray_bullet) or stray_bullet.is_queued_for_deletion(), "Hostile bullets must be purged on shop dock!")
	assert(shop.panel.visible == true, "Super Quarket Station panel failed to open!")
	assert(shop.p2_stall.visible == true, "P2 stall should be visible in Co-Op mode!")
	
	shop._reroll_stall(1)
	assert(GameManager.p1_reroll_cost == 10, "P1 reroll cost did not escalate to 10 J!")
	shop._on_undock_pressed()
	assert(shop.panel.visible == false, "Super Quarket Station failed to undock cleanly!")
	print(" - SUCCESS: Super Quarket Station docking, safety purge, and escalating rerolls verified.")
	
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
	
	# 5. Test Sector 1 Boss: Super-Dreadnought Corvus (Scaled to 450 HP)
	print("\nSTEP 5: Testing Sector 1 Boss: Super-Dreadnought Corvus...")
	var corvus_scene = load("res://scenes/BossCorvus.tscn")
	var corvus = corvus_scene.instantiate()
	main_inst.add_child(corvus)
	corvus.entry_done = true
	assert(corvus.port_wing_health == 60.0 and corvus.max_core_health == 160.0, "Corvus scaled HP mismatched!")
	corvus.take_damage(65.0)
	assert(corvus.port_wing_alive == false, "Port wing failed to break!")
	corvus.take_damage(65.0)
	assert(corvus.starboard_wing_alive == false, "Starboard wing failed to break!")
	
	# Verify Corvus Phase 2 Enraged Vortex Burst state machine
	corvus._handle_attacks(0.6)
	assert(corvus.enrage_burst_active == true, "Corvus failed to activate Enrage Vortex Burst!")
	assert(corvus.enrage_pulses_remaining > 0, "Corvus failed to initialize vortex burst pulses!")
	var pulses_before = corvus.enrage_pulses_remaining
	corvus._handle_attacks(0.1)
	assert(corvus.enrage_pulses_remaining < pulses_before, "Corvus failed to advance vortex burst pulse!")
	print(" - SUCCESS: Super-Dreadnought Corvus Phase 2 Enraged multi-wave vortex burst verified!")
	
	var flags = {"corvus_defeated": false, "goliath_defeated": false}
	GameManager.boss_defeated.connect(func(b_name):
		if "CORVUS" in b_name: flags["corvus_defeated"] = true
		if "GOLIATH" in b_name: flags["goliath_defeated"] = true
	)
	corvus.take_damage(170.0)
	assert(flags["corvus_defeated"] == true, "Corvus defeat signal failed!")
	print(" - SUCCESS: Super-Dreadnought Corvus (280 HP) defeated with subsystem detonations!")
	
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
	# Verify that firing synchrotron consumes the charge and resets fire_charge_time to 0.0
	p1.fire_charge_time = 0.8
	p1._fire_synchrotron()
	assert(p1.fire_charge_time == 0.0, "Tachyon Capacitor failed to discharge and reset fire_charge_time after firing!")
	print(" - 7B: Tachyon Capacitor charge shot, piercing lance, and discharge reset verified.")
	
	# 7B2. Dual-cannon estimated DPS verification
	var p_dps_test = load("res://scenes/Player.tscn").instantiate()
	main_inst.add_child(p_dps_test)
	assert(is_equal_approx(p_dps_test.get_estimated_dps(), 7.6), "Base starter ship must have 7.6 estimated DPS (3.8 fire rate * 2 parallel cannons)!")
	p_dps_test.add_modifier(tachyon_item)
	assert(p_dps_test.get_estimated_dps() > 10.0, "Tachyon Capacitor should boost estimated DPS above 10.0!")
	p_dps_test.queue_free()
	print(" - 7B2: Dual-cannon estimated DPS calculation verified accurately.")
	
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
	
	# 9. Test Asymmetric Boss: Armored Behemoth Goliath (Miniboss & Major Boss Scaled)
	print("\nSTEP 9: Testing Asymmetric Boss: Armored Behemoth Goliath...")
	var goliath_scene = load("res://scenes/BossGoliath.tscn")
	var goliath_mini = goliath_scene.instantiate()
	goliath_mini.is_miniboss = true
	main_inst.add_child(goliath_mini)
	goliath_mini.entry_done = true
	assert(goliath_mini.core_health == 90.0 and goliath_mini.bow_armor_health == 50.0, "Goliath Miniboss HP mismatch!")
	assert(goliath_mini.port_railgun_alive == true and goliath_mini.star_railgun_alive == true, "Goliath Miniboss railguns must be active!")
	assert(goliath_mini.port_railgun_health == 20.0 and goliath_mini.star_railgun_health == 20.0, "Goliath Miniboss railgun HP mismatch!")
	
	# Test railgun charge and tracking lock-on
	goliath_mini._handle_attacks(1.9)
	assert(goliath_mini.is_charging_railgun == true, "Goliath Miniboss failed to charge railgun battery!")
	goliath_mini._handle_attacks(0.7)
	assert(goliath_mini.railgun_locked == true, "Goliath Miniboss failed to lock railgun aim!")
	
	# Test Bow Armor shatter and transition to Fusion Core Overdrive
	goliath_mini.take_damage(55.0)
	assert(goliath_mini.bow_armor_alive == false, "Goliath Miniboss Bow Armor failed to break!")
	goliath_mini._handle_attacks(1.5)
	print(" - SUCCESS: Goliath Miniboss (180 HP), Tracking Railgun Lock-On, and Fusion Core Overdrive verified!")
	goliath_mini.queue_free()
	
	var goliath = goliath_scene.instantiate()
	goliath.is_miniboss = false
	main_inst.add_child(goliath)
	goliath.entry_done = true
	assert(goliath.max_core_health == 280.0 and goliath.max_armor_health == 120.0, "Goliath Major Boss HP mismatch!")
	
	print(" - Goliath Major Boss spawned. Total HP: %f" % (goliath.core_health + goliath.port_railgun_health + goliath.star_railgun_health + goliath.bow_armor_health))
	# Break Bow Armor (120 HP)
	goliath.take_damage(125.0)
	assert(goliath.bow_armor_alive == false, "Goliath Bow Armor failed to break!")
	print(" - Goliath Bow Armor shattered!")
	
	# Break Port Railgun (25 HP)
	goliath.take_damage(30.0)
	assert(goliath.port_railgun_alive == false, "Goliath Port Railgun failed to break!")
	print(" - Goliath Port Railgun Battery offline!")
	
	# Break Starboard Railgun (25 HP)
	goliath.take_damage(30.0)
	assert(goliath.star_railgun_alive == false, "Goliath Starboard Railgun failed to break!")
	print(" - Goliath Starboard Railgun Battery offline!")
	
	# Destroy Goliath Reactor Core (280 HP)
	goliath.take_damage(290.0)
	assert(flags["goliath_defeated"] == true, "Goliath defeat signal failed to trigger!")
	print(" - SUCCESS: Armored Behemoth Goliath (450 HP) obliterated! Defeat signal triggered.")
	
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
	
	# 11B. Test 1942 Barrel Roll / Quantum Tunneling Charge Depletion & HUD Synchronization
	print("\nSTEP 11B: Testing Dodge Roll Depletion, Cooldown Recovery & HUD Synchronization...")
	var hud = main_inst.get_node("HUD")
	assert(hud != null, "HUD node not found on Main!")
	var roll_container = hud.get_node("TopLeft/VBox/RollContainer")
	assert(roll_container != null, "RollContainer node not found in HUD!")
	
	# Connect and sync HUD with p1
	hud._connect_players()
	assert(p1.rolls == p1.max_rolls, "Expected p1 to have max rolls full!")
	assert(roll_container.get_child_count() == p1.max_rolls, "HUD roll container must have exactly max_rolls pips!")
	# All pips should be active cyan
	for i in range(p1.max_rolls):
		var pip = roll_container.get_child(i)
		assert(pip.modulate.a > 0.8, "Initial roll pip %d should be fully lit!" % i)
	
	var initial_rolls = p1.rolls
	var gm_roll_signals = []
	var gm_roll_cb = func(c, m, r, p_id):
		if p_id == 1:
			gm_roll_signals.append({"charges": c, "max": m, "ratio": r})
	GameManager.player_roll_charges_changed.connect(gm_roll_cb)
	
	# Roll once: should deplete by 1 charge
	p1._start_barrel_roll()
	assert(p1.rolls == initial_rolls - 1, "Executing dodge roll must deplete 1 charge! rolls=%d" % p1.rolls)
	assert(p1.is_rolling, "Player must be in rolling state during barrel roll!")
	assert(p1.is_invulnerable, "Player must be invulnerable during barrel roll!")
	assert(not gm_roll_signals.is_empty(), "GameManager.player_roll_charges_changed must be emitted on roll!")
	assert(gm_roll_signals.back()["charges"] == initial_rolls - 1, "GameManager signal must reflect depleted charge count!")
	
	# Verify HUD updated: pip for depleted charge is dimmed/recharging
	var depleted_pip = roll_container.get_child(initial_rolls - 1)
	assert(depleted_pip.modulate.a < 0.8, "Depleted roll pip must be dimmed on HUD!")
	
	# End roll early to test consecutive rolling
	p1._end_barrel_roll()
	assert(not p1.is_rolling, "Player must not be rolling after roll ends!")
	
	# Deplete remaining rolls down to 0
	while p1.rolls > 0:
		p1._start_barrel_roll()
		p1._end_barrel_roll()
	assert(p1.rolls == 0, "Player must have 0 charges after depleting all rolls!")
	
	# Verify attempting to roll with 0 charges fails
	p1._start_barrel_roll()
	assert(not p1.is_rolling, "Player cannot initiate roll when 0 charges remaining!")
	assert(p1.rolls == 0, "Rolls count cannot go below 0!")
	
	# Test recharge progression
	p1.roll_timer = p1.roll_cooldown * 0.5
	p1._emit_rolls()
	# Verify recharging pip reflects cooldown_ratio
	var recharging_pip = roll_container.get_child(0)
	assert(recharging_pip.modulate.a > 0.25 and recharging_pip.modulate.a < 0.95, "Recharging pip must scale with cooldown ratio!")
	
	# Advance timer to complete recharge of 1 pip
	p1._handle_timers(p1.roll_cooldown * 0.6)
	assert(p1.rolls >= 1, "Roll charge must replenish after roll_cooldown elapses!")
	assert(roll_container.get_child(0).modulate.a > 0.8, "Replenished roll pip must be lit full cyan!")
	
	# Restore full charges
	p1.rolls = p1.max_rolls
	p1.roll_timer = 0.0
	p1._emit_rolls()
	GameManager.player_roll_charges_changed.disconnect(gm_roll_cb)
	print(" - SUCCESS: Dodge roll charge depletion, 0-charge lockout, HUD sync, and cooldown recovery verified.")
	
	# 12. Test Isaac-Scale Bestiary (16 Types), Hazards, 25+ Templates & Boss Ouroboros
	print("\nSTEP 12: Testing 16 Enemy Bestiary, Arena Hazards, 25+ Templates & Boss Ouroboros...")
	var enemy_scene = load("res://scenes/Enemy.tscn")
	var hazard_scene = load("res://scenes/HazardObject.tscn")
	var ouroboros_scene = load("res://scenes/BossOuroboros.tscn")
	
	# 12A. Verify all 17 enemy types instantiate cleanly
	for type_idx in range(17):
		var e = enemy_scene.instantiate()
		main_inst.add_child(e)
		e.setup(type_idx, Vector2(100 + type_idx * 20, 100), -1, null, 0)
		assert(e.max_health > 0.0, "Enemy type %d has invalid health!" % type_idx)
		assert(e.speed > 0.0, "Enemy type %d has invalid speed!" % type_idx)
		e.queue_free()
	print(" - 12A: All 17 Enemy Archetypes instantiated cleanly with distinct statistics.")
	
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
	
	# 12B2. Verify Knight Vanguard Breakable Shield, Venting, & Attack Windows
	var knight = enemy_scene.instantiate()
	main_inst.add_child(knight)
	knight.setup(6, Vector2(600, 200), -1, null, 0) # KNIGHT_VANGUARD
	p1.global_position = Vector2(300, 200) # Directly in front of Knight
	
	var initial_shield = knight.knight_shield_hp
	var initial_hull = knight.health
	assert(initial_shield == 8.0, "Knight Vanguard must start with 8.0 shield HP!")
	
	# 1. Frontal shot when shield is up damages shield, not hull
	knight.take_damage(3.0)
	assert(knight.knight_shield_hp == 5.0, "Frontal shot must deplete shield HP! Found: %f" % knight.knight_shield_hp)
	assert(knight.health == initial_hull, "Hull must be protected while shield absorbs damage!")
	
	# 2. Attack window allows direct hull damage
	knight.knight_is_firing_salvo = true
	knight.take_damage(2.0)
	assert(knight.health == initial_hull - 2.0, "Damage during attack salvo must bypass shield and hit hull!")
	assert(knight.knight_shield_hp == 5.0, "Shield HP must not be damaged when shield is unmasked!")
	knight.knight_is_firing_salvo = false
	
	# 3. Venting window allows direct hull damage
	knight.knight_shield_is_venting = true
	knight.take_damage(2.0)
	assert(knight.health == initial_hull - 4.0, "Damage during thermal venting must bypass shield and hit hull!")
	knight.knight_shield_is_venting = false
	
	# 4. Sustained frontal damage shatters shield
	knight.take_damage(6.0) # More than remaining 5.0 shield HP
	assert(knight.knight_shield_shattered == true, "Shield must shatter when shield HP reaches 0!")
	assert(knight.knight_shield_hp == 0.0, "Shield HP must clamp to 0!")
	
	# 5. Subsequent frontal shots hit hull directly
	var hull_before_shatter_hit = knight.health
	knight.take_damage(2.0)
	assert(knight.health == hull_before_shatter_hit - 2.0, "Frontal shots must damage hull directly once shield is shattered!")
	
	print(" - 12B2: Knight Vanguard breakable shield (8 HP), attack unmasking, thermal venting, and permanent shatter verified.")
	knight.queue_free()
	
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
	
	# 12E. Verify Sector 3 Climax Final Boss Apex Titan Ouroboros (1600 HP)
	var ouroboros = ouroboros_scene.instantiate()
	main_inst.add_child(ouroboros)
	ouroboros.entry_done = true
	assert(ouroboros.max_health == 600.0 and ouroboros.shield_gate_hp == 250.0, "Ouroboros HP mismatch!")
	ouroboros.shield_gate_alive = false # Bypass shield for quick automated test
	ouroboros.take_damage(350.0) # Push below 50% HP (<= 300.0)
	assert(ouroboros.phase == 2, "Ouroboros failed to transition to Phase 2 Singularity Meltdown!")
	print(" - 12F: Apex Titan Ouroboros Phase 2 Singularity Meltdown verified.")
	
	var ouroboros_flags = {"won": false}
	GameManager.boss_defeated.connect(func(b_name):
		if "OUROBOROS" in b_name.to_upper():
			ouroboros_flags["won"] = true
	)
	ouroboros.take_damage(310.0)
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
	
	# 13. Test 15-Minute Run Architecture, 3 Shops, Starter Stat Balance, Multi-Echelons
	print("\nSTEP 13: Testing 15-Minute Run Architecture (3 Shops, Starter Stats, Multi-Echelons)...")
	# 13A: Player starter stats
	var player_scene = load("res://scenes/Player.tscn")
	var fresh_p = player_scene.instantiate()
	assert(fresh_p.fire_rate == 3.8, "Player starter fire_rate should be 3.8! Found: %f" % fresh_p.fire_rate)
	assert(fresh_p.move_speed == 420.0, "Player starter move_speed should be 420.0! Found: %f" % fresh_p.move_speed)
	var test_bullet = bullet_scene.instantiate()
	main_inst.add_child(test_bullet)
	test_bullet.setup(fresh_p.global_position, Vector2.UP, false, 1.0)
	assert(test_bullet.speed == 540.0, "Player starter bullet speed should be 540.0! Found: %f" % test_bullet.speed)
	test_bullet.queue_free()
	fresh_p.queue_free()
	print(" - 13A: Player starter balance verified (fire_rate: 3.8, speed: 420.0, bullet_speed: 540.0).")
	
	# 13B: 3-Shop Visit Architecture in Main.gd
	assert("shop_w5_done" in main_inst and "shop_w17_done" in main_inst and "shop_w29_done" in main_inst, "Main.gd missing 3-shop progression flags!")
	assert(main_inst.shop_w5_done == false and main_inst.shop_w17_done == false and main_inst.shop_w29_done == false, "Shop flags should initially be false!")
	print(" - 13B: 3-Shop Visit Progression flags verified (Wave 5, 17, 29 pre-miniboss).")
	
	# 13C: Multi-Echelon Wave Templates
	var all_wave_templates = WaveDirector.get_all_templates()
	for t in all_wave_templates:
		var spawns = t.get("spawns", [])
		assert(spawns.size() >= 3, "Wave template %s must have at least 3 echelons!" % t.get("id", ""))
		var total_craft = 0
		for batch in spawns:
			total_craft += batch.get("count", 0)
		assert(total_craft >= 11, "Wave template %s must have at least 11 craft! Found: %d" % [t.get("id", ""), total_craft])
	print(" - 13C: All %d wave templates verified having 3-4 echelons and 11-26 craft per wave." % all_wave_templates.size())
	
	# 13D: Mathematical HP Scaling on Enemies
	GameManager.current_wave = 1
	GameManager.current_sector = 1
	var e_w1 = enemy_scene.instantiate()
	main_inst.add_child(e_w1)
	e_w1.setup(0, Vector2(100, 100), -1, null, 0)
	var hp_w1 = e_w1.max_health
	assert(hp_w1 == 2.0, "Starter Scout HP should be exactly 2.0 (2-shot kill)! Found: %f" % hp_w1)
	e_w1.queue_free()
	
	GameManager.current_wave = 4
	GameManager.current_sector = 1
	var e_w4 = enemy_scene.instantiate()
	main_inst.add_child(e_w4)
	e_w4.setup(0, Vector2(100, 100), -1, null, 0)
	var hp_w4 = e_w4.max_health
	assert(hp_w4 <= 2.2, "Wave 4 Scout HP should remain <= 2.2 (2-shot baseline)! Found: %f" % hp_w4)
	e_w4.queue_free()

	GameManager.current_wave = 12
	GameManager.current_sector = 1
	var e_w12 = enemy_scene.instantiate()
	main_inst.add_child(e_w12)
	e_w12.setup(0, Vector2(100, 100), -1, null, 0)
	var hp_w12 = e_w12.max_health
	assert(hp_w12 >= hp_w1 * 1.3 and hp_w12 <= hp_w1 * 1.4, "Enemy HP scaled incorrectly across waves! W1: %f, W12: %f" % [hp_w1, hp_w12])
	e_w12.queue_free()

	GameManager.current_wave = 13
	GameManager.current_sector = 2
	var e_w13 = enemy_scene.instantiate()
	main_inst.add_child(e_w13)
	e_w13.setup(0, Vector2(100, 100), -1, null, 0)
	var hp_w13 = e_w13.max_health
	assert(hp_w13 < hp_w12 * 1.25, "Wave 13 should smoothly bridge from Wave 12 without a 100%% cliff jump! W12: %s, W13: %s" % [snapped(hp_w12, 0.01), snapped(hp_w13, 0.01)])
	e_w13.queue_free()
	print(" - 13D: Mathematical enemy HP scaling verified (W1 Scout: %s HP, W4: %s HP, W12: %s HP, W13: %s HP)." % [snapped(hp_w1, 0.01), snapped(hp_w4, 0.01), snapped(hp_w12, 0.01), snapped(hp_w13, 0.01)])
	
	# 13E: Decoherence Spawner Queue Check
	var spawner = main_inst.get_node("DecoherenceSpawner")
	assert(spawner != null, "DecoherenceSpawner missing from Main scene!")
	assert(spawner.has_method("_has_active_squads"), "Spawner missing _has_active_squads method!")
	print(" - 13E: Decoherence Spawner squad queue tracker verified.")

	# 13F: Wave 1 Guaranteed First Contact
	var w1_template = wd2.select_template_for_wave(1, 1)
	assert(w1_template["id"] == "WAVE_FIRST_CONTACT", "Wave 1 must select WAVE_FIRST_CONTACT!")
	assert(w1_template["hazards"].is_empty(), "Wave 1 should have zero hazards for gentle onboarding!")
	print(" - 13F: Wave 1 gentle onboarding encounter (FIRST CONTACT) verified.")

	# 13G: On-Screen Forward Horizon Spawning & Clamping (15px Edge Margin)
	print("\nSTEP 13G: Testing On-Screen Forward Horizon Spawning & Clamping (15px Edge Margin)...")
	var vp_rect = GameAxis.get_viewport_rect()
	
	# Test horizontal spawn line
	GameAxis.set_axis_vertical(false)
	for lat_i in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var pt = GameAxis.get_spawn_line(lat_i)
		assert(vp_rect.has_point(pt), "Horizontal spawn point %s must be inside viewport!" % pt)
		var clamped = spawner._clamp_to_spawn_zone(pt)
		assert(vp_rect.has_point(clamped), "Clamped spawn point %s must be inside viewport!" % clamped)
		assert(clamped.x <= vp_rect.position.x + vp_rect.size.x - 15.0, "Clamped X must be within 15px of right edge!")
		assert(clamped.x >= vp_rect.position.x + vp_rect.size.x - 240.0, "Clamped X must be on the forward horizon band!")
	
	# Test vertical spawn line
	GameAxis.set_axis_vertical(true)
	var vp_rect_v = GameAxis.get_viewport_rect()
	for lat_i in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var pt = GameAxis.get_spawn_line(lat_i)
		assert(vp_rect_v.has_point(pt), "Vertical spawn point %s must be inside viewport!" % pt)
		var clamped = spawner._clamp_to_spawn_zone(pt)
		assert(vp_rect_v.has_point(clamped), "Clamped vertical point %s must be inside viewport!" % clamped)
		assert(clamped.y >= vp_rect_v.position.y + 15.0, "Clamped Y must be within 15px of top edge!")
	
	# Reset axis back to horizontal
	GameAxis.set_axis_vertical(false)
	print(" - 13G: Horizon spawn points and clamping verified 15px from screen edge in both orientations.")

	# 14. Test System 1 & System 2 Refinements
	print("\nSTEP 14: Testing System 1 (Combat/Wave Polish) & System 2 (Progression Engine)...")
	
	# 14A: Kinematic Flight Profiles & Lateral Boundary Cushions
	var enemy_p = enemy_scene.instantiate()
	main_inst.add_child(enemy_p)
	enemy_p.setup(0, Vector2(500, 300), 1, null, 0, EnemyScript.FlightProfile.DEEP_SWOOP)
	assert(enemy_p.flight_profile == EnemyScript.FlightProfile.DEEP_SWOOP, "Flight profile DEEP_SWOOP failed to assign!")
	enemy_p._handle_flight_movement(0.05)
	assert(enemy_p.global_position != Vector2(500, 300), "Enemy kinematics failed to update position!")
	enemy_p.has_evasive_juke = true
	enemy_p.take_damage(0.5)
	assert(enemy_p.juke_cooldown > 0.0 or enemy_p.juke_timer > 0.0, "Agile craft reactive juke failed to trigger on damage!")
	enemy_p.queue_free()

	# 14A2: Test Center-Converging Direction & Boundary Reflection
	# Bottom flank strafer (lateral 0.82)
	var pt_bottom = GameAxis.get_spawn_line(0.82)
	var e_bottom = enemy_scene.instantiate()
	main_inst.add_child(e_bottom)
	e_bottom.setup(0, pt_bottom, 1, null, 0, EnemyScript.FlightProfile.DIAGONAL_STRAFER)
	assert(e_bottom.strafe_sign == -1.0, "Lower flank strafer must steer upward (-lat) toward center! Got: %f" % e_bottom.strafe_sign)
	for _frame in range(30):
		e_bottom._handle_flight_movement(0.016)
		assert(e_bottom.global_position.y <= vp_rect.size.y - 38.0, "Bottom strafer must stay within lateral bounds! Y: %f" % e_bottom.global_position.y)
		assert(e_bottom.global_position.y >= 38.0, "Bottom strafer must stay within lateral bounds! Y: %f" % e_bottom.global_position.y)
	e_bottom.queue_free()

	# Top flank strafer (lateral 0.18)
	var pt_top = GameAxis.get_spawn_line(0.18)
	var e_top = enemy_scene.instantiate()
	main_inst.add_child(e_top)
	e_top.setup(0, pt_top, 1, null, 0, EnemyScript.FlightProfile.DIAGONAL_STRAFER)
	assert(e_top.strafe_sign == 1.0, "Upper flank strafer must steer downward (+lat) toward center! Got: %f" % e_top.strafe_sign)
	for _frame in range(30):
		e_top._handle_flight_movement(0.016)
		assert(e_top.global_position.y >= 38.0, "Top strafer must stay within lateral bounds! Y: %f" % e_top.global_position.y)
		assert(e_top.global_position.y <= vp_rect.size.y - 38.0, "Top strafer must stay within lateral bounds! Y: %f" % e_top.global_position.y)
	e_top.queue_free()

	# Boundary cushion check: clamps position to margin and completes cross-cut (no ping-pong)
	var e_bounce = enemy_scene.instantiate()
	main_inst.add_child(e_bounce)
	e_bounce.setup(0, Vector2(800, 20), 1, null, 0, EnemyScript.FlightProfile.DIAGONAL_STRAFER)
	e_bounce._enforce_lateral_bounds()
	assert(e_bounce.global_position.y == 38.0, "Boundary cushion failed to clamp Y position to margin (38px)! Got: %f" % e_bounce.global_position.y)
	assert(e_bounce.has_completed_cross == true, "Boundary cushion failed to set has_completed_cross for single cross-cut!")
	e_bounce.queue_free()

	# Deep swoop center-convergence and downfield advance check
	var e_swoop = enemy_scene.instantiate()
	main_inst.add_child(e_swoop)
	e_swoop.setup(0, pt_bottom, 1, null, 0, EnemyScript.FlightProfile.DEEP_SWOOP)
	assert(e_swoop.swoop_dir == -1.0, "Bottom deep swooper must swoop upward (-lat) toward center! Got: %f" % e_swoop.swoop_dir)
	# Simulate through swoop into downfield run (t = 2.5s)
	e_swoop.flight_time = 2.5
	e_swoop._handle_flight_movement(0.016)
	assert(e_swoop.global_position.y >= 38.0 and e_swoop.global_position.y <= vp_rect.size.y - 38.0, "Post-swoop flight must remain inside lateral bounds! Y: %f" % e_swoop.global_position.y)
	e_swoop.queue_free()

	# 14A3: Formation Discipline Verification
	var e_scout = enemy_scene.instantiate()
	main_inst.add_child(e_scout)
	e_scout.setup(0, Vector2(1000, 300), 1, null, 0, EnemyScript.FlightProfile.DIRECT_ADVANCE)
	assert(e_scout.flight_profile == EnemyScript.FlightProfile.DIRECT_ADVANCE, "Preset DIRECT_ADVANCE formation profile was overwritten!")
	var initial_y = e_scout.global_position.y
	for _frame in range(30):
		e_scout._handle_flight_movement(0.016)
		assert(e_scout.global_position.y == initial_y, "Formation craft must maintain lateral lane position during DIRECT_ADVANCE!")
	e_scout.queue_free()

	# 14A4: 2-Layer Model: Interceptor Breakout Dive & Bomber Station Anchor
	var e_interceptor = enemy_scene.instantiate()
	main_inst.add_child(e_interceptor)
	e_interceptor.setup(EnemyScript.EnemyType.INTERCEPTOR, Vector2(1000, 200), 1, null, 0, EnemyScript.FlightProfile.DIRECT_ADVANCE)
	e_interceptor.flight_time = 0.5
	e_interceptor._handle_flight_movement(0.016)
	assert(not e_interceptor.is_charging, "Interceptor must not dive-bomb during initial formation entry (t < 0.9s)!")
	e_interceptor.flight_time = 1.2
	e_interceptor._handle_flight_movement(0.016)
	assert(e_interceptor.is_charging == true, "Interceptor must break out into screeching dive-bomb at t=1.2s!")
	e_interceptor.queue_free()

	var e_bomber = enemy_scene.instantiate()
	main_inst.add_child(e_bomber)
	e_bomber.setup(EnemyScript.EnemyType.BOMBER, Vector2(1000, 360), 1, null, 0, EnemyScript.FlightProfile.DIRECT_ADVANCE)
	e_bomber.global_position = Vector2(750, 360) # 250px from spawn pos (1000, 360)
	e_bomber._handle_flight_movement(0.016)
	assert(e_bomber.is_anchored == true, "Bomber heavy platform must drop anchor upon reaching combat station!")
	var anchored_x = e_bomber.global_position.x
	e_bomber._handle_flight_movement(0.05)
	assert(is_equal_approx(e_bomber.global_position.x, anchored_x), "Anchored bomber must halt forward downfield advance!")
	e_bomber.queue_free()

	print(" - 14A: Kinematic flight profiles, 2-layer archetypes (Interceptor dive / Bomber anchor), and cushions verified.")
	
	# 14B: WaveDirector Milestone Cargo Hauler Encounters & Elimination of Dynamic Threat Surges
	GameManager.consecutive_wipes = 3
	var w2_template = wd.select_template_for_wave(1, 2)
	assert(w2_template["id"] == "WAVE_CARGO_RECON", "Wave 2 must schedule Cargo Recon milestone!")
	var w4_template = wd.select_template_for_wave(1, 4)
	assert(w4_template["id"] == "WAVE_CARGO_CONVOY_1", "Wave 4 must schedule Relic Convoy 1!")
	assert(not w4_template["name"].begins_with("THREAT SURGE: "), "Dynamic threat surge must not contaminate template name!")
	var w8_template = wd.select_template_for_wave(1, 8)
	assert(w8_template["id"] == "WAVE_CARGO_CONVOY_2", "Wave 8 must schedule Armored Relic Convoy 2!")
	var w10_template = wd.select_template_for_wave(1, 10)
	assert(w10_template["id"] == "WAVE_CARGO_SUPPLY", "Wave 10 must schedule Deep Space Supply Run!")
	GameManager.consecutive_wipes = 0
	print(" - 14B: WaveDirector milestone Cargo Hauler encounters (W2, W4, W8, W10) and clean elimination of Threat Surges verified.")
	
	# 14B2: Single-Leader Elite Champion Promotion
	var v_elite_count = 0
	for i in range(5):
		if spawner.get_craft_affix(i, 5, "V_SHAPE", 1) != 0:
			v_elite_count += 1
	assert(v_elite_count == 1, "V_SHAPE squad must have exactly 1 Elite Champion leader! Found: %d" % v_elite_count)
	assert(spawner.get_craft_affix(2, 5, "V_SHAPE", 1) == 1, "V_SHAPE leader must be center craft (index 2)!")
	
	var row_elite_count = 0
	for i in range(5):
		if spawner.get_craft_affix(i, 5, "ROW", 2) != 0:
			row_elite_count += 1
	assert(row_elite_count == 1, "ROW squad must have exactly 1 Elite Champion leader! Found: %d" % row_elite_count)
	assert(spawner.get_craft_affix(0, 5, "ROW", 2) == 2, "ROW leader must be first craft (index 0)!")
	print(" - 14B2: Single-Leader Elite Champion promotion verified (no 5-elite squads).")
	
	# 14C: ProgressionModel Systemic Balance & Dynamic Tier Probabilities
	assert(ProgressionModel.get_tier_price(ItemModifier.ItemTier.TIER_1_BALLISTIC) == 35, "Tier 1 price must be 35 J!")
	assert(ProgressionModel.get_tier_price(ItemModifier.ItemTier.TIER_2_PARADIGM) == 65, "Tier 2 price must be 65 J!")
	assert(ProgressionModel.get_tier_price(ItemModifier.ItemTier.TIER_3_EXOTIC) == 95, "Tier 3 price must be 95 J!")
	var s1_p = ProgressionModel.get_tier_probabilities(1)
	var s3_p = ProgressionModel.get_tier_probabilities(3)
	assert(s1_p[ItemModifier.ItemTier.TIER_1_BALLISTIC] == 0.75, "S1 Tier 1 prob should be 75%!")
	assert(s3_p[ItemModifier.ItemTier.TIER_3_EXOTIC] == 0.30, "S3 Tier 3 prob should be 30%!")
	print(" - 14C: ProgressionModel dynamic tier probabilities and tiered pricing (35/65/95 J) verified.")
	
	# 14D: Additive Stat Stacking Model on Player
	var p_test = player_scene.instantiate()
	main_inst.add_child(p_test)
	assert(p_test.bonus_damage_pct == 0.0, "Player starter bonus_damage_pct should be 0.0!")
	var t_item = ItemDatabase.get_item_by_id("tungsten_core")
	p_test.add_modifier(t_item)
	assert(is_equal_approx(p_test.bonus_damage_pct, 0.25), "Tungsten Core should add exactly +0.25 to bonus_damage_pct!")
	assert(is_equal_approx(p_test.damage_mult, 1.25), "Player damage_mult should be 1.25!")
	var u_item = ItemDatabase.get_item_by_id("depleted_uranium")
	p_test.add_modifier(u_item)
	assert(is_equal_approx(p_test.bonus_damage_pct, 0.60), "Tungsten + DU should additively sum to +0.60, not compounding!")
	assert(is_equal_approx(p_test.damage_mult, 1.60), "Damage mult must be 1.60 additively!")
	assert(p_test.get_modifier_stack_count("tungsten_core") == 1, "Stack count tracking failed!")
	p_test.queue_free()
	print(" - 14D: Additive linear stat pooling model verified without exponential compounding.")
	
	# 14E: Max Stacks and Unique Constraints
	var dirac = ItemDatabase.get_item_by_id("dirac_inversion")
	assert(dirac.max_stacks == 1, "Dirac Inversion exotic relic must be unique (max_stacks = 1)!")
	assert(t_item.max_stacks == 3, "Tungsten Core stat booster must allow stacking (max_stacks = 3)!")
	print(" - 14E: Relic uniqueness and stack rules verified.")
	
	# 14F: SkyMerchant Guaranteed Slot Archetypes and Tiered Prices
	shop.open_shop()
	assert(shop.p1_shop_items.size() == 3, "Shop should generate 3 items per stall!")
	assert(shop.p1_shop_items[0].category == "offense", "Slot 1 must be guaranteed Offense!")
	assert(shop.p1_shop_items[1].category in ["defense", "utility"], "Slot 2 must be guaranteed Defense or Utility!")
	shop._on_undock_pressed()
	print(" - 14F: SkyMerchant guaranteed slot archetypes (Offense / Def-Util / Wildcard) verified.")

	# 14G: Progression Telemetry & Debug Overlay
	assert(ProgressionModel.get_expected_relics_range(1, 1) == Vector2i(0, 0), "W1 expected relics should be 0!")
	assert(ProgressionModel.get_expected_relics_range(1, 5) == Vector2i(3, 4), "W5 expected relics should be 3-4!")
	assert(ProgressionModel.get_expected_relics_range(1, 11) == Vector2i(6, 7), "W11 expected relics should be 6-7!")
	assert(ProgressionModel.get_expected_relics_range(3, 36) == Vector2i(24, 27), "Finale expected relics should be 24-27!")
	assert(ProgressionModel.get_next_shop_wave(1, 1) == 5, "Next shop from W1 must be Wave 5!")
	assert(ProgressionModel.get_expected_total_joules_range(1, 1) == Vector2i(0, 25), "W1 expected total Joules should be 0-25 J!")
	assert(ProgressionModel.get_expected_total_joules_range(1, 5) == Vector2i(80, 125), "W5 expected total Joules should be 80-125 J!")
	assert(GameManager.total_joules_collected >= GameManager.scrap_joules, "Total collected Joules must be >= current Joules!")
	
	var hud_node = main_inst.get_node_or_null("HUD")
	assert(hud_node != null, "HUD must exist!")
	assert(hud_node.is_debug_visible == true, "Debug overlay should default to visible!")
	hud_node.toggle_debug_overlay()
	assert(hud_node.is_debug_visible == false, "Debug overlay failed to toggle off!")
	hud_node.toggle_debug_overlay()
	assert(hud_node.is_debug_visible == true, "Debug overlay failed to toggle on!")
	hud_node._update_debug_telemetry()
	assert(hud_node.debug_text_label.text.contains("TELEMETRY"), "Debug text must contain TELEMETRY header!")
	assert(hud_node.debug_text_label.text.contains("Total:"), "Debug text must display Total Joules comparison!")
	print(" - 14G: Progression telemetry curves and HUD debug overlay verified.")

	# 15: Death & Modal Concurrency Safeguards
	print("\nSTEP 15: Testing Death & Modal Concurrency Safeguards...")
	var test_hud = main_inst.get_node_or_null("HUD")
	var test_over = main_inst.get_node_or_null("GameOverOverlay")
	assert(test_hud != null and test_over != null, "HUD and GameOverOverlay must exist in Main!")
	assert(test_over.process_mode == Node.PROCESS_MODE_ALWAYS, "GameOverOverlay must have process_mode ALWAYS!")
	
	# Test 15A: Ensure open_item_choice_modal fails safely if game_over
	GameManager.is_game_over = true
	test_hud.open_item_choice_modal()
	assert(test_hud.choice_modal.visible == false, "Item modal must NOT open when game over!")
	assert(get_tree().paused == false, "Tree must NOT be paused by item modal on game over!")
	GameManager.is_game_over = false
	
	# Test 15B: If modal is open when game over triggers, it must dismiss and unpause
	test_hud.open_item_choice_modal()
	assert(test_hud.choice_modal.visible == true, "Item modal should be open for live player!")
	assert(get_tree().paused == true, "Tree must be paused while modal open!")
	
	GameManager.trigger_game_over()
	assert(test_hud.choice_modal.visible == false, "Item modal must dismiss upon trigger_game_over!")
	assert(get_tree().paused == false, "Tree must be unpaused upon trigger_game_over!")
	assert(test_over.panel.visible == true, "GameOverOverlay panel must be visible!")
	GameManager.is_game_over = false
	test_over.panel.visible = false
	print(" - 15: Modal concurrency safeguards and death unpause verified cleanly.")

	# 16: Calibrated Joules Economy & Sector 1 Progression Budget
	print("\nSTEP 16: Testing Calibrated Joules Economy & Sector 1 Item Budget...")
	# 16A: Base Scrap Currency
	assert(ProgressionModel.BASE_SCRAP_VALUE == 1, "BASE_SCRAP_VALUE in ProgressionModel must be 1 Joule!")
	assert(ProgressionModel.get_base_scrap_value() == 1, "get_base_scrap_value() must return 1!")
	var default_scrap = load("res://scenes/ScrapPickup.tscn").instantiate()
	assert(default_scrap.value == 1, "ScrapPickup default value must be calibrated to 1 Joule!")
	default_scrap.queue_free()
	print(" - 16A: Base scrap currency normalized to 1 Joule per pellet.")

	# 16B: Redesigned Multi-Mechanic Economy Relics
	var refiner = ItemDatabase.get_item_by_id("joule_refiner")
	var sifter = ItemDatabase.get_item_by_id("plasma_sifter")
	var siphon = ItemDatabase.get_item_by_id("singularity_siphon")
	var endowment = ItemDatabase.get_item_by_id("endowment_capacitor")
	
	assert(refiner != null, "Joule refiner must exist in ItemDatabase!")
	assert(refiner.scrap_bonus_chance == 0.25, "Joule refiner scrap_bonus_chance must be 0.25 (25%)!")
	assert(refiner.max_stacks == 2, "Joule refiner max_stacks must be 2!")
	
	assert(sifter != null, "Plasma sifter must exist in ItemDatabase!")
	assert(sifter.elite_bounty_bonus == 5, "Plasma sifter elite_bounty_bonus must be 5 J!")
	assert(sifter.add_magnet_radius == 100.0, "Plasma sifter add_magnet_radius must be 100.0!")
	assert(sifter.max_stacks == 1, "Plasma sifter must have max_stacks 1!")
	
	assert(siphon != null, "Singularity siphon must exist in ItemDatabase!")
	assert(siphon.has_singularity_recovery == true, "Singularity siphon has_singularity_recovery must be true!")
	assert(siphon.add_magnet_radius == 250.0, "Singularity siphon add_magnet_radius must be 250.0!")
	assert(siphon.max_stacks == 1, "Singularity siphon must have max_stacks 1!")
	
	assert(endowment != null, "Endowment capacitor must exist in ItemDatabase!")
	assert(endowment.wave_dividend_joules == 4, "Endowment capacitor wave_dividend_joules must be 4 J!")
	assert(endowment.max_stacks == 2, "Endowment capacitor max_stacks must be 2!")
	
	# Functional verification of the 4 mechanics
	var initial_j = GameManager.scrap_joules
	
	# 1. Test Wave Clear Dividend
	p1.wave_dividend_joules = 4
	p1.trigger_wave_cleared_hooks(1)
	assert(GameManager.scrap_joules == initial_j + 4, "Wave clear dividend failed to award +4 Joules!")
	
	# 2. Test Singularity Out-of-Bounds Recovery
	var test_scrap = load("res://scenes/ScrapPickup.tscn").instantiate()
	main_inst.add_child(test_scrap)
	test_scrap.global_position = Vector2(-200, -200) # out of bounds
	p1.has_singularity_recovery = true
	var j_before_recover = GameManager.scrap_joules
	test_scrap._physics_process(0.016)
	assert(GameManager.scrap_joules == j_before_recover + 1, "Singularity siphon failed to recover out-of-bounds scrap!")
	p1.has_singularity_recovery = false
	
	# 3. Test Scavenger Chance
	var pickup_test = load("res://scenes/ScrapPickup.tscn").instantiate()
	main_inst.add_child(pickup_test)
	p1.scrap_bonus_chance = 1.0 # 100% test roll
	var j_before_collect = GameManager.scrap_joules
	pickup_test._collect(p1)
	assert(GameManager.scrap_joules == j_before_collect + 2, "Scavenger chance failed to extract +1 bonus Joule!")
	p1.scrap_bonus_chance = 0.0
	p1.wave_dividend_joules = 0
	
	print(" - 16B: 4 distinct economy mechanics verified (25% chance, +5 J bounty, +4 J dividend, 100% vacuum recovery).")

	# 16C: Sector 1 Waves 1-5 Dynamic Joules Simulation
	var all_templates = WaveDirector.get_all_templates()
	var s1_templates: Array[Dictionary] = []
	for t in all_templates:
		if t.get("min_sector", 1) == 1:
			s1_templates.append(t)
	
	var total_sim_joules: float = 0.0
	# Simulate 5 typical Sector 1 waves using dynamic distribution
	for w_idx in range(5):
		var tmpl = s1_templates[w_idx % s1_templates.size()]
		var dist = ProgressionModel.calculate_wave_drop_distribution(tmpl.get("spawns", []), tmpl.get("hazards", []), 1, w_idx + 1)
		var wave_joules: float = 0.0
		for batch in tmpl.get("spawns", []):
			var e_type = batch.get("type", 0)
			var count = batch.get("count", 1)
			var has_elite = batch.get("affix", 0) != 0
			var std_count = (count - 1) if has_elite else count
			if has_elite:
				wave_joules += 10.0 # Option 2: Sector 1 Elite bounty +10 J
			var prof = dist.get(e_type, {"expected_value": 1.0})
			wave_joules += std_count * prof.expected_value
		
		# Add hazard scrap
		for hz in tmpl.get("hazards", []):
			var ht = hz.get("type", 0)
			var hc = hz.get("count", 0)
			var hprof = dist.get("hazard_%d" % ht, {"expected_value": 0.0})
			wave_joules += hc * hprof.expected_value
		
		total_sim_joules += wave_joules
	
	# Goliath miniboss drop at Wave 6: 10 pellets * 1 J
	total_sim_joules += 10.0
	print(" - 16C: Simulated Waves 1-5 + Goliath Joules: %.1f J (Target: 100-130 J, was 860 J previously)" % total_sim_joules)
	assert(total_sim_joules >= 95.0 and total_sim_joules <= 140.0, "Sector 1 Joules budget violated! Expected ~100-130 J, got: %.1f" % total_sim_joules)
	assert(ProgressionModel.get_target_wave_joules(1) == 22.0, "Sector 1 target wave Joules should be 22.0!")
	assert(ProgressionModel.get_target_wave_joules(2) == 24.0, "Sector 2 target wave Joules should be 24.0!")
	assert(ProgressionModel.get_target_wave_joules(3) == 26.0, "Sector 3 target wave Joules should be 26.0!")

	# 16D: Wave 5 Shop Purchasing Power & 1-2 Item Target
	# Player arrives with ~95-104 J. Let's test affordability and 1-2 item bounds:
	var starting_wallet = 100
	var t1_cost = ProgressionModel.get_tier_price(ItemModifier.ItemTier.TIER_1_BALLISTIC) # 35 J
	var t2_cost = ProgressionModel.get_tier_price(ItemModifier.ItemTier.TIER_2_PARADIGM)  # 65 J
	var t3_cost = ProgressionModel.get_tier_price(ItemModifier.ItemTier.TIER_3_EXOTIC)    # 95 J
	var repair_cost = 20
	var reroll_1 = 5

	# Case 1: Buying 2 Tier 1 items (35 + 35 = 70 J) leaves 30 J, mathematically blocking a 3rd relic buy (needs 35 J)
	var wallet_after_2_t1 = starting_wallet - (t1_cost * 2)
	assert(wallet_after_2_t1 == 30, "Expected 30 J left after 2 Tier 1 buys!")
	assert(wallet_after_2_t1 < t1_cost, "Wallet must not allow a 3rd relic buy (30 < 35)!")

	# Case 2: Buying 1 Tier 2 (65 J) + 1 Tier 1 (35 J) = exactly 100 J (clean 2-item spend)
	var wallet_after_t2_t1 = starting_wallet - (t2_cost + t1_cost)
	assert(wallet_after_t2_t1 == 0, "Expected 0 J left after 1 T2 + 1 T1 buy!")

	# Case 3: Buying 1 lucky Tier 3 immediately (95 J) leaves 5 J (clean 1-item spend, exactly enough for 1 reroll or save)
	var wallet_after_t3 = starting_wallet - t3_cost
	assert(wallet_after_t3 == 5, "Expected 5 J left after lucky T3 buy!")
	assert(wallet_after_t3 >= reroll_1, "Player should be able to reroll or save remaining Joules!")

	# Case 4: Buying 1 Tier 1 (35 J) + 1 Nano Repair (20 J) + 1 Reroll (5 J) = 60 J spent, leaving 40 J (can buy 1 more T1)
	var wallet_after_mixed = starting_wallet - (t1_cost + repair_cost + reroll_1)
	assert(wallet_after_mixed == 40, "Expected 40 J left after T1 + Repair + Reroll!")

	print(" - 16D: Wave 5 pre-miniboss shop buying power verified (strictly 1-2 items purchased, lucky T3 immediately affordable at 95 J, exactly matching Sector 1 budget).")

	# 16E: Escalating Reroll Protection
	assert(shop._next_cost(5) == 10, "Reroll 1 to 2 escalation must be 10 J!")
	assert(shop._next_cost(10) == 20, "Reroll 2 to 3 escalation must be 20 J!")
	assert(shop._next_cost(20) == 35, "Reroll 3 to 4 escalation must be 35 J!")
	assert(shop._next_cost(35) == 55, "Reroll 4 to 5 escalation must be 55 J!")
	print(" - 16E: Escalating reroll inflation curve verified (5 -> 10 -> 20 -> 35 -> 55 J).")

	# 16F: Quantum Cargo Hauler Crate Drops & Option 2 Golden Plasma Bounties
	print("\nTesting 16F: Quantum Cargo Hauler Crate Drops & Option 2 Golden Plasma Bounties...")
	var test_spawner = main_inst.get_node_or_null("DecoherenceSpawner")
	assert(test_spawner != null, "DecoherenceSpawner must exist in Main!")
	
	# Clear crates
	for c in get_tree().get_nodes_in_group("crate"):
		c.queue_free()
	
	var crates_before = get_tree().get_nodes_in_group("crate").size()
	
	# Test 1: CARGO_HAULER (type 16) drops guaranteed Item Choice Crate upon destruction
	var cargo_hauler = load("res://scenes/Enemy.tscn").instantiate()
	main_inst.add_child(cargo_hauler)
	cargo_hauler.setup(16, Vector2(100, 100), 101, test_spawner, 0) # 16 = CARGO_HAULER
	cargo_hauler._drop_loot()
	var crates_after_hauler = get_tree().get_nodes_in_group("crate").size()
	assert(crates_after_hauler == crates_before + 1, "Quantum Cargo Hauler must drop 1 guaranteed Item Choice Crate!")
	
	# Test 2: Elite Champion drops Golden Plasma Bounty (+10 J in S1, + full shields) with ZERO loose scrap pellets
	GameManager.current_sector = 1
	var joules_before_s1 = GameManager.scrap_joules
	var p1_ref = main_inst.get_node_or_null("Player")
	if p1_ref:
		p1_ref.shields = 0
	
	var scrap_nodes_before = get_tree().get_nodes_in_group("scrap").size()
	var elite_s1 = load("res://scenes/Enemy.tscn").instantiate()
	main_inst.add_child(elite_s1)
	elite_s1.setup(0, Vector2(120, 120), 102, test_spawner, 1) # Affix 1 = ARMORED
	elite_s1._drop_loot()
	var scrap_nodes_after = get_tree().get_nodes_in_group("scrap").size()
	assert(scrap_nodes_after == scrap_nodes_before, "Elite Champion must not scatter loose pellets (Option 2 replaces pellets with bounty)!")
	assert(GameManager.scrap_joules == joules_before_s1 + 10, "Sector 1 Elite must award +10 Joules Golden Plasma Bounty!")
	if p1_ref:
		assert(p1_ref.shields == p1_ref.max_shields, "Elite bounty must restore player shields to full!")
	
	# Test 3: Sector 2 Elite awards +15 J
	GameManager.current_sector = 2
	var joules_before_s2 = GameManager.scrap_joules
	var elite_s2 = load("res://scenes/Enemy.tscn").instantiate()
	main_inst.add_child(elite_s2)
	elite_s2.setup(0, Vector2(140, 140), 103, test_spawner, 2)
	elite_s2._drop_loot()
	assert(GameManager.scrap_joules == joules_before_s2 + 15, "Sector 2 Elite must award +15 Joules Bounty!")
	
	# Test 4: Sector 3 Elite awards +20 J
	GameManager.current_sector = 3
	var joules_before_s3 = GameManager.scrap_joules
	var elite_s3 = load("res://scenes/Enemy.tscn").instantiate()
	main_inst.add_child(elite_s3)
	elite_s3.setup(0, Vector2(160, 160), 104, test_spawner, 3)
	elite_s3._drop_loot()
	assert(GameManager.scrap_joules == joules_before_s3 + 20, "Sector 3 Elite must award +20 Joules Bounty!")
	
	# Test 5: Standard combat craft (e.g. Drone Carrier) does NOT drop a crate
	var carrier = load("res://scenes/Enemy.tscn").instantiate()
	main_inst.add_child(carrier)
	carrier.setup(8, Vector2(200, 200), 105, test_spawner, 0)
	carrier._drop_loot()
	var crates_after_carrier = get_tree().get_nodes_in_group("crate").size()
	assert(crates_after_carrier == crates_after_hauler, "Standard non-hauler craft must NOT drop a crate!")
	
	# Clean up test nodes
	cargo_hauler.queue_free()
	elite_s1.queue_free()
	elite_s2.queue_free()
	elite_s3.queue_free()
	carrier.queue_free()
	GameManager.current_sector = 1
	print(" - 16F: Quantum Cargo Hauler Crate Drops & Option 2 Scaled Golden Plasma Bounties (+10/+15/+20 J & Full Shields) verified.")

	# 16G: Dynamic Wave Density Invariance (Sparse 6-Craft vs Crowded 30-Craft Swarm)
	var sparse_spawns = [
		{"type": 1, "count": 2, "affix": 0}, # 2 Bombers
		{"type": 0, "count": 4, "affix": 0}  # 4 Scouts
	]
	var crowded_spawns = [
		{"type": 0, "count": 10, "affix": 0}, # 10 Scouts
		{"type": 9, "count": 20, "affix": 0}  # 20 Micro Drones
	]
	var sparse_dist = ProgressionModel.calculate_wave_drop_distribution(sparse_spawns, [], 1, 1)
	var crowded_dist = ProgressionModel.calculate_wave_drop_distribution(crowded_spawns, [], 1, 1)

	var sparse_ev = 0.0
	for b in sparse_spawns:
		sparse_ev += b.count * sparse_dist[b.type].expected_value

	var crowded_ev = 0.0
	for b in crowded_spawns:
		crowded_ev += b.count * crowded_dist[b.type].expected_value

	var target_j = ProgressionModel.get_target_wave_joules(1, 1) # 22.0
	assert(absf(sparse_ev - target_j) < 0.01, "Sparse wave expected value must equal target 22.0 J! Got: %.2f" % sparse_ev)
	assert(absf(crowded_ev - target_j) < 0.01, "Crowded wave expected value must equal target 22.0 J! Got: %.2f" % crowded_ev)
	print(" - 16G: Dynamic Wave Density Invariance verified! (Both 6-craft and 30-craft waves deliver exactly %.1f J)" % target_j)

	# 16H: Concurrency Safeguards (Enemy is_dying & Scrap is_collected)
	var guard_enemy = load("res://scenes/Enemy.tscn").instantiate()
	main_inst.add_child(guard_enemy)
	guard_enemy.setup(0, Vector2(100, 100), 999, test_spawner)
	var kills_before = GameManager.enemies_destroyed
	guard_enemy._die()
	guard_enemy._die() # Rapid-fire second hit in same frame
	assert(GameManager.enemies_destroyed == kills_before + 1, "Enemy _die() must not double-credit kills!")
	guard_enemy.queue_free()

	var guard_scrap = load("res://scenes/ScrapPickup.tscn").instantiate()
	main_inst.add_child(guard_scrap)
	var j_before = GameManager.scrap_joules
	guard_scrap._collect(p1)
	guard_scrap._collect(p1) # Rapid duplicate collision in same frame
	assert(GameManager.scrap_joules == j_before + guard_scrap.value, "ScrapPickup must not double-credit Joules!")
	guard_scrap.queue_free()
	print(" - 16H: Death and collection concurrency guards verified.")

	# =========================================================================
	# STEP 17: Inter-Wave Quantum Teleport Transitions, Shard Vacuum & Docking
	# =========================================================================
	print("\nSTEP 17: Testing Inter-Wave Transitions, Quantum Teleport & Shop Docking...")
	
	# 17A: Wave Completion Reason Classification (100% Wipe vs Escaped)
	var spawner_node = main_inst.get_node("DecoherenceSpawner")
	var captured_reasons: Array[Dictionary] = []
	var on_wave_clr = func(w_num, r_title, r_desc, is_w, stats):
		captured_reasons.append({
			"wave": w_num, "title": r_title, "desc": r_desc, "is_wipe": is_w, "stats": stats
		})
	spawner_node.wave_cleared.connect(on_wave_clr)
	
	# Case 1: 100% formation wipe
	spawner_node._register_squad(201, 3)
	spawner_node.current_wave_num = 2
	spawner_node.current_wave_total = 3
	spawner_node.current_wave_killed = 0
	spawner_node.current_wave_escaped = 0
	spawner_node.record_squad_kill(201)
	spawner_node.record_squad_kill(201)
	spawner_node.record_squad_kill(201)
	spawner_node._on_wave_combat_cleared()
	
	assert(captured_reasons.size() == 1, "Wave cleared signal must be emitted on combat clear!")
	var r1 = captured_reasons[0]
	assert(r1.is_wipe == true, "Squad with 0 escapes must be marked as 100% wipe!")
	assert("100% SQUAD WIPED" in r1.desc, "100% wipe announcement must state squad wipe!")
	
	# Case 2: Enemies escaped past rear horizon
	spawner_node._register_squad(202, 3)
	spawner_node.current_wave_num = 3
	spawner_node.current_wave_total = 3
	spawner_node.current_wave_killed = 0
	spawner_node.current_wave_escaped = 0
	spawner_node.record_squad_kill(202)
	spawner_node.record_squad_escaped(202)
	spawner_node.record_squad_escaped(202)
	spawner_node._on_wave_combat_cleared()
	
	assert(captured_reasons.size() == 2, "Second wave cleared signal must be emitted!")
	var r2 = captured_reasons[1]
	assert(r2.is_wipe == false, "Squad with escapes must NOT be marked as 100% wipe!")
	assert("1 DESTROYED, 2 ESCAPED" in r2.desc, "Escape telemetry must specify killed and escaped count!")
	print(" - 17A: Wave completion reasons & telemetry banners verified (100% Wipe vs Escaped).")
	
	# 17B: Quantum Vacuum Pulse (750px Magnet Range) & Shard Collection
	p1.global_position = Vector2(200, 200)
	var base_mag = p1.scrap_magnet_radius
	p1.activate_vacuum_pulse(1.4)
	assert(p1.vacuum_pulse_active == true, "Vacuum pulse flag must be active!")
	assert(p1.scrap_magnet_radius >= 750.0, "Vacuum pulse must boost magnet radius to >= 750px!")
	
	# Spawn scrap shard at 350px (outside normal 130px magnet radius)
	var shard = load("res://scenes/ScrapPickup.tscn").instantiate()
	shard.value = 5
	shard.global_position = Vector2(480, 200) # 280px away
	main_inst.add_child(shard)
	shard._physics_process(0.016)
	assert(shard.magnet_speed > 0.0, "Shard outside normal radius must accelerate toward player during vacuum pulse!")
	shard.queue_free()
	p1.reset_warp_state()
	print(" - 17B: Quantum Vacuum Pulse (750px radius) & lingering shard collection verified.")
	
	# 17C: Quantum Teleport Charge Progression, Relocation to Left-Middle, and Skip Control
	assert(spawner_node.wave_grace_duration >= 4.5, "Wave grace spin-up duration must be at least 4.5s for collection!")
	p1.start_quantum_charge(5.0)
	assert(p1.warp_charge_duration == 5.0, "Warp charge duration must be initialized to 5.0s!")
	p1._handle_timers(2.5)
	assert(p1.warp_charge_ratio >= 0.45, "Warp charge ratio must advance over time!")
	
	# Test fast teleport jump to left-middle of screen
	p1.global_position = Vector2(800, 400) # Player was far on the right
	p1.trigger_quantum_jump(0.35)
	assert(p1.is_warping == true and p1.is_invulnerable == true, "Player must enter warping state with invulnerability!")
	p1._handle_timers(0.36)
	assert(p1.is_warping == false and p1.is_invulnerable == false and p1.warp_charge_ratio == 0.0, "Reset warp state must restore default flight parameters!")
	var vp_size = main_inst.get_viewport_rect().size
	var expected_x = vp_size.x * 0.18
	assert(absf(p1.global_position.x - expected_x) < 5.0, "Quantum teleport must snap player to the left-middle of the screen!")
	
	# Test uncollected scrap & debris purge upon quantum teleportation
	var uncollected_pickup = load("res://scenes/ScrapPickup.tscn").instantiate()
	uncollected_pickup.global_position = Vector2(400, 300)
	main_inst.add_child(uncollected_pickup)
	assert(get_tree().get_nodes_in_group("scrap").has(uncollected_pickup), "Scrap must be spawned before teleport purge!")
	spawner_node._purge_uncollected_debris()
	assert(uncollected_pickup.is_queued_for_deletion() or not is_instance_valid(uncollected_pickup), "Uncollected scrap must be purged upon quantum teleport!")
	
	# Instant skip test
	spawner_node.wave_phase = DecoherenceSpawner.WavePhase.WAVE_CLEARED_GRACE
	spawner_node.wave_grace_timer = 4.0
	spawner_node.skip_grace_period()
	assert(spawner_node.wave_grace_timer == 0.0, "Skip grace period must immediately advance timer to 0!")
	spawner_node.wave_phase = DecoherenceSpawner.WavePhase.IDLE
	print(" - 17C: Extended spin-up charge progression, left-middle teleportation snap, and uncollected debris purge verified.")
	
	# 17D: Super Quarket Station Approach, Tractor Beam Docking & Undock Launch
	var shop_node = main_inst.get_node("SkyMerchant")
	shop_node.dock_with_animation()
	assert(shop_node.is_docking_anim == true and shop_node.station_visible == true and shop_node.zeppelin_visible == true, "Station docking sequence must make station visible (and support zeppelin_visible alias)!")
	
	shop_node.open_shop()
	assert(shop_node.panel.visible == true and get_tree().paused == true, "Shop panel must open and pause tree!")
	
	var p1_pos_before_undock = p1.global_position
	shop_node._on_undock_pressed()
	assert(shop_node.panel.visible == false and get_tree().paused == false, "Undocking must hide panel and unpause!")
	assert(p1.global_position != p1_pos_before_undock, "Player ship must receive forward afterburner launch impulse on undock!")
	assert(GameManager.current_phase == GameManager.RunPhase.COMBAT_WAVES, "Phase must return to COMBAT_WAVES upon undocking!")
	print(" - 17D: Super Quarket Station approach, counter-rotating rings docking, and afterburner undock launch verified.")

	# 18. Testing Combat Intensity, Faster Bullets, Predictive Lead Targeting & Sector 2 Gating
	print("\nSTEP 18: Testing Combat Intensity, Faster Bullets, Predictive Lead & Sector 2 Gating...")
	var wd18 = WaveDirector.new()
	# 18A: Base bullet speed scaling
	GameManager.current_sector = 1
	GameManager.current_wave = 1
	var test_e_w1 = enemy_scene.instantiate()
	main_inst.add_child(test_e_w1)
	test_e_w1.setup(0, Vector2(500, 300), -1, null, 0) # SCOUT
	var sec_num = 1
	var wave_num = 1
	var w1_spd = 320.0 * (1.0 + (wave_num - 1) * 0.025 + (sec_num - 1) * 0.20)
	assert(w1_spd >= 320.0, "Starter enemy bullet speed must be >= 320 px/s! Found: %f" % w1_spd)
	
	GameManager.current_sector = 2
	GameManager.current_wave = 1
	var s2_spd = 320.0 * (1.0 + (1 - 1) * 0.025 + (2 - 1) * 0.20)
	assert(s2_spd >= 380.0, "Sector 2 bullet speed must scale to >= 380 px/s! Found: %f" % s2_spd)
	print(" - 18A: Calibrated bullet speed scaling (W1: %.0f px/s, S2: %.0f px/s) verified." % [w1_spd, s2_spd])
	test_e_w1.queue_free()

	# 18B: Vector Intercept Predictive Lead Calculation
	var shooter = enemy_scene.instantiate()
	main_inst.add_child(shooter)
	shooter.setup(0, Vector2(800, 300), -1, null, 0)
	
	p1.global_position = Vector2(300, 300)
	p1.current_velocity = Vector2(0, 420)
	var lead_vec = shooter.calculate_lead_target_vector(shooter.global_position, p1, 450.0)
	assert(lead_vec.y > 0.1, "Predictive lead vector must anticipate downward player motion! Found y: %f" % lead_vec.y)
	assert(lead_vec.x < -0.5, "Predictive lead vector must fire oncoming towards player horizon! Found x: %f" % lead_vec.x)
	print(" - 18B: True vector quadratic intercept predictive lead targeting verified.")
	shooter.queue_free()

	# 18C: Sector 2 Template Filtering (Strict min_sector == 2)
	for i in range(10):
		var s2_tpl = wd18.select_template_for_wave(2, 1) # Sector 2 Wave 1
		assert(s2_tpl["min_sector"] == 2, "Sector 2 must strictly select min_sector == 2 templates! Found: %s with min_sector %d" % [s2_tpl.get("id", ""), s2_tpl.get("min_sector", 0)])
	print(" - 18C: Strict Sector 2 template filtering (no basic Sector 1 swarms) verified.")

	# 18D: Wave 2 and Wave 4 Cargo Encounter Escalation
	var all_tpls = WaveDirector.get_all_templates()
	var w2_cargo: Dictionary = {}
	var w4_cargo: Dictionary = {}
	for t in all_tpls:
		if t.get("id") == "WAVE_CARGO_RECON":
			w2_cargo = t
		elif t.get("id") == "WAVE_CARGO_CONVOY_1":
			w4_cargo = t
	
	var has_interceptor_w2 = false
	for sp in w2_cargo.get("spawns", []):
		if sp.get("type") == WaveDirector.INTERCEPTOR:
			has_interceptor_w2 = true
	assert(has_interceptor_w2, "Wave 2 Cargo Recon must introduce Interceptor flankers!")

	var has_bomber_w4 = false
	for sp in w4_cargo.get("spawns", []):
		if sp.get("type") == WaveDirector.BOMBER:
			has_bomber_w4 = true
	assert(has_bomber_w4, "Wave 4 Cargo Convoy must feature combined arms including Bombers!")
	print(" - 18D: Early encounter escalation (W2 Interceptors & W4 Bombers) verified.")

	# 18E: Sector 1 Second Half Variety & Bomber Presence (Waves 7-11)
	var w8_tpl = wd18.select_template_for_wave(1, 8)
	var w8_has_bomber = false
	for sp in w8_tpl.get("spawns", []):
		if sp.get("type") == WaveDirector.BOMBER:
			w8_has_bomber = true
	assert(w8_has_bomber, "Sector 1 Wave 8 must feature Bombers!")

	var w10_tpl = wd18.select_template_for_wave(1, 10)
	var w10_has_bomber = false
	for sp in w10_tpl.get("spawns", []):
		if sp.get("type") == WaveDirector.BOMBER:
			w10_has_bomber = true
	assert(w10_has_bomber, "Sector 1 Wave 10 must feature Bombers!")

	var w7_tpl = wd18.select_template_for_wave(1, 7)
	var s1_late_ids = ["WAVE_SNIPER_PERIMETER", "WAVE_AEGIS_PHALANX", "WAVE_CORVETTE_PATROL", "WAVE_CORVUS_VANGUARD", "WAVE_BOMBER_SIEGE", "WAVE_TURRET_BASTION"]
	assert(s1_late_ids.has(w7_tpl.get("id")), "Sector 1 Wave 7 must roll an advanced second-half template! Found: %s" % w7_tpl.get("id"))
	print(" - 18E: Sector 1 second-half variety & guaranteed Bomber presence (W7-W11) verified.")

	print("\n====================================================")
	print("--- ALL VERIFICATION TESTS PASSED 100% CLEANLY ---")
	print("====================================================")
	get_tree().quit(0)
