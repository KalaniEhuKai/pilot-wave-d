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

## Headless Test Execution & Anti-Hang Guidelines
- **Root Cause of Godot Headless Hangs**: When a GDScript `assert()` fails or an uncaught error occurs during a headless run, Godot halts execution of the calling stack frame (e.g. `_ready()`), but the engine itself **does not quit**. It keeps idling in its main loop forever waiting for input. Because `get_tree().quit(0)` is at the bottom of the script, it is never reached.
- **Rule 1 (In Test Scripts)**: Always arm a SceneTree watchdog timer at the very beginning of `_ready()` in any test runner:
  ```gdscript
  get_tree().create_timer(8.0).timeout.connect(func():
      printerr("\n[WATCHDOG TIMEOUT] Tests failed to complete within 8s. Force quitting...")
      get_tree().quit(1)
  )
  ```
- **Rule 2 (In Antigravity `run_command`)**: When running the test suite via `run_command`, always specify `WaitMsBeforeAsync: 10000` (10s). Because the in-engine watchdog triggers at 8.0s, the command will *always* complete synchronously and return the exact error backtrace, never leaving a zombie process hanging in the background.
