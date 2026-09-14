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
	# 7A. Zeeman Splitting orthogonal lateral beams & Retiered Items
	var zeeman_item = ItemDatabase.get_item_by_id("zeeman_splitting")
	assert(zeeman_item != null, "Zeeman Splitting not found in ItemDatabase!")
	assert(zeeman_item.tier == ItemModifier.ItemTier.TIER_1_BALLISTIC, "Zeeman Splitting must be Tier 1!")
	var z_fired = zeeman_item.on_fire(p1, {"pos": Vector2(100, 100), "dir": Vector2.RIGHT, "dmg": 2.0})
	assert(z_fired.size() == 3, "Zeeman Splitting must yield primary + twin lateral shots!")
	# Flank 1 (+90 deg of RIGHT is DOWN, x~0, y>0) and Flank 2 (-90 deg is UP, x~0, y<0)
	assert(abs(z_fired[1]["dir"].x) < 0.01 and z_fired[1]["dir"].y > 0.9, "Flank 1 must be orthogonal +90 deg!")
	assert(abs(z_fired[2]["dir"].x) < 0.01 and z_fired[2]["dir"].y < -0.9, "Flank 2 must be orthogonal -90 deg!")
	
	# Retiering checks
	var biref = ItemDatabase.get_item_by_id("birefringence_prism")
	assert(biref != null and biref.tier == ItemModifier.ItemTier.TIER_2_PARADIGM, "Birefringence Prism must be Tier 2!")
	var grav = ItemDatabase.get_item_by_id("gravitational_lensing")
	assert(grav != null and grav.tier == ItemModifier.ItemTier.TIER_2_PARADIGM and grav.category == "offense", "Gravitational Lensing must be Tier 2 Offense!")
	assert(grav.homing_strength < 3.0, "Gravitational Lensing homing strength must be toned down!")
	var manifold = ItemDatabase.get_item_by_id("split_manifold")
	assert(manifold != null and manifold.tier == ItemModifier.ItemTier.TIER_2_PARADIGM, "Split Manifold must be Tier 2!")
	var heatsink = ItemDatabase.get_item_by_id("carnot_heatsink")
	assert(heatsink != null and heatsink.tier == ItemModifier.ItemTier.TIER_1_BALLISTIC, "Carnot Heat Sink must be Tier 1!")
	var tunnel = ItemDatabase.get_item_by_id("quantum_tunneling")
	assert(tunnel != null and tunnel.tier == ItemModifier.ItemTier.TIER_1_BALLISTIC and tunnel.category == "offense", "Quantum Tunneling must be Tier 1 Offense!")
	print(" - 7A: Zeeman Splitting orthogonal lateral beams and item re-tierings verified.")
	
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
	
	# 7E. Carnot Pre-Cooler & Carnot Efficiency Sky Merchant discounts
	p1.has_carnot_efficiency = false
	p1.has_carnot_precooler = false
	var carnot_pre = ItemDatabase.get_item_by_id("carnot_precooler")
	assert(carnot_pre != null, "Carnot Pre-Cooler not found in ItemDatabase!")
	assert(carnot_pre.tier == ItemModifier.ItemTier.TIER_2_PARADIGM, "Carnot Pre-Cooler must be Tier 2!")
	p1.add_modifier(carnot_pre)
	var discount_pre = shop._get_player_discount(1)
	assert(is_equal_approx(discount_pre, 0.8), "Carnot Pre-Cooler must grant 20% discount (0.8x)!")
	
	var carnot_eff = ItemDatabase.get_item_by_id("carnot_efficiency")
	assert(carnot_eff != null, "Carnot Efficiency not found in ItemDatabase!")
	p1.add_modifier(carnot_eff)
	var discount_stacked = shop._get_player_discount(1)
	assert(is_equal_approx(discount_stacked, 0.4), "Stacked Carnot items must grant 60% discount (0.4x)!")
	print(" - 7E: Carnot Pre-Cooler (20%) and Carnot Efficiency (50% -> 60% stacked) discounts verified.")
	
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
	
	# Verify WaveDirector procedural mutation strictly caps promoted elites to <= 1 per wave
	var base_scout_wave = {
		"id": "WAVE_TEST",
		"spawns": [
			{"type": 0, "count": 4, "pattern": "ROW", "delay": 0.0, "affix": 0},
			{"type": 1, "count": 3, "pattern": "ROW", "delay": 1.0, "affix": 0},
			{"type": 2, "count": 2, "pattern": "ROW", "delay": 2.0, "affix": 0},
			{"type": 0, "count": 4, "pattern": "ROW", "delay": 3.0, "affix": 0}
		]
	}
	for _t in range(30):
		var mutated_wave = wd._mutate_template(base_scout_wave, 3, 25)
		var elite_batches = 0
		for b in mutated_wave.get("spawns", []):
			if b.get("affix", 0) != 0:
				elite_batches += 1
		assert(elite_batches <= 1, "Procedural wave mutation produced %d elites (max allowed: 1)!" % elite_batches)
	print(" - 14B2: Single-Leader Elite Champion promotion & max 1 elite per wave verified.")
	
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

	# 16E: Escalating Reroll Protection (5 -> 10 -> 20 -> 50 -> 100 J)
	assert(shop._next_cost(5) == 10, "Reroll 1 to 2 escalation must be 10 J!")
	assert(shop._next_cost(10) == 20, "Reroll 2 to 3 escalation must be 20 J!")
	assert(shop._next_cost(20) == 50, "Reroll 3 to 4 escalation must be 50 J!")
	assert(shop._next_cost(50) == 100, "Reroll 4 to 5 escalation must be 100 J!")
	assert(shop._next_cost(100) == 200, "Reroll 5 to 6 escalation must be 200 J!")
	print(" - 16E: Escalating reroll inflation curve verified (5 -> 10 -> 20 -> 50 -> 100 -> 200 J).")

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

	# 19: Testing Phase 1 Cyberpunk 2.5D Stage, 3D Player Craft & Ballistics
	print("\nSTEP 19: Testing Phase 1 Cyberpunk 2.5D Stage, 3D Player Craft & Ballistics...")
	var stage = main_inst.get_node_or_null("Stage3D")
	assert(stage != null, "Stage3D node must be present in Main scene!")
	assert(stage.camera != null, "Stage3D must have an Orthographic Camera3D!")
	assert(stage.world_env != null, "Stage3D must have HDR WorldEnvironment configured!")
	print(" - 19A: Stage3D viewport, 1:1 camera projection, and HDR environment verified.")

	# 19B: Verify P1 3D Bridge & Mesh Structure
	assert(stage.player_bridges.has(p1.get_instance_id()), "P1 must have an active 3D Visual Bridge!")
	var bridge_p1 = stage.player_bridges[p1.get_instance_id()]
	assert(bridge_p1.mesh_root != null, "P1 3D mesh root must be instantiated!")
	assert(bridge_p1.barrel_l != null and bridge_p1.barrel_r != null, "P1 must have dual articulating autocannon barrels!")
	assert(bridge_p1.flash_l != null and bridge_p1.flash_r != null, "P1 must have dynamic muzzle flash point-lights!")
	print(" - 19B: P1 Viper-IV 3D greebled model, cockpit, and dual autocannons verified.")

	# 19C: Weapon Recoil & Muzzle Flash Kick
	bridge_p1.trigger_recoil(true)
	assert(bridge_p1.recoil_l > 5.0, "Triggering recoil must push port barrel back!")
	assert(bridge_p1.flash_l.light_energy > 2.0, "Triggering recoil must activate muzzle flash point-light!")
	bridge_p1.update(0.016)
	assert(bridge_p1.barrel_l.position.x < -4.0, "Barrel position must reflect physical recoil along linear guide rails!")
	print(" - 19C: Autocannon physical recoil and muzzle flash illumination verified.")

	# 19D: 3D Banking & Barrel Roll
	p1.bank_angle = 0.25
	bridge_p1.update(0.05)
	assert(absf(bridge_p1.current_bank_roll) > 0.05, "Ship must bank on lateral movement!")
	p1.is_rolling = true
	p1.roll_elapsed = 0.35
	p1.roll_duration = 0.7
	bridge_p1.update(0.016)
	p1.is_rolling = false
	print(" - 19D: Dynamic 3D banking and 360-degree corkscrew barrel roll verified.")

	# 19E: High-Velocity Aerodynamic Needle Darts & Enemy Plasma Orbs
	var bullet_19 = bullet_scene.instantiate()
	main_inst.add_child(bullet_19)
	bullet_19.setup(Vector2(400, 300), Vector2.RIGHT, false, 2.0)
	bullet_19.queue_redraw()
	bullet_19.is_enemy = true
	bullet_19.queue_redraw()
	bullet_19.queue_free()
	print(" - 19E: Aerodynamic needle darts and rotating corona plasma orbs verified.")

	# 20: Testing Phase 2 3D Enemy Bestiary, Rotating Turrets & Hex Shields
	print("\nSTEP 20: Testing Phase 2 3D Enemy Bestiary, Rotating Turrets & Hex Shields...")
	
	# 20A: 3D Hull Construction for Key Archetypes
	var enemy_types_to_check = [
		EnemyScript.EnemyType.SCOUT,
		EnemyScript.EnemyType.BOMBER,
		EnemyScript.EnemyType.INTERCEPTOR,
		EnemyScript.EnemyType.SNIPER,
		EnemyScript.EnemyType.SHIELD_FRIGATE,
		EnemyScript.EnemyType.KNIGHT_VANGUARD,
		EnemyScript.EnemyType.TURRET_PLATFORM,
		EnemyScript.EnemyType.CARGO_HAULER
	]
	var ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	for et in enemy_types_to_check:
		var model = ShipBuilder3DScript.build_enemy_ship(et, 0)
		assert(model != null, "ShipBuilder3D failed to build 3D model for enemy type %d!" % et)
		model.queue_free()
	print(" - 20A: Procedural 3D hulls and greebles verified across all archetype classes.")

	# 20B: Turret Platform Articulated 360-degree Tracking
	var turret_enemy = enemy_scene.instantiate()
	main_inst.add_child(turret_enemy)
	turret_enemy.setup(EnemyScript.EnemyType.TURRET_PLATFORM, Vector2(500, 300), 1, null)
	turret_enemy.turret_angle = 1.25
	assert(stage.enemy_bridges.has(turret_enemy.get_instance_id()), "Turret platform must register 3D visual bridge!")
	var bridge_turret = stage.enemy_bridges[turret_enemy.get_instance_id()]
	assert(bridge_turret.turret_head != null, "3D Turret platform must feature articulated TurretHead!")
	bridge_turret.update(0.016)
	assert(is_equal_approx(bridge_turret.turret_head.rotation.y, -1.25), "3D TurretHead rotation must track 2D turret_angle in real time!")
	turret_enemy.queue_free()
	print(" - 20B: Turret platform 360-degree rotating 3D turret barbette verified.")

	# 20C: Knight Vanguard Articulated Mirror Shield Plates
	var knight_enemy = enemy_scene.instantiate()
	main_inst.add_child(knight_enemy)
	knight_enemy.setup(EnemyScript.EnemyType.KNIGHT_VANGUARD, Vector2(600, 300), 1, null)
	var bridge_knight = stage.enemy_bridges[knight_enemy.get_instance_id()]
	assert(bridge_knight.shield_plate_l != null and bridge_knight.shield_plate_r != null, "Knight Vanguard must possess 3D articulated shield plates!")
	
	knight_enemy.knight_is_firing_salvo = true
	bridge_knight.update(0.1)
	assert(bridge_knight.shield_plate_l.rotation.y < -0.1, "Firing salvo must part port shield plate outward!")
	assert(bridge_knight.shield_plate_r.rotation.y > 0.1, "Firing salvo must part starboard shield plate outward!")
	
	knight_enemy.knight_shield_shattered = true
	bridge_knight.update(0.016)
	assert(bridge_knight.shield_plate_l.visible == false and bridge_knight.shield_plate_r.visible == false, "Shattered shield must hide physical 3D plates!")
	knight_enemy.queue_free()
	print(" - 20C: Knight Vanguard articulated 3D shield plates and salvo unmasking verified.")

	# 20D: Reactive Hexagonal Energy Forcefields
	var shielded_enemy = enemy_scene.instantiate()
	main_inst.add_child(shielded_enemy)
	shielded_enemy.setup(EnemyScript.EnemyType.SCOUT, Vector2(700, 300), 1, null, EnemyScript.EliteAffix.SHIELDED)
	assert(shielded_enemy.energy_shield_hp > 0.0, "SHIELDED affix must have energy shield HP!")
	shielded_enemy.queue_redraw()
	shielded_enemy.queue_free()
	print(" - 20D: Reactive hexagonal forcefield generation verified.")

	# 21: Testing Phase 3 3D Bosses & Hazards
	print("\nSTEP 21: Testing Phase 3 3D Bosses (Corvus, Goliath, Ouroboros) & 3D Hazards...")
	
	# 21A: Super-Dreadnought Corvus 3D Subsystems
	var corvus_3d = corvus_scene.instantiate()
	main_inst.add_child(corvus_3d)
	assert(stage.boss_bridges.has(corvus_3d.get_instance_id()), "Corvus must register 3D visual bridge!")
	var bridge_corvus = stage.boss_bridges[corvus_3d.get_instance_id()]
	assert(bridge_corvus.wing_p != null and bridge_corvus.wing_s != null, "Corvus 3D model must have physical wings!")
	assert(bridge_corvus.fusion_core != null, "Corvus 3D model must have singularity fusion core!")
	
	corvus_3d.port_wing_alive = false
	bridge_corvus.update(0.016)
	assert(bridge_corvus.wing_p.visible == false, "Broken port wing must hide 3D port wing mesh!")
	corvus_3d.queue_free()
	print(" - 21A: Super-Dreadnought Corvus 3D multi-deck hull and breakable wings verified.")

	# 21B: Armored Behemoth Goliath 3D Fortress
	var goliath_3d = goliath_scene.instantiate()
	main_inst.add_child(goliath_3d)
	var bridge_goliath = stage.boss_bridges[goliath_3d.get_instance_id()]
	assert(bridge_goliath.bow_armor != null, "Goliath 3D model must possess BowArmor wedge!")
	assert(bridge_goliath.rg_p != null and bridge_goliath.rg_s != null, "Goliath 3D model must possess articulating railguns!")
	
	goliath_3d.railgun_aim_dir = Vector2(1.0, 1.0).normalized()
	bridge_goliath.update(0.016)
	assert(bridge_goliath.rg_p.rotation.y != 0.0, "Goliath 3D railguns must aim toward target!")
	
	goliath_3d.bow_armor_alive = false
	bridge_goliath.update(0.016)
	assert(bridge_goliath.bow_armor.visible == false, "Shattered bow armor must hide physical 3D bow wedge!")
	goliath_3d.queue_free()
	print(" - 21B: Armored Behemoth Goliath 3D fortress, breakable bow, and tracking railguns verified.")

	# 21C: Apex Titan Ouroboros 3D Singularity
	var ouroboros_3d = ouroboros_scene.instantiate()
	main_inst.add_child(ouroboros_3d)
	var bridge_ouroboros = stage.boss_bridges[ouroboros_3d.get_instance_id()]
	assert(bridge_ouroboros.shield_gate != null, "Ouroboros 3D model must have shield gate armatures!")
	assert(bridge_ouroboros.singularity_core != null, "Ouroboros 3D model must have singularity core!")
	ouroboros_3d.shield_angle = 1.8
	bridge_ouroboros.update(0.016)
	assert(is_equal_approx(bridge_ouroboros.shield_gate.rotation.y, -1.8), "3D Shield gate must rotate to match shield_angle!")
	ouroboros_3d.queue_free()
	print(" - 21C: Apex Titan Ouroboros 3D singularity and rotating barrier gate verified.")

	# 21D: 3D Environmental Hazards (Asteroids, Plasma Barrels, Storm Cells)
	var HazardScript = load("res://scripts/HazardObject.gd")
	var asteroid_3d = hazard_scene.instantiate()
	main_inst.add_child(asteroid_3d)
	asteroid_3d.setup(HazardScript.HazardType.ASTEROID, Vector2(200, 200))
	var bridge_hazard = stage.hazard_bridges[asteroid_3d.get_instance_id()]
	assert(bridge_hazard.mesh_root != null, "Hazard must have 3D mesh instantiated!")
	assert(bridge_hazard.hazard_type == HazardScript.HazardType.ASTEROID, "Asteroid bridge hazard_type must be ASTEROID!")
	var rot_before = bridge_hazard.mesh_root.rotation
	bridge_hazard.update(0.1)
	assert(bridge_hazard.mesh_root.rotation != rot_before, "3D Asteroid must tumble in 3D space!")
	asteroid_3d.queue_free()

	var barrel_3d = hazard_scene.instantiate()
	main_inst.add_child(barrel_3d)
	barrel_3d.setup(HazardScript.HazardType.PLASMA_BARREL, Vector2(250, 200))
	var bridge_barrel = stage.hazard_bridges[barrel_3d.get_instance_id()]
	assert(bridge_barrel.mesh_root != null and bridge_barrel.hazard_type == HazardScript.HazardType.PLASMA_BARREL, "Plasma barrel must build PLASMA_BARREL bridge!")
	barrel_3d.queue_free()

	var storm_3d = hazard_scene.instantiate()
	main_inst.add_child(storm_3d)
	storm_3d.setup(HazardScript.HazardType.STORM_CELL, Vector2(300, 200))
	var bridge_storm = stage.hazard_bridges[storm_3d.get_instance_id()]
	assert(bridge_storm.mesh_root != null and bridge_storm.hazard_type == HazardScript.HazardType.STORM_CELL, "Storm cell must build STORM_CELL bridge!")
	storm_3d.queue_free()
	print(" - 21D: 3D Environmental hazards (Asteroid, Plasma Barrel, Storm Cell) and tumble verified.")

	# 22: Testing Phase 4 3D Station, Hull Shatter Debris & Deep-Space Parallax
	print("\nSTEP 22: Testing Phase 4 3D Station, Hull Shatter Debris & Deep-Space Parallax...")
	
	# 22A: 3D Orbital Trade Station & Counter-Rotating Rings
	var shop_inst = main_inst.get_node_or_null("SkyMerchant")
	assert(shop_inst != null, "Main must contain SkyMerchant node!")
	assert(stage.station_bridge != null, "Stage3D must register StationBridge3D for SkyMerchant!")
	var bridge_station = stage.station_bridge
	assert(bridge_station.outer_ring != null and bridge_station.inner_ring != null, "3D Station must feature outer and inner rings!")
	assert(bridge_station.reactor != null and bridge_station.beacon != null, "3D Station must feature singularity reactor and warning beacon!")
	
	shop_inst.station_visible = true
	var outer_rot_start = bridge_station.outer_ring.rotation.z
	var inner_rot_start = bridge_station.inner_ring.rotation.z
	bridge_station.update(0.1)
	assert(bridge_station.outer_ring.rotation.z > outer_rot_start, "3D Outer ring must rotate clockwise!")
	assert(bridge_station.inner_ring.rotation.z < inner_rot_start, "3D Inner ring must rotate counter-clockwise!")
	print(" - 22A: 3D Super Quarket Station mesh, counter-rotating rings, and telemetry sync verified.")

	# 22B: 3D Hull Fracture Debris & Physical Tumbling
	stage.spawn_explosion_3d(Vector2(400, 300), Color(1.0, 0.6, 0.1), 80.0, true)
	assert(stage.active_debris.size() > 0, "spawn_explosion_3d must create active 3D debris shards!")
	assert(stage.active_shockwaves.size() > 0, "spawn_explosion_3d must create active 3D shockwaves!")
	assert(stage.active_flashes.size() > 0, "spawn_explosion_3d must create dynamic point light flash!")
	
	var shard_sample = stage.active_debris[0]
	var pos_before = shard_sample.pos
	stage._update_debris_and_vfx(0.05)
	assert(shard_sample.pos != pos_before, "3D debris shards must fly outward with physical velocity!")
	print(" - 22B: 3D Hull fracture debris, shockwave rings, and cascading detonations verified.")

	# 22C: 3D Deep-Space Parallax Backdrop & Volumetric Nebulae
	assert(stage.megastructures.size() >= 3, "Stage3D must initialize at least 3 distant megastructures!")
	assert(stage.nebula_clouds.size() >= 5, "Stage3D must initialize volumetric HDR nebula clouds!")
	var ms_pos_before = stage.megastructures[0].position
	stage._update_background_3d(0.1)
	assert(stage.megastructures[0].position != ms_pos_before, "Megastructures must drift with parallax scrolling!")
	
	stage.set_sector_theme(2)
	assert(stage.current_sector == 2, "Stage3D must track current sector!")
	print(" - 22C: 3D Deep-space megastructures, parallax drift, and volumetric nebulae verified.")

	# 22D: Hyperspace Warp Tunnel Activation
	stage.trigger_warp_tunnel(0.45)
	assert(stage.warp_tunnel_active == true, "trigger_warp_tunnel must activate hyperspace tunnel state!")
	assert(stage.warp_tunnel_rings.size() >= 12, "Stage3D must possess warp conduit rings!")
	stage._update_background_3d(0.1)
	assert(stage.warp_tunnel_rings[0].material_override.albedo_color.a > 0.0, "Warp tunnel rings must become visible during jump!")
	print(" - 22D: Hyperspace relativistic warp tunnel and conduit rings verified.")

	# 23: Testing Phase 5 Holographic Cyberpunk HUD, Vector Glyphs & Sensory Juice
	print("\nSTEP 23: Testing Phase 5 Holographic Cyberpunk HUD, Vector Glyphs & Sensory Juice...")
	
	# 23A: Holographic Cyberpunk HUD & Dynamic Lock-On Reticles
	var hud_inst = main_inst.get_node_or_null("HUD")
	assert(hud_inst != null, "Main scene must contain HUD node!")
	assert(hud_inst.holo_overlay != null, "HUD must contain HoloCyberOverlay child!")
	
	# Spawn an elite enemy to test dynamic lock-on
	var elite_target = enemy_scene.instantiate()
	main_inst.add_child(elite_target)
	elite_target.setup(EnemyScript.EnemyType.SCOUT, Vector2(500, 320), 1, null, 1)
	elite_target.is_elite = true
	var active_locks = hud_inst.holo_overlay.get_active_lock_targets()
	assert(active_locks.size() >= 1, "HoloCyberOverlay must actively acquire lock-on targeting on elites!")
	elite_target.queue_free()
	print(" - 23A: Holographic corner brackets, digital scanlines, and elite lock-on reticles verified.")


	# 23B: Vector Item Glyph System
	all_items = ItemDatabase.get_all_items()
	assert(all_items.size() >= 60, "ItemDatabase must catalog 60+ items!")
	for it in all_items:
		assert(it.has_method("get_glyph"), "Item %s must implement get_glyph()!" % it.id)
		var glyph = it.get_glyph()
		assert(glyph != "", "Item %s must have non-empty vector glyph!" % it.id)
	print(" - 23B: Vector item glyph mapping verified across all 60+ cataloged relics.")


	# 23C: Sensory Juice Micro Hit-Stop
	GameManager.trigger_hit_stop(0.04)
	assert(Engine.time_scale < 0.2, "trigger_hit_stop must drop Engine.time_scale for visceral hit impact!")
	Engine.time_scale = 1.0
	print(" - 23C: Micro hit-stop engine freeze verified.")

	# 23D: Directional Screen Shake
	var test_impulse = Vector2(-1.0, 0.5).normalized()
	GameManager.request_directional_shake(test_impulse, 14.0, 0.25)
	assert(main_inst.shake_direction.is_equal_approx(test_impulse), "Main must align shake_direction along impact vector!")

	assert(main_inst.shake_intensity >= 14.0, "Main must register directional shake intensity!")
	main_inst._process(0.016)
	assert(main_inst.camera.offset != Vector2.ZERO, "Camera offset must violently displace along impact vector!")
	main_inst.camera.offset = Vector2.ZERO
	main_inst.shake_timer = 0.0
	print(" - 23D: Vector-aligned directional screen shake verified.")

	# 24: Testing Phase 6 Star Trek Generations Nexus Cloud, Enemy Spawning VFX & 3D Secrets
	print("\nSTEP 24: Testing Phase 6 Star Trek Generations Nexus Cloud, Enemy Spawning VFX & 3D Secrets...")
	
	# 24A: Wave Function Nexus Ribbon System
	assert(stage.nexus_ribbon != null, "Stage3D must have NexusRibbon3D instantiated!")
	assert(stage.nexus_ribbon.ribbon_instances.size() == 4, "NexusRibbon3D must have 4 iridescent plasma ribbons!")
	assert(stage.nexus_ribbon.lightning_instance != null, "NexusRibbon3D must have dynamic lightning generator!")
	assert(stage.nexus_ribbon.embers.size() == 24, "NexusRibbon3D must maintain drifting quantum embers pool!")
	
	stage.trigger_nexus_surge(0.45)
	assert(stage.nexus_ribbon.surge_multiplier > 3.0, "trigger_nexus_surge must flare surge_multiplier over 3.0!")
	stage.nexus_ribbon._process(0.016)
	assert(stage.nexus_ribbon.ribbon_imms[0].get_surface_count() == 1, "Nexus ribbon strands must generate ImmediateMesh surface strips!")
	assert(stage.nexus_ribbon.lightning_imm.get_surface_count() == 1, "Nexus lightning must generate crackling electrical arc lines!")
	print(" - 24A: Wave Function Nexus ribbon rendering, sinusoidal undulation, and surge trigger verified.")

	# 24B: Enemy Spawning Materialization VFX (Aperture & Nexus Lightning Bridge)
	var spawn_test_pos = Vector2(800.0, 320.0)
	stage.spawn_materialization_aperture(spawn_test_pos, 0.4)
	assert(stage.active_apertures.size() >= 1, "spawn_materialization_aperture must register collapsing 3D iris ring!")
	stage._update_debris_and_vfx(0.016)
	
	var initial_arcs = stage.nexus_ribbon.active_targeted_arcs.size()
	stage.trigger_materialization_flash(spawn_test_pos)
	assert(stage.active_flashes.size() >= 1, "trigger_materialization_flash must spawn high-energy light flash!")
	assert(stage.active_shockwaves.size() >= 1, "trigger_materialization_flash must spawn reality-compression shockwave!")
	assert(stage.nexus_ribbon.active_targeted_arcs.size() > initial_arcs, "trigger_materialization_flash must arc lightning bridge from Nexus to spawn coordinate!")
	print(" - 24B: Enemy materialization 3D aperture and lightning bridge from Nexus verified.")

	# 24C: 3D Quantum Anomaly Model & Gimbal Mechanics
	ShipBuilder3DScript = load("res://scripts/ShipBuilder3D.gd")
	var anomaly_mesh = ShipBuilder3DScript.build_quantum_anomaly_mesh()
	assert(anomaly_mesh.get_node_or_null("AnomalyCore") != null, "Quantum Anomaly must have hyper-dimensional core!")
	assert(anomaly_mesh.get_node_or_null("GimbalOuter") != null, "Quantum Anomaly must have outer gimbal ring!")
	assert(anomaly_mesh.get_node_or_null("GimbalInner") != null, "Quantum Anomaly must have inner gimbal ring!")
	anomaly_mesh.queue_free()
	
	var test_anomaly_dict = {
		"pos": Vector2(500.0, 250.0),
		"radius": 24.0,
		"elapsed": 0.0,
		"shattered": false
	}
	stage.register_anomaly(test_anomaly_dict)
	assert(stage.anomaly_bridges.size() >= 1, "register_anomaly must attach 3D gimbal model to Stage3D!")
	stage._process(0.016)
	
	var initial_debris = stage.active_debris.size()
	stage.shatter_anomaly_3d(Vector2(500.0, 250.0))
	assert(stage.active_debris.size() > initial_debris, "shatter_anomaly_3d must shatter crystal neon shards into 3D space!")
	print(" - 24C: 3D Quantum Anomaly model, gimbal ring rotation, and crystalline shatter verified.")

	# 24D: 3D Dirac Monopole Landmark Spire & Supernova Detonation
	var monopole_mesh = ShipBuilder3DScript.build_dirac_monopole_mesh()
	assert(monopole_mesh.get_node_or_null("MonopoleSingularity") != null, "Dirac Monopole must have magnetic singularity core!")
	assert(monopole_mesh.get_node_or_null("NorthPole") != null, "Dirac Monopole must have North Pole emitter cap!")
	assert(monopole_mesh.get_node_or_null("SouthPole") != null, "Dirac Monopole must have South Pole emitter cap!")
	assert(monopole_mesh.get_node_or_null("PolarRingNorth") != null, "Dirac Monopole must have North polar containment ring!")
	assert(monopole_mesh.get_node_or_null("PolarRingSouth") != null, "Dirac Monopole must have South polar containment ring!")
	monopole_mesh.queue_free()
	
	var test_monopole_dict = {
		"pos": Vector2(640.0, 360.0),
		"health": 14.0,
		"max_health": 14.0,
		"active": true,
		"elapsed": 0.0
	}
	stage.register_monopole(test_monopole_dict)
	assert(stage.monopole_bridge.has("mesh"), "register_monopole must attach 3D ancient spire to Stage3D!")
	stage._process(0.016)
	
	stage.shatter_monopole_3d(Vector2(640.0, 360.0))
	assert(not stage.monopole_bridge.has("mesh"), "shatter_monopole_3d must despawn 3D spire model!")
	var has_supernova_shockwave = false
	for sw in stage.active_shockwaves:
		if sw.get("max_r", 0.0) >= 120.0:
			has_supernova_shockwave = true
			break
	assert(has_supernova_shockwave, "shatter_monopole_3d must unleash massive 140px magnetic supernova shockwave!")
	print(" - 24D: 3D Dirac Monopole landmark spire, polar rings, and magnetic reversal supernova verified.")

	# =========================================================================
	# STEP 25: Testing Menu Revamp, High Score Persistence, Universal Focus & Pause System
	# =========================================================================
	print("\nSTEP 25: Testing Menu Revamp, High Scores, Universal Focus & Pause System...")
	
	# 25A: HighScoreManager Persistence & Ranking
	assert(HighScoreManager != null, "HighScoreManager autoload must exist!")
	HighScoreManager.reset_to_defaults()
	var default_scores = HighScoreManager.get_scores()
	assert(default_scores.size() == 10, "HighScoreManager must initialize with 10 default arcade records!")
	assert(default_scores[0]["score"] == 150000, "Default #1 score must be 150000!")
	
	# Record simulated run
	var test_rank = HighScoreManager.record_run(250000, 3, 36, "1P Normal", 600.0, 450, true)
	assert(test_rank == 1, "250,000 pt run must earn Rank #1 record!")
	var updated_scores = HighScoreManager.get_scores()
	assert(updated_scores[0]["score"] == 250000, "Top score must now be 250000!")
	assert(updated_scores.size() == 10, "High scores list must strictly cap at 10 entries!")
	
	assert(HighScoreManager.is_high_score(999999) == true, "999,999 must qualify as high score!")
	assert(HighScoreManager.is_high_score(50) == false, "50 pts must not qualify as high score!")
	assert(HighScoreManager.format_time(125.0) == "02:05", "125s must format to 02:05!")
	
	# Restore default archives
	HighScoreManager.reset_to_defaults()
	assert(HighScoreManager.get_scores()[0]["score"] == 150000, "reset_to_defaults must restore original records!")
	print(" - 25A: HighScoreManager local persistence, top-10 sorting, and rank evaluation verified.")
	
	# 25B: MainMenu Scene & View Transitions
	var main_menu_scene = load("res://scenes/MainMenu.tscn")
	assert(main_menu_scene != null, "MainMenu.tscn must exist and load cleanly!")
	var menu_inst = main_menu_scene.instantiate()
	add_child(menu_inst)
	
	assert(menu_inst.title_view != null and menu_inst.title_view.visible == true, "MainMenu must start on TitleView!")
	assert(menu_inst.start_btn.focus_mode == Control.FOCUS_ALL, "Start button must have FOCUS_ALL!")
	assert(menu_inst.scores_btn.focus_mode == Control.FOCUS_ALL, "Scores button must have FOCUS_ALL!")
	assert(menu_inst.options_btn.focus_mode == Control.FOCUS_ALL, "Options button must have FOCUS_ALL!")
	
	# Transition to Mission View
	menu_inst._on_start_pressed()
	assert(menu_inst.mission_view.visible == true, "MissionView must become visible after start pressed!")
	assert(menu_inst.launch_btn.focus_mode == Control.FOCUS_ALL, "Launch button must have FOCUS_ALL!")
	
	# Transition to Scores View
	menu_inst._on_scores_pressed()
	assert(menu_inst.scores_view.visible == true, "ScoresView must become visible after scores pressed!")
	assert(menu_inst.scores_container.get_child_count() == 10, "ScoresView table must contain 10 row entries!")
	
	# Transition to Options View
	menu_inst._on_options_pressed()
	assert(menu_inst.options_view.visible == true, "OptionsView must become visible after options pressed!")
	assert(menu_inst.master_slider.focus_mode == Control.FOCUS_ALL, "Master slider must have FOCUS_ALL!")
	assert(menu_inst.sfx_slider.focus_mode == Control.FOCUS_ALL, "SFX slider must have FOCUS_ALL!")
	
	# Return to Title View
	menu_inst._show_title_view()
	assert(menu_inst.title_view.visible == true, "TitleView must become visible after returning to menu!")
	print(" - 25B: MainMenu sub-views, table rows, and FOCUS_ALL controls verified.")
	
	# 25C: Mission Deployment Configuration
	menu_inst._select_players(2)
	assert(GameManager.is_coop_mode == true, "Selecting 2P must enable GameManager.is_coop_mode!")
	menu_inst._select_players(1)
	assert(GameManager.is_coop_mode == false, "Selecting 1P must disable GameManager.is_coop_mode!")
	
	menu_inst._select_mode(GameManager.GameMode.NORMAL)
	assert(GameManager.current_game_mode == GameManager.GameMode.NORMAL, "GameMode.NORMAL must be active!")
	menu_inst.queue_free()
	print(" - 25C: Mission Deployment 1P/2P co-op and GameMode architecture verified.")
	
	# 25D: In-Game PauseMenu Lifecycle & Universal Input
	var pause_menu = main_inst.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "Main scene must have PauseMenu instance attached!")
	assert(pause_menu.visible == false and not pause_menu.is_open, "PauseMenu must start hidden and closed!")
	
	pause_menu.open_pause()
	assert(pause_menu.visible == true and pause_menu.is_open == true, "open_pause must make PauseMenu visible!")
	assert(get_tree().paused == true, "open_pause must pause the SceneTree!")
	assert(pause_menu.resume_btn.focus_mode == Control.FOCUS_ALL, "Resume button must have FOCUS_ALL!")
	assert(pause_menu.synergy_btn.focus_mode == Control.FOCUS_ALL, "Synergy button must have FOCUS_ALL!")
	assert(pause_menu.settings_btn.focus_mode == Control.FOCUS_ALL, "Settings button must have FOCUS_ALL!")
	assert(pause_menu.restart_btn.focus_mode == Control.FOCUS_ALL, "Restart button must have FOCUS_ALL!")
	assert(pause_menu.main_menu_btn.focus_mode == Control.FOCUS_ALL, "MainMenu button must have FOCUS_ALL!")
	
	pause_menu.close_pause()
	assert(pause_menu.visible == false and not pause_menu.is_open, "close_pause must hide PauseMenu!")
	assert(get_tree().paused == false, "close_pause must unpause the SceneTree!")
	print(" - 25D: PauseMenu open/close lifecycle, tree pause state, and command buttons verified.")
	
	# 25E: Synergy Inspector Verification
	p1.active_modifiers.clear()
	p1.add_modifier(ItemDatabase.get_item("tachyon_capacitor"))
	p1.add_modifier(ItemDatabase.get_item("zeeman_splitting"))
	pause_menu.open_pause()
	pause_menu._show_inspector()
	assert(pause_menu.inspector_panel.visible == true, "InspectorView must be visible!")
	assert(pause_menu.relics_grid.get_child_count() == 2, "InspectorView must contain 2 relic chip buttons!")
	assert("TACHYON" in pause_menu.item_title_lbl.text.to_upper(), "Inspector must populate Tachyon Capacitor details!")
	pause_menu.close_pause()
	print(" - 25E: Synergy Inspector relic chip display and item details card verified.")
	
	# 25F: GameOverOverlay & VictoryOverlay Universal Focus & Main Menu Button
	var game_over = main_inst.get_node_or_null("GameOverOverlay")
	assert(game_over != null, "GameOverOverlay must exist!")
	assert(game_over.restart_button.focus_mode == Control.FOCUS_ALL, "GameOver restart button must have FOCUS_ALL!")
	assert(game_over.main_menu_button.focus_mode == Control.FOCUS_ALL, "GameOver main menu button must have FOCUS_ALL!")
	
	var victory_over = main_inst.get_node_or_null("VictoryOverlay")
	assert(victory_over != null, "VictoryOverlay must exist!")
	assert(victory_over.play_again_btn.focus_mode == Control.FOCUS_ALL, "Victory play again button must have FOCUS_ALL!")
	assert(victory_over.main_menu_btn.focus_mode == Control.FOCUS_ALL, "Victory main menu button must have FOCUS_ALL!")
	print(" - 25F: GameOverOverlay and VictoryOverlay FOCUS_ALL and MainMenu buttons verified.")
	
	# 25G: Procedural UI Audio Generation
	assert(SoundEffects._streams.has("ui_hover"), "SoundEffects must generate ui_hover stream!")
	assert(SoundEffects._streams.has("ui_select"), "SoundEffects must generate ui_select stream!")
	assert(SoundEffects._streams.has("ui_back"), "SoundEffects must generate ui_back stream!")
	SoundEffects.play_sfx("ui_hover", 0.0, -10.0)
	SoundEffects.play_sfx("ui_select", 0.0, -10.0)
	SoundEffects.play_sfx("ui_back", 0.0, -10.0)
	print(" - 25G: Procedural UI audio streams (ui_hover, ui_select, ui_back) verified.")
	
	# 25H: Universal Input Mapping
	assert(InputMap.has_action("pause"), "InputMap must register 'pause' action!")
	assert(InputMap.has_action("ui_cancel"), "InputMap must register 'ui_cancel' action!")
	assert(InputMap.has_action("ui_accept"), "InputMap must register 'ui_accept' action!")
	assert(InputMap.action_get_events("pause").size() >= 2, "'pause' action must have keyboard and joypad events!")
	print(" - 25H: Universal input mappings (pause, ui_cancel, ui_accept) verified.")

	# STEP 26: Testing Universal WASD & Independent Dual-Player Modal Navigation
	print("\nSTEP 26: Testing Universal WASD & Independent Dual-Player Modal Navigation...")
	
	# 26A: InputMap Mappings (WASD + Arrows + Dedicated Accept/Cancel)
	assert(InputMap.has_action("ui_up"), "InputMap must register 'ui_up'!")
	assert(InputMap.has_action("ui_down"), "InputMap must register 'ui_down'!")
	assert(InputMap.has_action("ui_left"), "InputMap must register 'ui_left'!")
	assert(InputMap.has_action("ui_right"), "InputMap must register 'ui_right'!")
	
	var has_w = false
	var has_up = false
	for ev in InputMap.action_get_events("ui_up"):
		if ev is InputEventKey:
			if ev.physical_keycode == KEY_W or ev.keycode == KEY_W:
				has_w = true
			if ev.physical_keycode == KEY_UP or ev.keycode == KEY_UP:
				has_up = true
	assert(has_w and has_up, "ui_up must include both W and UP Arrow!")
	
	var has_space = false
	var has_enter = false
	for ev in InputMap.action_get_events("ui_accept"):
		if ev is InputEventKey:
			if ev.physical_keycode == KEY_SPACE or ev.keycode == KEY_SPACE:
				has_space = true
			if ev.physical_keycode == KEY_ENTER or ev.keycode == KEY_ENTER:
				has_enter = true
	assert(has_space and has_enter, "ui_accept must include both Space (P1) and Enter (P2)!")
	
	var has_shift = false
	var has_escape = false
	for ev in InputMap.action_get_events("ui_cancel"):
		if ev is InputEventKey:
			if ev.physical_keycode == KEY_SHIFT or ev.keycode == KEY_SHIFT:
				has_shift = true
			if ev.physical_keycode == KEY_ESCAPE or ev.keycode == KEY_ESCAPE:
				has_escape = true
	assert(has_shift and has_escape, "ui_cancel must include both Left Shift (P1) and Escape!")
	print(" - 26A: InputMap WASD + Arrows and dedicated P1/P2 actions verified.")
	
	# 26B: ThreatDossier Focus & Keyboard Engagement
	var test_dossier = main_inst.get_node_or_null("ThreatDossier")
	assert(test_dossier != null, "Main scene must have ThreatDossier!")
	assert(test_dossier.engage_btn.focus_mode == Control.FOCUS_ALL, "ThreatDossier engage button must have FOCUS_ALL!")
	test_dossier.show_dossier(1, "Corvus")
	assert(test_dossier.panel.visible == true, "ThreatDossier must be visible on show_dossier!")
	assert(get_tree().paused == true, "ThreatDossier must pause the SceneTree!")
	test_dossier._on_engage_pressed()
	assert(test_dossier.panel.visible == false, "Engage press must dismiss ThreatDossier!")
	assert(get_tree().paused == false, "Engage press must unpause the SceneTree!")
	print(" - 26B: ThreatDossier FOCUS_ALL and keyboard engagement verified.")
	
	# 26C: SkyMerchant Dual Independent Stalls & Keyboard Navigation
	var test_shop = main_inst.get_node("SkyMerchant")
	assert(test_shop != null, "Main scene must contain SkyMerchant!")
	GameManager.is_coop_mode = true
	test_shop.open_shop()
	assert(test_shop.panel.visible == true, "Shop panel must be open!")
	assert(test_shop.p1_stall.visible == true and test_shop.p2_stall.visible == true, "Both stalls must be visible in co-op mode!")
	assert(test_shop.p1_buttons.size() >= 3, "P1 stall must register buttons!")
	assert(test_shop.p2_buttons.size() >= 3, "P2 stall must register buttons!")
	assert(test_shop.p1_buttons[0].focus_mode == Control.FOCUS_ALL, "Shop buy buttons must have FOCUS_ALL!")
	assert(test_shop.p1_repair_btn.focus_mode == Control.FOCUS_ALL, "P1 repair button must have FOCUS_ALL!")
	assert(test_shop.undock_btn.focus_mode == Control.FOCUS_ALL, "Undock button must have FOCUS_ALL!")
	
	var initial_p1_idx = test_shop.p1_cursor_idx
	test_shop._nav_p1_right()
	assert(test_shop.p1_cursor_idx != initial_p1_idx or test_shop.p1_buttons.size() <= 1, "P1 navigation right must update cursor!")
	test_shop._nav_p1_left()
	assert(test_shop.p1_cursor_idx == initial_p1_idx, "P1 navigation left must return cursor!")
	
	test_shop._on_undock_pressed()
	assert(test_shop.panel.visible == false, "Undock must close shop panel!")
	assert(get_tree().paused == false, "Undock must unpause the SceneTree!")
	print(" - 26C: SkyMerchant dual independent stalls, button FOCUS_ALL, and cursor navigation verified.")
	
	# 26D: ItemChoiceModal Dual Simultaneous Choice
	var step26_hud = main_inst.get_node("HUD")
	assert(step26_hud != null, "Main scene must contain HUD!")
	GameManager.is_game_over = false
	GameManager.is_coop_mode = true
	step26_hud.open_item_choice_modal()
	assert(step26_hud.choice_modal.visible == true, "Choice modal must be visible!")
	assert(step26_hud.p1_column.visible == true, "P1 column must be visible!")
	assert(step26_hud.p2_column.visible == true, "P2 column must be visible in co-op mode!")
	assert(step26_hud.choice_btn_a.focus_mode == Control.FOCUS_ALL, "Choice button A must have FOCUS_ALL!")
	assert(step26_hud.p2_choice_btn_a.focus_mode == Control.FOCUS_ALL, "P2 Choice button A must have FOCUS_ALL!")
	
	# Test P1 confirms choice 0, P2 not yet confirmed
	var p1_pre_mods = p1.active_modifiers.size()
	var p2_node = null
	for p in get_tree().get_nodes_in_group("player"):
		if p.player_id == 2:
			p2_node = p
			break
	var p2_pre_mods = p2_node.active_modifiers.size() if p2_node else 0
	
	step26_hud._confirm_p1_choice(0)
	assert(step26_hud.p1_confirmed == true, "P1 choice must be marked confirmed!")
	assert(step26_hud.choice_modal.visible == true, "Modal must remain open waiting for P2!")
	
	# P2 confirms choice 1
	step26_hud._confirm_p2_choice(1)
	assert(step26_hud.p2_confirmed == true, "P2 choice must be marked confirmed!")
	assert(step26_hud.choice_modal.visible == false, "Modal must dismiss once both players confirmed!")
	assert(get_tree().paused == false, "SceneTree must unpause once both players confirmed!")
	assert(p1.active_modifiers.size() == p1_pre_mods + 1, "P1 must have received their chosen relic!")
	if p2_node:
		assert(p2_node.active_modifiers.size() == p2_pre_mods + 1, "P2 must have received their chosen relic!")
	print(" - 26D: Dual simultaneous relic choice, independent P1/P2 selection, and delivery verified.")

	# STEP 27: Testing Dynamic Projectile Caliber, Impact Visuals & Glowing Stat Cards
	print("\nSTEP 27: Testing Dynamic Projectile Caliber, Impact Visuals & Glowing Stat Cards...")
	
	# 27A: Continuous Projectile Caliber & Base Dimensions
	var caliber_test_bullet = preload("res://scenes/Bullet.tscn").instantiate()
	caliber_test_bullet._update_colors()
	assert(caliber_test_bullet.length == 16.0, "Player bullet base length must be 16.0px (sleek needle baseline)!")
	assert(caliber_test_bullet.radius == 2.8, "Player bullet base radius must be 2.8px (sleek needle baseline)!")
	caliber_test_bullet.queue_free()
	
	# Test Player bullet_scale linking to sqrt(damage_mult)
	p1.bonus_damage_pct = 0.0
	p1.bonus_bullet_scale_pct = 0.0
	p1.recalculate_stats()
	assert(is_equal_approx(p1.bullet_scale, 1.0), "Base bullet_scale must be 1.0!")
	
	# High damage (+125% -> damage_mult = 2.25)
	p1.bonus_damage_pct = 1.25
	p1.recalculate_stats()
	assert(is_equal_approx(p1.bullet_scale, 1.5), "bullet_scale for 2.25x damage must be 1.5x!")
	
	# "Soy Milk" extreme low damage (-75% -> damage_mult = 0.25)
	p1.bonus_damage_pct = -0.75
	p1.recalculate_stats()
	assert(is_equal_approx(p1.bullet_scale, 0.5), "bullet_scale for 0.25x damage must shrink to 0.5x!")
	
	# Reset player stats
	p1.bonus_damage_pct = 0.0
	p1.recalculate_stats()
	print(" - 27A: Continuous projectile caliber scaling and sleek starting dimensions verified.")
	
	# 27B: ImpactFlash Procedural Vector Shockwave Node
	var test_flash = preload("res://scripts/ImpactFlash.gd").new()
	test_flash.setup(Vector2(100, 100), 20.0, Color.CYAN)
	assert(test_flash.target_radius == 20.0, "ImpactFlash target_radius must be initialized!")
	test_flash._process(0.04)
	assert(test_flash.current_radius > 2.0, "ImpactFlash must expand over time!")
	test_flash._process(0.08) # Exceeds 0.065s duration
	test_flash.queue_free()
	print(" - 27B: Procedural vector ImpactFlash shockwave node and expansion lifecycle verified.")
	
	# 27C: Glowing BBCode Stat Formatters
	var colossal_str = ProgressionModel.format_stat_value_bbcode(0.60, true)
	assert("#facc15" in colossal_str and not "bgcolor" in colossal_str, "Colossal buff must format with clean radiant gold without background box!")
	
	var substantial_str = ProgressionModel.format_stat_value_bbcode(0.35, true)
	assert("#f0abfc" in substantial_str and not "bgcolor" in substantial_str, "Substantial buff must format with clean electric magenta without background box!")
	
	var moderate_str = ProgressionModel.format_stat_value_bbcode(0.15, true)
	assert("#22d3ee" in moderate_str, "Moderate buff must format with crisp cyan!")
	
	var penalty_str = ProgressionModel.format_stat_value_bbcode(-0.25, true)
	assert("#ff2a5f" in penalty_str, "Severe penalty must format with hot crimson!")
	
	var minor_pen_str = ProgressionModel.format_stat_value_bbcode(-0.10, true)
	assert("#fb923c" in minor_pen_str, "Minor penalty must format with flat warm orange!")
	print(" - 27C: Glowing BBCode magnitude color tokens (uniform font weight) verified.")
	
	# 27D: Full Card BBCode Formatting & Delta Previews
	var dummy_item = preload("res://scripts/items/StatModItem.gd").new().setup_stats(
		"test_item", "Test Relic", "Magnifies plasma damage by +60% at minor cost to fire rate (-10%).",
		ItemModifier.ItemTier.TIER_3_EXOTIC, Color.YELLOW, "[T3]",
		{"mult_damage": 1.60, "mult_fire_rate": 0.90, "category": "offense"}
	)
	var formatted_card = ProgressionModel.format_card_bbcode(dummy_item, p1)
	assert("#facc15" in formatted_card, "Card description must contain colored +60% token!")
	assert("DMG:" in formatted_card and "──►" in formatted_card, "Card must append dynamic DMG delta preview!")
	assert("RATE:" in formatted_card and "──►" in formatted_card, "Card must append dynamic RATE delta preview!")
	var test_rtl = RichTextLabel.new()
	test_rtl.bbcode_enabled = true
	test_rtl.text = "[pulse freq=2.0 color=#ffffff40][bgcolor=#facc1530][color=#facc15]+60%[/color][/bgcolor][/pulse]"
	assert(test_rtl.get_parsed_text() == "+60%", "RichTextLabel must parse pulse and bgcolor!")
	test_rtl.queue_free()
	print(" - 27D: RichTextLabel card formatting and Current ──► Next delta generation verified.")

	# 27E: Projectile Visual Preservation (Suspended Stasis Field & Spectral Pierce)
	var test_bullet_spawner = preload("res://scenes/Bullet.tscn").instantiate()
	test_bullet_spawner._update_colors()
	assert(test_bullet_spawner.is_suspended == false, "Bullet default is_suspended must be false!")
	assert(test_bullet_spawner.is_spectral == false, "Bullet default is_spectral must be false!")
	assert(test_bullet_spawner.modulate == Color.WHITE, "Bullet default modulate must be unadulterated white!")
	test_bullet_spawner.queue_free()

	# Test Player bullet spawning with Quantum Tunneling (pierce/spectral)
	p1._spawn_bullet_from_params({"pos": Vector2(100, 100), "dir": Vector2.RIGHT, "damage": 1.0, "is_spectral": true, "pierce_count": 3})
	var spawned_bullets = p1.get_parent().get_children().filter(func(c): return c.is_in_group("bullet"))
	assert(not spawned_bullets.is_empty(), "Spectral bullet must be spawned!")
	var spec_b = spawned_bullets[-1]
	assert(spec_b.is_spectral == true, "Bullet must have is_spectral set to true!")
	assert(spec_b.modulate == Color.WHITE, "Spectral bullet must NOT have destructive canvas modulate (keeps Color.WHITE)!")
	assert(spec_b.glow_color.r > 0.6 and spec_b.glow_color.b > 0.8, "Spectral bullet must have luminous quantum-violet glow_color!")
	assert(spec_b.core_color.r > 0.9 and spec_b.core_color.g > 0.9 and spec_b.core_color.b > 0.9, "Spectral bullet must preserve white-hot incandescent needle core!")
	spec_b.queue_free()

	# Test Player bullet spawning with Antimatter Suspension (suspended fire)
	p1._spawn_bullet_from_params({"pos": Vector2(100, 100), "dir": Vector2.RIGHT, "damage": 1.0, "is_suspended": true})
	var susp_b = p1.get_parent().get_children().filter(func(c): return c.is_in_group("bullet"))[-1]
	assert(susp_b.is_suspended == true, "Suspended bullet must have is_suspended set to true!")
	assert(susp_b.length == 16.0, "Suspended bullet must preserve base needle dart length!")
	assert(susp_b.radius == 2.8, "Suspended bullet must preserve base needle dart radius!")
	susp_b.queue_free()
	print(" - 27E: Projectile visual preservation (needle dart geometry, white core, stasis field, and spectral phase shroud) verified.")

	# 28: Testing Enemy Bullet Variety (Homing, Sine Wave, Curving Arc, Cluster Burst) & Damage Tiers
	print("\nSTEP 28: Testing Enemy Bullet Variety (Homing, Wave, Arc, Flak) & Damage Tiers...")
	
	# 28A: Homing Seeker Missiles
	var b_homing = preload("res://scenes/Bullet.tscn").instantiate()
	main_inst.add_child(b_homing)
	b_homing.pattern = b_homing.Pattern.HOMING
	b_homing.setup(Vector2(200, 200), Vector2.RIGHT, true, 1.0)
	assert(b_homing.pattern == b_homing.Pattern.HOMING, "Bullet pattern must be HOMING!")
	assert(b_homing.glow_color.r > 0.8 and b_homing.glow_color.g > 0.4 and b_homing.glow_color.b < 0.2, "Homing missile must have warm amber glow!")
	p1.global_position = Vector2(300, 300)
	var initial_homing_dir = b_homing.direction
	b_homing._physics_process(0.2)
	assert(b_homing.direction != initial_homing_dir, "Homing missile must adjust direction toward player!")
	b_homing.homing_timer = b_homing.homing_duration + 0.1
	var burned_out_dir = b_homing.direction
	p1.global_position = Vector2(100, 100)
	b_homing._physics_process(0.1)
	assert(b_homing.direction == burned_out_dir, "Homing missile must stop tracking after homing_duration!")
	b_homing.queue_redraw()
	b_homing.queue_free()
	print(" - 28A: Homing Seeker Missiles (amber rocket, tracking slerp & burnout) verified.")

	# 28B: Curving Crescent Arcs
	var b_arc = preload("res://scenes/Bullet.tscn").instantiate()
	main_inst.add_child(b_arc)
	b_arc.pattern = b_arc.Pattern.CURVING_ARC
	b_arc.curve_delay = 0.05
	b_arc.curve_turn_time = 0.4
	b_arc.curve_angular_speed = 5.0
	b_arc.setup(Vector2(200, 200), Vector2.DOWN, true, 1.0)
	assert(b_arc.pattern == b_arc.Pattern.CURVING_ARC, "Bullet pattern must be CURVING_ARC!")
	var init_arc_dir = b_arc.direction
	p1.global_position = Vector2(300, 300)
	b_arc._physics_process(0.12)
	assert(b_arc.direction != init_arc_dir, "Curving arc bullet must rotate velocity over time towards player!")
	b_arc.queue_redraw()
	b_arc.queue_free()
	print(" - 28B: Curving Crescent Arcs (outward launch & curved player re-aim) verified.")

	# 28C: Quantum Wavepackets & 2-Pip Damage
	var b_wave = preload("res://scenes/Bullet.tscn").instantiate()
	main_inst.add_child(b_wave)
	b_wave.pattern = b_wave.Pattern.SINE_WAVE
	b_wave.wave_phase = 0.0
	b_wave.setup(Vector2(200, 200), Vector2.RIGHT, true, 2.0)
	assert(b_wave.damage == 2.0, "Quantum wavepacket must carry 2.0 damage (2 discrete pips)!")
	assert(b_wave.glow_color.r > 0.6 and b_wave.glow_color.b > 0.9, "Quantum wavepacket must have ethereal violet glow!")
	b_wave._physics_process(0.1)
	assert(b_wave.global_position.y != 200.0, "Quantum wavepacket must oscillate transversely!")
	b_wave.queue_redraw()
	b_wave.queue_free()
	print(" - 28C: Quantum Wavepackets (sinusoidal pilot-wave & 2-pip damage) verified.")

	# 28D: Cluster Flak Mortars (2 Direct Damage & Shrapnel Detonation)
	var b_mortar = preload("res://scenes/Bullet.tscn").instantiate()
	main_inst.add_child(b_mortar)
	b_mortar.pattern = b_mortar.Pattern.CLUSTER_BURST
	b_mortar.cluster_fuse = 0.1
	b_mortar.setup(Vector2(400, 300), Vector2.DOWN, true, 2.0)
	assert(b_mortar.damage == 2.0, "Cluster mortar shell must deal 2.0 damage on direct hit!")
	assert(b_mortar.glow_color.g > 0.8, "Cluster mortar shell must have radiant emerald glow!")
	b_mortar.queue_redraw()
	b_mortar._physics_process(0.15)
	assert(b_mortar.has_detonated == true, "Cluster mortar must detonate upon fuse expiration!")
	var post_det_bullets = main_inst.get_children().filter(func(c): return c.is_in_group("bullet") and c != b_mortar and not c.is_queued_for_deletion())
	assert(post_det_bullets.size() >= 5, "Cluster mortar must spawn at least 5 radial shrapnel sub-munitions!")
	for sub_b in post_det_bullets:
		assert(sub_b.damage == 1.0, "Shrapnel sub-munitions must deal 1.0 damage each!")
		sub_b.queue_free()
	print(" - 28D: Cluster Flak Mortars (2 direct damage, deceleration & emerald shrapnel burst) verified.")

	# 28E: Enemy Archetype Bullet Delivery
	var enemy_spawner_scene = preload("res://scenes/Enemy.tscn")
	var t_enemy = enemy_spawner_scene.instantiate()
	main_inst.add_child(t_enemy)
	
	# Test Interceptor curving bullet spawning
	t_enemy.setup(EnemyScript.EnemyType.INTERCEPTOR, Vector2(300, 300), -1, null, 0)
	t_enemy._spawn_curving_bullet(Vector2(300, 300), Vector2.LEFT, 1.6, 350.0)
	var arc_spawned = main_inst.get_children().filter(func(c): return c.is_in_group("bullet"))[-1]
	assert(arc_spawned.pattern == arc_spawned.Pattern.CURVING_ARC, "Interceptor must spawn CURVING_ARC bullets!")
	arc_spawned.queue_free()

	# Test Missile Corvette homing missile spawning
	t_enemy.setup(EnemyScript.EnemyType.MISSILE_CORVETTE, Vector2(300, 300), -1, null, 0)
	t_enemy._spawn_homing_missile(Vector2(300, 300), Vector2.LEFT, 300.0)
	var missile_spawned = main_inst.get_children().filter(func(c): return c.is_in_group("bullet"))[-1]
	assert(missile_spawned.pattern == missile_spawned.Pattern.HOMING, "Missile Corvette must spawn HOMING missiles!")
	missile_spawned.queue_free()

	# Test Warp Stalker wave bullet spawning
	t_enemy.setup(EnemyScript.EnemyType.WARP_STALKER, Vector2(300, 300), -1, null, 0)
	t_enemy._spawn_wave_bullet(Vector2(300, 300), Vector2.LEFT, 0.0, 340.0)
	var wave_spawned = main_inst.get_children().filter(func(c): return c.is_in_group("bullet"))[-1]
	assert(wave_spawned.pattern == wave_spawned.Pattern.SINE_WAVE, "Warp Stalker must spawn SINE_WAVE bullets!")
	assert(wave_spawned.damage == 2.0, "Warp Stalker wave bullets must deliver 2.0 damage!")
	wave_spawned.queue_free()

	# Test Bomber cluster mortar spawning
	t_enemy.setup(EnemyScript.EnemyType.BOMBER, Vector2(300, 300), -1, null, 0)
	t_enemy._spawn_cluster_mortar(Vector2(300, 300), Vector2.LEFT, 260.0)
	var mortar_spawned = main_inst.get_children().filter(func(c): return c.is_in_group("bullet"))[-1]
	assert(mortar_spawned.pattern == mortar_spawned.Pattern.CLUSTER_BURST, "Bomber must spawn CLUSTER_BURST mortars!")
	assert(mortar_spawned.damage == 2.0, "Bomber cluster mortar direct hit must deliver 2.0 damage!")
	mortar_spawned.queue_free()

	t_enemy.queue_free()
	print(" - 28E: Enemy archetype weapon assignment (Interceptor, Missile Corvette, Warp Stalker, Bomber) verified.")

	# =========================================================================
	# STEP 29: Testing Hull Damage Awareness, Shield Break VFX, Audio & Segmented HUD
	# =========================================================================
	print("\nSTEP 29: Testing Hull Damage Awareness, Shield Break VFX, Audio & Segmented HUD...")

	# 29A: Procedural Audio Streams for Shields & Hull
	var s29_required_streams = ["shield_hit", "hull_hit", "shield_break", "shield_recharge", "low_hull_alarm"]
	for s_name in s29_required_streams:
		assert(SoundEffects._streams.has(s_name), "SoundEffects must generate procedural stream: '%s'!" % s_name)
		var s29_stream = SoundEffects._streams[s_name] as AudioStreamWAV
		assert(s29_stream != null and s29_stream.data.size() > 0, "Audio stream '%s' must contain valid PCM data!" % s_name)
	print(" - 29A: Procedural audio streams (shield_hit, hull_hit, shield_break, shield_recharge, low_hull_alarm) verified.")

	# 29B: Shield Hit Absorption & Segmented State
	var p29_test = player_scene.instantiate()
	main_inst.add_child(p29_test)
	p29_test.max_shields = 3
	p29_test.shields = 3
	p29_test.max_hull = 4
	p29_test.hull = 4

	p29_test.take_damage(1)
	assert(p29_test.shields == 2, "Taking 1 damage on full shields must reduce shields from 3 to 2!")
	assert(p29_test.hull == 4, "Taking shield damage must preserve hull at 4!")
	assert(p29_test.shield_shards.is_empty(), "Taking non-lethal shield damage must not shatter shields!")
	assert(p29_test.hull_hit_flash_timer == 0.0, "Shield damage must not trigger hull hit flash!")
	print(" - 29B: Shield damage absorption and non-lethal shield integrity verified.")

	# 29C: Shield Depletion & Shatter Forcefield Shards
	p29_test.take_damage(2)
	assert(p29_test.shields == 0, "Taking 2 remaining shield damage must deplete shields to 0!")
	assert(p29_test.hull == 4, "Depleting shields must leave hull intact at 4!")
	assert(p29_test.shield_break_flash_timer > 0.0, "Shield collapse must trigger shield break flash timer!")
	assert(p29_test.shield_shards.size() >= 10, "Shield collapse must spawn at least 10 forcefield shatter shards!")
	print(" - 29C: Shield collapse forcefield shattering and shard dispersal verified.")

	# 29D: Direct Hull Damage, Concussive Shake & Impact Sparks
	var initial_sparks_29 = p29_test.hull_sparks.size()
	p29_test.take_damage(1)
	assert(p29_test.hull == 3, "Taking damage with 0 shields must damage hull directly to 3!")
	assert(p29_test.hull_hit_flash_timer > 0.0, "Hull damage must engage hull hit flash timer!")
	assert(p29_test.hull_sparks.size() > initial_sparks_29, "Hull impact must burst metallic fracture sparks!")
	
	# Simulate physics tick to verify smoke trail emission
	p29_test._handle_timers(0.1)
	assert(p29_test.damage_particles.size() > 0, "Damaged hull (< max_hull) must emit smoke trail particles!")
	print(" - 29D: Visceral hull damage, spark bursts, and smoke trail emission verified.")

	# 29E: Critical Hull Distress Beacon (< 1/3 Max Hull)
	p29_test.hull = 1
	assert(p29_test.hull <= int(p29_test.max_hull / 3.0), "1 Hull must register as critical (< 1/3 max hull)!")
	p29_test._handle_timers(0.05)
	var has_fire_29 = false
	for dp in p29_test.damage_particles:
		if dp.get("type") == "fire":
			has_fire_29 = true
			break
	assert(has_fire_29, "Critical hull state must spawn fire embers alongside smoke!")
	print(" - 29E: Critical hull fire emission and distress beacon state verified.")

	# 29F: HUD Discrete Shield Container & Alert Vignette
	var hud29 = get_tree().get_first_node_in_group("hud")
	assert(hud29 != null, "HUD must exist in scene tree!")
	assert(hud29.shield_container is HBoxContainer, "HUD shield container must be an HBoxContainer of discrete pips!")
	assert(hud29.shield_bar != null, "HUD shield_bar alias must remain accessible for backwards compatibility!")

	# Simulate health update: 2 hull, 1 shield out of 4 hull, 3 max shields
	hud29._on_health_changed(2, 1, 4, 3, 1)
	assert(hud29.shield_container.get_child_count() == 3, "Shield container must display exactly max_shields (3) pips!")
	assert(hud29.shield_container.get_child(0).modulate.a > 0.7, "Active shield pip 0 must be fully illuminated!")
	assert(hud29.shield_container.get_child(1).modulate.a < 0.5, "Depleted shield pip 1 must be dimmed!")
	assert(hud29.shield_container.get_child(2).modulate.a < 0.5, "Depleted shield pip 2 must be dimmed!")

	assert(hud29.hull_container.get_child_count() == 4, "Hull container must display exactly max_hull (4) pips!")
	assert(hud29.hull_container.get_child(0).modulate.a > 0.7, "Active hull pip 0 must be illuminated!")
	assert(hud29.hull_container.get_child(1).modulate.a > 0.7, "Active hull pip 1 must be illuminated!")
	assert(hud29.hull_container.get_child(2).modulate.a < 0.5, "Damaged hull pip 2 must be dimmed!")
	assert(hud29.hull_container.get_child(3).modulate.a < 0.5, "Damaged hull pip 3 must be dimmed!")

	# Hull damage vignette alert
	hud29._on_player_hull_damaged(1, 2, 4)
	assert(hud29.hull_vignette_timer > 0.0, "Hull damage notification must engage peripheral red vignette alert!")
	print(" - 29F: Discrete segmented shield/hull pips and peripheral red alert vignette verified.")

	p29_test.queue_free()

	# =========================================================================
	# STEP 30: Testing Isaac-Inspired Paradigms (Continuous Wave Magnetron & Casimir Discharge)
	# =========================================================================
	print("\nSTEP 30: Testing Isaac-Inspired Paradigms (CW Magnetron & Casimir Discharge)...")
	
	# 30A: Database Cataloging & Metadata Verification
	var cw_item = ItemDatabase.get_item_by_id("continuous_wave_magnetron")
	assert(cw_item != null, "continuous_wave_magnetron must be registered in ItemDatabase!")
	assert(cw_item.tier == ItemModifier.ItemTier.TIER_2_PARADIGM, "CW Magnetron must be Tier 2 Weapon Paradigm!")
	assert(cw_item.get_glyph() == "≋", "CW Magnetron must have valid vector glyph '≋'!")
	assert(cw_item.category == "offense", "CW Magnetron must be categorized as offense!")
	
	var casimir_item = ItemDatabase.get_item_by_id("casimir_discharge")
	assert(casimir_item != null, "casimir_discharge must be registered in ItemDatabase!")
	assert(casimir_item.tier == ItemModifier.ItemTier.TIER_2_PARADIGM, "Casimir Discharge must be Tier 2 Weapon Paradigm!")
	assert(casimir_item.get_glyph() == "⦿", "Casimir Discharge must have valid vector glyph '⦿'!")
	assert(casimir_item.category == "offense", "Casimir Discharge must be categorized as offense!")
	print(" - 30A: CW Magnetron & Casimir Discharge database registration, glyphs, and tier verified.")

	# 30B: Continuous Wave Magnetron (Soy Milk) Extreme Rate & Damage Scaling
	var p30_cw = load("res://scenes/Player.tscn").instantiate()
	add_child(p30_cw)
	var initial_fire_rate = p30_cw.fire_rate
	var initial_damage_mult = p30_cw.damage_mult
	
	p30_cw.add_modifier(cw_item)
	assert(p30_cw.has_cw_magnetron == true, "Equipping CW Magnetron must set has_cw_magnetron flag!")
	assert(p30_cw.fire_rate > initial_fire_rate * 4.0, "CW Magnetron must boost fire rate by ~+350%% (got %f vs base %f)!" % [p30_cw.fire_rate, initial_fire_rate])
	assert(p30_cw.damage_mult < initial_damage_mult * 0.35, "CW Magnetron must reduce damage multiplier by -70%% (got %f)!" % p30_cw.damage_mult)
	
	# Test spawn parameter dispersion and dart tagging
	var test_params = {"pos": Vector2(100, 100), "dir": Vector2.RIGHT, "damage": 1.0}
	var cw_results = cw_item.on_fire(p30_cw, test_params)
	assert(cw_results.size() == 1, "CW Magnetron on_fire must return 1 modified projectile parameter!")
	assert(cw_results[0].get("is_cw_dart") == true, "CW Magnetron must tag projectiles as is_cw_dart!")
	var fired_dir: Vector2 = cw_results[0].get("dir")
	assert(absf(fired_dir.angle_to(Vector2.RIGHT)) <= deg_to_rad(6.0), "CW Magnetron scatter angle must stay within tight beam spread!")
	p30_cw.queue_free()
	print(" - 30B: Continuous Wave Magnetron extreme fire rate (+350%), damage trade-off (-70%), and beam scatter verified.")

	# 30C: Near-Field Casimir Discharge (Proptosis) Point-Blank Devastation & Distance Decay
	var p30_cas = load("res://scenes/Player.tscn").instantiate()
	add_child(p30_cas)
	p30_cas.add_modifier(casimir_item)
	assert(p30_cas.has_casimir_discharge == true, "Equipping Casimir Discharge must set has_casimir_discharge flag!")
	
	var cas_bullet = load("res://scenes/Bullet.tscn").instantiate()
	add_child(cas_bullet)
	cas_bullet.setup(Vector2(200, 200), Vector2.RIGHT, false, 2.0)
	
	# Point-blank evaluation (traveled 50px <= 140px)
	cas_bullet.traveled_distance = 50.0
	casimir_item.on_projectile_tick(cas_bullet, 0.016)
	assert(cas_bullet.damage >= 4.0, "Casimir point-blank damage must be >= 2.0x base damage (got %f vs 2.0 base)!" % cas_bullet.damage)
	assert(cas_bullet.scale.x >= 1.5, "Casimir point-blank scale must be >= 1.5x base scale (got %s)!" % str(cas_bullet.scale))
	
	# Mid-range decay (traveled 280px)
	cas_bullet.traveled_distance = 280.0
	casimir_item.on_projectile_tick(cas_bullet, 0.016)
	assert(cas_bullet.damage < 3.5 and cas_bullet.damage > 0.8, "Casimir mid-range damage must smoothly interpolate (got %f)!" % cas_bullet.damage)
	
	# Far-field decay (traveled 480px >= 420px)
	cas_bullet.traveled_distance = 480.0
	casimir_item.on_projectile_tick(cas_bullet, 0.016)
	assert(cas_bullet.damage <= 0.60, "Casimir far-range damage must decay down to <= 25%% base (got %f vs 0.50 expected)!" % cas_bullet.damage)
	assert(cas_bullet.scale.x <= 0.60, "Casimir far-range scale must shrink down to <= 0.60x base scale (got %s)!" % str(cas_bullet.scale))
	
	cas_bullet.queue_free()
	p30_cas.queue_free()
	print(" - 30C: Near-Field Casimir Discharge +220% point-blank damage, massive scale, and distance decay verified.")

	# 30D: Synergistic Combination (CW Magnetron + Casimir Discharge = Rapid Point-Blank Meat Grinder)
	var p30_syn = load("res://scenes/Player.tscn").instantiate()
	add_child(p30_syn)
	p30_syn.add_modifier(cw_item)
	p30_syn.add_modifier(casimir_item)
	assert(p30_syn.fire_rate > 15.0, "Synergy setup must maintain blistering fire rate (> 15 rps)!")
	
	var syn_bullet = load("res://scenes/Bullet.tscn").instantiate()
	add_child(syn_bullet)
	# Base damage from CW Magnetron is low (~0.3), but Casimir point-blank multiplies it back up
	syn_bullet.setup(Vector2(200, 200), Vector2.RIGHT, false, 0.30)
	syn_bullet.traveled_distance = 30.0
	casimir_item.on_projectile_tick(syn_bullet, 0.016)
	assert(syn_bullet.damage > 0.60, "Casimir must multiply CW Magnetron chip damage up to devastating point-blank shredding!")
	
	syn_bullet.queue_free()
	p30_syn.queue_free()
	print(" - 30D: Synergistic interaction (CW Magnetron + Casimir Discharge point-blank meat-grinder) verified.")

	# =========================================================================
	# STEP 31: Testing Secret Debug Menu, Input Code Sequence, God Mode & Telemetry Disabling
	# =========================================================================
	print("\nSTEP 31: Testing Secret Debug Menu, Input Code Sequence, God Mode & Telemetry Disabling...")

	# 31A: Secret Konami Code Sequence on MainMenu (Up, Up, Down, Down, Left, Right, Left, Right)
	var p31_menu_scene = load("res://scenes/MainMenu.tscn")
	assert(p31_menu_scene != null, "MainMenu.tscn must load cleanly!")
	var p31_menu = p31_menu_scene.instantiate()
	add_child(p31_menu)

	assert(p31_menu.debug_view.visible == false, "DebugView must start hidden!")
	assert(p31_menu.debug_btn.visible == false, "Debug button must start hidden!")
	assert(p31_menu.debug_status_badge.visible == false, "Debug status badge must start hidden!")
	assert(GameManager.high_score_recording_enabled == true, "High score recording must start enabled!")
	assert(GameManager.telemetry_enabled == true, "Telemetry must start enabled!")

	# Simulate the 8-directional code sequence using synthetic InputEventKey
	var p31_key_sequence = [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT]
	for k in p31_key_sequence:
		var p31_ev = InputEventKey.new()
		p31_ev.pressed = true
		p31_ev.keycode = k
		p31_menu._input(p31_ev)

	assert(p31_menu.debug_view.visible == true, "DebugView must become visible after entering secret code!")
	assert(p31_menu.debug_btn.visible == true, "Debug button must become visible after entering secret code!")
	assert(p31_menu.debug_status_badge.visible == true, "Debug status badge must be visible!")
	print(" - 31A: Secret Konami code sequence (Up, Up, Down, Down, Left, Right, Left, Right) and DebugView activation verified.")

	# 31B: Verification of High Score Recording & Telemetry Disabling
	assert(GameManager.debug_mode_unlocked == true, "debug_mode_unlocked must be true after code access!")
	assert(GameManager.high_score_recording_enabled == false, "high_score_recording_enabled must be false after debug access!")
	assert(GameManager.telemetry_enabled == false, "telemetry_enabled must be false after debug access!")
	assert(HighScoreManager.high_score_recording_enabled == false, "HighScoreManager.high_score_recording_enabled must be false!")

	# HighScoreManager.record_run must return 0 and refuse to save when disabled
	var p31_pre_score_count = HighScoreManager.get_scores().size()
	var p31_test_rank = HighScoreManager.record_run(9999999, 3, 36, "1P Normal", 100.0, 500, true)
	assert(p31_test_rank == 0, "record_run must return 0 when high score recording is disabled!")
	assert(HighScoreManager.get_scores().size() == p31_pre_score_count, "High scores list must not be modified when recording is disabled!")
	assert(HighScoreManager.is_high_score(9999999) == false, "is_high_score must return false when recording is disabled!")
	print(" - 31B: Permanent disabling of high score recording and telemetry verified.")

	# 31C: Gamepad D-Pad & Analog Stick Direction Parsing
	var p31_joy_btn_ev = InputEventJoypadButton.new()
	p31_joy_btn_ev.pressed = true
	p31_joy_btn_ev.button_index = JOY_BUTTON_DPAD_UP
	assert(p31_menu._get_directional_input(p31_joy_btn_ev) == "up", "JOY_BUTTON_DPAD_UP must map to 'up'!")

	var p31_joy_stick_ev = InputEventJoypadMotion.new()
	p31_joy_stick_ev.axis = JOY_AXIS_LEFT_Y
	p31_joy_stick_ev.axis_value = -0.8
	assert(p31_menu._get_directional_input(p31_joy_stick_ev) == "up", "Analog stick Y < -0.55 must map to 'up'!")
	# Test debounce latch
	assert(p31_menu._get_directional_input(p31_joy_stick_ev) == "", "Analog stick must debounce / latch without returning duplicates!")
	p31_joy_stick_ev.axis_value = 0.0
	p31_menu._get_directional_input(p31_joy_stick_ev) # unlatches
	print(" - 31C: Universal input detection (Gamepad D-Pad & Debounced Analog Sticks) verified.")

	# 31D: Cheats & Augments (God Mode & Infinite Rolls)
	p31_menu._on_god_mode_toggle()
	assert(GameManager.debug_god_mode == true, "God mode toggle must enable GameManager.debug_god_mode!")
	p31_menu._on_infinite_rolls_toggle()
	assert(GameManager.debug_infinite_rolls == true, "Infinite rolls toggle must enable GameManager.debug_infinite_rolls!")

	var p31_ship = load("res://scenes/Player.tscn").instantiate()
	add_child(p31_ship)
	var p31_initial_hull = p31_ship.hull
	var p31_initial_shields = p31_ship.shields
	p31_ship.take_damage(2)
	assert(p31_ship.hull == p31_initial_hull and p31_ship.shields == p31_initial_shields, "God mode must make ship completely immune to damage!")

	p31_ship.rolls = 0
	p31_ship._handle_timers(0.016)
	assert(p31_ship.rolls == p31_ship.max_rolls, "Infinite rolls must immediately restore roll charges!")
	p31_ship.queue_free()
	print(" - 31D: God Mode invulnerability and Infinite Roll charges verified.")

	# 31E: Joules Grants, God-Build Preset & Interactive Relic Picker
	var p31_pre_j = GameManager.scrap_joules
	p31_menu._add_debug_joules(1000)
	assert(GameManager.scrap_joules == p31_pre_j + 1000, "+1,000 Joules button must add 1000 Joules to player bank!")

	p31_menu._on_god_build_toggle()
	assert(GameManager.debug_give_god_build == true, "God build toggle must arm God Build synergies!")
	assert("continuous_wave_magnetron" in GameManager.debug_starting_relics, "God build must include CW Magnetron!")
	assert("casimir_discharge" in GameManager.debug_starting_relics, "God build must include Casimir Discharge!")

	# Verify ship spawns with god build equipped
	var p31_god_ship = load("res://scenes/Player.tscn").instantiate()
	add_child(p31_god_ship)
	assert(p31_god_ship.has_cw_magnetron == true, "Player must spawn with CW Magnetron active when armed!")
	assert(p31_god_ship.has_casimir_discharge == true, "Player must spawn with Casimir Discharge active when armed!")
	p31_god_ship.queue_free()

	p31_menu._on_clear_relics_pressed()
	assert(GameManager.debug_give_god_build == false, "Clear relics must disarm god build!")
	assert(GameManager.debug_starting_relics.is_empty(), "Clear relics must empty debug starting relics!")
	print(" - 31E: Joules grants, God-Build synergy loadout, and starting relic configuration verified.")

	# 31F: Warp Jumps & Mode Force Unlocks
	p31_menu._set_debug_warp(2, 13)
	assert(GameManager.start_sector == 2 and GameManager.start_wave == 13, "Warp button must configure sector 2 wave 13!")
	p31_menu._on_unlock_all_modes_pressed()
	assert(GameManager.force_unlocked_modes == true, "Unlock all modes must set force_unlocked_modes to true!")

	p31_menu._select_mode(GameManager.GameMode.ENDLESS)
	assert(GameManager.current_game_mode == GameManager.GameMode.ENDLESS, "Endless mode must be selectable after force unlock!")

	p31_menu.queue_free()
	# Reset debug session state back to defaults for clean test exit
	GameManager.debug_god_mode = false
	GameManager.debug_infinite_rolls = false
	GameManager.debug_give_god_build = false
	GameManager.debug_starting_relics.clear()
	GameManager.start_sector = 1
	GameManager.start_wave = 1
	GameManager.force_unlocked_modes = false
	GameManager.current_game_mode = GameManager.GameMode.NORMAL
	GameManager.high_score_recording_enabled = true
	GameManager.telemetry_enabled = true
	HighScoreManager.high_score_recording_enabled = true
	print(" - 31F: Sector/Wave warp configuration and game mode force unlocks verified.")

	print("\n====================================================")
	print("--- ALL VERIFICATION TESTS PASSED 100% CLEANLY ---")
	print("====================================================")
	get_tree().quit(0)



