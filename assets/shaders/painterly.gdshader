shader_type canvas_item;
// Rifinitura leggera a tutto schermo sul mondo (sfondo, fattoria), sotto
// l'interfaccia: luce calda del sole e grana della carta, per legare tra
// loro illustrazioni e parti disegnate da codice. Non sfoca e non spegne i
// colori: le illustrazioni devono restare nitide e vivaci (docs/art_direction.md).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 warm_tint = vec3(1.025, 1.0, 0.95);
uniform float paper_strength = 0.035;
uniform float vignette = 0.18;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 col = textureLod(screen_tex, SCREEN_UV, 0.0).rgb * warm_tint;
	float grain = hash(floor(FRAGCOORD.xy));
	col *= 1.0 - (grain - 0.5) * paper_strength;
	// vignettatura calda ai bordi
	vec2 d = SCREEN_UV - 0.5;
	col = mix(col, col * vec3(0.86, 0.78, 0.68), smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.8))) * vignette);
	COLOR = vec4(col, 1.0);
}
