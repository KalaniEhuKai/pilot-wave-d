class_name BestiaryData
extends RefCounted

## BestiaryData.gd - Static tactical database for all hostile craft and bosses.
## Contains descriptive combat profiles, flight kinematics, ballistic behaviors, and sector spawn ranges.

const EnemyScript = preload("res://scripts/Enemy.gd")

static func get_all_entries() -> Array[Dictionary]:
	return [
		{
			"id": "scout",
			"name": "SCOUT",
			"enemy_type": EnemyScript.EnemyType.SCOUT,
			"boss_id": "",
			"speed": 220.0,
			"flight_style": "DIRECT_ADVANCE",
			"sector_spawn": "Sector 1+ (Wave 1+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 1+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nHigh-speed frontline vanguard. Advances in disciplined flight corridors or cascading wave formations. Highly agile but lightly armored.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nFires rapid twin plasma bolts. Features predictive lead calculation—it aims ahead of your current movement vector to intercept you in flight.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nEasily destroyed by basic blasters. Abruptly alter your lateral heading right as they fire to throw off their predictive targeting."
		},
		{
			"id": "bomber",
			"name": "BOMBER",
			"enemy_type": EnemyScript.EnemyType.BOMBER,
			"boss_id": "",
			"speed": 110.0,
			"flight_style": "FORWARD_ANCHOR",
			"sector_spawn": "Sector 1+ (Wave 3+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 3+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nHeavily reinforced siege station. Moves downfield and drops anchor into an artillery position to establish crossfire denial.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nAlternates between two firing modes: an expanding 3-to-5 purple fan spread, followed by a heavy emerald cluster mortar that detonates on proximity into shrapnel.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nHigh hull durability. When you see the green cluster mortar approach, slip laterally or barrel roll right before airburst detonation."
		},
		{
			"id": "interceptor",
			"name": "INTERCEPTOR",
			"enemy_type": EnemyScript.EnemyType.INTERCEPTOR,
			"boss_id": "",
			"speed": 240.0,
			"flight_style": "DIVE_BOMB",
			"sector_spawn": "Sector 1+ (Wave 2+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 2+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nFast strike raider. Banks along outer formation rails before executing a screeching dive-bomb directly down the player's flight lane.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nFires twin curving crescent arcs that flare wide (±52°) to box you in, before banking sharply inward toward your position, followed by a straight center dart.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nDo not retreat straight back into the closing pincer. Wait for the flank bullets to flare outward, then slip inward through the center corridor."
		},
		{
			"id": "sniper",
			"name": "SNIPER",
			"enemy_type": EnemyScript.EnemyType.SNIPER,
			"boss_id": "",
			"speed": 90.0,
			"flight_style": "STANDOFF_SENTRY",
			"sector_spawn": "Sector 1+ (Wave 7+) // Sector 2 & 3",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 7+) // Sector 2 & 3\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nDeep standoff sentry. Holds position on the far rear horizon and refuses to advance into close-quarters dogfights.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nTracks your craft with a bright red targeting laser telegraph. Once locked, fires a hyper-velocity kinetic railgun slug (950 px/s) with quadratic lead prediction.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nWatch the laser telegraph closely. Hold your heading to bait the shot, then abruptly juke laterally or barrel roll the split-second the beam discharges."
		},
		{
			"id": "shield_frigate",
			"name": "SHIELD FRIGATE",
			"enemy_type": EnemyScript.EnemyType.SHIELD_FRIGATE,
			"boss_id": "",
			"speed": 95.0,
			"flight_style": "FORWARD_ANCHOR",
			"sector_spawn": "Sector 2+ (Wave 13+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 2+ (Wave 13+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nArmored command escort. Anchors in mid-field and projects a massive 140px quantum aegis aura around itself.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nEmits pulsing 6-way radial plasma flak rings to deter close-range flanking approaches.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\n[color=#ff0055]PRIORITY TARGET![/color] All other enemy ships inside its aegis aura are completely invulnerable. You must focus fire and destroy the Shield Frigate first."
		},
		{
			"id": "heavy_cruiser",
			"name": "HEAVY CRUISER",
			"enemy_type": EnemyScript.EnemyType.HEAVY_CRUISER,
			"boss_id": "",
			"speed": 75.0,
			"flight_style": "FORWARD_ANCHOR",
			"sector_spawn": "Sector 3 (Wave 25+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 3 (Wave 25+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nColossal capital battery. Moves steadily to the center of the sector, deploying heavy broadside armor plates.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nUnleashes dense 5-way suppressing walls of heavy plasma darts, blanketing the airspace with lethal crossfire.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nExtremely high health pool. Weave between the expanding angles of its bullet wall, or use point-blank high-damage ordnance (e.g. Casimir Discharge) to melt its hull."
		},
		{
			"id": "knight_vanguard",
			"name": "KNIGHT VANGUARD",
			"enemy_type": EnemyScript.EnemyType.KNIGHT_VANGUARD,
			"boss_id": "",
			"speed": 110.0,
			"flight_style": "DIRECT_ADVANCE",
			"sector_spawn": "Sector 1+ (Wave 7+) // Sector 2 & 3",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 7+) // Sector 2 & 3\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nDisciplined shock-trooper cruiser. Equipped with an impenetrable front-facing directional mirror shield.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nUnmasks its heavy bow cannons during periodic heat-venting cycles, unleashing high-velocity twin kinetic salvos.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nFrontal attacks are deflected by its mirror shield. Wait for its venting cycle to unmask its blasters, flank it from the side/rear, or shatter its shield with sustained firepower."
		},
		{
			"id": "phantom",
			"name": "PHANTOM",
			"enemy_type": EnemyScript.EnemyType.PHANTOM,
			"boss_id": "",
			"speed": 150.0,
			"flight_style": "CLOAK_INFILTRATOR",
			"sector_spawn": "Sector 3 (Wave 25+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 3 (Wave 25+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nQuantum stealth skirmisher. Periodically phases out of reality into complete invisibility, becoming intangible and repositioning unpredictably.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nMaterializes from stealth to fire piercing quantum sine wavepackets that weave smoothly through space.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nCannot be damaged while cloaked. Track the faint sub-space distortion ripples in the background and strike aggressively the instant it uncloaks."
		},
		{
			"id": "drone_carrier",
			"name": "DRONE CARRIER",
			"enemy_type": EnemyScript.EnemyType.DRONE_CARRIER,
			"boss_id": "",
			"speed": 70.0,
			"flight_style": "STANDOFF_SENTRY",
			"sector_spawn": "Sector 3 (Wave 25+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 3 (Wave 25+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nAutonomous mothership. Hangs back in safe flight lanes while operating robotic assembly bays.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nContinuously launches swarms of 3 autonomous Micro Drones, while occasionally providing defensive suppressing fire.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nEliminate promptly. If allowed to remain on screen, its deployed drone swarms will quickly saturate the sector and overwhelm maneuver room."
		},
		{
			"id": "micro_drone",
			"name": "MICRO DRONE",
			"enemy_type": EnemyScript.EnemyType.MICRO_DRONE,
			"boss_id": "",
			"speed": 260.0,
			"flight_style": "SERPENTINE_SWARM",
			"sector_spawn": "Sector 1+ (Wave 1+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 1+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nLightweight sub-quantum swarmer. Rushes downfield in high-frequency sinusoidal serpentine weaves.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nDoes not fire projectiles—its primary threat is high-density kinetic ramming and screen area denial.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nVery low durability (single-hit kill). Wide spread blasters, piercing beams, or continuous wave lasers will shred entire swarms in seconds."
		},
		{
			"id": "turret_platform",
			"name": "TURRET PLATFORM",
			"enemy_type": EnemyScript.EnemyType.TURRET_PLATFORM,
			"boss_id": "",
			"speed": 30.0,
			"flight_style": "FORWARD_ANCHOR",
			"sector_spawn": "Sector 1+ (Wave 4+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 4+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nStationary armored orbital defense satellite. Deploys into fixed coordinates with a full 360° gimbal turret.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nIts articulating turret tracks your position in real-time, firing rapid 4-round bursts with pinpoint accuracy.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nMaintain orbital movement around its line of sight. Circle-strafe around its turret tracking rate to avoid taking direct hits."
		},
		{
			"id": "warp_stalker",
			"name": "WARP STALKER",
			"enemy_type": EnemyScript.EnemyType.WARP_STALKER,
			"boss_id": "",
			"speed": 100.0,
			"flight_style": "QUANTUM_BLINK",
			"sector_spawn": "Sector 3 (Wave 25+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 3 (Wave 25+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nQuantum displacement craft. Teleports instantaneously across the screen in bright sub-space blinks, breaking locks.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nFires braided double-helix quantum sine wavepackets (dealing 2 damage) that undulate through the air.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nMove perpendicular to the braided wave axis to pass through the nodes safely. Anticipate its blink cadence to catch it when it reappears."
		},
		{
			"id": "drainer_leech",
			"name": "DRAINER LEECH",
			"enemy_type": EnemyScript.EnemyType.DRAINER_LEECH,
			"boss_id": "",
			"speed": 110.0,
			"flight_style": "LATERAL_HOMING",
			"sector_spawn": "Sector 2+ (Wave 13+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 2+ (Wave 13+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nParasitic hunter. Actively glides laterally across the screen to lock onto and match your ship's lateral coordinate.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nFires rapid crimson disruptor siphon needles directly down its locked lane.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nExploit its lateral tracking: bait it into lining up with your weapon line, unleash a concentrated volley, then step aside before its siphon needles arrive."
		},
		{
			"id": "missile_corvette",
			"name": "MISSILE CORVETTE",
			"enemy_type": EnemyScript.EnemyType.MISSILE_CORVETTE,
			"boss_id": "",
			"speed": 85.0,
			"flight_style": "DIRECT_ADVANCE",
			"sector_spawn": "Sector 1+ (Wave 7+) // Sector 2 & 3",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Wave 7+) // Sector 2 & 3\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nHeavy missile gunship. Advances steadily along formation corridors providing standoff heavy ordnance support.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nEjects twin amber homing seeker missiles wide (±45°), which ignite their rocket boosters and curve to track your ship across the screen.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nGuide missiles into sharp tight turns to run them out of fuel, or perform a barrel roll through their collision box to trigger their proximity fuse safely."
		},
		{
			"id": "mine_tether",
			"name": "MINE TETHER",
			"enemy_type": EnemyScript.EnemyType.MINE_TETHER,
			"boss_id": "",
			"speed": 40.0,
			"flight_style": "FORWARD_ANCHOR",
			"sector_spawn": "Sector 3 (Wave 25+)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 3 (Wave 25+)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nArea-denial mine core. Drifts slowly into narrow sectors, creating spatial hazard zones.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nPeriodically radiates 6-way explosive shockwave rings, and detonates violently into shrapnel upon hull destruction.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\nEngage at long range. Never linger in point-blank proximity when delivering the killing blow, as its death burst can damage nearby craft."
		},
		{
			"id": "cargo_hauler",
			"name": "CARGO HAULER",
			"enemy_type": EnemyScript.EnemyType.CARGO_HAULER,
			"boss_id": "",
			"speed": 95.0,
			"flight_style": "DIRECT_ADVANCE",
			"sector_spawn": "Sector 1+ (Milestone Waves 2, 4, 8, 10, 14, 16, 20, 22)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1+ (Milestone Waves 2, 4, 8, 10, 14, 16, 20, 22)\n\n[color=#00f0ff]FLIGHT BEHAVIOR:[/color]\nHeavily reinforced quantum bullion transport making a run across the sector. Heavy armor plating.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nLow-cadence defensive aft blaster turret that fires basic protective shots.\n\n[color=#ff4060]TACTICAL ADVICE:[/color]\n[color=#ffd700]HIGH-VALUE PRIZE![/color] Destroying a Cargo Hauler guarantees a massive drop of Joules scrap and valuable relic loot crates."
		},
		{
			"id": "boss_corvus",
			"name": "SUPER-DREADNOUGHT CORVUS",
			"enemy_type": -1,
			"boss_id": "corvus",
			"speed": 60.0,
			"flight_style": "FLAGSHIP_CAPITAL",
			"sector_spawn": "Sector 1 Climax (Wave 12 Flagship Boss)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1 Climax (Wave 12 Flagship Boss)\n\n[color=#00f0ff]SECTOR 1 FLAGSHIP BOSS:[/color]\nColossal multi-deck battleship featuring breakable Port & Starboard armor wings and an exposed singularity core.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nTwin heavy bow railguns, alternating wing sweeps, wing fracture flak, and a devastating Phase 2 Enraged Singularity Vortex (18-bullet spiral storm).\n\n[color=#ff4060]TACTICAL DIRECTIVE:[/color]\nVaporize Port & Starboard wings first to break sweeping crossfire, then unleash concentrated firepower on the central singularity core."
		},
		{
			"id": "boss_goliath",
			"name": "ARMORED BEHEMOTH GOLIATH",
			"enemy_type": -1,
			"boss_id": "goliath",
			"speed": 55.0,
			"flight_style": "FLAGSHIP_CAPITAL",
			"sector_spawn": "Sector 1 & 2 Miniboss (Wave 6, 18) // Sector 2 Boss (Wave 24)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 1 & 2 Miniboss (Wave 6, 18) // Sector 2 Boss (Wave 24)\n\n[color=#00f0ff]SECTOR 2 FLAGSHIP BOSS:[/color]\nAsymmetric fortress carrier with heavy bow armor wedge, articulating tracking railguns, and hangar drone launch bays.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nContinuous sweeping railgun targeting lasers, fighter carrier bay drone launches, and core overdrive radial pulses.\n\n[color=#ff4060]TACTICAL DIRECTIVE:[/color]\nBreak through the heavy Bow Armor plates to expose the vulnerable fusion reactor. Stay mobile to evade the sweeping railgun targeting lasers."
		},
		{
			"id": "boss_ouroboros",
			"name": "APEX TITAN OUROBOROS",
			"enemy_type": -1,
			"boss_id": "ouroboros",
			"speed": 50.0,
			"flight_style": "FLAGSHIP_CAPITAL",
			"sector_spawn": "Sector 3 Climax (Wave 36 Final Boss)",
			"description": "[color=#ffd700]ENCOUNTER SECTOR:[/color] Sector 3 Climax (Wave 36 Final Boss)\n\n[color=#00f0ff]SECTOR 3 CLIMAX BOSS:[/color]\nFinal apex titan surrounded by an orbiting quantum barrier gate and singularity distortion engine.\n\n[color=#ffd700]BULLET BEHAVIOR:[/color]\nSweeping tachyon lances, rotating barrier gate defense, quantum phase blinks, and bullet hell singularity vortex barrages.\n\n[color=#ff4060]TACTICAL DIRECTIVE:[/color]\nTime your shots through the rotating shield gate gap. During bullet hell vortex phases, weave carefully and use barrel rolls to navigate dense bullet clusters."
		}
	]

static func get_entry(index: int) -> Dictionary:
	var entries = get_all_entries()
	if index >= 0 and index < entries.size():
		return entries[index]
	return entries[0]
