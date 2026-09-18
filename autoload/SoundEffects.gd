extends Node

## SoundEffects.gd - High-Fidelity Cyberpunk Audio Synthesizer.
## Synthesizes pristine 16-bit 44.1 kHz PCM audio buffers with zero digital clipping,
## zero DC offset, smooth cosine windowing, and dedicated SFX bus routing.
##
## NOTE FOR FUTURE SOUND DESIGN & MODIFICATIONS:
## Consult 'docs/AUDIO_SYNTHESIS_AND_SFX_GUIDE.md' and AGENTS.md before modifying or adding sounds.
## 1. Fundamentals must stay >= 85 Hz (punch comes from 140-350 Hz body + 800-2500 Hz snap; sub-80Hz blows out speaker cones).
## 2. All buffers must pass through _create_stream_from_floats() to guarantee 0.0 at start and end via cosine windowing.
## 3. Master limiter (-1.0 dBFS ceiling) and SFX high-pass filter (65 Hz) protect output from digital clipping and driver rattling.

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_frame_played: Dictionary = {}
var _frame_play_count: Dictionary = {}
const MAX_VOICES: int = 16
const SAMPLE_RATE: int = 44100

func _ready() -> void:
	_setup_audio_bus_pipeline()
	
	# Create pool of AudioStreamPlayers routed to SFX bus
	for i in range(MAX_VOICES):
		var p = AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	
	# Generate procedural audio streams
	_streams["laser"] = _generate_laser()
	_streams["hit"] = _generate_hit()
	_streams["explosion"] = _generate_explosion()
	_streams["roll"] = _generate_roll()
	_streams["bonus"] = _generate_bonus()
	_streams["hurt"] = _generate_hurt()
	_streams["quantum_collapse"] = _generate_quantum_collapse()
	_streams["warp_charge"] = _generate_warp_charge()
	_streams["quantum_jump"] = _generate_quantum_jump()
	_streams["docking_clamp"] = _generate_docking_clamp()
	_streams["wave_cleared"] = _generate_wave_cleared()
	_streams["ui_hover"] = _generate_ui_hover()
	_streams["ui_select"] = _generate_ui_select()
	_streams["ui_back"] = _generate_ui_back()
	_streams["shield_hit"] = _generate_shield_hit()
	_streams["hull_hit"] = _generate_hull_hit()
	_streams["shield_break"] = _generate_shield_break()
	_streams["shield_recharge"] = _generate_shield_recharge()
	_streams["roll_recharge"] = _generate_roll_recharge()
	_streams["low_hull_alarm"] = _generate_low_hull_alarm()

func _setup_audio_bus_pipeline() -> void:
	# 1. Ensure SFX bus exists and routes to Master
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")
	
	# 2. Master bus limiter to prevent OS-level digital distortion/clipping
	var has_limiter = false
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var limiter = AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -2.0
		AudioServer.add_bus_effect(0, limiter)
	
	# 3. SFX bus High-Pass Filter: Cuts rogue frequencies below 65 Hz so small/laptop
	# speakers never experience cone bottoming-out or buzzing distortion.
	var has_hp = false
	for i in range(AudioServer.get_bus_effect_count(sfx_idx)):
		if AudioServer.get_bus_effect(sfx_idx, i) is AudioEffectHighPassFilter:
			has_hp = true
			break
	if not has_hp:
		var hp = AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 65.0
		AudioServer.add_bus_effect(sfx_idx, hp)

