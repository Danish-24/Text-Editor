package verde

import "core:fmt"
import "core:math"

import gl "vendor:OpenGL"

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

MAX_TRIANGLES     :: 4096
MAX_VERTEX_COUNT  :: MAX_TRIANGLES * 3
MAX_TEXTURES      :: 16

VTX_SIZE :: size_of(Render_Vertex)
WHITE_TEXTURE :: 0

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

Texture_Handle :: struct {
  gl_id : u32,
  next : u32, // freelist pointer to next ~INTERNAL ID~
}

Texture :: struct {
  data: rawptr,
  width, height, channels: i32,
}

TextureType :: enum {
  Normal,
  Bitmap
}

gfx_texture_upload :: proc(gfx: ^GFX_State, texture: Texture, type := TextureType.Normal) -> u32 {
  if texture.data == nil || texture.width <= 0 || texture.height <= 0 || texture.channels < 1 || texture.channels > 4 {
    return WHITE_TEXTURE
  }

  result_idx: u32
  
  if gfx.texture_freelist != 0 {
    result_idx = gfx.texture_freelist
    handle := &gfx.texture_slots[result_idx]
    gfx.texture_freelist = handle.next
  } else {
    result_idx = gfx.num_textures
    if result_idx >= MAX_TEXTURES { 
      return WHITE_TEXTURE
    }
    gfx.num_textures += 1
  }
  
  handle := &gfx.texture_slots[result_idx]
  handle^ = {}
  
  gl.GenTextures(1, &handle.gl_id)
  
  internal_format: i32
  format: u32
  switch texture.channels {
  case 1:
    internal_format = gl.RED
    format = gl.RED
  case 2:
    internal_format = gl.RG
    format = gl.RG
  case 3:
    internal_format = gl.RGB
    format = gl.RGB
  case 4:
    internal_format = gl.RGBA
    format = gl.RGBA
  case:
    handle.gl_id = 0
    handle.next = gfx.texture_freelist
    gfx.texture_freelist = result_idx
    return WHITE_TEXTURE
  }
  
  gl.ActiveTexture(gl.TEXTURE0 + result_idx)
  gl.BindTexture(gl.TEXTURE_2D, handle.gl_id)
  
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

  if type == .Bitmap && texture.channels == 1 {
    swizzle := [4]i32{gl.ONE, gl.ONE, gl.ONE, gl.RED}
    gl.TexParameteriv(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_RGBA, &swizzle[0])
  }
  
  gl.TexImage2D(
    gl.TEXTURE_2D,
    0, // level
    internal_format,
    texture.width,
    texture.height,
    0, // border
    format,
    gl.UNSIGNED_BYTE,
    texture.data,
  )

  gl.GenerateMipmap(gl.TEXTURE_2D)
  
  return result_idx
}

gfx_texture_update :: proc(gfx : ^GFX_State, id : u32, w, h : i32, channels: i32, data : rawptr) -> bool {
  if id >= gfx.num_textures {
    return false
  }
  
  handle := &gfx.texture_slots[id]
  if handle.gl_id == 0 {
    return false
  }
  
  format: u32
  switch channels {
  case 1: format = gl.RED
  case 2: format = gl.RG
  case 3: format = gl.RGB
  case 4: format = gl.RGBA
  case: return false
  }
  
  gl.ActiveTexture(gl.TEXTURE0 + id)
  gl.BindTexture(gl.TEXTURE_2D, handle.gl_id)
  gl.TexSubImage2D(
    gl.TEXTURE_2D,
    0,
    0, 0,
    w,
    h,
    format,
    gl.UNSIGNED_BYTE,
    data,
  )
  gl.GenerateMipmap(gl.TEXTURE_2D)
  
  return true
}

gfx_texture_delete :: proc(gfx: ^GFX_State, id: u32) -> bool{
  if id == WHITE_TEXTURE {
    return false
  }

  if id >= gfx.num_textures {
    return false
  }

  handle := &gfx.texture_slots[id]

  if handle.gl_id == 0 {
    return false
  }

  gl.DeleteTextures(1, &handle.gl_id)

  handle.gl_id = 0
  handle.next = gfx.texture_freelist
  gfx.texture_freelist = id

  return true
}

GFX_State :: struct {
  ui_vao, ui_vbo, ui_ibo : u32,
  ui_shader              : u32,
  uniform_loc            : [Shader_Uniform]i32,

  render_buffer          : Render_Buffer,

  texture_slots : [MAX_TEXTURES]Texture_Handle,
  num_textures : u32,
  texture_freelist : u32,

  bound_textures : [MAX_TEXTURES]bool,
  current_texture : u32,
}

gfx_init :: proc(load_proc: gl.Set_Proc_Address_Type) -> (ctx: GFX_State, ok: bool) {
  ctx = GFX_State{}

  gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, load_proc)

  gl.Enable(gl.BLEND)
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
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
  
  ctx.render_buffer.vertices = make([^]Render_Vertex, MAX_VERTEX_COUNT, context.allocator)
  ctx.render_buffer.indices = make([^]u32, MAX_VERTEX_COUNT, context.allocator)
  
  
  white_pixel := [4]u8{255, 255, 255, 255}
  texture := Texture {
    width = 1,
    height = 1,
    channels = 4,
    data = &white_pixel[0]
  }

  gfx_texture_upload(&ctx, texture)

  return ctx, true
}

