# Visual Effects (VFX) & 3D Model Asset Guide
## Reference Guide for <Pilot | Wave> : Decoherence

This document serves as a permanent reference guide for sourcing, creating, and integrating **3D models** and **Visual Effects (VFX)** into *<Pilot | Wave> : Decoherence*.

---

## 1. Architectural Context: How Pilot Wave Renders Visuals

*Pilot Wave* uses a **2.5D decoupled architecture**:
- **Gameplay Layer (2D)**: Player movement, enemy flight paths, hitboxes, bullet collisions, and damage calculations exist entirely in a 2D coordinate plane (`CharacterBody2D`, `Area2D`).
- **Render Layer (3D)**: Handled by [`Stage3D.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/Stage3D.gd), which hosts an orthographic `Camera3D`, dynamic sun and rim lights, HDR bloom (`WorldEnvironment`), and deep-space parallax megastructures.
- **Synchronization Bridge**: [`VisualBridge3D.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/VisualBridge3D.gd) maps each 2D entity to a 3D visual instance, applying dynamic bank roll, recoil animations, and pitch tilt.

> **Key Takeaway**: Because gameplay and visuals are completely separated, replacing procedural shapes with real 3D models or adding 3D particle effects requires **zero modifications** to hitboxes, weapon damage, or flight code.

---

## 2. Demystifying Game Visual Effects (VFX)

### Are Visual Effects 3D Models or Something Else?

In real-time game development, visual effects are almost **never** single, sculpted 3D models. Instead, VFX are **dynamic composite systems** assembled from four primary components:

```
┌─────────────────────────────────────────────────────────────────┐
│                       Composite Game VFX                         │
├─────────────────┬───────────────────┬───────────────────────────┤
│ 1. Particles    │ 2. Helper Meshes  │ 3. Shaders & Textures     │
│    (GPU / CPU)  │    (Rings, Cones) │    (Noise, Dissolve, UV)  │
├─────────────────┴───────────────────┴───────────────────────────┤
│ 4. Environment & Lighting (OmniLight3D, HDR Bloom, Shake)       │
└─────────────────────────────────────────────────────────────────┘
```

### The 4 Core Building Blocks of Game VFX

#### 1. Particle Systems (`GPUParticles3D` / `GPUParticles2D`)
- **What they are**: High-performance GPU emitters that spawn dozens or hundreds of small quads (2D sprites facing the camera) or lightweight 3D meshes (shards, sparks, embers).
- **Properties**: Velocity, gravity, drag, scale curves over time, color ramps (e.g., bright yellow core fading to orange then smoky gray), and lifetime.
- **Used for**: Engine thruster plumes, sparking impacts, smoke clouds, quantum embers, exploding debris.

#### 2. Simple Helper Meshes (Procedural Geometry)
- **What they are**: Low-poly geometric primitives used to direct light and texture movement:
  - **Torus / Ring Mesh**: Expands outward to create explosion shockwaves or warp conduit rings.
  - **Cone / Cylinder Mesh**: Tapered to create thruster jets, spotlights, or beam weapons.
  - **Ribbon / Strip Mesh (Quad Strips)**: Stretches dynamically behind moving objects to create flight trails, lightning bolts, or slicing blade arcs.
  - **Sphere / Capsule Mesh**: Encapsulates a ship to render energy shields and deflector barriers.

#### 3. Shaders & Noise Textures
- **What they are**: GPU programs that calculate the color and transparency of every pixel on a surface.
- **Common Techniques**:
  - **UV Scrolling**: Moving a seamless noise texture continuously across a mesh (e.g., flowing energy in a laser or fire in an exhaust nozzle).
  - **Fresnel / Rim Glow**: Shading the edges of geometry brighter when viewed at an angle, creating translucent hologram or forcefield effects.
  - **Dissolve / Erosion**: Using a grayscale noise map (Perlin or Voronoi) and a cutoff threshold to make an object cleanly disintegrate or materialize from thin air.

#### 4. Dynamic Lighting & Post-Processing
- **What they are**: Engine-level render features that sell the illusion of power:
  - **Short-lived `OmniLight3D`**: Illuminates surrounding hulls during an explosion or muzzle flash.
  - **HDR Bloom / Glow**: Bright emissive values (> 1.0) bleed into adjacent pixels, giving laser blasts and neon conduits their vivid cyber glow.
  - **Camera Shake**: Trauma impulses driven by `GameManager.request_screen_shake()`.

---

## 3. How Common Shmup Effects Are Built

