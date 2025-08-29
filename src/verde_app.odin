package verde

import "core:fmt"
import "core:time"
import "base:runtime"
import "vendor:glfw"

Window_Handle :: glfw.WindowHandle

App_State :: struct {
  window      : Window_Handle,
  input       : Input_State,
  viewport    : [2]f32,

  gfx         : GFX_State,
  ui          : UI_State,

  font        : Font_Atlas,

  frame_delta : f32,
}

app_init :: proc(ctx: ^App_State) -> bool {
  if !glfw.Init() {
    fmt.println("Failed to Initialize GLFW")
    return false
  }

  glfw.WindowHint(glfw.RESIZABLE, true)
  glfw.WindowHint(glfw.MAXIMIZED, false)
  glfw.WindowHint(glfw.DECORATED, true)

  ctx.window = glfw.CreateWindow(640, 480, "verde", nil, nil)
  if ctx.window == nil { 
    fmt.println("Failed to create window");
    return false 
  }

  
  glfw.MakeContextCurrent(ctx.window)
  glfw.SwapInterval(0)
  ctx.viewport = {640, 480}

  ok: bool
  ctx.gfx, ok = gfx_init(glfw.gl_set_proc_address)
  if !ok {
    fmt.eprintln("Failed to initialize GFX")
    return false
  }

  gfx_resize_target(&ctx.gfx, i32(ctx.viewport.x), i32(ctx.viewport.y))

  ctx.font, ok = font_atlas_create(&ctx.gfx, #load("fonts/jetbrains_mono.ttf"), font_height = 24)
  if !ok {
    fmt.println("fail")
  }
  font_atlas_preload_ascii(&ctx.gfx, &ctx.font)

  glfw.SetWindowUserPointer(ctx.window, ctx)
  glfw.SetFramebufferSizeCallback(ctx.window, proc "c" (window: Window_Handle, width, height: i32) {
    context = runtime.default_context()
    ctx := cast(^App_State) glfw.GetWindowUserPointer(window)
    gfx_resize_target(&ctx.gfx, width, height)
    ctx.viewport = {f32(width), f32(height)}
  })

  glfw.SetCharCallback(ctx.window, proc "c" (window: Window_Handle, codepoint: rune) {
    context = runtime.default_context()
    ctx := cast(^App_State) glfw.GetWindowUserPointer(window)
    ctx.input.char_stream = codepoint
    ctx.input.had_char_input = true
  })

  glfw.SetKeyCallback(ctx.window, proc "c" (window: Window_Handle, key, scancode, action, mods: i32) {
    context = runtime.default_context()
    ctx := cast(^App_State) glfw.GetWindowUserPointer(window)
    keycode := _get_keycode_from_platform(key) 

    ctx.input.keys_current += {keycode} if action == glfw.PRESS else {}
    ctx.input.keys_repeat += {keycode} if action == glfw.REPEAT else {}
    ctx.input.keys_current -= {keycode} if action == glfw.RELEASE else {}
  })

  glfw.SetScrollCallback(ctx.window, proc "c" (window: Window_Handle, x, y: f64) {
    context = runtime.default_context()
    ctx := cast(^App_State) glfw.GetWindowUserPointer(window)

    ctx.input.scroll = {f32(x), f32(y)}
  })

  ui_init(&ctx.ui)
  ui_set_context(&ctx.ui)

  return true
}

app_run :: proc(ctx: ^App_State) {
  time_now  := f32(0.0);
  time_last := f32(0.0);

  window := ctx.window
  gfx := &ctx.gfx
  ui := &ctx.ui
  input := &ctx.input

  for !glfw.WindowShouldClose(window) {
    free_all(context.temp_allocator)
    { /* input polling */
      using ctx.input
      
      keys_prev = keys_current
      keys_repeat = {}

      mouse_prev = mouse_current
      mouse_current = {}
      scroll = {}

      had_char_input = false

      glfw.PollEvents()

      x, y := glfw.GetCursorPos(window)
      pointer_prev = pointer_current
      pointer_current = {f32(x), f32(y)}

      for m in Mouse_Code {
        if glfw.GetMouseButton(window, cast(i32) m) == glfw.PRESS {
          mouse_current += {m}
        }
      }
    }

    time_last = time_now
    time_now  = cast(f32) glfw.GetTime()
    ctx.frame_delta = time_now - time_last;

    gfx_clear(hex_color(0))
    


    if is_key_down(ctx, .W) {
      gfx_wireframe(true)
    } else {
      gfx_wireframe(false)
    }

    height := font_atlas_height(&ctx.font)
    if on_key_repeat(ctx, .Equal) {
      font_atlas_resize_glyphs(gfx, &ctx.font, height + 5)
    } 
    else if on_key_repeat(ctx, .Minus) && height > 10{
      font_atlas_resize_glyphs(gfx, &ctx.font, height - 5)
    } 

    
    ui_layout_begin(ctx.viewport.x, ctx.viewport.y, direction=.L_to_R)
  
    ui_begin({
      size = {
        size_fixed(200),
        size_fill(),
      },
      padding = {4,4,2,4},
      child_gap = 4,
      flags = {.Invisible}
    })
    ui_begin({
      size = {size_fill(), size_fill()},
      color = hex_color(0x282828),
      radius = 5
    })
    ui_end()

    ui_end()

    ui_begin({
      size = {
        size_fill(),
        size_fill(),
      },
      padding = {2,4,4,4},
      child_gap = 4,
      flags = {.Invisible},
    })
    panel_id := ui_begin({
      size = {size_fill(), size_fixed(ui_region_left().y - 200)},
      color = hex_color(0x282828),
      padding = {5,5,5,5},
      radius = 5
    })
    ui_end()
    ui_begin({
      size = {size_fill(), size_fill()},
      color = hex_color(0x282828),
      padding = {5,5,5,5},
      radius = 5
    })
    ui_end()
    ui_end()

    boxes := ui_layout_end()

    gfx_begin_frame(gfx)

    for box, idx in boxes {
      if .Invisible in box.flags { continue }
      gfx_push_rect_rounded(
        gfx,
        box.position,
        box.resolved_size,
        box.color,
        box.radius,
      )
    }
    
    gfx_flush(gfx)
    gfx_ready(gfx)
    
    panel := ui_get_box(panel_id)

    @(static) offset : f32 = 0
    offset += ctx.input.scroll.y * height * 4

    
    gfx_push_clip(gfx, panel.inner_rect)
    gfx_push_text(
        gfx,
        #load("shaders/ui.frag"),
        &ctx.font,
        color=hex_color(0xebdbc7),
        x = panel.inner_rect.min.x,
        y = panel.inner_rect.min.y + offset,
        x_advance = height * 0.5
      )
    gfx_end_frame(gfx)
      
    gfx_pop_clip(gfx)
      
    glfw.SwapBuffers(window)
  }
}

_get_platfrom_keycode :: #force_inline proc(code : Key_Code) -> u32 {
  switch code {
  case .Space         : return 32
  case .Apostrophe    : return 39  
  case .Comma         : return 44  
  case .Minus         : return 45  
  case .Period        : return 46  
  case .Slash         : return 47  
  case .Semicolon     : return 59  
  case .Equal         : return 61  
  case .Left_Bracket  : return 91  
  case .Backslash     : return 92  
  case .Right_Bracket : return 93  
  case .Grave_Accent  : return 96  
  case .World_1       : return 161 
  case .World_2       : return 162 
  case .Zero  : return 48
  case .One   : return 49
  case .Two   : return 50
  case .Three : return 51
  case .Four  : return 52
  case .Five  : return 53
  case .Six   : return 54
  case .Seven : return 55
  case .Eight : return 56
  case .Nine  : return 57
  case .A : return 65
  case .B : return 66
  case .C : return 6
  case .D : return 68
  case .E : return 69
  case .F : return 70
  case .G : return 71
  case .H : return 72
  case .I : return 73
  case .J : return 74
  case .K : return 75
  case .L : return 76
  case .M : return 77
  case .N : return 78
  case .O : return 79
  case .P : return 80
  case .Q : return 81
  case .R : return 82
  case .S : return 83
  case .T : return 84
  case .U : return 85
  case .V : return 86
  case .W : return 87
  case .X : return 88
  case .Y : return 89
  case .Z : return 90
  case .Escape       : return 256
  case .Enter        : return 257
  case .Tab          : return 258
  case .Backspace    : return 259
  case .Insert       : return 260
  case .Delete       : return 261
  case .Right        : return 262
  case .Left         : return 263
  case .Down         : return 264
  case .Up           : return 265
  case .Page_Up      : return 266
  case .Page_Down    : return 267
  case .Home         : return 268
  case .End          : return 269
  case .Caps_Lock    : return 280
  case .Scroll_Lock  : return 281
  case .Num_Lock     : return 282
  case .Print_Screen : return 283
  case .Pause        : return 284
  case .F1  : return 290
  case .F2  : return 291
  case .F3  : return 292
  case .F4  : return 293
  case .F5  : return 294
  case .F6  : return 295
  case .F7  : return 296
  case .F8  : return 297
  case .F9  : return 298
  case .F10 : return 299
  case .F11 : return 300
  case .F12 : return 301
  case .F13 : return 302
  case .F14 : return 303
  case .F15 : return 304
  case .F16 : return 305
  case .F17 : return 306
  case .F18 : return 307
  case .F19 : return 308
  case .F20 : return 309
  case .F21 : return 310
  case .F22 : return 311
  case .F23 : return 312
  case .F24 : return 313
  case .F25 : return 314
  case .KP_0 : return 320
  case .KP_1 : return 321
  case .KP_2 : return 322
  case .KP_3 : return 323
  case .KP_4 : return 324
  case .KP_5 : return 325
  case .KP_6 : return 326
  case .KP_7 : return 327
  case .KP_8 : return 328
  case .KP_9 : return 329
  case .KP_Decimal  : return 330
  case .KP_Divide   : return 331
  case .KP_Multiply : return 332
  case .KP_Subtract : return 333
  case .KP_Add      : return 334
  case .KP_Enter    : return 335
  case .KP_Equal    : return 336
  case .Left_Shift    : return 340
  case .Left_Control  : return 341
  case .Left_Alt      : return 342
  case .Left_Super    : return 343
  case .Right_Shift   : return 344
  case .Right_Control : return 345
  case .Right_Alt     : return 346
  case .Right_Super   : return 347
  case .Menu          : return 348
  case : return 0
  }
}

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
