# Agent Instructions & Project Guidelines: <Pilot | Wave> : Decoherence

## Godot Executable Locations
The Godot engine binaries are located in the user's Downloads folder:
- **Headless / Console Binary (for tests & CLI commands):**
  `C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- **GUI Binary (for visual editor / game execution):**
  `C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`

> **Note:** `godot` is NOT in the system `$env:PATH`. Always invoke the full executable path above with PowerShell call operator `&`.

## Running the Automated Test Suite
To run the automated headless test suite:
```powershell
& "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless scenes/TestRunner.tscn
```

## Running the Game
To run the game directly:
```powershell
& "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" scenes/Main.tscn
```

## Project Architecture & Conventions
- **Engine**: Godot 4.7 (GL Compatibility).
- **Core Autoloads**:
  - `GameAxis`: Orientation abstraction (Horizontal 16:9 vs Vertical 9:16 portrait).
  - `GameManager`: Run lifecycle, sector/wave tracking, Joules currency, score, and state transitions.
  - `SoundEffects`: Synthesized/procedural audio.
- **Encounter System**:
  - `WaveDirector.gd`: Sector-gated wave templates and threat budget computation.
  - `DecoherenceSpawner.gd`: Spawns waves, quantum probability bubbles, and environmental hazards.
  - `Enemy.gd`: Kinematic profiles, behavioral mutation traits, elite affixes, and damage handling.
- **Bounds Rule**:
  - Combat playfield lateral margins are enforced so enemies never exit laterally through the ceiling or floor; enemies exit only through the rear horizon past the player.

## Procedural Audio & SFX Guidelines (The "Blown-Out Speaker" Prevention Rules)
- **Audio Architecture (`autoload/SoundEffects.gd`)**:
  - All procedural sounds use **16-bit 44.1 kHz PCM** (`AudioStreamWAV.FORMAT_16_BITS`).
  - All voices route to the dedicated `SFX` bus, which routes to `Master`.
  - `Master` bus has an `AudioEffectLimiter` (ceiling -1.0 dBFS, threshold -2.0 dBFS) to prevent OS-level digital hard clipping when multiple voices sum.
  - `SFX` bus has an `AudioEffectHighPassFilter` (`cutoff_hz = 65.0 Hz`) to protect small/laptop/monitor speaker cones from mechanical excursion blowout.
- **Rule 1: Frequency Register Safety**:
  - Never generate pure fundamentals or unfiltered noise below **85 Hz**. Punch comes from **140–350 Hz body resonance** + **800–2500 Hz presence transients**, NOT 20–60 Hz sub-bass. Sub-80 Hz at high volume makes speaker cones bottom out and sound like blown-out speakers.
- **Rule 2: Universal Windowing & Zero Discontinuity**:
  - Every audio buffer MUST be created through `_create_stream_from_floats(samples)`.
  - It applies automatic 2ms cosine attack and 5ms cosine release windowing, guaranteeing the first and last samples are strictly `0.0000`. Truncated buffers snap to zero and sound like static pops / torn speaker paper.
- **Rule 3: Decibel Clamping**:
  - `play_sfx()` clamps incoming caller `volume_db` to a maximum of `0.0 dB` with a `-4.0 dB` voice trim. Target peak per voice is `0.58` (~ -4.7 dBFS headroom).
- **Rule 4: UI Audio**:
  - UI sounds must be crisp, tactile micro-clicks or affirmative dual-tone chimes (800 Hz – 1.4 kHz). Never use low bass thuds (< 200 Hz) for hover/select.
- **Full Guide**: See `docs/AUDIO_SYNTHESIS_AND_SFX_GUIDE.md` for DSP recipes, patterns, and failure mode analysis.

## Headless Test Execution & Anti-Hang Guidelines
- **Root Cause of Godot Headless Hangs**:
  1. **Runtime assert/halt**: When a GDScript `assert()` fails or an uncaught runtime error occurs during a headless run, Godot halts execution of the calling stack frame (e.g. `_ready()`), but the engine itself **does not quit**. It keeps idling in its main loop forever waiting for input. Because `get_tree().quit(0)` is at the bottom of the script, it is never reached.
  2. **Compile / Parse Errors**: If a test script has a syntax or parse error (e.g., duplicate variable name in the same scope), Godot **fails to load the script entirely**. Because the script never loads, `_ready()` is never called, meaning an in-engine SceneTree watchdog timer inside `_ready()` is **never armed**. Godot then idles in its headless event loop indefinitely.
- **Rule 1 (In Test Scripts)**: Always arm a SceneTree watchdog timer at the very beginning of `_ready()` in any test runner:
  ```gdscript
  get_tree().create_timer(8.0).timeout.connect(func():
      printerr("\n[WATCHDOG TIMEOUT] Tests failed to complete within 8s. Force quitting...")
      get_tree().quit(1)
  )
  ```
- **Rule 2 (In Antigravity `run_command`)**: When running the test suite via `run_command`, always specify `WaitMsBeforeAsync: 10000` (10s).
- **Rule 3 (Parse Error Safeguard)**: Before running the test suite after editing `TestRunner.gd`, ensure all new variables have distinct, scoped names to prevent GDScript parse error shadowing that prevents `_ready()` from executing.
