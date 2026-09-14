# Audio Synthesis & Sound Design Guide: <Pilot | Wave> : Decoherence

This document serves as the permanent engineering guide and architectural specification for procedural audio synthesis, sound effect design, and bus mastering in *<Pilot | Wave> : Decoherence*.

---

## 1. The Core Problem: Why Audio Sounded Like "Blown-Out Speakers"

During early development, audio was reported as sounding like "everything is playing on blown out speakers". A deep DSP and acoustic audit revealed three distinct failure modes that **must never be reintroduced**:

### Failure Mode 1: Subsonic Speaker Driver Excursion (< 80 Hz)
- **Acoustics**: Most players play on laptop built-in speakers, desktop monitor speakers, budget desktop speakers, or standard gaming headsets. These physical drivers have tiny cones (10mm – 40mm) and high resonant roll-off below 100 Hz.
- **Root Cause**: Generators producing raw sine waves or rumble between **20 Hz and 60 Hz** (e.g., 20 Hz in `explosion`, 38 Hz in `hit`, 48 Hz in `laser`, 55 Hz in `ui_hover`) forced these small speaker voice coils past their physical mechanical excursion limit.
- **Symptom**: The speaker paper/plastic cone violently rattles against the chassis and voice coil suspension. This produces a loud mechanical buzzing/fluttering sound that **literally mimics a torn or blown speaker cone**.

### Failure Mode 2: Truncated Envelopes & Edge Clicks (DC Discontinuities)
- **Signal Theory**: When an audio buffer ends at an amplitude other than `0.0` (e.g. `warp_charge` was terminating at sample value `+2906`, `ui_hover` at `-343`), the audio hardware must instantly snap the physical cone from that voltage back to zero in a single sample (1/44100 sec).
- **Symptom**: This step change acts as a Dirac impulse, producing a sharp high-frequency snap/pop at the end of playback. Rapidly repeated (e.g. hovering over buttons or spooling warp), this sounds like static discharge or torn paper.

### Failure Mode 3: Polyphonic Bus Summation & OS Mixer Hard-Clipping
- **Signal Theory**: In a bullet-hell shmup, 10+ sound effects can trigger simultaneously (lasers firing every 120ms, enemy shots, hits, explosions, scrap pickups).
- **Root Cause**: If individual streams are normalized near 0 dBFS or callers pass positive decibels (`+3.0 dB` to `+6.0 dB`), summing 5 to 10 voices causes the audio bus level to exceed +6 dB to +12 dBFS. Without a brickwall limiter, the operating system's audio mixer (Windows WASAPI/DirectSound) clips the floating-point values into hard square waves.
- **Symptom**: Abrasive, harsh digital distortion across the entire audio output.

---

## 2. The Five Golden Rules of Audio in Pilot | Wave

Whenever adding or modifying a sound effect in `autoload/SoundEffects.gd`, follow these strict rules:

### Rule 1: The Anti-Blown-Speaker Frequency Register
- **Punch comes from 140 Hz – 350 Hz, NOT Sub-Bass (< 80 Hz).**
- **Clarity and bite come from 800 Hz – 2.5 kHz presence transients.**
- **Strict Prohibition**: Never generate pure fundamentals or unfiltered noise below **85 Hz**.
- For "heavy" impacts, lasers, or explosions, design a rapid descending pitch sweep starting in the mid-range (e.g., 720 Hz -> 160 Hz in 15ms) with warm 2nd/3rd harmonics (320 Hz / 480 Hz). This delivers massive physical weight on all speaker systems without distorting small cones.

### Rule 2: Universal Cosine Windowing & Zero Boundaries
- **Every single sound buffer MUST start at `0.0000` and end at `0.0000`.**
- Always generate audio through `_create_stream_from_floats(samples)`. This function automatically applies:
  - A 2ms cosine attack fade-in: `0.5 * (1.0 - cos(PI * i / att_samples))`
  - A 5ms cosine release fade-out: `0.5 * (1.0 - cos(PI * rem / rel_samples))`
  - Peak normalization scaled to `target_peak = 0.58` (-4.7 dBFS headroom per voice).
- **Never** write raw PCM bytes directly or create an `AudioStreamWAV` without passing through `_create_stream_from_floats()`.

### Rule 3: Dedicated Bus Architecture & Limiting
All sound effects must play on the dedicated `SFX` bus, which routes to `Master`:
1. **Master Bus Limiter**: An `AudioEffectLimiter` is dynamically placed on the Master bus (index 0) with:
   - `ceiling_db = -1.0 dBFS`
   - `threshold_db = -2.0 dBFS`
   - Hard digital clipping is mathematically impossible, even when 16 voices fire at once.
2. **SFX Bus High-Pass Filter**: An `AudioEffectHighPassFilter` is placed on the `SFX` bus with:
   - `cutoff_hz = 65.0 Hz`
   - Acts as an acoustic barrier against rogue subsonic frequencies.

