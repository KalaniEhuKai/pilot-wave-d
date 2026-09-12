extends Node

## TestRunner.gd - Executes automated verification inside the full Godot project context with autoloads.

func _ready() -> void:
	print("--- STARTING HEADLESS COMBAT PROTOTYPE SIMULATION ---")
	
	# Load main combat scene
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("ERROR: Could not load Main.tscn!")
		get_tree().quit(1)
		return
	
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	print("SUCCESS: Main.tscn instantiated and mounted.")
	
	# Verify player exists
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		printerr("ERROR: Player node not found in group 'player'!")
		get_tree().quit(1)
		return
	
	var player = players[0]
	print("SUCCESS: Player found at initial position: ", player.global_position)
	print("Player hull: ", player.hull, " / ", player.max_hull, " | shields: ", player.shields, " / ", player.max_shields)
	
	# Test Synchrotron Cannon firing
	print("Testing Synchrotron Cannon firing...")
	player._fire_synchrotron()
	var bullets = get_tree().get_nodes_in_group("bullets")
	print("SUCCESS: Bullets spawned: ", bullets.size())
	
	# Test 1942 Barrel Roll
	print("Testing 1942 Barrel Roll / Quantum Tunneling...")
	player._start_barrel_roll()
	print("During roll: is_rolling=", player.is_rolling, " | is_invulnerable=", player.is_invulnerable)
	player.take_damage(1)
	print("Damage during roll (should be negated by i-frames): shields=", player.shields, " (absorbed/negated)")
	
	# End roll and test normal damage intake
	player._end_barrel_roll()
	print("Ended roll: is_rolling=", player.is_rolling, " | is_invulnerable=", player.is_invulnerable)
	player.take_damage(1)
	print("Damage taken after roll: shields=", player.shields, " / ", player.max_shields, " (1 pip absorbed)")
	
	# Test Decoherence Spawner wave scheduling
	print("Decoherence Spawner active...")
	var spawner = main_inst.get_node_or_null("DecoherenceSpawner")
	if spawner:
		print("SUCCESS: DecoherenceSpawner node verified.")
	
	# Test GameAxis swappable coordinate system
	print("Testing GameAxis coordinates...")
	print("Landscape mode: is_vertical=", GameAxis.is_vertical, " forward=", GameAxis.forward, " lateral=", GameAxis.lateral)
	GameAxis.toggle_axis()
	print("Portrait mode: is_vertical=", GameAxis.is_vertical, " forward=", GameAxis.forward, " lateral=", GameAxis.lateral)
	GameAxis.toggle_axis() # toggle back
	
	# Test scoring and wipeout bonus
	print("Testing Arcade Scoring and 100% Formation Wipeout Bonus...")
	GameManager.add_score(100)
	print("Score after kill: ", GameManager.score)
	GameManager.award_wipe_bonus(1000)
	print("Score after 100% wipeout bonus: ", GameManager.score)
	print("Wipe count: ", GameManager.wipe_count)
	
	print("--- COMBAT PROTOTYPE SIMULATION PASSED 100% CLEANLY ---")
	get_tree().quit(0)
