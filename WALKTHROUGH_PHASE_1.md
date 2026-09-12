# Walkthrough - Phase 1: The 60-Second Playable Arcade Prototype

**`<Pilot | Wave> : Decoherence`** now has a fully playable arcade combat prototype built in Godot 4.7.2.

---

## What Was Built in Phase 1

### 1. Universal Godot 4 Project Setup
- **Directory**: `C:\Users\family\.gemini\antigravity-ide\scratch\pilot-wave-d`
- **Engine**: Godot 4.7.2 (`gl_compatibility` renderer) configured for instant cross-platform execution on Desktop, Mobile, and WebGL 2 / Web.
- **Dynamic Viewport**: Flexible canvas items scaling supporting both 16:9 Landscape and 9:16 Portrait.

### 2. Core Architectural Systems
- **`GameAxis.gd` (Swappable Coordinate System)**:
  - Vector abstraction dynamically providing `forward`, `lateral`, `scroll_dir`, and boundary lines.
  - Allows swapping between **Horizontal 16:9** (flying right) and **Vertical 9:16** (flying up) at any time via the UI toggle or `[Tab]` key.
- **`GameManager.gd` (Arcade Lifecycle & Scoring)**:
  - Tracks live score, enemies vaporized, survival time, and wave counter.
  - **100% Formation Wipeout Bonus**: Defeating all ships in an enemy squadron before they leave the screen awards an immediate **+1,000 pts** bonus with visual screen punch and triumphant chime.
  - Decaying screen shake coordinator.
- **`SoundEffects.gd` (Zero-Asset Procedural Audio Synthesizer)**:
  - Generates synthetic 8-bit/16-bit sound buffers at boot (`laser`, `hit`, `explosion`, `roll`, `bonus`, `hurt`).
  - Zero external `.wav` or `.mp3` files required, guaranteeing instant, lightweight loading on both web and native desktop.

### 3. Combat & Flight Mechanics
- **`Player.gd` (The Pilot)**:
  - Snappy 0.04s micro-damped flight model with dynamic banking roll.
  - Dual control options:
    - **PC / Gamepad**: WASD / Arrow keys + Space / Left-Click to fire.
    - **Mobile**: Relative touch drag (steer 1:1 with finger displacement anywhere on screen without covering the ship) + on-screen Fire button.
  - **1942 Barrel Roll / Quantum Tunneling**:
    - Triggered with `[Shift]`, Right-Click, or touch "ROLL" button.
    - 0.7s duration with full 360-degree rotation, squash/stretch animation, and complete damage invulnerability frames.
    - 3 stock charges that recharge over time.
  - **Health System**:
    - 4 Hull Integrity blocks.
    - 2 Energy Shield pips that absorb hits and regenerate after 4s without damage.
  - **`Synchrotron Cannon`**: Dual forward relativistic particle streams (8.5 rounds/sec) firing luminous cyan projectiles.

### 4. The Decoherence Spawner & Enemies
- **`DecoherenceSpawner.gd`**:
  - Materializes squadrons using quantum probability bubbles with interference fringes 0.42s prior to entry, providing tactical telegraphing for player positioning and pre-firing.
  - **Scout Fighter Squadrons**: 5-ship V-formations executing high-speed flybys.
  - **Heavy Bomber Squadrons**: Heavy armored craft firing aimed dual magenta plasma bursts.
  - Formation wipe detector awarding +1,000 pts on 100% elimination.

### 5. Parallax Background & HUD
- **`ParallaxBackground.gd`**: Infinite looping starfield, neon cyberpunk grid, and forward velocity streaks scrolling along `-GameAxis.forward`.
- **`HUD.gd`**: Luminous health pips, shield bar, barrel roll charges, live score interpolation, wave tracker, axis toggle button, and mobile touch controls.
- **`GameOverOverlay.gd`**: Death recap panel with final score, wipes achieved, survival time, and instant restart (`[R]` or tap).

---

## Verification Results

Automated headless simulation (`TestRunner.tscn`) ran against Godot 4.7.2 with zero errors:

```text
--- STARTING HEADLESS COMBAT PROTOTYPE SIMULATION ---
SUCCESS: Main.tscn instantiated and mounted.
SUCCESS: Player found at initial position: (256.0, 640.0)
Player hull: 4 / 4 | shields: 2 / 2
Testing Synchrotron Cannon firing...
SUCCESS: Bullets spawned: 2
Testing 1942 Barrel Roll / Quantum Tunneling...
During roll: is_rolling=true | is_invulnerable=true
Damage during roll (should be negated by i-frames): shields=2 (absorbed/negated)
Ended roll: is_rolling=false | is_invulnerable=false
Damage taken after roll: shields=1 / 2 (1 pip absorbed)
Decoherence Spawner active...
SUCCESS: DecoherenceSpawner node verified.
Testing GameAxis coordinates...
Landscape mode: is_vertical=false forward=(1.0, 0.0) lateral=(0.0, 1.0)
Portrait mode: is_vertical=true forward=(0.0, -1.0) lateral=(1.0, 0.0)
Testing Arcade Scoring and 100% Formation Wipeout Bonus...
Score after kill: 100
Score after 100% wipeout bonus: 1100
Wipe count: 1
--- COMBAT PROTOTYPE SIMULATION PASSED 100% CLEANLY ---
```

---

## How to Play the Prototype

You can launch the game directly via Godot from PowerShell:

```powershell
& "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "C:\Users\family\.gemini\antigravity-ide\scratch\pilot-wave-d"
```

Or open the project in the Godot Editor by pointing it to `C:\Users\family\.gemini\antigravity-ide\scratch\pilot-wave-d`.

### Controls
| Action | Key / Input |
| :--- | :--- |
| **Move** | `W, A, S, D` or `Arrow Keys` or Gamepad Left Stick / Touch Drag |
| **Fire** | `Space` or `Left Mouse Button` or on-screen `FIRE` button |
| **1942 Barrel Roll** | `Shift` or `Right Mouse Button` or on-screen `ROLL` button |
| **Toggle Axis (16:9 / 9:16)** | `Tab` or top-center `MODE` button |
| **Quick Restart** | `R` key or tap Restart on Game Over |
