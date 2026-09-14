shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// Futuristic Jet Thruster Shader (Advanced End & Edge Fading with Supersonic Shock Diamonds)
uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.42, 0.1, 1.0);
uniform float speed : hint_range(1.0, 50.0) = 22.0;
uniform float shock_freq : hint_range(1.0, 40.0) = 18.0;
uniform float shock_intensity : hint_range(0.0, 2.0) = 0.75;
uniform float end_fade_power : hint_range(0.5, 4.0) = 1.6;
uniform float edge_fade_power : hint_range(0.5, 4.0) = 1.8;
uniform float intensity : hint_range(0.5, 6.0) = 2.8;

void fragment() {
	// UV.y: 0.0 at nozzle base (connected to ship), 1.0 at exhaust tip (trailing in space)
	float progress = clamp(UV.y, 0.0, 1.0);
	
	// 1. Longitudinal End Fading: smooth dissipation toward the plume tip
	float end_fade = pow(clamp(1.0 - progress, 0.0, 1.0), end_fade_power);
	
	// 2. View-Space Silhouette Edge Fading: soft volumetric cylindrical falloff (no hard polygon edges from any camera angle)
	float view_angle = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float edge_fade = pow(view_angle, edge_fade_power);
	
	// 3. Supersonic Shock Diamonds (Mach Disks): periodic compression nodes rushing down the plume
	float wave = sin(progress * shock_freq - TIME * speed);
	float diamond = pow(clamp(wave, 0.0, 1.0), 2.5) * shock_intensity * end_fade;
	
	// 4. High-frequency turbulent exhaust flicker & longitudinal streaks
	float streaks = sin(UV.x * 37.699 + TIME * 6.0) * 0.08 * end_fade;
	float flicker = sin(progress * 42.0 - TIME * (speed * 1.5)) * 0.08 * end_fade;
	
	// 5. Total plasma density
	float density = clamp((end_fade + diamond + flicker + streaks) * edge_fade, 0.0, 1.0);
	
	// 6. Two-tone thermal gradient: incandescent white-hot core near nozzle, rich plasma on outer sheath
	float core_weight = pow(clamp(1.0 - progress, 0.0, 1.0), 2.2) * pow(edge_fade, 1.2) + diamond * 0.5;
	vec3 final_color = mix(flame_color.rgb, core_color.rgb, clamp(core_weight, 0.0, 1.0));
	
	ALBEDO = final_color * (density * intensity);
	ALPHA = density;
}
