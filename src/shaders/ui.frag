#version 330 core

in vec2 Frag_UV;
in vec2 Frag_CircCoords;
in vec4 Frag_Color;
in float Frag_TexID;

uniform sampler2D Textures[16];

layout (location = 0) out vec4 Out_Color;

void main() {
  int tex_id = int(Frag_TexID);
  float dist = length(Frag_CircCoords) - 1.0;

  float edge_width = fwidth(dist) * 0.7;
  float alpha = 1.0 - smoothstep(-edge_width, edge_width, dist);

  vec4 base = Frag_Color * texture(Textures[tex_id], Frag_UV);
  Out_Color = vec4(base.rgb, base.a * alpha);
}
