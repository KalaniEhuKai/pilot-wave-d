# Walkthrough: ⟨Pilot | Wave⟩ : Decoherence

**`<Pilot | Wave> : Decoherence`** is a cyberpunk shoot 'em up (shmup) and roguelite in Godot 4.7.2, blending *1942* flight combat with *The Binding of Isaac* combinatorial item synergies.

---

## Phase 1 Accomplishments: The 60-Second Playable Arcade Prototype
- **Universal Engine Setup**: Godot 4.7.2 configured with the `gl_compatibility` renderer for universal PC, mobile, and WebGL 2 execution.
- **`GameAxis.gd`**: Dynamic coordinate abstraction supporting real-time toggling between **Horizontal 16:9** (Desktop) and **Vertical 9:16** (Mobile) via `[Tab]` or the UI button.
- **Flight Model & 1942 Barrel Roll**: 0.04s micro-damped flight model, relative touch drag steering for mobile, and evasive 1942 Barrel Roll with complete invulnerability frames and 3 recharging stock charges.
- **The Decoherence Spawner**: Materializes enemy squadrons out of quantum probability bubbles with 0.42s tactical telegraphing.
- **Arcade Scoring**: Base kill points + **100% Formation Wipeout Bonus (+1,000 pts)** on squad annihilation.
- **Procedural Sound Effects**: Zero-asset in-engine procedural audio synthesizer (`SoundEffects.gd`) for lasers, hits, rolls, explosions, and chimes.

---

## Phase 2 Accomplishments: The First Broken Synergies & Elite Drops

### 1. Modular Isaac-Style Synergy Hook Engine (`ItemModifier.gd`)
Implemented a data-driven resource pipeline with lifecycle hooks:
- `on_ship_init(ship)`
- `on_fire(ship, spawn_params)`
- `on_projectile_tick(bullet, delta)`
- `on_hit(bullet, victim, hit_info)`
- `on_kill(ship, victim, pos)`
- `on_roll(ship)`
- `on_wave_start(ship, wave_index)`
- `on_take_damage(ship, amount) -> bool`

### 2. The 5 Foundational Multi-Tier Relics
1. **Birefringence Prism** (*Tier 1 Ballistic*):
   - Projectiles split into 3 refracted beams (18° spread) after traveling 180px, tripling screen coverage.
2. **Gravitational Lensing** (*Tier 1 Ballistic*):
   - Curves projectile paths toward the nearest enemy center of mass with smooth slerp curvature (homing).
3. **Anti-Matter Suspension** (*Tier 2 Paradigm Mutator* - The *Isaac Anti-Gravity* equivalent):
   - Fired bullets do not launch forward; they freeze motionless in space as hovering plasma traps.
   - Releasing the fire button violently slingshots them all forward simultaneously in a synchronized relativistic burst at 1.45x speed!
4. **Meissner Shield Matrix** (*Tier 3 Exotic Relic* - The *Isaac Holy Mantle* equivalent):
   - Generates a superconducting field that completely absorbs and negates the **first hit taken in every wave**.
   - Recharges automatically at the start of each new wave.
5. **Maxwell's Demon** (*Tier 3 Exotic Relic*):
   - Violates entropy to magnetically pull all Energy Scrap and Plasma Joules across the entire screen directly into your engine.

### 3. Energy Scrap Economy & Elite Drops
- **Energy Scrap (`ScrapPickup.tscn`)**: Destroyed enemies drop glowing plasma rhomboid Joules that magnetize toward the player and accumulate in the Joules wallet.
- **Elite Enemy Champions (`Enemy.gd`)**:
   - **Armored Affix**: +150% max HP, golden armor aura, and 3x scrap drops.
   - **Volatile Affix**: Detonates into an 8-way ring of bullets upon death.
- **Item Choice Crate (`ItemCrate.tscn`)**:
   - Dropped by defeated Elite Champions.
   - Flying into the crate opens the **Item Choice Modal**, pausing combat and presenting 2 random relics with descriptions and tier badges.