gfx_clear :: proc(color: vec4 = {0.1, 0.1, 0.1, 1.0}) {
  gl.ClearColor(color.r, color.g, color.b, color.a)
  gl.Clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT)
}

gfx_begin_frame :: proc(ctx: ^GFX_State, texture_id : u32 = WHITE_TEXTURE) {
  gfx_ready(ctx)

  gl.UseProgram(ctx.ui_shader)
  gl.BindVertexArray(ctx.ui_vao)

  gl.BindBuffer(gl.ARRAY_BUFFER, ctx.ui_vbo)
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ui_ibo)

  gfx_set_texture(ctx, texture_id)
}

gfx_set_texture :: proc(ctx: ^GFX_State, texture_id: u32) {
  id := texture_id
  if id >= ctx.num_textures {
    id = WHITE_TEXTURE
  }

  if ctx.current_texture != id {
    ctx.current_texture = id
    
    handle := &ctx.texture_slots[id]
    if handle.gl_id != 0 {
      gl.ActiveTexture(gl.TEXTURE0)
      gl.BindTexture(gl.TEXTURE_2D, handle.gl_id)
      gl.Uniform1i(ctx.uniform_loc[.UI_Texture], 0)
    }
  }
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

  handle := &texture_slots[current_texture]
  if handle.gl_id != 0 {
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, handle.gl_id)
    gl.Uniform1i(uniform_loc[.UI_Texture], 0)
  }

  gl.BufferSubData(gl.ARRAY_BUFFER, 0, cast(int) render_buffer.vtx_count * VTX_SIZE, render_buffer.vertices)
  gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, cast(int) render_buffer.idx_count * size_of(u32), render_buffer.indices)
  gl.DrawElements(gl.TRIANGLES, cast(i32) render_buffer.idx_count, gl.UNSIGNED_INT, nil)
}

gfx_push_rect :: proc(ctx : ^GFX_State, pos, size : vec2, color : [4]vec4 = 1.0, uv : vec4 = {0,0,1,1}) {
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

  render_buffer.vertices[vc + 0] = Render_Vertex{p0, color[0], uv.xy, 0}
  render_buffer.vertices[vc + 1] = Render_Vertex{p1, color[1], uv.zy, 0}
  render_buffer.vertices[vc + 2] = Render_Vertex{p2, color[2], uv.zw, 0}
  render_buffer.vertices[vc + 3] = Render_Vertex{p3, color[3], uv.xw, 0}

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
  vertices := render_buffer.vertices

  vertices[base_index + 0] = Render_Vertex{p0, col0, uv0, cir0}
  vertices[base_index + 1] = Render_Vertex{p1, col1, uv1, cir1}
  vertices[base_index + 2] = Render_Vertex{p2, col2, uv2, cir2}

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
  
  radii := radii
  adjust_side :: #force_inline proc(s1, s2 : ^f32, max : f32) {
    side_sum := s1^ + s2^
    if side_sum > max {
      s1^ *= max / side_sum
      s2^ *= max / side_sum
    }
  }
  
  adjust_side(&radii[0], &radii[1], size.x)
  adjust_side(&radii[2], &radii[3], size.x)
  adjust_side(&radii[2], &radii[1], size.y)
  adjust_side(&radii[0], &radii[3], size.y)

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
    radius := radii[i]
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
    radius := radii[i]
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
gfx_wireframe :: proc(on : bool) { gl.PolygonMode(gl.FRONT_AND_BACK, on ? gl.LINE : gl.FILL) }

// ===============================================
// Utility procedures
// ===============================================

quad_gradient :: proc(col1, col2: vec4, angle_deg: f32) -> [4]vec4 {
  radian := angle_deg * math.PI / 180 + math.PI / 4

  sin_val := math.sin(radian)
  cos_val := math.cos(radian)

  max_val := max(abs(cos_val), abs(sin_val))
  half_inv_max := 0.5 / max_val

  col_diff := col2 - col1

  return {
    col1 + col_diff * ((cos_val + max_val) * half_inv_max),
    col1 + col_diff * ((-sin_val + max_val) * half_inv_max),
    col1 + col_diff * ((-cos_val + max_val) * half_inv_max),
    col1 + col_diff * ((sin_val + max_val) * half_inv_max),
  }
}

hex_color :: proc(hex: u32be) -> vec4 {
  r := f32((hex >> 16) & 0xFF) / 255.0
  g := f32((hex >> 8) & 0xFF) / 255.0
  b := f32(hex & 0xFF) / 255.0
  return {r, g, b, 1.0}
}

hex_color_rgba :: proc(hex: u32be) -> vec4 {
  r := f32((hex >> 24) & 0xFF) / 255.0
  g := f32((hex >> 16) & 0xFF) / 255.0  
  b := f32((hex >> 8) & 0xFF)  / 255.0
  a := f32(hex & 0xFF) / 255.0
  return {r, g, b, a}
}
