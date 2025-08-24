#version 330 core

in vec2 Frag_UV;
in vec2 Frag_CircCoords;
in vec4 Frag_Color;

uniform sampler2D Texture;

layout (location = 0) out vec4 Out_Color;

void main() {
  float dist = length(Frag_CircCoords) - 1.0;

  float edge_width = fwidth(dist) * 0.5;
  float alpha = 1.0 - smoothstep(-edge_width, edge_width, dist);

  vec4 base = Frag_Color * texture(Texture, Frag_UV);
  Out_Color = vec4(base.rgb, base.a * alpha);
}