func play_sfx(name: String, pitch_range: float = 0.08, volume_db: float = 0.0, base_pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	
	# Rate-limit identical SFX in the same frame to protect audio server from digital clipping / voice clobber
	var cur_frame = Engine.get_physics_frames()
	if _last_frame_played.get(name, -1) != cur_frame:
		_last_frame_played[name] = cur_frame
		_frame_play_count[name] = 1
	else:
		_frame_play_count[name] += 1
		if _frame_play_count[name] > 3:
			return
	
	# Sane volume limit: clamp callers passing high positive dB, apply -4.0 dB voice trim
	var final_vol = clampf(volume_db, -40.0, 0.0) - 4.0
	var pitch = maxf(0.35, base_pitch + randf_range(-pitch_range, pitch_range))
	
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch
			p.volume_db = final_vol
			p.play()
			return
	
	# If all busy, hijack first player
	_players[0].stream = _streams[name]
	_players[0].pitch_scale = pitch
	_players[0].volume_db = final_vol
	_players[0].play()

func _create_stream_from_floats(samples: PackedFloat32Array, sample_rate: int = SAMPLE_RATE) -> AudioStreamWAV:
	var num = samples.size()
	if num == 0:
		return AudioStreamWAV.new()
	
	# Cosine window parameters: guaranteed 0.0 at sample 0 and sample (num - 1)
	var att_samples = mini(int(0.002 * sample_rate), num / 4)
	var rel_samples = mini(int(0.005 * sample_rate), num / 4)
	
	# Peak detection
	var max_peak = 0.0001
	for i in range(num):
		var a = absf(samples[i])
		if a > max_peak:
			max_peak = a
	
	# Target peak amplitude: 0.58 (-4.7 dBFS headroom per voice)
	var target_peak = 0.58
	var scale = target_peak / max_peak if max_peak > target_peak else 1.0
	
	var data = PackedByteArray()
	data.resize(num * 2)
	
	for i in range(num):
		var s = samples[i] * scale
		
		# Smooth cosine attack window
		if i < att_samples and att_samples > 0:
			s *= 0.5 * (1.0 - cos(PI * float(i) / att_samples))
		# Smooth cosine release window
		var rem = num - 1 - i
		if rem < rel_samples and rel_samples > 0:
			s *= 0.5 * (1.0 - cos(PI * float(rem) / rel_samples))
		
		var val = clampi(int(s * 32767.0), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

# --- Procedural Audio Generators (Pristine Cyberpunk Synth Aesthetic) ---

func _generate_laser() -> AudioStreamWAV:
	# Heavy electromagnetic pulse cannon (punchy mid-bass attack, tight body, zero harsh buzz)
	var duration = 0.088
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		# Punch transient: starts at 720 Hz, rapidly descends to 160 Hz
		var freq = 160.0 + 560.0 * exp(-t * 80.0)
		phase += freq * (TAU / SAMPLE_RATE)
		var env = pow(1.0 - p, 1.5)
		# Fundamental + 2nd harmonic (warmth) + subtle 3rd
		var s = (sin(phase) * 0.68 + sin(phase * 2.0) * 0.24 + sin(phase * 3.0) * 0.08) * env
		samples[i] = s
	
	return _create_stream_from_floats(samples)

func _generate_hit() -> AudioStreamWAV:
	# Kinetic armor impact (crisp transient snap + solid 200 Hz punch, zero muddy low-end)
	var duration = 0.045
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 280.0 - p * 120.0
		phase += freq * (TAU / SAMPLE_RATE)
		
		# High-frequency transient click in first 8ms
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.7 * last_noise + 0.3 * white
		var click_env = exp(-t * 280.0)
		var thud_env = exp(-t * 75.0)
		
		var s = sin(phase) * 0.7 * thud_env + last_noise * 0.3 * click_env
		samples[i] = s
	
	return _create_stream_from_floats(samples)

func _generate_explosion() -> AudioStreamWAV:
	# Seismic detonation (solid punch 180->85 Hz + smoothed acoustic rumble, no speaker fluttering)
	var duration = 0.38
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	var last_noise = 0.0
	var noise_hp = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		
		# Detonation thud: 180 Hz sliding down to 85 Hz
		var freq = 85.0 + 95.0 * exp(-t * 25.0)
		phase += freq * (TAU / SAMPLE_RATE)
		var thud = sin(phase) * exp(-t * 14.0) * 0.55
		
		# Filtered rumble: smoothed noise with sub-rumble rejection
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.82 * last_noise + 0.18 * white
		noise_hp = 0.95 * (noise_hp + last_noise - 0.5 * white)
		var rumble = noise_hp * 0.45 * pow(1.0 - p, 1.4)
		
		samples[i] = thud + rumble
	
	return _create_stream_from_floats(samples)

func _generate_roll() -> AudioStreamWAV:
	# Smooth vector thruster whoosh (aerodynamic resonance, no whistling)
	var duration = 0.22
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 240.0 + sin(p * PI) * 240.0
		phase += freq * (TAU / SAMPLE_RATE)
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.85 * last_noise + 0.15 * white
		var env = sin(p * PI)
		samples[i] = (sin(phase) * 0.65 + last_noise * 0.35) * env
	
	return _create_stream_from_floats(samples)

func _generate_bonus() -> AudioStreamWAV:
	# Velvety synthwave arpeggiated chord (A3, C#4, E4, A4 in warm analog textures)
	var duration = 0.32
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var notes = [220.0, 277.18, 329.63, 440.0]
	var staggers = [0.0, 0.045, 0.090, 0.135]
	var phases = [0.0, 0.0, 0.0, 0.0]
	
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var s = 0.0
		for idx in range(4):
			phases[idx] += notes[idx] * (TAU / SAMPLE_RATE)
			var t_note = t - staggers[idx]
			if t_note >= 0.0:
				var env = exp(-t_note * 12.0)
				var wave = sin(phases[idx]) * 0.8 + sin(phases[idx] * 2.0) * 0.2
				s += wave * env * 0.35
		samples[i] = s
	
	return _create_stream_from_floats(samples)

func _generate_hurt() -> AudioStreamWAV:
	# Heavy structural hull stress alert (dissonant warning interval 200+270 Hz + impact crunch)
	var duration = 0.16
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var p1 = 0.0
	var p2 = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		p1 += (220.0 - p * 80.0) * (TAU / SAMPLE_RATE)
		p2 += (285.0 - p * 110.0) * (TAU / SAMPLE_RATE)
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.7 * last_noise + 0.3 * white
		var crunch_env = exp(-t * 120.0)
		var tone_env = pow(1.0 - p, 1.4)
		var s = (sin(p1) * 0.45 + sin(p2) * 0.35) * tone_env + last_noise * 0.35 * crunch_env
		samples[i] = s
	
	return _create_stream_from_floats(samples)

func _generate_quantum_collapse() -> AudioStreamWAV:
	# Gravitational vortex sweep (340 Hz descending to 120 Hz with clean closure)
	var duration = 0.18
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 340.0 - pow(p, 0.7) * 220.0
		phase += freq * (TAU / SAMPLE_RATE)
		var env = pow(1.0 - p, 1.1)
		samples[i] = (sin(phase) * 0.75 + sin(phase * 2.0) * 0.25) * env
	
	return _create_stream_from_floats(samples)

func _generate_warp_charge() -> AudioStreamWAV:
	# Relativistic warp engine spool-up (180 Hz rising smoothly to 520 Hz with clean envelope)
	var duration = 0.35
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 180.0 + pow(p, 1.3) * 340.0
		phase += freq * (TAU / SAMPLE_RATE)
		var mod = 1.0 + 0.15 * sin(t * 45.0)
		var env = sin(p * PI) * mod
		samples[i] = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * env
	
	return _create_stream_from_floats(samples)

func _generate_quantum_jump() -> AudioStreamWAV:
	# Hyperspace displacement (fast 360->130 Hz punch with phase dispersion)
	var duration = 0.20
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 360.0 - pow(p, 0.5) * 230.0
		phase += freq * (TAU / SAMPLE_RATE)
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.8 * last_noise + 0.2 * white
		var env = exp(-t * 16.0)
		samples[i] = (sin(phase) * 0.7 + last_noise * 0.3) * env
	
	return _create_stream_from_floats(samples)

func _generate_docking_clamp() -> AudioStreamWAV:
	# Heavy industrial magnetic docking latch (dual mechanical click + soft air release)
	var duration = 0.22
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var p1 = 0.0
	var p2 = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		p1 += 680.0 * (TAU / SAMPLE_RATE)
		var strike1 = sin(p1) * exp(-t * 90.0)
		var strike2 = 0.0
		if t >= 0.035:
			p2 += 520.0 * (TAU / SAMPLE_RATE)
			strike2 = sin(p2) * exp(-(t - 0.035) * 80.0) * 0.8
		
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.85 * last_noise + 0.15 * white
		var hiss = last_noise * 0.25 * exp(-t * 22.0)
		
		samples[i] = strike1 * 0.5 + strike2 * 0.5 + hiss
	
	return _create_stream_from_floats(samples)

func _generate_wave_cleared() -> AudioStreamWAV:
	# Cinematic synthwave milestone resolution (warm ascending arpeggio F3-A3-C4-E4-A4)
	var duration = 0.45
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var notes = [174.61, 220.00, 261.63, 329.63, 440.00]
	var staggers = [0.0, 0.065, 0.130, 0.195, 0.260]
	var phases = [0.0, 0.0, 0.0, 0.0, 0.0]
	
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var s = 0.0
		for idx in range(5):
			phases[idx] += notes[idx] * (TAU / SAMPLE_RATE)
			var t_note = t - staggers[idx]
			if t_note >= 0.0:
				var env = exp(-t_note * 9.0)
				var wave = sin(phases[idx]) * 0.75 + sin(phases[idx] * 2.0) * 0.25
				s += wave * env * 0.28
		samples[i] = s
	
	return _create_stream_from_floats(samples)

func _generate_ui_hover() -> AudioStreamWAV:
	# Crisp tactile optical micro-switch click (1300 -> 800 Hz in 12ms, zero bass mud)
	var duration = 0.012
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 1300.0 - p * 500.0
		phase += freq * (TAU / SAMPLE_RATE)
		var env = exp(-t * 350.0)
		samples[i] = sin(phase) * env
	
	return _create_stream_from_floats(samples)

func _generate_ui_select() -> AudioStreamWAV:
	# Clean affirmative electronic two-tone chime (660 Hz -> 990 Hz, 48ms)
	var duration = 0.048
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var p1 = 0.0
	var p2 = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		p1 += 660.0 * (TAU / SAMPLE_RATE)
		p2 += 990.0 * (TAU / SAMPLE_RATE)
		var env1 = exp(-t * 90.0)
		var env2 = exp(-maxf(0.0, t - 0.015) * 80.0) if t >= 0.015 else 0.0
		samples[i] = sin(p1) * 0.6 * env1 + sin(p2) * 0.5 * env2
	
	return _create_stream_from_floats(samples)

func _generate_ui_back() -> AudioStreamWAV:
	# Soft downward electronic cancel tap (460 -> 280 Hz, 38ms)
	var duration = 0.038
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 460.0 - p * 180.0
		phase += freq * (TAU / SAMPLE_RATE)
		var env = pow(1.0 - p, 1.8)
		samples[i] = sin(phase) * env
	
	return _create_stream_from_floats(samples)

func _generate_shield_hit() -> AudioStreamWAV:
	# Resonant plasma deflection / energy absorption snap (460 -> 240 Hz with electric snap transient)
	var duration = 0.065
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 240.0 + 220.0 * exp(-t * 85.0)
		phase += freq * (TAU / SAMPLE_RATE)
		
		# High-frequency electric snap transient in first 12ms
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.75 * last_noise + 0.25 * white
		var snap_env = exp(-t * 220.0)
		var body_env = exp(-t * 45.0)
		
		var s = (sin(phase) * 0.7 + sin(phase * 2.0) * 0.25) * body_env + last_noise * 0.35 * snap_env
		samples[i] = s
	
	return _create_stream_from_floats(samples)

func _generate_hull_hit() -> AudioStreamWAV:
	# Heavy concussive structural impact & metal crunch (190 -> 98 Hz body with crunch noise)
	var duration = 0.15
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase_body = 0.0
	var phase_dissonant = 0.0
	var last_noise = 0.0
	var hp_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		
		# Fundamental slides 190 Hz down to 98 Hz
		var freq = 98.0 + 92.0 * exp(-t * 30.0)
		phase_body += freq * (TAU / SAMPLE_RATE)
		phase_dissonant += 135.0 * (TAU / SAMPLE_RATE)
		
		# Dense metal fracture crunch
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.7 * last_noise + 0.3 * white
		hp_noise = 0.9 * (hp_noise + last_noise - 0.5 * white)
		
		var crunch_env = exp(-t * 110.0)
		var thud_env = pow(1.0 - p, 1.6)
		
		var body = (sin(phase_body) * 0.65 + sin(phase_dissonant) * 0.25) * thud_env
		var crunch = hp_noise * 0.45 * crunch_env
		samples[i] = body + crunch
	
	return _create_stream_from_floats(samples)

func _generate_shield_break() -> AudioStreamWAV:
	# Crystalline forcefield shattering and energy collapse (780 -> 240 Hz dispersal with fizzle)
	var duration = 0.24
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var p1 = 0.0
	var p2 = 0.0
	var p3 = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		
		# Tri-harmonic crystalline cluster sweeping down
		var f1 = 260.0 + 520.0 * exp(-t * 18.0)
		var f2 = 340.0 + 540.0 * exp(-t * 22.0)
		var f3 = 180.0 + 320.0 * exp(-t * 14.0)
		p1 += f1 * (TAU / SAMPLE_RATE)
		p2 += f2 * (TAU / SAMPLE_RATE)
		p3 += f3 * (TAU / SAMPLE_RATE)
		
		# Electrical fizzle noise
		var white = (randf() * 2.0 - 1.0)
		last_noise = 0.8 * last_noise + 0.2 * white
		var fizzle_env = pow(1.0 - p, 1.3) * (0.5 + 0.5 * sin(t * 120.0))
		var shatter_env = exp(-t * 16.0)
		
		var s = (sin(p1) * 0.35 + sin(p2) * 0.3 + sin(p3) * 0.25) * shatter_env + last_noise * 0.35 * fizzle_env
		samples[i] = s
	
	return _create_stream_from_floats(samples)

func _generate_shield_recharge() -> AudioStreamWAV:
	# Affirmative dual-tone harmonic chime (330 Hz -> 660 Hz ascending energy engage)
	var duration = 0.22
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 330.0 + pow(p, 1.4) * 330.0
		phase += freq * (TAU / SAMPLE_RATE)
		var env = sin(p * PI)
		samples[i] = (sin(phase) * 0.7 + sin(phase * 2.0) * 0.3) * env
	
	return _create_stream_from_floats(samples)

func _generate_low_hull_alarm() -> AudioStreamWAV:
	# Tactical cockpit warning double-blip (880 Hz / 740 Hz micro-beeps)
	var duration = 0.16
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var p1 = 0.0
	var p2 = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		p1 += 880.0 * (TAU / SAMPLE_RATE)
		p2 += 740.0 * (TAU / SAMPLE_RATE)
		
		# Beep 1: 0.00 to 0.06s
		var env1 = 0.0
		if t < 0.06:
			env1 = sin((t / 0.06) * PI)
			
		# Beep 2: 0.08 to 0.14s
		var env2 = 0.0
		if t >= 0.08 and t < 0.14:
			env2 = sin(((t - 0.08) / 0.06) * PI)
			
		samples[i] = sin(p1) * 0.6 * env1 + sin(p2) * 0.6 * env2
	
	return _create_stream_from_floats(samples)

func _generate_roll_recharge() -> AudioStreamWAV:
	# Subtle, affirmative quantum energy recharge ping (680 Hz -> 980 Hz ascending snap)
	var duration = 0.11
	var num_samples = int(SAMPLE_RATE * duration)
	var samples = PackedFloat32Array()
	samples.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / SAMPLE_RATE
		var p = t / duration
		var freq = 680.0 + pow(p, 1.2) * 300.0
		phase += freq * (TAU / SAMPLE_RATE)
		var env = sin(p * PI)
		# Crisp fundamental + glassy octave overtone
		samples[i] = (sin(phase) * 0.65 + sin(phase * 2.0) * 0.25) * env
	
	return _create_stream_from_floats(samples)


