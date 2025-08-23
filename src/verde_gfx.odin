package verde

import "core:fmt"
import "core:math"

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
  circ_mask: vec2,
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

  gl.Enable(gl.MULTISAMPLE);

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

  gl.VertexAttribPointer(3, 2, gl.FLOAT, gl.FALSE, VTX_SIZE, cast(uintptr) offset_of(Render_Vertex, circ_mask))
  gl.EnableVertexAttribArray(3)

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

  gl.BindBuffer(gl.ARRAY_BUFFER, ctx.ui_vbo)
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ui_ibo)
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

  gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) render_buffer.vtx_count * VTX_SIZE, render_buffer.vertices)
  gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) render_buffer.idx_count * size_of(u32), render_buffer.indices)
  gl.DrawElements(gl.TRIANGLES, cast(i32) render_buffer.idx_count, gl.UNSIGNED_INT, nil)
}

gfx_push_rect :: proc(ctx : ^GFX_State, pos, size : vec2, color : vec4 = 1.0, uv : vec4 = {0,0,1,1}) {
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

  render_buffer.vertices[vc + 0] = Render_Vertex{p0, color, uv.xy, {-1,-1}}
  render_buffer.vertices[vc + 1] = Render_Vertex{p1, color, uv.zy, { 1,-1}}
  render_buffer.vertices[vc + 2] = Render_Vertex{p2, color, uv.zw, { 1, 1}}
  render_buffer.vertices[vc + 3] = Render_Vertex{p3, color, uv.xw, {-1, 1}}

  render_buffer.indices[ic + 0] = vc + 0
  render_buffer.indices[ic + 1] = vc + 1
  render_buffer.indices[ic + 2] = vc + 2
  render_buffer.indices[ic + 3] = vc + 2
  render_buffer.indices[ic + 4] = vc + 3
  render_buffer.indices[ic + 5] = vc + 0

  render_buffer.vtx_count += 4
  render_buffer.idx_count += 6
}

gfx_push_triangle :: proc(
  ctx : ^GFX_State,
  p0, p1, p2 : vec2,
  col0, col1, col2 : vec4,
  uv0, uv1, uv2 : vec2,
  cir0, cir1, cir2 : vec2,
) {
  using ctx

  if render_buffer.vtx_count + 3 > MAX_VERTEX_COUNT || render_buffer.idx_count + 3 > MAX_VERTEX_COUNT {
    gfx_flush(ctx)
    gfx_ready(ctx)
  }

  base_index := render_buffer.vtx_count
  vptr := render_buffer.vertices

  vptr[base_index + 0] = Render_Vertex{p0, col0, uv0, cir0}
  vptr[base_index + 1] = Render_Vertex{p1, col1, uv1, cir1}
  vptr[base_index + 2] = Render_Vertex{p2, col2, uv2, cir2}

  iptr := render_buffer.indices
  iptr[render_buffer.idx_count + 0] = base_index + 0
  iptr[render_buffer.idx_count + 1] = base_index + 1
  iptr[render_buffer.idx_count + 2] = base_index + 2

  render_buffer.vtx_count += 3
  render_buffer.idx_count += 3
}

gfx_push_rect_rounded :: proc(
  ctx : ^GFX_State,
  pos, size : [2]f32,
  color : [4]f32 = 1.0,
  radii : [4]f32 = 10.0,
  uv : [4]f32 = {0,0,1,1},
) {
  using ctx
  if size.x <= 0.0 || size.y <= 0.0 { return }
  
  /*
    radii correction
  */
  adjusted_radii := radii

  top_sum := radii[0] + radii[1]
  bottom_sum := radii[3] + radii[2]
  max_horizontal := max(top_sum, bottom_sum)
  if max_horizontal > size.x {
    scale := size.x / max_horizontal
    adjusted_radii[0] *= scale
    adjusted_radii[1] *= scale
    adjusted_radii[2] *= scale
    adjusted_radii[3] *= scale
  }

  left_sum := radii[0] + radii[3]
  right_sum := radii[1] + radii[2]
  max_vertical := max(left_sum, right_sum)
  if max_vertical > size.y {
    scale := size.y / max_vertical
    adjusted_radii[0] *= scale
    adjusted_radii[1] *= scale
    adjusted_radii[2] *= scale
    adjusted_radii[3] *= scale
  }


  chopped_corners := [8][2]f32 {}
  num_corners := 0

  corners := [?][2]f32 {
    pos,
    pos + {size.x, 0},
    pos + size,
    pos + {0, size.y},
  }

  @(static, rodata) clock_wise := [?][2]f32 {
    {1.0, 0.0}, {0.0, 1.0}, {-1.0, 0.0}, {0.0, -1.0}
  }

  @(static, rodata) anti_clockwise := [?][2]f32 {
    {0.0, 1.0}, {-1.0, 0.0}, {0.0, -1.0}, {1.0, 0.0}
  }

  vertex_positions : [12][2]f32
  num_vertices := u32(0)
  
  for i in 0..<4 {
    radius := adjusted_radii[i]
    corner := corners[i]

    if radius <= 0.5 {
      vertex_positions[num_vertices] = corner
      num_vertices += 1
    } else {
      vertex_positions[num_vertices]   = corner + anti_clockwise[i] * radius
      vertex_positions[num_vertices+1] = corner + clock_wise[i] * radius
      num_vertices += 2
    }
  }

  v_slots := (MAX_VERTEX_COUNT - render_buffer.vtx_count)
  i_slots := (MAX_VERTEX_COUNT - render_buffer.idx_count)

  if v_slots < num_vertices || i_slots < (num_vertices - 2) * 3 {
    gfx_flush(ctx)
    gfx_ready(ctx)
  }
  
  base_index := render_buffer.vtx_count

  for i in 0..<num_vertices {
    v := &render_buffer.vertices[base_index + u32(i)]
  
    local_pos := vertex_positions[i] - pos
    local_uv := local_pos / size

    v.position = vertex_positions[i]
    v.color = color
    v.uv = local_uv * (uv.zw - uv.xy) + uv.xy
    v.circ_mask = {0,0}
  }

  for i in 1..<num_vertices - 1 {
    render_buffer.indices[render_buffer.idx_count + (i - 1) * 3 + 0] = base_index
    render_buffer.indices[render_buffer.idx_count + (i - 1) * 3 + 1] = base_index + u32(i + 1)
    render_buffer.indices[render_buffer.idx_count + (i - 1) * 3 + 2] = base_index + u32(i)
  }

  render_buffer.vtx_count += num_vertices
  render_buffer.idx_count += (num_vertices - 2) * 3

  for i in 0..<4 {
    radius := adjusted_radii[i]
    corner := corners[i]

    if radius <= 0.5 { continue }

    p1, p2, p3 := corner, corner + anti_clockwise[i] * radius, corner + clock_wise[i] * radius
    
    gfx_push_triangle( 
      ctx,
      p1, p2, p3,
      color, color, color,
      (p1 - pos) / size * (uv.zw - uv.xy) + uv.xy, (p2 - pos) / size * (uv.zw - uv.xy) + uv.xy, (p3 - pos) / size * (uv.zw - uv.xy) + uv.xy,
      {1,1}, {0, 1},{1, 0}
    )
  }
}

//=========================
// Helpers
//=========================

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

gfx_wireframe :: proc(on : bool) {
  gl.PolygonMode(gl.FRONT_AND_BACK, on ? gl.LINE : gl.FILL)
}

