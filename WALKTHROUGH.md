# Walkthrough: Progression Rebalance & Single-Leader Elite Fix

## Overview
This update addresses the early-game power curve, eliminates upgrade deserts across all three sectors, fixes the 5-elite squad spawn glitch, de-compounds enemy health scaling, and re-tunes boss health pools to align with realistic player DPS.

---

## 1. Single-Leader Elite Promotion (Fixing 5-Elite Squad Glitch)
- **Problem**: When a squad spawned with an elite affix (e.g. `ARMORED`, `QUANTUM_BURST`, `PHANTOM_BLINK`), all 5 crafts in the formation inherited the affix, turning the entire echelon into bullet-sponge elites and flooding drops or wiping the player.
- **Solution**:
  - Added `get_craft_affix(craft_idx, count, pattern, batch_affix)` in [DecoherenceSpawner.gd](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/DecoherenceSpawner.gd).
  - Only the flight leader (`leader_index` — the apex craft in `V_SHAPE` or the lead craft in `ROW`/flanks) is promoted to an Elite Champion.
  - Non-leader squad members spawn as standard archetype ships.
  - Elite Champions receive a visible scale boost (`Vector2(1.22, 1.22)`), ensuring clear visual telegraphing and guaranteeing exactly 1 elite crate per champion squad.

---

## 2. Upgrade Cadence & Eradication of "3+ Wave Deserts"
Players now receive meaningful power progression every 1–2 waves throughout the entire 36-wave run:

| Wave | Encounter / Event | Upgrade Source | Cumulative Player Items |
| :--- | :--- | :--- | :--- |
| **Wave 2** | First Contact complete | Guaranteed Starter Item Crate | 1 Item |
| **Wave 4** | Threat Surge / Echelon 2 | Guaranteed Single Elite Champion | 2 Items |
| **Wave 5** | Pre-Miniboss Checkpoint | Sky Merchant Zeppelin (1-2 items) | 3–4 Items |
| **Wave 6** | Miniboss (Armored Goliath) | Miniboss Item Crate Drop | 4–5 Items |
| **Wave 8** | Mid-Sector Pressure | Guaranteed Single Elite Champion | 5–6 Items |
| **Wave 10** | Deep Space Supply Crate | Automated Supply Drop Crate | 6–7 Items |
| **Wave 12** | Sector Boss (Corvus) | Major Boss Relic Crate | 7–8 Items |

*The same consistent 1–2 wave cadence is repeated in Sector 2 (Waves 13–24) with shop at Wave 17, and Sector 3 (Waves 25–36) with shop at Wave 29.*

---

## 3. Mathematical Enemy HP De-Compounding
- **Previous Formula**: Compounding exponential jumps creating a severe 100% cliff spike from Wave 12 to 13 (`1.36x` -> `2.72x`), causing enemies at Wave 4 and Wave 13 to feel overwhelmingly tanky.
- **Calibrated Formula** in [ProgressionModel.gd](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/ProgressionModel.gd):
  $$\text{Multiplier} = 1.0 + (\text{Sector} - 1) \times 0.45 + (\text{WaveInSector} - 1) \times 0.03$$
- **Health Progression Results**:
  - Wave 1 Scout: `2.00 HP` (2 player shots to defeat)
  - Wave 4 Scout: `2.18 HP` (smooth 2–3 shot baseline)
  - Wave 12 Scout: `2.66 HP`
  - Wave 13 Scout: `2.90 HP` (smooth bridge into Sector 2 without any cliff jump)
  - Sector 1 `ARMORED` affix multiplier tuned from `2.2x` down to `1.45x`.

---

## 4. Boss & Miniboss HP Re-Anchoring
Boss and miniboss health pools were re-anchored to realistic applied DPS while preserving multi-part destructible subsystems:

| Boss / Subsystem | Old Effective HP | Calibrated HP | Target Time to Kill |
| :--- | :--- | :--- | :--- |
| **Miniboss Goliath** (Wave 6) | 85 HP (Passive) | **180 HP** (90 Core / 50 Bow / 2×20 Railguns) | ~15–20 seconds |
| **Major Boss Goliath** (Wave 24) | 900 HP | **450 HP** (280 Core / 120 Bow / 2×25 Guns) | ~30–40 seconds |
| **Major Boss Corvus** (Wave 12) | 580 HP | **280 HP** (160 Core / 2×60 Wings) | ~30–40 seconds |
| **Apex Titan Ouroboros** (Wave 36) | 1,600 HP | **850 HP** (600 Core / 250 Shield Gate) | ~45–60 seconds |

