extends Node

## SoundEffects.gd - In-engine procedural sound synthesis for instant, zero-asset, cross-platform audio.
## Generates clean retro-modern shmup audio buffers at boot.

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
const MAX_VOICES: int = 12

func _ready() -> void:
	# Create pool of AudioStreamPlayers
	for i in range(MAX_VOICES):
		var p = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)
	
	# Generate sound waveforms
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

func play_sfx(name: String, pitch_range: float = 0.08, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = 1.0 + randf_range(-pitch_range, pitch_range)
			p.volume_db = volume_db
			p.play()
			return
	
	# If all busy, hijack first
	_players[0].stream = _streams[name]
	_players[0].pitch_scale = 1.0 + randf_range(-pitch_range, pitch_range)
	_players[0].volume_db = volume_db
	_players[0].play()

func _create_stream_from_samples(samples: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = samples
	return wav

func _generate_laser() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.11
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = lerpf(980.0, 240.0, t / duration)
		phase += freq * (TAU / sample_rate)
		var envelope = 1.0 - (t / duration)
		var s = sin(phase) * envelope
		data[i] = clampi(int((s * 0.7 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_hit() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.07
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = lerpf(450.0, 120.0, t / duration)
		phase += freq * (TAU / sample_rate)
		var env = exp(-t * 35.0)
		var s = (sin(phase) + (randf() * 2.0 - 1.0) * 0.4) * env
		data[i] = clampi(int((s * 0.6 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_explosion() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.42
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var progress = t / duration
		var env = pow(1.0 - progress, 1.8)
		# Low pass filtered white noise
		var white = (randf() * 2.0 - 1.0)
		last_noise = lerpf(last_noise, white, 0.25)
		var rumble = sin(t * TAU * lerpf(95.0, 35.0, progress)) * 0.5
		var s = (last_noise * 0.8 + rumble) * env
		data[i] = clampi(int((s * 0.85 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_roll() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.35
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var p = t / duration
		# Up-and-down resonant pitch sweep
		var freq = 300.0 + sin(p * PI) * 550.0
		phase += freq * (TAU / sample_rate)
		var env = sin(p * PI)
		var s = (sin(phase) * 0.7 + (randf() * 2.0 - 1.0) * 0.2) * env
		data[i] = clampi(int((s * 0.7 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_bonus() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.45
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	# Arpeggio chime: 523Hz (C5) -> 659Hz (E5) -> 784Hz (G5) -> 1046Hz (C6)
	var notes = [523.25, 659.25, 783.99, 1046.50]
	var phase = 0.0
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var note_idx = clampi(int(t / 0.1), 0, notes.size() - 1)
		var freq = notes[note_idx]
		phase += freq * (TAU / sample_rate)
		var env = 1.0 - (t / duration)
		var s = sin(phase) * env
		data[i] = clampi(int((s * 0.7 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_hurt() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.22
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var freq = lerpf(220.0, 75.0, t / duration)
		phase += freq * (TAU / sample_rate)
		var env = 1.0 - (t / duration)
		var s = (sin(phase) * 0.8 + (randf() * 2.0 - 1.0) * 0.3) * env
		data[i] = clampi(int((s * 0.8 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_quantum_collapse() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.18
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var p = t / duration
		var base_freq = lerpf(840.0, 90.0, pow(p, 0.7))
		var mod = sin(t * TAU * 52.0) * (180.0 * (1.0 - p))
		phase += (base_freq + mod) * (TAU / sample_rate)
		var env = pow(1.0 - p, 0.85)
		var pop = sin(t * TAU * 65.0) * exp(-p * 4.0) * 0.4
		var s = (sin(phase) * 0.65 + pop) * env
		data[i] = clampi(int((s * 0.85 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_warp_charge() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.40
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var p = t / duration
		# Accelerating de Broglie frequency sweep with pulsing vibrato
		var freq = lerpf(240.0, 780.0, pow(p, 1.4))
		var vibrato = sin(t * TAU * 18.0) * (60.0 * p)
		phase += (freq + vibrato) * (TAU / sample_rate)
		var env = pow(p, 0.6) * 0.9
		var s = sin(phase) * env
		data[i] = clampi(int((s * 0.75 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_quantum_jump() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.36
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	var last_noise = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var p = t / duration
		# Relativistic downward displacement sweep + hyper-velocity burst
		var freq = lerpf(1800.0, 80.0, pow(p, 0.45))
		phase += freq * (TAU / sample_rate)
		var env = exp(-p * 4.2)
		var white = (randf() * 2.0 - 1.0)
		last_noise = lerpf(last_noise, white, 0.3)
		var tone = sin(phase) * 0.6
		var s = (tone + last_noise * 0.4) * env
		data[i] = clampi(int((s * 0.85 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_docking_clamp() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.28
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var p = t / duration
		# Initial metallic strike (fast decay) + pneumatic hiss
		var strike_env = exp(-t * 45.0)
		var freq = lerpf(380.0, 95.0, minf(1.0, t * 25.0))
		phase += freq * (TAU / sample_rate)
		var strike = sin(phase) * strike_env
		
		# Hiss component (0.04s onwards)
		var hiss_env = 0.0
		if t > 0.04:
			hiss_env = (1.0 - (t - 0.04) / (duration - 0.04)) * 0.35
		var hiss = (randf() * 2.0 - 1.0) * hiss_env
		
		var s = strike * 0.7 + hiss * 0.3
		data[i] = clampi(int((s * 0.8 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)

func _generate_wave_cleared() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.35
	var num_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	# Bright 3-tone arpeggio: D5 (587.33), F#5 (739.99), A5 (880.0)
	var notes = [587.33, 739.99, 880.00]
	var phase = 0.0
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var note_idx = clampi(int(t / 0.11), 0, notes.size() - 1)
		var freq = notes[note_idx]
		phase += freq * (TAU / sample_rate)
		var note_t = fmod(t, 0.11)
		var env = (1.0 - (t / duration)) * (1.0 - (note_t / 0.11) * 0.35)
		var s = (sin(phase) * 0.75 + sin(phase * 2.0) * 0.2) * env
		data[i] = clampi(int((s * 0.75 + 1.0) * 127.5), 0, 255)
	
	return _create_stream_from_samples(data, sample_rate)
