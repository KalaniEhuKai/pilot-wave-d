# Projectile Ballistics & Threat Analysis Guide
## <Pilot | Wave> : Decoherence

This document serves as the formal design analysis and engineering roadmap for enemy projectile threat mechanics, deconstructing why the **Interceptor** is currently the most formidable adversary in the game and laying out concrete mechanical blueprints to elevate the rest of the fleet.

---

## 1. Executive Summary

In shmups (shoot-'em-ups), perceived difficulty and engagement are rarely a function of raw projectile density or speed. Instead, threat is governed by **trajectory readability, kinematic subversion, and spatial confinement**.

The **Interceptor** excels because its weapon system violates the player's early trajectory prediction model via a **three-phase curved pincer**, reinforced by an **asynchronous center-spike follow-up** and **kinematic distance compression** (the dive-bomb). In contrast, most other enemies deploy predictable linear rays, fixed diverging spreads, or lazy continuous homing.

---

## 2. Anatomy of the Interceptor: Why It Is So Lethal

### A. The 3-Phase "False Flank" Ballistic Model (`Pattern.CURVING_ARC`)
*Defined in [`Enemy.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/Enemy.gd) (lines 808–841) and [`Bullet.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/Bullet.gd) (lines 342–372).*

```
          [Interceptor]
             /     \         PHASE 1 (0.00s - 0.32s): Flank Ejection (±52° / ±0.91 rad)
            /       \        Feigns missing wide; triggers false sense of safety.
           /         \
          (   0.32s   )      PHASE 2 (0.32s - 0.87s): Inward Whip-Turn (slerp 5.5 rad/s)
           \         /       Aggressive banking re-aim directed at player's live position.
            \       /
             \     /         PHASE 3 (t > 0.87s): Ballistic Lock (437 px/s)
                X            Trajectory locks onto inward diagonal vectors crossing player airspace.
             [Player]        <-- Converging Cross-Fire Zone
```

#### Phase Breakdown:
1. **Phase 1: The Dispersal Feint ($0.00\text{s} - 0.32\text{s}$)**:
   - Two projectiles are ejected at **$\pm 52^\circ$ ($\pm 0.91\text{ rad}$)** relative to the player heading.
   - **Cognitive Impact**: Human peripheral vision automatically projects linear motion vectors. Because the initial vectors diverge sharply away from the player, the brain registers: *"These shots are missing wide; focus attention on forward hazards."*
2. **Phase 2: The Pincer Whip-Turn ($0.32\text{s} - 0.87\text{s}$)**:
   - At $t = 0.32\text{s}$, the projectiles have reached the lateral margins. They suddenly activate active angular re-aiming toward the player's **current position** using:
     ```gdscript
     direction = direction.slerp(desired_dir, curve_angular_speed * delta).normalized()
     ```
   - **Angular Velocity**: `curve_angular_speed = 5.5 rad/s` ($\approx 315^\circ/\text{s}$). This is not a drifting glide; it is a violent snap-turn inward.
   - **Dynamic Tracking**: Because `desired_dir` tracks the player's position during this window, the bullets adjust to punish any evasion or repositioning attempted during Phase 1.
3. **Phase 3: Ballistic Lock ($t > 0.87\text{s}$)**:
   - Re-aiming stops (`curve_timer >= curve_delay + curve_turn_time`). The bullets freeze their new heading and travel downfield at high speed ($380 \times 1.15 = 437\text{ px/s}$).
   - The two paths form an **inward X-intersection** across the player's corridor.

---

### B. The "Bracket + Spike" Combo Phasing (Wave 4+ / Sector 2+)
*Defined in [`Enemy.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/Enemy.gd) (lines 835–841).*

120ms after the curving flank bullets fire, the Interceptor launches a **third bullet straight down the center line** at $458\text{ px/s}$:
- **Center Lane**: Blocked by the hyper-velocity straight bullet.
- **Left / Right Lanes**: Blocked by the inward-curving flank bullets.
- **Result**: A classic geometric dilemma. Standard lateral streaming or tap-dodging runs directly into one of the closing bracket arms.

---

### C. Kinematic Distance Compression (The Dive-Bomb)
*Defined in [`Enemy.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/Enemy.gd) (lines 595–624).*

At $t = 0.9\text{s}$, the Interceptor breaks out of formation and initiates a screeching dive toward the player:
```gdscript
charge_vector = (oncoming * 0.78 + to_p * 0.48).normalized()
var dive_vel = charge_vector * speed * 1.45 * delta
```
- Dive speed reaches **$406\text{ px/s}$**, closing distance rapidly.
- When an enemy charges while discharging delayed-curving ordnance, the player's reaction horizon is halved ($1.2\text{s} \rightarrow 0.55\text{s}$), making decision-making feel intense and urgent.

---

## 3. Bestiary Threat Audit: Current Deficiencies

A side-by-side analysis of why other enemy ships fail to generate comparable pressure:

| Archetype | Weapon Type | Current Behavior | Why Threat is Low / Predictable |
| :--- | :--- | :--- | :--- |
| **Scout** | `LINEAR` | 1–2 straight shots directed at player. | Easily negated by micro-tapping or continuous strafing. |
| **Bomber** | `LINEAR` Fan & `CLUSTER_BURST` | Odd volleys: 3–5 fan spread. Even volleys: solo cluster mortar. | **Diverging Fan Paradox**: Gaps between bullets widen with distance. Sitting far back guarantees safety. |
| **Heavy Cruiser** | 5-way `LINEAR` Fan | Broad spread (`-24°` to `+24°`) at $1.05\times$ speed. | Static geometric lines. No dynamic re-targeting or closing pinch points. |
| **Missile Corvette** | `HOMING` | 2 seeker missiles (`homing_strength = 2.4`). | Missiles have low turn rate and float sluggishly behind the player, allowing effortless out-running. |
| **Warp Stalker** | `SINE_WAVE` | Double-helix quantum waves (`wave_amplitude = 38.0`). | Beautiful visual oscillation, but net velocity is a fixed forward vector. Easy to step outside its lane. |
| **Turret Platform** | `LINEAR` Direct Burst | 4 sequential shots aimed directly at player coordinate. | Blind to velocity; circle-strafing or continuous movement completely trivializes it. |
| **Knight Vanguard** | `LINEAR` Salvo | 2-shot forward burst. Front shield absorbs frontal damage. | While defensively durable, its offensive output is completely standard. |

---

## 4. The Four Core Principles of High-Threat Projectiles

To make other ships feel as deadly, distinct, and memorable as the Interceptor, all new projectile designs should draw from these core tenets:

1. **State-Change Kinematics (The False Read)**:
   - Projectiles should shift state (speed, heading, or distribution) *after* launch ($t \approx 0.3 - 0.5\text{s}$).
   - This invalidates the player's immediate, instinctive dodge trajectory.
2. **Converging & Crossing Geometry (Inverting the Fan)**:
   - Move away from static diverging fans where the safe zone expands over distance.
   - Implement inward-converging or criss-crossing lanes that become *tighter* and more dangerous as they approach the player.
3. **Spatial Zoning & Combo Phasing (Bracket + Skewer)**:
   - Combine wide zoning hazards (flank brackets, airburst perimeters, lateral beams) with a central direct threat that denies the middle ground.
4. **Decisive Angular Velocity (Whip-Turn vs. Sluggish Drift)**:
   - Homing ordnance should not lazily trail behind targets. Two-stage missiles with a loiter phase followed by a high-G booster snap feel aggressive, intelligent, and dangerous.

---

## 5. Architectural Blueprints for Fleet Upgrades

### 1. Missile Corvette: Two-Stage "Sprint-and-Snap" Interceptor Torpedoes
* **Concept**: Transform lazy tracking missiles into true military-grade smart ordnance.
* **Stage 1 (Cold Ejection / Loiter)**:
  - Missiles fire wide at $\pm 45^\circ$ and decelerate to $160\text{ px/s}$ over $0.4\text{s}$, creating flanking waypoints.
* **Stage 2 (Burner Ignition & Terminal Sprint)**:
  - Thrusters ignite: speed surges to $580\text{ px/s}$ with a snappy $6.5\text{ rad/s}$ turn rate, vectoring directly into the player's predicted corridor.
* **Player Experience**: You cannot simply out-drift them. You must bait their ignition vector and sharp-cut to break their terminal track.

---

### 2. Heavy Cruiser: "Cross-Fire Guillotine" (Inverted Converging Broadside)
* **Concept**: Invert the traditional shmup fan spread.
* **Mechanics**:
  - Center shot travels straight forward at $420\text{ px/s}$.
  - Outer flank shots fire at $\pm 35^\circ$ for $0.35\text{s}$, then curve **inward toward the central corridor** at $4.0\text{ rad/s}$.
* **Player Experience**: As the salvo approaches, the bullet lanes criss-cross like shears. Standing far back no longer guarantees safety; players must either weave through early or advance forward into the wide gaps before the pinch point closes.

---

### 3. Bomber: "Bracket Flak Shells" (Cross-Cutting Inward Shrapnel)
* **Concept**: Replace the generic radial mortar blast with tactical airspace denial.
* **Mechanics**:
  - Bomber launches two heavy artillery canisters toward the left and right borders of the player's lateral zone.
  - Upon reaching the player's depth (or after $0.6\text{s}$), each canister airbursts, ejecting **a horizontal rake of 3–4 shrapnel darts directed horizontally inward**.
* **Player Experience**: The player's left and right escape corridors are suddenly swept by lateral shrapnel, trapping them in the path of oncoming standard volleys.

---

### 4. Turret Platform: "Predictive Lead-Sweep Burst" (Strafing Ladder)
* **Concept**: Punish brainless circle-strafing with predictive leading salvos.
* **Mechanics**:
  - Rather than firing 4 shots at the player's current position:
    - **Shot 1**: Directed at current player position.
    - **Shot 2**: Directed at $+0.5\times$ player velocity lead.
    - **Shot 3**: Directed at $+1.0\times$ player velocity lead.
    - **Shot 4**: Directed at $+1.5\times$ player velocity lead.
* **Player Experience**: If the player keeps strafing in the same direction, they walk directly into Shots 3 and 4. Surviving requires a stutter-step, reverse direction, or forward weave.

---

### 5. Warp Stalker: "Quantum Wavepacket Bifurcation"
* **Concept**: Elevate the sine wave from a cosmetic wiggle into a true quantum superposition collapse.
* **Mechanics**:
  - The bullet launches as a single dense violet singularity traveling straight downfield.
  - At mid-screen ($t \approx 0.42\text{s}$), the singularity collapses into two out-of-phase crescent arcs that flare outward and snap inward in a miniature dual-curve pincer.
* **Player Experience**: A single projectile suddenly splits into a cross-fire trap halfway across the screen.

---

### 6. Knight Vanguard: "Perpendicular Lancer Lance" (Lateral Gatecutter)
* **Concept**: Complement the Knight's frontal invulnerability with deep-corridor area denial.
* **Mechanics**:
  - Fires a heavy kinetic spear along the lateral boundary of the combat zone.
  - When the spear crosses the player's baseline coordinate, it triggers an instant $90^\circ$ perpendicular turn across the width of the screen.
* **Player Experience**: Prevents the player from camping in the bottom corners or safely ignoring the advancing Knight behind its shield.

---

## 6. Implementation Strategy & Parameter Reference

### Key Tuning Constants (`Bullet.gd`)
To support these patterns, the following parameters should be generalized in `Bullet.gd`:

```gdscript
# Curving & Converging Kinetics
var curve_delay: float = 0.32          # Delay before heading adjustment begins
var curve_turn_time: float = 0.55      # Active duration of turning phase
var curve_angular_speed: float = 5.5   # Angular velocity (rad/s)
var max_curve_angle: float = 1.22      # Maximum deflection cap (~70°)
var converge_target_axis: float = 0.0  # Optional lateral axis for inverted fan convergence

# Two-Stage Missile Parameters
var missile_loiter_speed: float = 160.0
var missile_sprint_speed: float = 580.0
var missile_ignition_delay: float = 0.40
var missile_terminal_turn_rate: float = 6.5
```

### Safety & Engine Guidelines
- **Viewport Constraints**: Ensure all curving and splitting behaviors obey off-screen turn prohibitions (`is_offscreen` check in `Bullet.gd:350`) to prevent unfair off-screen snipes.
- **Oncoming Cone Enforcement**: Any banking or curving bullet must maintain a forward dot product ($\ge 0.25$) with `GameAxis.forward` so bullets never reverse direction backward into spawn space.
- **Automated Testing**: Any new patterns added to `Pattern` enum must be verified in [`TestRunner.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/TestRunner.gd) with headless assertions verifying pattern execution, timing, and angle limits.