### Sector 1 Miniboss & Boss Encounter Tuning
- **Wave 6 Miniboss (Siege Goliath Threat Escalation)**:
  - **Tracking Converging Railguns**: Both port and starboard railgun mounts (20 HP each) actively swivel and track the player with visible red laser targeting lines during charging. At 75% charge (0.64s), the lasers lock into position, turn bright yellow-white, and fire a high-speed 2-bolt heavy beam salvo (480 px/s) directly down the locked vector! Standing still results in direct hits, requiring active rolling or dodging.
  - **Frontal Autocannon**: While Bow Armor (50 HP) is intact, Goliath fires a 5-bullet kinetic spread fan forward every 1.8s.
  - **Fusion Core Overdrive (Phase 2)**: Breaking the bow armor now **enrages** the exposed core instead of pacifying the front. The exposed core fires an aimed 3-bolt plasma burst every 1.4s and discharges an 8-bullet radial energy pulse every 3.8s, while strafe speed accelerates from 85 to 125 px/s.
  - **Flanking Interceptor Hangar**: Deploys 2 aggressive Interceptor drones from the far lateral flanks (85 px away from the central line of fire) every 3.5s (2.6s in Phase 2) so they actively dive and flank rather than getting vaporized instantly in the forward firing line.
- **Wave 12 Climax Boss (Super-Dreadnought Corvus Phase 2 Enraged)**:
  - **Multi-Wave Rotating Vortex Bursts**: Replaced the weak single-pulse 4-bullet shot with rapid 12-pulse rotating vortex bursts spaced 0.09s apart (48 bullets per burst) advancing by 0.22 radians per pulse.
  - **Alternating Direction**: Successive bursts alternate spin directions (Clockwise $\leftrightarrow$ Counter-Clockwise), creating dense overlapping spiral arms across the screen.
  - **Breather Sniper Intercept**: Reduced downtime between bursts to 1.1s. In the midpoint of the breather window (at 0.55s), the exposed singularity core fires an aimed twin-plasma shot directly at the player to prevent static camping.

---

## 6. Quantum Cargo Hauler Archetype & Option 2 Elite Bounty System
- **Quantum Cargo Hauler (`CARGO_HAULER`)**:
  - Replaced all static floating deep-space crates on Waves 2 and 10 with an active combat encounter.
  - Distinctive gilded bulk freighter silhouette with twin glowing cyan relic pods and amber hull.
  - Flies steady downfield with moderate durability (`10.0 * hp_mult`).
  - Upon defeat, drops the guaranteed **Item Choice Crate**.
  - Integrated into handcrafted milestone templates across all sectors:
    - **Wave 2 / 14 / 26**: `CARGO RECONNAISSANCE` (Solo Hauler + introductory escort)
    - **Wave 4 / 16 / 28**: `RELIC CONVOY INTERCEPTION` (Hauler + Scout V-wedge escort)
    - **Wave 8 / 20 / 32**: `ARMORED RELIC CONVOY` (Hauler + Shield Frigate + Interceptors)
    - **Wave 10 / 22 / 34**: `DEEP SPACE SUPPLY RUN` (Hauler + Turret Platforms + Interceptors)
- **Option 2 Scaled Golden Plasma Bounty**:
  - Every Elite Champion (`elite_affix != NONE`) defeated universally awards:
    - **Sector 1**: **+10 Joules** + Full Shield Recharge
    - **Sector 2**: **+15 Joules** + Full Shield Recharge
    - **Sector 3**: **+20 Joules** + Full Shield Recharge
  - **Replaces loose scrap pellets**: The elite drops 0 loose pellets, so the net currency gain over standard craft is only ~+4 Joules.
  - Zero wave checks, zero milestone flags on elites, and zero artificial drop clamps.
