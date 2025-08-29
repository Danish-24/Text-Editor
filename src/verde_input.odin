package verde


Key_Set :: bit_set[Key_Code]
Mouse_Set :: bit_set[Mouse_Code; u8]

Input_State :: struct {
  keys_current: Key_Set,
  keys_repeat: Key_Set,
  keys_prev: Key_Set,

  mouse_current: Mouse_Set,
  mouse_prev: Mouse_Set,

  pointer_current : vec2,
  pointer_prev : vec2,

  scroll : vec2,

  char_stream : rune,
  had_char_input : b32,
}

is_key_down :: proc(ctx: ^App_State, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_current
}

on_key_down :: proc(ctx: ^App_State, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_current && keycode not_in keys_prev
}

on_key_up :: proc(ctx: ^App_State, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode not_in keys_current && keycode in keys_prev
}

on_key_repeat :: proc(ctx: ^App_State, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_repeat || (keycode in keys_current && keycode not_in keys_prev)
}

on_key_repeat_only :: proc(ctx: ^App_State, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_repeat
}

is_mouse_down :: proc(ctx: ^App_State, button : Mouse_Code) -> bool {
  using ctx.input
  return button in mouse_current
}

on_mouse_down :: proc(ctx: ^App_State, button : Mouse_Code) -> bool {
  using ctx.input
  return (button in mouse_current) && (button not_in mouse_prev)
}

on_mouse_up :: proc(ctx: ^App_State, button : Mouse_Code) -> bool {
  using ctx.input
  return (button not_in mouse_current) && (button in mouse_prev)
}

get_pointer :: proc(ctx: ^App_State) -> vec2 {
  return ctx.input.pointer_current
}

get_pointer_delta :: proc(ctx: ^App_State) -> vec2 {
  return ctx.input.pointer_current - ctx.input.pointer_prev
}

get_char_stream :: proc(ctx: ^App_State) -> (codepoint:rune, ok:bool) {
  return ctx.input.char_stream, bool(ctx.input.had_char_input)
}

Key_Code :: enum u32 {
  Space         ,
  Apostrophe    , 
  Comma         , /* , */
  Minus         , /* - */
  Period        , /* . */
  Slash         , /* / */
  Semicolon     , /* ; */
  Equal         , /* :: */
  Left_Bracket  , /* [ */
  Backslash     , /* \ */
  Right_Bracket , /* ] */
  Grave_Accent  , /* ` */
  World_1       , /* non-us #1 */
  World_2       , /* non-us #2 */

  Zero  ,
  One   ,
  Two   ,
  Three ,
  Four  ,
  Five  ,
  Six   ,
  Seven ,
  Eight ,
  Nine  ,

  A ,
  B ,
  C ,
  D ,
  E ,
  F ,
  G ,
  H ,
  I ,
  J ,
  K ,
  L ,
  M ,
  N ,
  O ,
  P ,
  Q ,
  R ,
  S ,
  T ,
  U ,
  V ,
  W ,
  X ,
  Y ,
  Z ,

  Escape       ,
  Enter        ,
  Tab          ,
  Backspace    ,
  Insert       ,
  Delete       ,
  Right        ,
  Left         ,
  Down         ,
  Up           ,
  Page_Up      ,
  Page_Down    ,
  Home         ,
  End          ,
  Caps_Lock    ,
  Scroll_Lock  ,
  Num_Lock     ,
  Print_Screen ,
  Pause        ,

  F1  ,
  F2  ,
  F3  ,
  F4  ,
  F5  ,
  F6  ,
  F7  ,
  F8  ,
  F9  ,
  F10 ,
  F11 ,
  F12 ,
  F13 ,
  F14 ,
  F15 ,
  F16 ,
  F17 ,
  F18 ,
  F19 ,
  F20 ,
  F21 ,
  F22 ,
  F23 ,
  F24 ,
  F25 ,

  KP_0 ,
  KP_1 ,
  KP_2 ,
  KP_3 ,
  KP_4 ,
  KP_5 ,
  KP_6 ,
  KP_7 ,
  KP_8 ,
  KP_9 ,

  KP_Decimal  ,
  KP_Divide   ,
  KP_Multiply ,
  KP_Subtract ,
  KP_Add      ,
  KP_Enter    ,
  KP_Equal    ,

  Left_Shift    ,
  Left_Control  ,
  Left_Alt      ,
  Left_Super    ,
  Right_Shift   ,
  Right_Control ,
  Right_Alt     ,
  Right_Super   ,
  Menu          ,
}

Mouse_Code :: enum u32 {
  Button_1 = 0, /* left */
  Button_2, /* right */
  Button_3, /* middle */
  Button_4,
  Button_5,
  Button_6,
  Button_7,
  Button_8,
}
