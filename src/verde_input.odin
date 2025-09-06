package verde


//////////////////////////////////
// ~geb: Types

Key_Set :: bit_set[Key_Code]
Mouse_Set :: bit_set[Mouse_Code; u8]

Input_State :: struct {
  keys_current: Key_Set,
  keys_repeat: Key_Set,
  keys_prev: Key_Set,

  mouse_current: Mouse_Set,
  mouse_prev: Mouse_Set,

  pointer_current : vec2_f32,
  pointer_prev : vec2_f32,

  scroll : vec2_f32,

  char_stream : rune,
  had_char_input : b32,
}

//////////////////////////////////
// ~geb: Interface procs

is_key_down :: proc(ctx: ^App_Context, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_current
}

on_key_down :: proc(ctx: ^App_Context, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_current && keycode not_in keys_prev
}

on_key_up :: proc(ctx: ^App_Context, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode not_in keys_current && keycode in keys_prev
}

on_key_repeat :: proc(ctx: ^App_Context, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_repeat || (keycode in keys_current && keycode not_in keys_prev)
}

on_key_repeat_only :: proc(ctx: ^App_Context, keycode: Key_Code) -> bool {
  using ctx.input
  return keycode in keys_repeat
}

is_mouse_down :: proc(ctx: ^App_Context, button : Mouse_Code) -> bool {
  using ctx.input
  return button in mouse_current
}

on_mouse_down :: proc(ctx: ^App_Context, button : Mouse_Code) -> bool {
  using ctx.input
  return (button in mouse_current) && (button not_in mouse_prev)
}

on_mouse_up :: proc(ctx: ^App_Context, button : Mouse_Code) -> bool {
  using ctx.input
  return (button not_in mouse_current) && (button in mouse_prev)
}

get_pointer :: proc(ctx: ^App_Context) -> vec2_f32 {
  return ctx.input.pointer_current
}

get_pointer_delta :: proc(ctx: ^App_Context) -> vec2_f32 {
  return ctx.input.pointer_current - ctx.input.pointer_prev
}

get_scroll :: proc(ctx: ^App_Context) -> vec2_f32 {
  return ctx.input.scroll
}

get_char_stream :: proc(ctx: ^App_Context) -> (codepoint:rune, ok:bool) {
  return ctx.input.char_stream, bool(ctx.input.had_char_input)
}

//////////////////////////////////
// ~geb: Internal Codes

Key_Code :: enum u8 {
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

Mouse_Code :: enum u8 {
  Button_1 = 0, /* left */
  Button_2, /* right */
  Button_3, /* middle */
  Button_4,
  Button_5,
  Button_6,
  Button_7,
  Button_8,
}

/*///////////////////////////////////
 ~geb(INFO): One to one mapping from 
             internal input codes to 
             platform input codes.
             This is done to recduce 
             empty spaces in Key_Set.
*////////////////////////////////////



_get_keycode_from_platform :: #force_inline proc(platform_code : i32) -> Key_Code {
  switch platform_code {
  case 32  : return .Space
  case 39  : return .Apostrophe
  case 44  : return .Comma
  case 45  : return .Minus
  case 46  : return .Period
  case 47  : return .Slash
  case 59  : return .Semicolon
  case 61  : return .Equal
  case 91  : return .Left_Bracket
  case 92  : return .Backslash
  case 93  : return .Right_Bracket
  case 96  : return .Grave_Accent
  case 161 : return .World_1
  case 162 : return .World_2
  case 48 : return .Zero
  case 49 : return .One
  case 50 : return .Two
  case 51 : return .Three
  case 52 : return .Four
  case 53 : return .Five
  case 54 : return .Six
  case 55 : return .Seven
  case 56 : return .Eight
  case 57 : return .Nine
  case 65 : return .A
  case 66 : return .B
  case 67 : return .C  // Fixed: was 6 in original, should be 67
  case 68 : return .D
  case 69 : return .E
  case 70 : return .F
  case 71 : return .G
  case 72 : return .H
  case 73 : return .I
  case 74 : return .J
  case 75 : return .K
  case 76 : return .L
  case 77 : return .M
  case 78 : return .N
  case 79 : return .O
  case 80 : return .P
  case 81 : return .Q
  case 82 : return .R
  case 83 : return .S
  case 84 : return .T
  case 85 : return .U
  case 86 : return .V
  case 87 : return .W
  case 88 : return .X
  case 89 : return .Y
  case 90 : return .Z
  case 256 : return .Escape
  case 257 : return .Enter
  case 258 : return .Tab
  case 259 : return .Backspace
  case 260 : return .Insert
  case 261 : return .Delete
  case 262 : return .Right
  case 263 : return .Left
  case 264 : return .Down
  case 265 : return .Up
  case 266 : return .Page_Up
  case 267 : return .Page_Down
  case 268 : return .Home
  case 269 : return .End
  case 280 : return .Caps_Lock
  case 281 : return .Scroll_Lock
  case 282 : return .Num_Lock
  case 283 : return .Print_Screen
  case 284 : return .Pause
  case 290 : return .F1
  case 291 : return .F2
  case 292 : return .F3
  case 293 : return .F4
  case 294 : return .F5
  case 295 : return .F6
  case 296 : return .F7
  case 297 : return .F8
  case 298 : return .F9
  case 299 : return .F10
  case 300 : return .F11
  case 301 : return .F12
  case 302 : return .F13
  case 303 : return .F14
  case 304 : return .F15
  case 305 : return .F16
  case 306 : return .F17
  case 307 : return .F18
  case 308 : return .F19
  case 309 : return .F20
  case 310 : return .F21
  case 311 : return .F22
  case 312 : return .F23
  case 313 : return .F24
  case 314 : return .F25
  case 320 : return .KP_0
  case 321 : return .KP_1
  case 322 : return .KP_2
  case 323 : return .KP_3
  case 324 : return .KP_4
  case 325 : return .KP_5
  case 326 : return .KP_6
  case 327 : return .KP_7
  case 328 : return .KP_8
  case 329 : return .KP_9
  case 330 : return .KP_Decimal
  case 331 : return .KP_Divide
  case 332 : return .KP_Multiply
  case 333 : return .KP_Subtract
  case 334 : return .KP_Add
  case 335 : return .KP_Enter
  case 336 : return .KP_Equal
  case 340 : return .Left_Shift
  case 341 : return .Left_Control
  case 342 : return .Left_Alt
  case 343 : return .Left_Super
  case 344 : return .Right_Shift
  case 345 : return .Right_Control
  case 346 : return .Right_Alt
  case 347 : return .Right_Super
  case 348 : return .Menu
  case : return nil
  }
}
