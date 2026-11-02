shader_type canvas_item;

// Hit-flash: blends everything this CanvasItem draws toward flash_color.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = COLOR;
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
}
