package verde

import "core:fmt"
import stbtt "vendor:stb/truetype"

Font :: struct {
  font_info : stbtt.fontinfo,
  scale : f32,
  ascent : f32,
  descent : f32,
  line_gap : f32,
}

Font_Atlas_Glyph :: struct {
  codepoint : rune,
  x0, y0, x1, y1 : i32,
  xoff, yoff : f32,
  xadvance : f32,
}

Font_Atlas :: struct {
  font : Font,
  texture_id : u32,
  atlas_width: i32,
  atlas_height : i32,
  atlas_data : []u8,
  glyphs : map[rune]Font_Atlas_Glyph,
  current_x, current_y : i32,
  row_height:i32,
  dirty : b32,
}

font_atlas_create :: proc(gfx: ^GFX_State, data: []u8, size : i32 = 512, font_height : f32 = 15) -> (atlas: Font_Atlas, ok: bool) {
  using stbtt

  if !InitFont(&atlas.font.font_info, raw_data(data), 0) {
    return {}, false
  }

  atlas.font.scale = ScaleForPixelHeight(&atlas.font.font_info, font_height)

  ascent, descent, line_gap: i32
  GetFontVMetrics(&atlas.font.font_info, &ascent, &descent, &line_gap)
  atlas.font.ascent = f32(ascent) * atlas.font.scale
  atlas.font.descent = f32(descent) * atlas.font.scale
  atlas.font.line_gap = f32(line_gap) * atlas.font.scale

  atlas.atlas_width = size
  atlas.atlas_height = size
  atlas.atlas_data = make([]u8, size * size)
  atlas.glyphs = make(map[rune]Font_Atlas_Glyph)

  atlas.current_x = 1
  atlas.current_y = 1
  atlas.row_height = 0

  texture := Texture{
    data = raw_data(atlas.atlas_data),
    width = atlas.atlas_width,
    height = atlas.atlas_height,
    channels = 1,
  }

  atlas.texture_id = gfx_texture_upload(gfx, texture, .Bitmap)
  atlas.dirty = false

  return atlas, true
}

font_atlas_add_glyph :: proc(gfx: ^GFX_State, font_atlas: ^Font_Atlas, codepoint : rune) -> bool {
  using stbtt

  if codepoint in font_atlas.glyphs {
    return true
  }

  glyph_index := FindGlyphIndex(&font_atlas.font.font_info, codepoint)
  if glyph_index == 0 && codepoint != ' ' {
    return false
  }

  x0, y0, x1, y1: i32
  GetGlyphBitmapBox(&font_atlas.font.font_info, glyph_index, font_atlas.font.scale, font_atlas.font.scale, &x0, &y0, &x1, &y1)

  glyph_width := x1 - x0
  glyph_height := y1 - y0

  if glyph_width <= 0 || glyph_height <= 0 {
    advance_width: i32
    GetGlyphHMetrics(&font_atlas.font.font_info, glyph_index, &advance_width, nil)

    font_atlas.glyphs[codepoint] = Font_Atlas_Glyph{
      codepoint = codepoint,
      x0 = 0, y0 = 0, x1 = 0, y1 = 0,
      xoff = 0, yoff = 0,
      xadvance = f32(advance_width) * font_atlas.font.scale,
    }
    return true
  }

  if font_atlas.current_x + glyph_width + 1 > font_atlas.atlas_width {
    font_atlas.current_x = 1
    font_atlas.current_y += font_atlas.row_height + 1
    font_atlas.row_height = 0
  }

  if font_atlas.current_y + glyph_height + 1 > font_atlas.atlas_height {
    if !font_atlas_expand(gfx, font_atlas) {
      fmt.eprintln("Failed to expand font atlas")
      return false
    }
  }

  glyph_x := font_atlas.current_x
  glyph_y := font_atlas.current_y

  bitmap_width, bitmap_height: i32
  glyph_bitmap := GetGlyphBitmap(&font_atlas.font.font_info, 
    font_atlas.font.scale, font_atlas.font.scale, 
    glyph_index, &bitmap_width, &bitmap_height, nil, nil)

  defer if glyph_bitmap != nil { FreeBitmap(glyph_bitmap, nil) }

  if bitmap_width != glyph_width || bitmap_height != glyph_height {
    fmt.printf("Warning: bitmap dimensions (%d x %d) don't match calculated dimensions (%d x %d) for glyph %c\n", 
      bitmap_width, bitmap_height, glyph_width, glyph_height, codepoint)
    glyph_width = bitmap_width
    glyph_height = bitmap_height
  }

  if glyph_bitmap != nil && glyph_width > 0 && glyph_height > 0 {
    for row in 0..<glyph_height {
      atlas_y := glyph_y + row
      if atlas_y >= font_atlas.atlas_height { break }

      for col in 0..<glyph_width {
        atlas_x := glyph_x + col
        if atlas_x >= font_atlas.atlas_width { break }

        atlas_idx := atlas_y * font_atlas.atlas_width + atlas_x
        glyph_idx := row * glyph_width + col

        if int(atlas_idx) < len(font_atlas.atlas_data) && glyph_idx >= 0 {
          font_atlas.atlas_data[atlas_idx] = (cast([^]u8)glyph_bitmap)[glyph_idx]
        }
      }
    }
  }

  advance_width: i32
  GetGlyphHMetrics(&font_atlas.font.font_info, glyph_index, &advance_width, nil)

  font_atlas.glyphs[codepoint] = Font_Atlas_Glyph{
    codepoint = codepoint,
    x0 = glyph_x,
    y0 = glyph_y,
    x1 = glyph_x + glyph_width,
    y1 = glyph_y + glyph_height,
    xoff = f32(x0),
    yoff = f32(y0),
    xadvance = f32(advance_width) * font_atlas.font.scale,
  }

  font_atlas.current_x += glyph_width + 1
  font_atlas.row_height = max(font_atlas.row_height, glyph_height)
  font_atlas.dirty = true

  return true
}

