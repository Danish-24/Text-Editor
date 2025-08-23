#version 330 core
layout (location = 0) in vec2 Position;
layout (location = 1) in vec4 Color;
layout (location = 2) in vec2 UV;
layout (location = 3) in vec2 CircCoords;

uniform mat4 ProjMatrix;

out vec2 Frag_UV;
out vec2 Frag_CircCoords;
out vec4 Frag_Color;

void main() {
  Frag_UV = UV;
  Frag_Color = Color;
  Frag_CircCoords = CircCoords;
  gl_Position = ProjMatrix * vec4(Position, 0, 1);
}