### 4. Synergy Ribbon HUD
- Live Joules counter (`JOULES: 0 J`).
- Real-time **Synergy Ribbon** tray displaying active item badges with tooltip details.

---

## Verification Results

All automated tests passed 100% cleanly in headless Godot 4.7.2 (`TestRunner.tscn`):

```text
====================================================
--- STARTING PHASE 2 SYNERGY SUITE VERIFICATION ---
====================================================
STEP 1: Main.tscn instantiated and mounted.

STEP 2: Testing 1942 Barrel Roll / Quantum Tunneling...
 - is_rolling: true | is_invulnerable: true
 - Damage during roll negated cleanly by i-frames (shields: 2/2)

STEP 3: Testing Meissner Shield Matrix...
 - Meissner Shield equipped and active.
 - FIRST HIT absorbed by Meissner Shield! (shields remain: 2/2)
 - SECOND HIT successfully penetrates to shield pip (shields: 1/2)

STEP 4: Testing Birefringence Prism projectile splitting...
 - Spawned initial bullet. Bullets in scene: 1
 - Bullets in scene after refraction split: 3
 - SUCCESS: Birefringence Prism split bullet into 3 beams!

STEP 5: Testing Gravitational Lensing homing curvature...
 - Bullet initial dir.y: 0.000000 | Curving dir.y: 0.880006
 - SUCCESS: Gravitational Lensing dynamically curved bullet trajectory toward enemy!

STEP 6: Testing Anti-Matter Suspension (Plasma Trap & Slingshot)...
 - Bullet frozen motionless in space as hovering plasma trap.
 - SUCCESS: Fire released! Bullet violently slingshotted forward simultaneously at 1.45x speed!

STEP 7: Testing Maxwell's Demon scrap magnet...
 - Scrap initial distance: 944.847107 | Post-magnet distance: 564.847168
 - SUCCESS: Maxwell's Demon pulled scrap across screen into ship!

STEP 8: Testing Elite Enemy Champion & Item Choice Crate drop...
 - Elite Armored Champion verified (HP: 17.500000)
 - SUCCESS: Defeated Elite Champion dropped holographic Item Choice Crate!

====================================================
--- ALL PHASE 2 SYNERGY TESTS PASSED 100% CLEANLY ---
====================================================
```

---

---

## Phase 3 Accomplishments: Run Progression, Sky Merchant & 2-Player Co-Op

### 1. Zero-Friction 2-Player Local Co-Op
- **Dual Ship Roster**: P1 (Cyan particle trail, WASD / Space / Shift) and P2 (Amber-Gold particle trail, Arrow keys / Numpad 0 / Enter or Gamepad).
- **Zero-Friction Scrap Replication**: In-flight Energy Scrap credits **both players equally** upon pickup, completely eliminating toxic competition over resources.
- **Independent Wallets & Stalls**: Players maintain separate Plasma Joules balances for merchant transactions and rerolls.
- **HUD Co-Op Status**: P2 hull pips, shield bar, and separate Joules counter displayed when Co-Op mode is active.

### 2. In-Flight Shop: The Sky Merchant Zeppelin (`SkyMerchant.gd`)
- **Docking Sequence**: Docks smoothly alongside players after Wave 4.
- **Dual Supply Stalls**: Separate merchant inventory shelves for P1 and P2 offering Tier 1-3 relics and Hull Repair Nano-Injectors (15 J).
- **Independent Escalating Reroll Terminals**: Players can independently reroll their stall inventory for escalating Joules costs (5 J -> 10 J -> 20 J -> 35 J).
- **Undock Action**: Smoothly disengages and resumes combat patrol waves.

