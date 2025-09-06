package verde


//////////////////////////////////
// ~geb: Constants Привет

MAX_PANEL_COUNT :: 2048

//////////////////////////////////
// ~geb: Types
 
Panel_Flags :: bit_set[Panel_Flag; u32]
Panel_Flag :: enum {
  Invisible,
}

Panel_Handle :: i32

Panel :: struct {
  outer_rect, inner_rect : Range_2D,

  parent:        Panel_Handle,
  next_sibling:  Panel_Handle,
  first_child:   Panel_Handle,
  last_child:    Panel_Handle,

  position:      vec2_f32,
  resolved_size: vec2_f32,
  using _config: Panel_Config,
}

Panel_Size :: struct { w, h: Panel_Size_Axis }
Panel_Size_Axis :: struct {
  type: enum {
    Fixed = 0, 
    ParentPct,
    Fit,
    Fill,
  },
  value: f32,
}

Panel_Padding :: struct {
  left, top, right, bottom: f32
}

Layout_Dir :: enum { Vertical, Horizontal }

Panel_Config :: struct {
  size:             Panel_Size,
  padding:          Panel_Padding,
  child_gap:        f32,
  layout_direction: Layout_Dir,

  color:            vec4_f32,
  radius:           vec4_f32,
  flags:            Panel_Flags,
}


Layout_State :: struct {
  flat_array:        [^]Panel,
  panel_count:         u32, 
  open_panel:          Panel_Handle,
  layout_dimensions: vec2_f32,
  cursor_position:   vec2_f32,

  active, hot: Panel_Handle,
}

//////////////////////////////////
// ~geb: Layout procs
@(private) _ctx: ^Layout_State

layout_init :: proc(state: ^Layout_State) {
  state.flat_array = make([^]Panel, MAX_PANEL_COUNT)
  state.panel_count = 0
  state.open_panel = -1
}

layout_set_context :: proc(state: ^Layout_State) -> (prev: ^Layout_State) { 
  prev_ctx := _ctx
  _ctx = state 
  return prev_ctx
}

layout_begin :: proc(
  w, h : f32, 
  x:=f32(0), y:=f32(0),
  direction: Layout_Dir = .Vertical,
  padding: Panel_Padding = {},
  child_gap :f32= 0,
  color: vec4_f32=0,
  flags: Panel_Flags = {.Invisible}
) {
  _ctx.layout_dimensions = {w, h}
  _ctx.open_panel = -1
  _ctx.panel_count = 0
  _ctx.active = -1
  _ctx.active = -1

  id := panel_begin({
    size = {
      {.Fixed, w},
      {.Fixed, h}
    },
    padding = padding,
    child_gap = child_gap,
    color = color,
    flags = flags,
    layout_direction = direction,
  })

  root_panel := layout_get_panel(id)
  root_panel.position = {x, y}
  _ctx.cursor_position = root_panel.position + {root_panel.padding.left, root_panel.padding.top}
}

layout_end :: proc() -> []Panel {
  panel_end()

  return _ctx.flat_array[:_ctx.panel_count]
}

panel_begin :: proc(config: Panel_Config) -> Panel_Handle {
  using _ctx

  assert(panel_count < MAX_PANEL_COUNT, "Maximum panel count exceeded")

  result_idx := Panel_Handle(panel_count)
  parent_idx := open_panel

  parent := &flat_array[parent_idx] if parent_idx >= 0 else nil
  panel := &flat_array[panel_count]

  panel.parent = parent_idx
  panel.first_child = -1
  panel.last_child = -1
  panel.next_sibling = -1
  panel.flags = {}
  panel._config = config

  if panel.size.w.type == .Fixed {
    panel.resolved_size.x = panel.size.w.value
  }
  if panel.size.h.type == .Fixed {
    panel.resolved_size.y = panel.size.h.value
  }

  if parent != nil {
    panel.position = cursor_position
    if parent.first_child == -1 {
      parent.first_child = result_idx
      parent.last_child = result_idx
    } else {
      last_child := &flat_array[parent.last_child]
      last_child.next_sibling = result_idx
      parent.last_child = result_idx
    }

    padding := parent.padding
    
    if panel.size.w.type == .ParentPct && parent.resolved_size.x > 0 {
      panel.resolved_size.x = (parent.resolved_size.x - padding.left - padding.right) * panel.size.w.value
    }
    if panel.size.h.type == .ParentPct && parent.resolved_size.y > 0 {
      panel.resolved_size.y = (parent.resolved_size.y - padding.top - padding.bottom) * panel.size.h.value
    }
    
    available_space := vec2_f32{
      parent.position.x + parent.resolved_size.x - parent.padding.right - cursor_position.x,
      parent.position.y + parent.resolved_size.y - parent.padding.bottom - cursor_position.y,
    }

    if panel.size.w.type == .Fill {
      panel.resolved_size.x = max(0, available_space.x * panel.size.w.value)
    }
    if panel.size.h.type == .Fill {
      panel.resolved_size.y = max(0, available_space.y * panel.size.h.value)
    }
    
    cursor_position = panel.position + {panel.padding.left, panel.padding.top}
  }

  open_panel = result_idx
  panel_count += 1

  return result_idx
}