| Effect | Primary Technique | Godot Implementation |
| :--- | :--- | :--- |
| **Explosion** | Light flash + expanding torus ring + particle debris burst + screen shake | `OmniLight3D` (0.2s life) + `MeshInstance3D` (Torus) + `GPUParticles3D` (spark shards) |
| **Engine Thruster** | Continuous particle jet or animated cone with scrolling flame shader | `GPUParticles3D` with alpha-soft particle texture or `ConeMesh` with noise UV scroll |
| **Bullet / Laser Trail** | Trail ribbon following the projectile's historical positions | `RibbonTrailMesh` or sub-emitter particles spawned at bullet coordinate |
| **Deflector Shield** | Sphere mesh with edge glow and impact ripple shader | `SphereMesh` + `ShaderMaterial` with Fresnel falloff and hit coordinate deformation |
| **Quantum Decoherence (Spawn)** | Contracting ring aperture + lightning arc + material dissolve | Expanding `TorusMesh` + `ImmediateMesh` lightning arc + alpha clip fade |

---

## 4. Curated Sources for CC0 / Free 3D Models

For Godot 4, the **`.glb` / `.gltf`** format is recommended. It embeds geometry, vertex colors, PBR textures, and animations in a single efficient binary.

### Top Repositories for Sci-Fi & Cyberpunk

