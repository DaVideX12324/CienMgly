shader_type canvas_item;
// Wejście do walki: zrzut świata tnie się na poziome paski, które z błyskiem i rozdzieleniem RGB
// wyjeżdżają na przemian w lewo i w prawo, zostawiając czerń.
// progress 0 = obraz świata bez zmian, 1 = pełna czerń.

uniform sampler2D snap : filter_nearest, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float bands = 14.0;
uniform float split_max = 0.035;
uniform float punch = 0.12;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float inside(float x) {
	return step(0.0, x) * step(x, 1.0);
}

void fragment() {
	float p = progress;
	float id = floor(UV.y * bands);
	float h = hash(id + 1.0);
	float dir = mod(id, 2.0) < 1.0 ? 1.0 : -1.0;

	// najazd kamery na początku, potem paski ruszają w różnych momentach
	float start = 0.2 + h * 0.25;
	float t = clamp((p - start) / (1.0 - start), 0.0, 1.0);
	float off = dir * t * t * (1.2 + h);
	float glitch = (h - 0.5) * 0.04 * sin(p * 40.0) * p;
	float split = split_max * t;

	vec2 c = UV - 0.5;
	c *= 1.0 - punch * min(p * 4.0, 1.0);
	float x = c.x + 0.5 - off + glitch;
	float y = clamp(c.y + 0.5, 0.0, 1.0);

	float xr = x + split;
	float xb = x - split;
	float r = texture(snap, vec2(clamp(xr, 0.0, 1.0), y)).r * inside(xr);
	float g = texture(snap, vec2(clamp(x, 0.0, 1.0), y)).g * inside(x);
	float b = texture(snap, vec2(clamp(xb, 0.0, 1.0), y)).b * inside(xb);
	vec3 col = vec3(r, g, b) * (1.0 - 0.4 * p);

	// krótki biały błysk na początku
	float flash = exp(-pow((p - 0.12) / 0.06, 2.0));
	col += vec3(0.8 * flash) * inside(x);

	COLOR = vec4(col, COLOR.a);  // alfa z modulate rodzica — bez tego fade na końcu nie działa (nakładka znika skokiem)
}