panel_end :: proc() {
  using _ctx

  assert(open_panel >= 0, "panel_end() called without matching panel_begin()")

  current_panel := &flat_array[open_panel]
  parent_idx := current_panel.parent
  
  if current_panel.size.w.type == .Fit || current_panel.size.h.type == .Fit {
    if current_panel.first_child != -1 {
      fit_size := vec2_f32{0, 0}
      child_handle := current_panel.first_child
      child_count := 0
      
      for child_handle >= 0 {
        child := &flat_array[child_handle]
        
        if current_panel.layout_direction == .Horizontal {
          fit_size.x += child.resolved_size.x
          fit_size.y = max(fit_size.y, child.resolved_size.y)
        } else {
          fit_size.x = max(fit_size.x, child.resolved_size.x)
          fit_size.y += child.resolved_size.y
        }
        
        child_handle = child.next_sibling
        child_count += 1
      }
      
      if child_count > 1 {
        if current_panel.layout_direction == .Horizontal {
          fit_size.x += current_panel.child_gap * f32(child_count - 1)
        } else {
          fit_size.y += current_panel.child_gap * f32(child_count - 1)
        }
      }
      
      fit_size += {
        current_panel.padding.left + current_panel.padding.right,
        current_panel.padding.top + current_panel.padding.bottom
      }
      
      if current_panel.size.w.type == .Fit {
        current_panel.resolved_size.x = fit_size.x
      }
      if current_panel.size.h.type == .Fit {
        current_panel.resolved_size.y = fit_size.y
      }
    }
  }

  open_panel = parent_idx

  if parent_idx >= 0 {
    parent := &flat_array[parent_idx]
    layout := parent.layout_direction

    if layout == .Vertical {
      cursor_position.x = current_panel.position.x
      cursor_position.y = current_panel.position.y + current_panel.resolved_size.y + parent.child_gap
    } else if layout == .Horizontal {
      cursor_position.x = current_panel.position.x + current_panel.resolved_size.x + parent.child_gap
      cursor_position.y = current_panel.position.y
    }
  }

  current_panel.outer_rect.min = current_panel.position
  current_panel.outer_rect.max = current_panel.position + current_panel.resolved_size

  current_panel.inner_rect.min = current_panel.outer_rect.min + {current_panel.padding.left,current_panel.padding.top}
  current_panel.inner_rect.max = current_panel.outer_rect.max - {current_panel.padding.right,current_panel.padding.bottom}
}

layout_region_left :: proc() -> vec2_f32 {
  if _ctx.open_panel < 0 { return {} }
  panel := _ctx.flat_array[_ctx.open_panel]
  return {
    panel.position.x + panel.resolved_size.x - panel.padding.right -  _ctx.cursor_position.x,
    panel.position.y + panel.resolved_size.y - panel.padding.bottom - _ctx.cursor_position.y,
  }
}

layout_get_panel :: proc(handle: Panel_Handle) -> ^Panel {
  if handle < 0 || handle >= Panel_Handle(_ctx.panel_count) {
    return nil
  }
  return &_ctx.flat_array[handle]
}

//////////////////////////////////
// ~geb: Helper procs

size_fixed :: #force_inline proc "contextless" (val: f32)     -> Panel_Size_Axis { return {type = .Fixed, value = val} }
size_perc  :: #force_inline proc "contextless" (val: f32)     -> Panel_Size_Axis { return {type = .ParentPct, value = val} }
size_fill  :: #force_inline proc "contextless" (val: f32 = 1) -> Panel_Size_Axis { return {type = .Fill, value = val} }
size_fit   :: #force_inline proc "contextless" ()             -> Panel_Size_Axis { return {type = .Fit, value = 0}}


//////////////////////////////////
// ~geb: Prebuilt Components
