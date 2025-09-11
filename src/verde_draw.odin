package verde

//////////////////////////////////
// ~geb: Types

Draw_Cmd_Type :: enum u8 {
  Rect,
  Text,
  Clip_Begin,
  Clip_End,
}

Draw_Cmd :: struct {
  type:    Draw_Cmd_Type,
  variant: Draw_Cmd_Type,
}

Rectangle_Cmd :: struct {
  position:          vec2_f32,
  size:              vec2_f32,
  color:             vec4_f32,
  radii:             vec4_f32,
  outline_color:     vec4_f32,
  outline_thickness: f32,
  texture_id:        u32,
}

Text_Cmd :: struct {
  text:              string,
  position:          vec2_f32,
  color:             vec4_f32,
  font_atlas:        ^Font_Atlas,
  monospace_advance: f32,
}

Clip_Cmd :: struct {
  min: vec2_f32,
  max: vec2_f32,
}


Draw_Command_Buffer :: struct {
  commands:   [dynamic]Draw_Cmd,
  clip_stack: [dynamic]Clip_Cmd,
}