- **Complete Elimination of Dynamic Threat Surges**:
  - Removed `consecutive_wipes >= 2` dynamic elite mutation from [WaveDirector.gd](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/WaveDirector.gd).
  - Wiping squads cleanly awards score and wipe bonuses without punishing player skill with surprise elite rubber-banding.

---

## 7. Verification & Automated Test Suite Results
Ran the complete Godot automated test suite via console:
`Godot_v4.7.2-stable_win64_console.exe --headless scenes/TestRunner.tscn`

```
====================================================
--- STARTING PHASE 4 AUTOMATED TEST SUITE ---
====================================================
STEP 1: Main.tscn instantiated with Threat Dossier, Wave Director & Bosses.
STEP 2: Testing 2-Player Local Co-Op & Zero-Friction Economy...
 - SUCCESS: Zero-friction scrap replication verified! (+10 J P1, +10 J P2)
STEP 3: Testing Sky Merchant Zeppelin & Reroll Terminal...
 - SUCCESS: Sky Merchant docking, safety purge, and escalating rerolls verified.
STEP 4: Testing Secret Systems (Quantum Anomaly & Dirac Monopole)...
 - SUCCESS: Quantum Anomaly shattered! Awarded scrap and secret bonus.
 - SUCCESS: Legendary Dirac Monopole shattered (+10,000 pts & Full Hull Repair).
STEP 5: Testing Sector 1 Boss: Super-Dreadnought Corvus (280 HP defeated with subsystem detonations)...
STEP 6: Testing Adaptive Wave Director Threat Budget & Formations...
STEP 7: Testing Expanded 20+ Quantum Synergy Relics...
STEP 8: Testing Sector Threat Dossier Briefing...
STEP 9: Testing Asymmetric Boss: Armored Behemoth Goliath (450 HP defeated)...
STEP 10: Testing Run Victory Dialog & Game Pause...
STEP 11: Testing Expanded Item Database (60+ Items) & Stat Upgrades...
STEP 12: Testing 16 Enemy Bestiary, Arena Hazards, 25+ Templates & Boss Ouroboros...
 - 12A: All 17 Enemy Archetypes instantiated cleanly with distinct statistics.
 - Total Wave Templates Cataloged: 30
 - 12I: Horizon wave function spawning, cosmic hazard drift, and downfield shmup flight verified.
STEP 13: Testing 15-Minute Run Architecture (3 Shops, Starter Stats, Multi-Echelons)...
 - 13C: All 30 wave templates verified having 3-4 echelons and 11-26 craft per wave.
 - 13D: Mathematical enemy HP scaling verified (W1 Scout: 2.0 HP, W4: 2.18 HP, W12: 2.66 HP, W13: 2.9 HP).
 - 13G: Horizon spawn points and clamping verified 15px from screen edge.
STEP 14: Testing System 1 (Combat/Wave Polish) & System 2 (Progression Engine)...
 - 14B: WaveDirector milestone Cargo Hauler encounters (W2, W4, W8, W10) and clean elimination of Threat Surges verified.
 - 14B2: Single-Leader Elite Champion promotion verified (no 5-elite squads).
 - 14C: ProgressionModel dynamic tier probabilities and tiered pricing verified.
 - 14D: Additive linear stat pooling model verified without exponential compounding.
 - 14F: SkyMerchant guaranteed slot archetypes verified.
 - 14G: Progression telemetry curves and HUD debug overlay verified.
STEP 15: Testing Death & Modal Concurrency Safeguards...
STEP 16: Testing Calibrated Joules Economy & Sector 1 Item Budget...
 - 16C: Simulated Waves 1-5 + Goliath Joules: 129 J (Target: 100-130 J)
 - 16D: Wave 5 pre-miniboss shop buying power verified (1-2 items purchased)
 - 16E: Escalating reroll inflation curve verified (5 -> 10 -> 20 -> 35 -> 55 J)
Testing 16F: Quantum Cargo Hauler Crate Drops & Option 2 Golden Plasma Bounties...
 - 16F: Quantum Cargo Hauler Crate Drops & Option 2 Scaled Golden Plasma Bounties (+10/+15/+20 J & Full Shields) verified.
====================================================
--- ALL VERIFICATION TESTS PASSED 100% CLEANLY ---
====================================================
```
All 16 test steps passed with 0 runtime errors and 0 assertion failures.
