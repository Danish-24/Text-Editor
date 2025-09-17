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
  pos := linalg.floor(panel.inner_rect.min + {2,2})
  gfx_push_rect_rounded(
    gfx,
    pos = pos,
    size = {10, 20},
    color = 0x99856a_ff,
  )
}






