#version 330 core

in vec2 Frag_UV;
in vec2 Frag_CircCoords;
in vec4 Frag_Color;

uniform sampler2D Texture;

layout (location = 0) out vec4 Out_Color;

void main() {
    float dist2 = dot(Frag_CircCoords, Frag_CircCoords);

    float r2 = 1.0;

    float edge_width = fwidth(dist2) * 0.5;
    float alpha = 1.0 - smoothstep(r2 - edge_width, r2 + edge_width, dist2);

    vec4 base = Frag_Color;
    Out_Color = vec4(base.rgb, base.a * alpha);
}