font_atlas_expand :: proc(gfx: ^GFX_State, font_atlas: ^Font_Atlas) -> bool {
  new_width := font_atlas.atlas_width * 2
  new_height := font_atlas.atlas_height * 2

  if new_width > 4096 || new_height > 4096 {
    fmt.eprintln("Font atlas size limit reached")
    return false
  }

  new_data := make([]u8, new_width * new_height)

  for row in 0..<font_atlas.atlas_height {
    old_start := row * font_atlas.atlas_width
    new_start := row * new_width
    copy(new_data[new_start:new_start + font_atlas.atlas_width], 
      font_atlas.atlas_data[old_start:old_start + font_atlas.atlas_width])
  }

  delete(font_atlas.atlas_data)
  font_atlas.atlas_data = new_data
  font_atlas.atlas_width = new_width
  font_atlas.atlas_height = new_height

  gfx_texture_unload(gfx, font_atlas.texture_id)

  texture := Texture{
    data = raw_data(font_atlas.atlas_data),
    width = font_atlas.atlas_width,
    height = font_atlas.atlas_height,
    channels = 1,
  }

  font_atlas.texture_id = gfx_texture_upload(gfx, texture, .Bitmap)
  font_atlas.dirty = false

  fmt.printf("Font atlas expanded to %dx%d\n", new_width, new_height)
  return true
}

font_atlas_add_glyphs_from_string :: proc(gfx: ^GFX_State, font_atlas: ^Font_Atlas, text: string) {
  for codepoint in text {
    font_atlas_add_glyph(gfx, font_atlas, codepoint)
  }
}

font_atlas_update :: proc(gfx: ^GFX_State, font_atlas: ^Font_Atlas) {
  if !font_atlas.dirty {
    return
  }

  gfx_texture_update(
    gfx, font_atlas.texture_id, 
    font_atlas.atlas_width, 
    font_atlas.atlas_height, 
    1,
    raw_data(font_atlas.atlas_data)
  )

  font_atlas.dirty = false
}

font_atlas_preload_ascii :: proc(gfx: ^GFX_State, font_atlas: ^Font_Atlas) {
  for ch in 32..<127 {
    font_atlas_add_glyph(gfx, font_atlas, rune(ch))
  }
  font_atlas_update(gfx, font_atlas)
}

font_atlas_destroy :: proc(gfx: ^GFX_State, font_atlas: ^Font_Atlas) {
  gfx_texture_unload(gfx, font_atlas.texture_id)
  delete(font_atlas.atlas_data)
  delete(font_atlas.glyphs)
  font_atlas^ = {}
}

font_atlas_get_glyph :: proc(font_atlas: ^Font_Atlas, codepoint: rune) -> (Font_Atlas_Glyph, bool) {
  glyph, exists := font_atlas.glyphs[codepoint]
  return glyph, exists
}

font_atlas_resize_glyphs :: proc(gfx: ^GFX_State, font_atlas: ^Font_Atlas, new_font_height: f32) -> bool {
  using stbtt

  old_scale := font_atlas.font.scale
  new_scale := ScaleForPixelHeight(&font_atlas.font.font_info, new_font_height)

  if abs(new_scale - old_scale) < 0.001 {
    return true
  }

  font_atlas.font.scale = new_scale

  ascent, descent, line_gap: i32
  GetFontVMetrics(&font_atlas.font.font_info, &ascent, &descent, &line_gap)
  font_atlas.font.ascent = f32(ascent) * font_atlas.font.scale
  font_atlas.font.descent = f32(descent) * font_atlas.font.scale
  font_atlas.font.line_gap = f32(line_gap) * font_atlas.font.scale

  glyphs_to_regenerate := make([dynamic]rune, context.temp_allocator)

  for codepoint in font_atlas.glyphs {
    append(&glyphs_to_regenerate, codepoint)
  }

  for i in 0..<len(font_atlas.atlas_data) {
    font_atlas.atlas_data[i] = 0
  }

  clear(&font_atlas.glyphs)

  font_atlas.current_x = 1
  font_atlas.current_y = 1
  font_atlas.row_height = 0

  for codepoint in glyphs_to_regenerate {
    if !font_atlas_add_glyph(gfx, font_atlas, codepoint) {
      fmt.printf("Warning: Failed to regenerate glyph %c after resize\n", codepoint)
    }
  }

  font_atlas_update(gfx, font_atlas)
  return true
}

font_atlas_height :: #force_inline proc(atlas : ^Font_Atlas) -> f32 {
  return atlas.font.ascent - atlas.font.descent + atlas.font.line_gap
}
