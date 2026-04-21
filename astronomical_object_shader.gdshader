shader_type spatial;

void vertex() {
	COLOR = vec4(CUSTOM0.x, 0.0, 0.0, 1.0);
}

void fragment() {
	ALBEDO = COLOR.rgb;
}