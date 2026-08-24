shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;  // Centruj UV (-1 do 1)
	float dist = length(uv);  // Dystans od środka
	
	// Gradient od środka (0.0) do rogów (1.0)
	float vignette = smoothstep(0.5, 1.5, dist);
	
	COLOR = color;
	COLOR.a = vignette * intensity;
}
