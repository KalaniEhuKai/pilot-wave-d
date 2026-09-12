extends Area2D

## ItemCrate.gd - Floating holographic quantum relic crate dropped by elite squadrons.

signal crate_opened()

var elapsed: float = 0.0
var is_opened: bool = false

func _ready() -> void:
	add_to_group("crate")
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	elapsed += delta
	# Slow drift along scroll direction
	global_position += GameAxis.scroll_dir * 30.0 * delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	_open(body)

func _on_area_entered(area: Area2D) -> void:
	_open(area)

func _open(target: Node2D) -> void:
	if is_opened:
		return
	if target.is_in_group("player"):
		is_opened = true
		SoundEffects.play_sfx("bonus", 0.05, 3.0)
		GameManager.request_screen_shake(6.0, 0.2)
		
		# Open item choice modal via HUD
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_item_choice_modal"):
			hud.open_item_choice_modal()
		else:
			# Direct fallback: pick a random unequipped relic
			var player = target
			var current_ids: Array[String] = []
			for m in player.active_modifiers:
				current_ids.append(m.id)
			var choices = ItemDatabase.get_random_choice(current_ids, 1)
			if not choices.is_empty():
				player.add_modifier(choices[0])
		
		queue_free()

func _draw() -> void:
	var pulse = 1.0 + sin(elapsed * 4.0) * 0.15
	var box_color = Color(0.1, 0.95, 1.0, 0.9)
	var glow_color = Color(0.8, 0.2, 1.0, 0.4)
	
	# Outer pulsing glow
	draw_rect(Rect2(Vector2(-18, -18) * pulse, Vector2(36, 36) * pulse), glow_color, false, 2.0)
	
	# Solid holographic crate box
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), Color(0.06, 0.14, 0.24, 0.95), true)
	draw_rect(Rect2(Vector2(-14, -14), Vector2(28, 28)), box_color, false, 2.0)
	
	# Cross brackets
	draw_line(Vector2(-10, -10), Vector2(10, 10), box_color, 1.5)
	draw_line(Vector2(-10, 10), Vector2(10, -10), box_color, 1.5)
	draw_circle(Vector2.ZERO, 3.5, Color.WHITE)
