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

## How to Play

Launch the game using the Godot 4 console executable:

```powershell
& "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "C:\Users\family\.gemini\antigravity-ide\scratch\pilot-wave-d"
```

| Action | Control |
| :--- | :--- |
| **Move** | `W, A, S, D` / `Arrow Keys` / Gamepad / Touch Drag |
| **Fire** | `Space` / `Left Mouse Button` / on-screen `FIRE` |
| **1942 Barrel Roll** | `Shift` / `Right Mouse Button` / on-screen `ROLL` |
| **Toggle Axis** | `Tab` or top-center `MODE` button |
| **Restart** | `R` key or tap Restart on Game Over |
