package verde

import "core:fmt"
import gl "vendor:OpenGL"

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

MAX_TRIANGLES     :: 4096
MAX_VERTEX_COUNT  :: MAX_TRIANGLES * 3

VTX_SIZE :: size_of(Render_Vertex)

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

Render_Buffer :: struct {
  vertices : [^]Render_Vertex,
  indices  : [^]u32,

  vtx_count : u32,
  idx_count : u32,
}

GFX_State :: struct {
  ui_vao, ui_vbo, ui_ibo : u32,
  ui_shader              : u32,
  uniform_loc            : [Shader_Uniform]i32,

  render_buffer          : Render_Buffer,
}

gfx_init :: proc(load_proc: gl.Set_Proc_Address_Type) -> (ctx: GFX_State, ok: bool) {
  ctx = GFX_State{}

  gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, load_proc)

  gl.Enable(gl.DEPTH_TEST)
  gl.Enable(gl.BLEND)
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
  gl.DepthFunc(gl.LEQUAL)

  // Vertex Array
  gl.GenVertexArrays(1, &ctx.ui_vao)
  gl.BindVertexArray(ctx.ui_vao)

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

  ctx.render_buffer.vertices = make([^]Render_Vertex, MAX_VERTEX_COUNT)
  ctx.render_buffer.indices = make([^]u32, MAX_VERTEX_COUNT)

  return ctx, true
}

gfx_clear :: proc(color: vec4 = {0.1, 0.1, 0.1, 1.0}) {
  gl.ClearColor(color.r, color.g, color.b, color.a)
  gl.Clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT)
}

gfx_begin_frame :: proc(ctx: ^GFX_State) {
  gfx_ready(ctx)

  gl.UseProgram(ctx.ui_shader)
  gl.BindVertexArray(ctx.ui_vao)
}

gfx_end_frame :: proc(ctx: ^GFX_State) {
  gfx_flush(ctx)
}

gfx_ready :: proc(ctx: ^GFX_State) {
  ctx.render_buffer.vtx_count = 0
  ctx.render_buffer.idx_count = 0
}

gfx_flush :: proc(ctx: ^GFX_State) {
  using ctx

  gl.BindBuffer(gl.ARRAY_BUFFER, ui_vbo)
  gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) render_buffer.vtx_count * VTX_SIZE, render_buffer.vertices)

  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ui_ibo)
  gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) render_buffer.idx_count * size_of(u32), render_buffer.indices)
  gl.DrawElements(gl.TRIANGLES, cast(i32) render_buffer.idx_count, gl.UNSIGNED_INT, nil)
}

gfx_push_rect :: proc(ctx : ^GFX_State, pos, size : vec2, color : vec4 = 1.0) {
  using ctx

  if render_buffer.vtx_count + 4 > MAX_VERTEX_COUNT || render_buffer.idx_count + 6 > MAX_VERTEX_COUNT {
    gfx_flush(ctx)
    gfx_ready(ctx)
  }

  vc := render_buffer.vtx_count
  ic := render_buffer.idx_count

	p0 := pos
	p1 := pos + (vec2{size.x, 0})
	p2 := pos + (vec2{size.x, size.y})
	p3 := pos + (vec2{0, size.y})

	render_buffer.vertices[vc + 0] = Render_Vertex{p0, color, {0,0}}
	render_buffer.vertices[vc + 1] = Render_Vertex{p1, color, {1,0}}
	render_buffer.vertices[vc + 2] = Render_Vertex{p2, color, {1,1}}
	render_buffer.vertices[vc + 3] = Render_Vertex{p3, color, {0,1}}

	render_buffer.indices[ic + 0] = vc + 0
	render_buffer.indices[ic + 1] = vc + 1
	render_buffer.indices[ic + 2] = vc + 2
	render_buffer.indices[ic + 3] = vc + 2
	render_buffer.indices[ic + 4] = vc + 3
	render_buffer.indices[ic + 5] = vc + 0

	render_buffer.vtx_count += 4
	render_buffer.idx_count += 6
}

gfx_upload_proj :: proc(ctx: ^GFX_State, width, height : f32) {
  proj := ortho_matrix(0, width, height, 0, -1.0, 100.0)
  gl.UniformMatrix4fv(ctx.uniform_loc[.UI_ProjMatrix], 1, gl.FALSE, &proj[0][0])
}

ortho_matrix :: proc(left, right, bottom, top: f32, near, far: f32) -> mat4x4 {
    result: mat4x4 = 0
    result[0][0] =  2.0 / (right - left)
    result[1][1] =  2.0 / (top - bottom)
    result[2][2] = -2.0 / (far - near)

    result[3][0] = -(right + left) / (right - left)
    result[3][1] = -(top + bottom) / (top - bottom)
    result[3][2] = -(far + near) / (far - near)
    result[3][3] = 1.0
    return result
}

gfx_resize_target :: proc(w, h : i32) {
  gl.Viewport(0, 0, w, h)
}
