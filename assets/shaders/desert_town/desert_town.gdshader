shader_type canvas_item;

uniform vec2 player_position;
uniform float circle_radius : hint_range(0.0, 30.0); // pixels
uniform float min_alpha : hint_range(0.0, 1.0); // przezroczystość w miejscu gracza
uniform float max_alpha : hint_range(0.0, 1.0); // przezroczystość na zewnątrz koła
uniform float smoothness : hint_range(0.1, 10.0); // kontrola szybkości zmiany


varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0, 1.0)).xy;
}

void fragment() {
	float dist = distance(player_position, world_position);
	vec4 orig_color = texture(TEXTURE, UV);
	const float EPSILON = 0.0001;
	float alpha_total = 1.0;
	float t = clamp(dist / circle_radius, 0.0, 1.0);
	float power = pow(t, smoothness);
	// Sprawdzenie czy w obrębie okręgu (bez ostrzeżenia)
	if (abs(dist - circle_radius) < EPSILON) {
		alpha_total = mix(min_alpha, max_alpha, t);
	} else if (dist < circle_radius) {
		alpha_total = mix(min_alpha, max_alpha, power);
	}

	COLOR.rgb = orig_color.rgb;
	COLOR.a = alpha_total * orig_color.a;
}