### 3. Multi-Part Sector 1 Boss: Super-Dreadnought Corvus (`BossCorvus.gd`)
- **Subsystem Armor**: Breakable Port and Starboard wing batteries that fire 5-way spread salvos.
- **Subsystem Detonations**: Wings break individually with catastrophic explosions (+2,500 pts each), peeling away armor to expose the central Singularity Core.
- **Phase 2 Enrage**: When both wings are destroyed, Corvus unleashes a frantic rotating 4-spoke spiral bullet vortex.
- **Boss Health Bar**: Displays boss name and segmented HP in top center of HUD.
- **Victory Bounty**: Defeating Corvus rewards +15,000 pts, drops 10 scrap pellets, an Elite Item Crate, and displays the SECTOR 1 CLEARED banner!

### 4. Background Secrets & Exploration (`SecretDirector.gd`)
- **Quantum Anomalies**: Destructible shimmering anomalies in the starfield that detonate for bonus Joules and +500 pts.
- **The Dirac Monopole Landmark**: Extremely rare cosmic phenomenon drifting in deep space; shooting it shatters the monopole, immediately repairing 100% hull and awarding +10,000 pts.

---

## Verification Results

All automated tests passed 100% cleanly in headless Godot 4.7.2 (`TestRunner.tscn`):

```text
====================================================
--- STARTING PHASE 3 RUN & CO-OP VERIFICATION ---
====================================================
STEP 1: Main.tscn instantiated with Sky Merchant & Secret Director.

STEP 2: Testing 2-Player Local Co-Op & Zero-Friction Economy...
 - P1 (Cyan) found at (256.0, 576.0) | P2 (Amber) found at (256.0, 768.0)
 - After 10 J pickup by P1: P1 Wallet = 10 J | P2 Wallet = 10 J
 - SUCCESS: Zero-friction scrap replication verified! (+10 J P1, +10 J P2)
 - SUCCESS: Independent Co-Op wallets verified (P1: 25 J, P2: 50 J)

STEP 3: Testing Sky Merchant Zeppelin & Reroll Terminal...
 - Sky Merchant docked. Both P1 and P2 supply stalls active.
 - Initial P1 reroll cost: 5 J
 - P1 reroll cost after 1st reroll: 10 J
 - SUCCESS: Independent escalating rerolls verified (P1: 10 J, P2: 5 J)
 - Undocked from Sky Merchant. Resumed combat patrol.

STEP 4: Testing Secret Systems (Quantum Anomaly & Dirac Monopole)...
 - SUCCESS: Quantum Anomaly shattered! Awarded scrap and secret bonus.
 - SUCCESS: Legendary Dirac Monopole landmark shattered! (+10,000 pts & Full Hull Repair)

STEP 5: Testing Sector 1 Boss: Super-Dreadnought Corvus...
 - Super-Dreadnought Corvus spawned. Total HP: 200.000000
 - Port Wing Battery destroyed! Detonated with subsystem explosion.
 - Starboard Wing Battery destroyed! Both wings offline.
 - Central Singularity Core exposed! Testing core destruction...
 - SUCCESS: Super-Dreadnought Corvus vaporized! Awarded +15,000 pts and Sector Cleared banner.

====================================================
--- ALL PHASE 3 RUN & CO-OP TESTS PASSED 100% CLEANLY ---
====================================================
```

---

## How to Play

Launch the game using the Godot 4 console executable:

```powershell
& "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "C:\Users\family\.gemini\antigravity-ide\scratch\pilot-wave-d"
```

| Action | P1 Control | P2 Control (Co-Op) |
| :--- | :--- | :--- |
| **Move** | `W, A, S, D` / Touch Drag / Gamepad 1 | `Arrow Keys` / `I, J, K, L` / Gamepad 2 |
| **Fire** | `Space` / `Left Mouse Button` / on-screen `FIRE` | `Numpad 0` / `Slash /` / Gamepad 2 A |
| **1942 Barrel Roll** | `Shift` / `Right Mouse Button` / on-screen `ROLL` | `Right Control` / `Period .` / Gamepad 2 B |
| **Toggle Axis** | `Tab` or top-center `MODE` button | - |
| **Toggle Co-Op** | Top-center `CO-OP` button | - |
| **Restart** | `R` key or tap Restart on Game Over | - |