1. **[Quaternius](https://quaternius.com)**
   - **License**: CC0 (Public Domain — free for commercial/personal use, no attribution strictly required).
   - **Recommended Packs**:
     - *Ultimate Space Kit* (Modular spaceships, cockpits, cargo crates, turrets).
     - *Modular Sci-Fi Pack* (Interior space station corridors, bulkheads, consoles).
     - *Cyberpunk Vehicle Pack* (Hovercraft, flying speeders, drones).
   - **Format**: Natively provides `.gltf`/`.glb`.

2. **[Kenney.nl](https://kenney.nl/assets?q=3d)**
   - **License**: CC0 (Public Domain).
   - **Recommended Packs**:
     - *Space Kit* (100+ low-poly modular ships, antennas, solar panels).
     - *Sci-Fi Kit* (Modular space station and planetary base components).
   - **Visual Style**: Clean, stylized low-poly. Runs exceptionally fast and scales well on mobile and web.

3. **[Poly Pizza](https://poly.pizza)**
   - **License**: CC0 and CC-BY (creative commons with attribution).
   - **Search Queries**: `spaceship`, `fighter`, `cyberpunk`, `drone`, `mech`, `turret`.
   - **Format**: Direct `.glb` downloads from creators like Google Poly, J-Stuff, and independent artists.

4. **[OpenGameArt.org](https://opengameart.org)**
   - **License**: Varies (Filter search by **CC0** or **CC-BY**).
   - **Recommended Category**: 3D Art -> Space / Sci-Fi.
   - **Strength**: Classic retro arcade shmup ship designs, hard-surface dreadnoughts, and alien biomechanical craft.

5. **[Sketchfab](https://sketchfab.com)**
   - **License**: Filter search by **Downloadable** + **CC0 / CC-BY**.
   - **Strength**: High-detail "hero" craft ideal for major bosses (*Corvus*, *Goliath*, *Ouroboros*).

---

## 5. Curated Sources for Game Visual Effects (VFX)

### 1. Particle Textures (The Sprites Inside Particle Systems)
- **[Kenney's Particle Pack](https://kenney.nl/assets/particle-pack)** (**CC0**):
  - Over 80 clean, alpha-masked particle textures: smoke puffs, starbursts, laser flares, fire balls, radial rings, and electrical arcs.
  - Essential foundation for almost any Godot particle emitter.

### 2. Ready-to-Use Godot Shaders
- **[GodotShaders.com](https://godotshaders.com)** (**Free / MIT License**):
  - Search `Shield` -> Hexagonal energy barrier shaders.
  - Search `Dissolve` -> Procedural noise dissolve / quantum teleportation shaders.
  - Search `Shockwave` -> Screen-space refraction shockwaves.
  - Search `Lightning` -> Procedural procedural electrical discharge.

### 3. Pre-Rendered Simulation Flipbooks (Sprite Sheets)
- **[Itch.io Free VFX](https://itch.io/game-assets/free/tag-vfx)**:
  - High-end simulated explosions (often rendered from software like EmberGen, Blender Mantaflow, or Houdini) packed into sprite sheet animations.
  - Used when you want cinematic volumetric smoke and fireball detail at low CPU/GPU cost.

---

## 6. How to Integrate 3D Models into Pilot Wave

When you download a 3D model (e.g. `player_ship.glb`), here is the exact integration workflow:

### Step 1: Place Asset in Project
Create a folder structure:
```
pilot-wave-d/
  └── assets/
      ├── models/
      │   ├── player_ship.glb
      │   ├── enemy_interceptor.glb
      │   └── boss_corvus.glb
      └── vfx/
          └── particles/
              └── flare_01.png
```

### Step 2: Swap the Model in `VisualBridge3D.gd`
In [`scripts/VisualBridge3D.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/VisualBridge3D.gd), the bridge classes (`PlayerBridge3D`, `EnemyBridge3D`, `BossBridge3D`) currently instantiate procedural shapes:

```gdscript
# Current Procedural Instantiation:
mesh_instance = ShipBuilder3D.build_player_mesh()

# Replacement with Imported .glb Model:
const PLAYER_MODEL = preload("res://assets/models/player_ship.glb")
mesh_instance = PLAYER_MODEL.instantiate()
```

### Step 3: Align Orientation & Scale
Downloaded models might have different base orientations or scales. You can normalize them directly in the bridge initialization:
```gdscript
mesh_instance.scale = Vector3(1.2, 1.2, 1.2) # Adjust size to match 2D hitbox
mesh_instance.rotation_degrees = Vector3(0, 180, 0) # Rotate if facing backwards
```

The existing code in `VisualBridge3D.gd` will automatically handle:
- Synchronizing X/Y screen position with the 2D physics body.
- Banking during horizontal movement (barrel rolls, dynamic banking).
- 18° dorsal camera pitch for the top-down 2.5D perspective.
- Hit flash and destruction triggers.

---

## 7. How to Maintain a Cohesive Cyberpunk Art Style

When combining models from different artists, follow these three rules to prevent the "mismatched kitbash" look:

1. **Standardize Material Overrides**:
   Instead of using whatever texture or material came with the downloaded model, override its materials with calibrated `StandardMaterial3D`:
   - **Composite Hull Armor**: Satin/matte finish (`Metallic: 0.20`, `Roughness: 0.45 - 0.50`, `Rim: 0.20`, `Rim Tint: 0.4`). Avoid high metallic (>0.6) on primary hull colors because specular glare will cause bloom blowout.
   - **Neon Accents**: Moderate emission (`Emission Energy: 2.2 - 2.5`). Only apply to small details (canopy domes, conduits, weapon tips). Never apply to the main hull mesh surface!
   - **Engine Exhausts**: Compact rear nozzles with directed plasma cones, placed strictly behind the rear engine bells so flames never pierce forward through the ship's geometry.

2. **Unified Color Grading**:
   The `WorldEnvironment` inside [`Stage3D.gd`](file:///c:/Users/family/.gemini/antigravity-ide/scratch/pilot-wave-d/scripts/Stage3D.gd) applies Filmic Tonemapping and HDR Glow to all 3D assets simultaneously. The HDR glow threshold is set to `1.05`. Non-emissive hulls must stay below `1.0` total luminance so only true neon conduits, lasers, and thrusters glow.

3. **Consistent Poly Budget**:
   Stick to low-poly faceted assets or high-detail hard-surface assets, rather than mixing cartoon smooth shading with hyper-realistic photogrammetry.

---

## 8. PBR Shading, Lighting Balance & Preventing Bloom Burnout

Low-poly and mid-poly faceted models rely entirely on **directional light gradients** across their polygon faces to communicate 3D depth. If lighting is misconfigured, the models will either appear completely flat (washed out) or blow out into white glowing silhouettes:

1. **The Sunlight Limit**:
   Keep `DirectionalLight3D.light_energy` at approximately `1.0 - 1.2`. Sunlight values above `2.0` combined with bright hull albedos (e.g. coral red or yellow) exceed the `glow_hdr_threshold (1.05)`, causing the paint itself to bloom into white.
2. **Deep Space Ambient Contrast**:
   Keep `Environment.ambient_light_energy` at `0.20 - 0.25` with a cool deep blue-grey tint (`Color(0.16, 0.22, 0.32)`). High ambient light fills in shadows completely, flattening all geometric facets into a single shade.
3. **No Unnecessary Underglow OmniLights**:
   Do not attach high-energy `OmniLight3D` nodes directly underneath standard enemy ships. Point-blank omni lights illuminate the shadowed faces from below, destroying the crisp shading created by the directional sun.
4. **Surface 0 Rule for Imported Meshes**:
   In multi-surface OBJ/GLTF files, Surface 0 is usually the main body. Never assign an emissive material (`mat_neon`) to Surface 0. Emissive materials should only be used on dedicated trim surfaces or separate attached greeblies.

---

## 9. Summary Checklist for Future Implementation

- [ ] Choose primary asset style (Low-poly stylized vs hard-surface industrial).
- [ ] Download CC0 spaceship pack from Quaternius or Kenney.nl.
- [ ] Import models into `res://assets/models/enemies/` or `res://assets/models/player/`.
- [ ] Ensure model orientation has nose pointing along +X (e.g., `rot_y = 90.0` for +Z nose models).
- [ ] Position engine plumes strictly behind the rear engine bells.
- [ ] Verify bounding scales match 2D collision shapes (`CollisionPolygon2D` / `CollisionShape2D`).
- [ ] Run headless test suite to verify 100% test passage:
  `& "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless scenes/TestRunner.tscn`
