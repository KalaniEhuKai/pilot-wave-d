extends Node

## HighScoreManager.gd - Persistent arcade flight log and leaderboard tracker.
## Persists top 10 run records locally to user://high_scores.json.

signal high_scores_updated()

const SAVE_PATH: String = "user://high_scores.json"
const MAX_ENTRIES: int = 10

var high_score_recording_enabled: bool = true
var high_scores: Array[Dictionary] = []

const DEFAULT_SCORES: Array[Dictionary] = [
	{"rank": 1, "score": 150000, "sector": 3, "wave": 36, "mode": "1P Normal", "time_seconds": 540.0, "kills": 380, "date": "2026-09-12", "victory": true},
	{"rank": 2, "score": 115000, "sector": 3, "wave": 32, "mode": "2P Co-Op", "time_seconds": 490.0, "kills": 320, "date": "2026-09-11", "victory": false},
	{"rank": 3, "score": 88000, "sector": 2, "wave": 24, "mode": "1P Normal", "time_seconds": 410.0, "kills": 245, "date": "2026-09-10", "victory": true},
	{"rank": 4, "score": 62000, "sector": 2, "wave": 19, "mode": "1P Normal", "time_seconds": 320.0, "kills": 180, "date": "2026-09-09", "victory": false},
	{"rank": 5, "score": 45000, "sector": 1, "wave": 12, "mode": "2P Co-Op", "time_seconds": 250.0, "kills": 140, "date": "2026-09-08", "victory": true},
	{"rank": 6, "score": 32000, "sector": 1, "wave": 11, "mode": "1P Normal", "time_seconds": 210.0, "kills": 105, "date": "2026-09-07", "victory": false},
	{"rank": 7, "score": 24000, "sector": 1, "wave": 8, "mode": "1P Normal", "time_seconds": 160.0, "kills": 78, "date": "2026-09-06", "victory": false},
	{"rank": 8, "score": 18000, "sector": 1, "wave": 6, "mode": "1P Normal", "time_seconds": 125.0, "kills": 55, "date": "2026-09-05", "victory": false},
	{"rank": 9, "score": 12000, "sector": 1, "wave": 4, "mode": "1P Normal", "time_seconds": 85.0, "kills": 38, "date": "2026-09-04", "victory": false},
	{"rank": 10, "score": 7500, "sector": 1, "wave": 2, "mode": "1P Normal", "time_seconds": 45.0, "kills": 20, "date": "2026-09-03", "victory": false},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_scores()

func load_scores() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		reset_to_defaults()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		reset_to_defaults()
		return
	
	var json_str = file.get_as_text()
	file.close()
	
	var test_json = JSON.new()
	var err = test_json.parse(json_str)
	if err == OK and test_json.data is Array:
		high_scores.clear()
		for item in test_json.data:
			if item is Dictionary:
				high_scores.append(item)
		_reindex_and_sort()
	else:
		reset_to_defaults()

func save_scores() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(high_scores, "\t")
		file.store_string(json_str)
		file.close()
	high_scores_updated.emit()

func get_scores() -> Array[Dictionary]:
	return high_scores.duplicate(true)

func record_run(score: int, sector: int, wave: int, mode_name: String, time_sec: float, kills: int, victory: bool) -> int:
	if not high_score_recording_enabled or (GameManager != null and not GameManager.high_score_recording_enabled):
		return 0
	if score <= 0:
		return 0
	
	# Determine if this run ranks in the top 10
	var qualifies = false
	if high_scores.size() < MAX_ENTRIES:
		qualifies = true
	elif score > int(high_scores.back().get("score", 0)):
		qualifies = true
	
	if not qualifies:
		return 0
	
	var now = Time.get_date_string_from_system()
	var new_entry = {
		"rank": 0,
		"score": score,
		"sector": sector,
		"wave": wave,
		"mode": mode_name,
		"time_seconds": time_sec,
		"kills": kills,
		"date": now,
		"victory": victory
	}
	
	high_scores.append(new_entry)
	_reindex_and_sort()
	save_scores()
	
	# Find where new_entry landed
	for i in range(high_scores.size()):
		var entry = high_scores[i]
		if entry["score"] == score and entry["time_seconds"] == time_sec and entry["kills"] == kills:
			return int(entry["rank"])
	
	return 0

func is_high_score(score: int) -> bool:
	if not high_score_recording_enabled or (GameManager != null and not GameManager.high_score_recording_enabled):
		return false
	if score <= 0:
		return false
	if high_scores.size() < MAX_ENTRIES:
		return true
	return score > int(high_scores.back().get("score", 0))

func reset_to_defaults() -> void:
	high_scores.clear()
	for s in DEFAULT_SCORES:
		high_scores.append(s.duplicate())
	_reindex_and_sort()
	save_scores()

func clear_scores() -> void:
	high_scores.clear()
	save_scores()

func _reindex_and_sort() -> void:
	high_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa = int(a.get("score", 0))
		var sb = int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		# Tie break: longer survival / higher sector
		var seca = int(a.get("sector", 0))
		var secb = int(b.get("sector", 0))
		if seca != secb:
			return seca > secb
		return float(a.get("time_seconds", 0.0)) > float(b.get("time_seconds", 0.0))
	)
	
	while high_scores.size() > MAX_ENTRIES:
		high_scores.pop_back()
	
	for i in range(high_scores.size()):
		high_scores[i]["rank"] = i + 1

static func format_time(time_sec: float) -> String:
	var mins = int(time_sec / 60.0)
	var secs = int(fmod(time_sec, 60.0))
	return "%02d:%02d" % [mins, secs]