### Rule 4: Caller Decibel Clamping & Trim
In `SoundEffects.play_sfx()`:
```gdscript
# Always clamp caller volume_db to a safe maximum (0.0 dB) and apply a -4.0 dB master voice trim
var final_vol = clampf(volume_db, -40.0, 0.0) - 4.0
```
This ensures that even if game code calls `play_sfx("bonus", 0.05, 6.0)`, the volume is clamped to `-4.0 dB`, preserving clean polyphonic summing headroom.

### Rule 5: UI Audio Must Be Crisp & Tactile, Never Boomy
- **`ui_hover`**: Must be a delicate micro-switch click (1300 Hz -> 800 Hz, 12ms duration, volume -10 dB). Zero low-end mud.
- **`ui_select`**: Must be an affirmative dual-tone chime (660 Hz -> 990 Hz in 48ms).
- **`ui_back`**: Must be a gentle descending cancel pip (460 Hz -> 280 Hz in 38ms).
- Rapid navigation across menus (e.g. keyboard/controller D-pad or mouse scrolling) should feel silky and responsive, never producing repetitive bass thuds.

---

## 3. Procedural Sound Synthesis Recipe Catalog

Use these tested DSP patterns when authoring new sounds:

### Pattern A: Cyberpunk Pulse Cannon / Laser
```gdscript
# Punchy transient attack (720 -> 160 Hz) + warm 2nd harmonic
var duration = 0.088
var freq = 160.0 + 560.0 * exp(-t * 80.0)
var env = pow(1.0 - p, 1.5)
var s = (sin(phase) * 0.68 + sin(phase * 2.0) * 0.24 + sin(phase * 3.0) * 0.08) * env
```

### Pattern B: Kinetic Armor Impact
```gdscript
# High-frequency transient snap (first 8ms) + mid thud (280 -> 160 Hz)
var white = (randf() * 2.0 - 1.0)
last_noise = 0.7 * last_noise + 0.3 * white
var click_env = exp(-t * 280.0)
var thud_env = exp(-t * 75.0)
var s = sin(phase) * 0.7 * thud_env + last_noise * 0.3 * click_env
```

### Pattern C: Thunderous Seismic Explosion
```gdscript
# Punch (180 -> 85 Hz) + bandpass smoothed rumble (sub-rumble rejected)
var freq = 85.0 + 95.0 * exp(-t * 25.0)
var thud = sin(phase) * exp(-t * 14.0) * 0.55
var white = (randf() * 2.0 - 1.0)
last_noise = 0.82 * last_noise + 0.18 * white
noise_hp = 0.95 * (noise_hp + last_noise - 0.5 * white) # High-pass stage
var rumble = noise_hp * 0.45 * pow(1.0 - p, 1.4)
var s = thud + rumble
```

### Pattern D: Synthwave Reward / Milestone Chord
```gdscript
# Staggered arpeggiated major/minor triad with warm harmonics
var notes = [220.0, 277.18, 329.63, 440.0] # A-major
var staggers = [0.0, 0.045, 0.090, 0.135]
# Each note:
var env = exp(-t_note * 12.0)
var wave = sin(phases[idx]) * 0.8 + sin(phases[idx] * 2.0) * 0.2
```

### Pattern E: Tactile Micro-Switch Click (UI Hover)
```gdscript
# Super-short exponential sweep in 10-15ms
var duration = 0.012
var freq = 1300.0 - p * 500.0
var env = exp(-t * 350.0)
var s = sin(phase) * env
```

---

## 4. How to Add a New Sound Effect

1. Open `autoload/SoundEffects.gd`.
2. Write a private generator function `_generate_<name>() -> AudioStreamWAV`.
3. Synthesize your float array `samples`, keeping fundamentals above 85 Hz.
4. Pass `samples` to `_create_stream_from_floats(samples)`.
5. Register in `_ready()`:
   ```gdscript
   _streams["<name>"] = _generate_<name>()
   ```
6. In `scripts/TestRunner.gd`, verify the sound stream in `_test_25g_procedural_ui_audio()`:
   ```gdscript
   assert(SoundEffects._streams.has("<name>"), "<name> audio stream missing")
   ```
7. Run the headless test runner:
   ```powershell
   & "C:\Users\family\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless scenes/TestRunner.tscn
   ```

---

## 5. Verification Quick-Script for Audio Health

If audio ever sounds distorted or abnormal in the future, run this quick Godot script to inspect all streams:

```gdscript
# Inspects peak levels, sample counts, and boundary discontinuity
for name in SoundEffects._streams:
    var stream: AudioStreamWAV = SoundEffects._streams[name]
    var data = stream.data
    var first_sample = data.decode_s16(0)
    var last_sample = data.decode_s16(data.size() - 2)
    assert(first_sample == 0, name + " starts with non-zero click: " + str(first_sample))
    assert(last_sample == 0, name + " ends with non-zero pop: " + str(last_sample))
```
Every sound must pass with `first_sample == 0` and `last_sample == 0`.
