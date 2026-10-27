shader_type canvas_item;
// Wejście do walki: zrzut świata wiruje, pikseluje się i zamyka się w czarną „źrenicę”.
// progress 0 = obraz świata bez zmian, 1 = pełna czerń.

uniform sampler2D snap : filter_nearest, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size_max = 40.0;
uniform float swirl_turns = 0.9;
uniform float zoom = 0.4;

void fragment() {
	vec2 res = vec2(textureSize(snap, 0));
	vec2 c = UV - 0.5;
	float aspect = res.x / res.y;
	float r = length(c * vec2(aspect, 1.0)) / (0.5 * sqrt(aspect * aspect + 1.0));
	float p = progress;
	// wir silniejszy w środku, narasta z kwadratem postępu
	float ang = p * p * swirl_turns * TAU * (1.0 - clamp(r, 0.0, 1.0));
	mat2 rot = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang)));
	vec2 suv = rot * c * (1.0 - p * zoom) + 0.5;
	float px = mix(1.0, pixel_size_max, p * p);
	suv = (floor(suv * res / px) + 0.5) * px / res;
	vec3 col = texture(snap, clamp(suv, vec2(0.0), vec2(1.0))).rgb;
	// źrenica zamykająca się do środka
	float iris = mix(1.25, 0.0, smoothstep(0.35, 1.0, p));
	float edge = smoothstep(iris, iris - 0.08, r);
	col = mix(vec3(0.0), col * mix(1.0, 0.55, p), edge);
	COLOR = vec4(col, COLOR.a);  // alfa z modulate rodzica — bez tego fade na końcu nie działa (nakładka znika skokiem)
}
