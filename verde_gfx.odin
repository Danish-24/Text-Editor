package verde

import "core:fmt"
import gl "vendor:OpenGL"

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

MAX_TRIANGLES     :: 4096
MAX_VERTEX_COUNT  :: MAX_TRIANGLES * 3

@(rodata) VERTEX_SHADER   := #load("shaders/ui.vert", cstring)
@(rodata) FRAGMENT_SHADER := #load("shaders/ui.frag", cstring)

Shader_Uniform :: enum u32 {
  UI_Texture,
  UI_ProjMatrix,
}

Render_Vertex :: struct {
  position : vec2,
  color    : vec4,
  uv       : vec2,
}

GFX_Context :: struct {
  ui_vao, ui_vbo, ui_ibo : u32,
  ui_shader              : u32,
  uniform_loc            : [Shader_Uniform]i32,
}

gfx_init :: proc(load_proc: gl.Set_Proc_Address_Type) -> (ctx: GFX_Context, ok: bool) {
  ctx = GFX_Context{}

  gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, load_proc)

  gl.Enable(gl.DEPTH_TEST)
  gl.Enable(gl.BLEND)
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
  gl.DepthFunc(gl.LEQUAL)

  // Vertex Array
  gl.GenVertexArrays(1, &ctx.ui_vao)
  gl.BindVertexArray(ctx.ui_vao)

  VTX_SIZE :: size_of(Render_Vertex)

  // Vertex Buffer
  gl.GenBuffers(1, &ctx.ui_vbo)
  gl.BindBuffer(gl.ARRAY_BUFFER, ctx.ui_vbo)
  gl.BufferData(gl.ARRAY_BUFFER, MAX_VERTEX_COUNT * VTX_SIZE, nil, gl.DYNAMIC_DRAW)

  gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, VTX_SIZE, cast(uintptr) offset_of(Render_Vertex, position))
  gl.EnableVertexAttribArray(0)

  gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, VTX_SIZE, cast(uintptr) offset_of(Render_Vertex, color))
  gl.EnableVertexAttribArray(1)

  gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, VTX_SIZE, cast(uintptr) offset_of(Render_Vertex, uv))
  gl.EnableVertexAttribArray(2)

  // Index Buffer
  gl.GenBuffers(1, &ctx.ui_ibo)
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ui_ibo)
  gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, MAX_VERTEX_COUNT * size_of(u32), nil, gl.DYNAMIC_DRAW)

  // Shaders
  ctx.ui_shader = gl.CreateProgram()

  vtx_shader := gl.CreateShader(gl.VERTEX_SHADER)
  defer gl.DeleteShader(vtx_shader)
  gl.ShaderSource(vtx_shader, 1, &VERTEX_SHADER, nil)
  gl.CompileShader(vtx_shader)

  frg_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
  defer gl.DeleteShader(frg_shader)
  gl.ShaderSource(frg_shader, 1, &FRAGMENT_SHADER, nil)
  gl.CompileShader(frg_shader)

  gl.AttachShader(ctx.ui_shader, vtx_shader)
  gl.AttachShader(ctx.ui_shader, frg_shader)
  gl.LinkProgram(ctx.ui_shader)
  gl.UseProgram(ctx.ui_shader)

  ctx.uniform_loc = {
    .UI_Texture   = gl.GetUniformLocation(ctx.ui_shader, "Texture"),
    .UI_ProjMatrix = gl.GetUniformLocation(ctx.ui_shader, "ProjMatrix"),
  }

  return ctx, true
}

gfx_clear :: proc(color: vec4 = {0.1, 0.1, 0.1, 1.0}) {
  gl.ClearColor(color.r, color.g, color.b, color.a)
  gl.Clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT)
}
