class_name MenuStyleHelper
extends RefCounted

## MenuStyleHelper.gd - Centralized cyberpunk styling and audio feedback for UI buttons and controls.
## Ensures universal keyboard, controller, and mouse/touch focus across all game menus.

static func style_button(
	btn: Button,
	accent_color: Color = Color(0.2, 0.85, 1.0, 1.0),
	bg_color: Color = Color(0.08, 0.14, 0.22, 0.85),
	connect_audio: bool = true
) -> void:
	btn.focus_mode = Control.FOCUS_ALL
	
	# Normal stylebox
	var sb_normal = StyleBoxFlat.new()
	sb_normal.bg_color = bg_color
	sb_normal.border_width_left = 1
	sb_normal.border_width_top = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_bottom = 1
	sb_normal.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.45)
	sb_normal.corner_radius_top_left = 6
	sb_normal.corner_radius_top_right = 6
	sb_normal.corner_radius_bottom_right = 6
	sb_normal.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", sb_normal)
	
	# Hover stylebox (Mouse hover)
	var sb_hover = StyleBoxFlat.new()
	sb_hover.bg_color = Color(bg_color.r * 1.3, bg_color.g * 1.3, bg_color.b * 1.3, 0.95)
	sb_hover.border_width_left = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_bottom = 2
	sb_hover.border_color = accent_color
	sb_hover.corner_radius_top_left = 6
	sb_hover.corner_radius_top_right = 6
	sb_hover.corner_radius_bottom_right = 6
	sb_hover.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("hover", sb_hover)
	
	# Focus stylebox (Controller D-Pad/Left Stick & Keyboard Arrow/WASD)
	var sb_focus = StyleBoxFlat.new()
	sb_focus.bg_color = Color(accent_color.r * 0.25, accent_color.g * 0.25, accent_color.b * 0.25, 0.95)
	sb_focus.border_width_left = 2
	sb_focus.border_width_top = 2
	sb_focus.border_width_right = 2
	sb_focus.border_width_bottom = 2
	sb_focus.border_color = Color(1.0, 0.95, 0.4, 1.0) if accent_color == Color(0.2, 0.85, 1.0, 1.0) else Color(0.3, 1.0, 0.8, 1.0)
	sb_focus.corner_radius_top_left = 6
	sb_focus.corner_radius_top_right = 6
	sb_focus.corner_radius_bottom_right = 6
	sb_focus.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("focus", sb_focus)
	
	# Pressed stylebox
	var sb_pressed = StyleBoxFlat.new()
	sb_pressed.bg_color = Color(accent_color.r * 0.5, accent_color.g * 0.5, accent_color.b * 0.5, 0.95)
	sb_pressed.border_width_left = 2
	sb_pressed.border_width_top = 2
	sb_pressed.border_width_right = 2
	sb_pressed.border_width_bottom = 2
	sb_pressed.border_color = Color(1.0, 1.0, 1.0, 1.0)
	sb_pressed.corner_radius_top_left = 6
	sb_pressed.corner_radius_top_right = 6
	sb_pressed.corner_radius_bottom_right = 6
	sb_pressed.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	
	# Colors
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	
	if connect_audio:
		btn.mouse_entered.connect(func():
			if not btn.disabled and SoundEffects:
				SoundEffects.play_sfx("ui_hover", 0.05, -6.0)
		)
		btn.focus_entered.connect(func():
			if not btn.disabled and SoundEffects:
				SoundEffects.play_sfx("ui_hover", 0.05, -6.0)
		)
		btn.pressed.connect(func():
			if not btn.disabled and SoundEffects:
				SoundEffects.play_sfx("ui_select", 0.02, -3.0)
		)

static func create_panel_style(
	border_color: Color = Color(0.2, 0.85, 1.0, 0.8),
	bg_color: Color = Color(0.04, 0.06, 0.1, 0.92)
) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border_color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	return sb
