shader_type canvas_item;

uniform bool flash_active = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

uniform bool empowerment_active = false;
uniform float empowerment_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    vec3 final_color = texture_color.rgb;
    
    // Flash effect
    if (flash_active && texture_color.a > 0.1) {
        final_color = mix(final_color, flash_color.rgb, flash_amount);
    }
    
    // Empowerment effect – pokolorowanie na czerwono
    if (empowerment_active && texture_color.a > 0.1) {
        // Wzmacniaj red, zmniejszaj green i blue
        final_color.r = mix(final_color.r, final_color.r * 1.5, empowerment_amount);
        final_color.g = mix(final_color.g, final_color.g * 0.4, empowerment_amount);
        final_color.b = mix(final_color.b, final_color.b * 0.4, empowerment_amount);
    }
    
    COLOR = vec4(final_color, texture_color.a * alpha);
}
