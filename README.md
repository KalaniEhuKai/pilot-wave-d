# <Pilot | Wave> : Decoherence

A hybrid cyberpunk shoot 'em up (shmup) and roguelite built in **Godot 4.7.2**, blending the accessible, readable flight combat of *1942* with the emergent, combinatorial item synergies of *The Binding of Isaac*, grounded in high-energy physics and de Broglie's pilot wave theory.

- **Moniker**: *Pilot Wave* / *PWD*
- **Target Platforms**: PC, Mobile, and Web (HTML5/WebGL 2 via `gl_compatibility`)

## Architecture & Controls
- **Swappable Coordinate System**: `GameAxis.gd` supports both **Landscape 16:9** and **Portrait 9:16** dynamically.
- **Flight Model**: 0.04s micro-damped flight model with dynamic banking.
- **1942 Barrel Roll**: 3 charges, invulnerability frames, and full 360-degree evasive maneuver.
- **The Decoherence Spawner**: Materializes enemy formations out of quantum probability bubbles with 0.4s tactical telegraphing.
- **Arcade Scoring**: Formation wipeout bonuses (+1,000 pts for 100% squad elimination).
- **Procedural Sound Effects**: Pure in-engine audio synthesis (`SoundEffects.gd`) with zero external sound file dependencies.

## Quick Launch
Run the project using Godot 4:
```powershell
& "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "."
```

## Documentation
- [Implementation Plan](IMPLEMENTATION_PLAN.md)
- [Phase 1 Walkthrough](WALKTHROUGH_PHASE_1.md)
- [3D Models & VFX Reference Guide](docs/VFX_AND_3D_ASSETS_GUIDE.md)
