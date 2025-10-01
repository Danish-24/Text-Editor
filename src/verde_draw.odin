package verde


import "core:fmt"
import "core:math/linalg"

draw_panels :: proc(gfx: ^GFX_State, font: ^Font_Atlas, panels: []Panel) {
  font_height := font_atlas_height(font)
  monospace_advance := font_height * 0.5;

  for &panel in panels {
    if .Invisible in panel.flags { continue }
    if .Custom_Draw in panel.flags && panel.custom_draw_proc != nil {
      panel.custom_draw_proc(gfx, &panel)
      continue
    }
    panel_pos := panel.position
    panel_size := panel.resolved_size
    if .Text in panel.flags && panel.text != "" {
      gfx_push_clip(&ctx.gfx, panel.inner_rect.min, panel.inner_rect.max)
      text_dimensions := font_atlas_measure(&ctx.font, panel.text, monospace_advance)
      text_pos := layout_text_position(panel.inner_rect, panel.text_layout, text_dimensions)
      gfx_push_text(
        &ctx.gfx,
        panel.text,
        &ctx.font,
        x = text_pos.x,
        y = text_pos.y,
        color = panel.color,
        monospace_advance = monospace_advance
      )
    }else if panel.outline_thickness > 0.5 {
      gfx_push_rect_rounded(
        &ctx.gfx,
        panel_pos,
        panel_size,
        panel.outline_color,
        panel.radius
      )
      gfx_push_rect_rounded(
        &ctx.gfx,
        panel_pos + panel.outline_thickness,
        panel_size - panel.outline_thickness * 2,
        panel.color,
        panel.radius - panel.outline_thickness,
      )
    } else {
      gfx_push_rect_rounded(
        &ctx.gfx,
        panel_pos,
        panel_size,
        panel.color,
        panel.radius
      )
    }
  }
}

///////////////////////////////////
// ~geb: Custom UIs

draw_file_buffer_view :: proc(gfx: ^GFX_State, panel: ^Panel) {
  @(static) cursor_offset : vec2_f32
  @(static) cursor_render_offset : vec2_f32

  cursor_render_offset = smooth_damp(cursor_render_offset, cursor_offset, 0.02, ctx.frame_delta)

  rect_pos := linalg.floor(panel.inner_rect.min)
  rect_size := panel.inner_rect.max - panel.inner_rect.min;

  ctx := cast(^App_Context) panel.custom_draw_data
  font := &ctx.font
  font_height := font_atlas_height(font)
  x_advance := font_height * 0.5
  cursor_size := vec2_f32{0.5, 1.0} * font_height

  if (on_key_repeat(ctx, .L)) do cursor_offset.x += 1
  if (on_key_repeat(ctx, .H)) do cursor_offset.x -= 1
  if (on_key_repeat(ctx, .J)) do cursor_offset.y += 1
  if (on_key_repeat(ctx, .K)) do cursor_offset.y -= 1

  if (is_key_down(ctx, .Left_Control) && on_key_repeat(ctx, .D)) do cursor_offset.y += 10
  if (is_key_down(ctx, .Left_Control) && on_key_repeat(ctx, .U)) do cursor_offset.y -= 10

  gfx_push_clip(gfx,panel.inner_rect.min, panel.inner_rect.max, true)

  cursor_pos := rect_pos + cursor_render_offset * cursor_size
  gfx_push_rect_rounded(
    gfx,
    pos = cursor_pos,
    size = cursor_size,
    color = 0x00ff00_ff,
  )
  gfx_push_rect_rounded(
    gfx,
    pos = cursor_pos+1,
    size = cursor_size-2,
    color = 0x131313_ff,
  )

  gfx_push_text(
    gfx,
    #load("verde_types.odin"),
    font,
    color = 0x99856a_ff,
    monospace_advance = x_advance,
    x = rect_pos.x,
    y = rect_pos.y,
  )
}






