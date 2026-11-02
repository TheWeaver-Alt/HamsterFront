shader_type canvas_item;
// Hit-flash: blends the sprite towards flash_color while keeping its alpha.
// `flash` 0..1 is driven by the owning entity (tweened down after each hit).
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Optional rainbow "Sugar Rush" shimmer (0 = off).
uniform float rainbow : hint_range(0.0, 1.0) = 0.0;
// Optional warp-corruption green tint (0 = off).
uniform float warp : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = COLOR;
	if (rainbow > 0.0) {
		float t = TIME * 6.0 + UV.y * 10.0 + UV.x * 4.0;
		vec3 rb = 0.5 + 0.5 * cos(vec3(t, t + 2.094, t + 4.188));
		c.rgb = mix(c.rgb, c.rgb * 0.5 + rb * 0.6, rainbow * 0.7);
	}
	if (warp > 0.0) {
		float pulse = 0.5 + 0.5 * sin(TIME * 8.0);
		c.rgb = mix(c.rgb, vec3(0.55, 1.0, 0.35) * (0.6 + 0.4 * pulse), warp * 0.5);
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
