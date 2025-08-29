package verde

MAX_BOX_COUNT :: 2048

UI_BoxFlags :: bit_set[UI_BoxFlag; u32]
UI_BoxFlag :: enum {
  Invisible
}

UI_Rect :: struct {
  min, max : vec2
}

UI_Handle :: i32
UI_Box :: struct {

  outer_rect, inner_rect : UI_Rect,

  parent:        UI_Handle,
  next_sibling : UI_Handle,
  first_child :  UI_Handle,
  last_child :   UI_Handle,

  position: vec2,
  resolved_size: vec2,
  using _config: UI_Config,
}

UI_Size :: struct { w, h: UI_SizeAxis }
UI_SizeAxis :: struct {
  type: enum {
    Fixed = 0, 
    ParentPct,
    Fit,
    Fill,
  },
  value: f32,
}

size_fixed :: #force_inline proc(val: f32)     -> UI_SizeAxis { return {type = .Fixed, value = val} }
size_perc  :: #force_inline proc(val: f32)     -> UI_SizeAxis { return {type = .ParentPct, value = val} }
size_fill  :: #force_inline proc(val: f32 = 1) -> UI_SizeAxis { return {type = .Fill, value = val} }
size_fit   :: #force_inline proc()             -> UI_SizeAxis { return {type = .Fit, value = 0}}

UI_Padding :: struct {
  left, top, right, bottom: f32
}

UI_LayoutDir :: enum { T_to_B, L_to_R }

UI_Config :: struct {
  size:             UI_Size,
  padding:          UI_Padding,
  child_gap:        f32,
  layout_direction: UI_LayoutDir,

  color:            vec4,
  radius:           vec4,
  flags :           UI_BoxFlags,
}

@(private) _ctx: ^UI_State

UI_State :: struct {
  flat_array:        [^]UI_Box,
  box_count:         u32, 
  open_box:          UI_Handle,
  layout_dimensions: vec2,
  cursor_position:   vec2
}

ui_init :: proc(state: ^UI_State) {
  state.flat_array = make([^]UI_Box, MAX_BOX_COUNT)
  state.box_count = 0
  state.open_box = -1
}

ui_set_context :: proc(state: ^UI_State) -> (prev: ^UI_State) { 
  prev_ctx := _ctx
  _ctx = state 
  return prev_ctx
}

ui_layout_begin :: proc(
  w, h : f32, 
  x:=f32(0), y:=f32(0),
  direction: UI_LayoutDir = .T_to_B,
  padding: UI_Padding = {},
  child_gap :f32= 0,
  color: vec4=0,
  flags: UI_BoxFlags = {.Invisible}
) {
  _ctx.layout_dimensions = {w, h}
  _ctx.open_box = -1
  _ctx.box_count = 0

  id := ui_begin({
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

  root_box := ui_get_box(id)
  root_box.position = {x, y}
  _ctx.cursor_position = root_box.position + {root_box.padding.left, root_box.padding.top}
}

ui_layout_end :: proc() -> []UI_Box {
  ui_end()

  return _ctx.flat_array[:_ctx.box_count]
}

ui_begin :: proc(config: UI_Config) -> UI_Handle {
  using _ctx

  assert(box_count < MAX_BOX_COUNT, "Maximum box count exceeded")

  result_idx := UI_Handle(box_count)
  parent_idx := open_box

  parent := &flat_array[parent_idx] if parent_idx >= 0 else nil
  box := &flat_array[box_count]

  box.parent = parent_idx
  box.first_child = -1
  box.last_child = -1
  box.next_sibling = -1
  box.flags = {}
  box._config = config

  // Initialize resolved size for Fixed sizing
  if box.size.w.type == .Fixed {
    box.resolved_size.x = box.size.w.value
  }
  if box.size.h.type == .Fixed {
    box.resolved_size.y = box.size.h.value
  }

  if parent != nil {
    box.position = cursor_position
    if parent.first_child == -1 {
      parent.first_child = result_idx
      parent.last_child = result_idx
    } else {
      last_child := &flat_array[parent.last_child]
      last_child.next_sibling = result_idx
      parent.last_child = result_idx
    }

    padding := parent.padding
    
    if box.size.w.type == .ParentPct && parent.resolved_size.x > 0 {
      box.resolved_size.x = (parent.resolved_size.x - padding.left - padding.right) * box.size.w.value
    }
    if box.size.h.type == .ParentPct && parent.resolved_size.y > 0 {
      box.resolved_size.y = (parent.resolved_size.y - padding.top - padding.bottom) * box.size.h.value
    }
    
    available_space := vec2{
      parent.position.x + parent.resolved_size.x - parent.padding.right - cursor_position.x,
      parent.position.y + parent.resolved_size.y - parent.padding.bottom - cursor_position.y,
    }

    if box.size.w.type == .Fill {
      box.resolved_size.x = max(0, available_space.x * box.size.w.value)
    }
    if box.size.h.type == .Fill {
      box.resolved_size.y = max(0, available_space.y * box.size.h.value)
    }
    
    cursor_position = box.position + {box.padding.left, box.padding.top}
  }

  open_box = result_idx
  box_count += 1

  return result_idx
}

ui_end :: proc() {
  using _ctx

  assert(open_box >= 0, "ui_end() called without matching ui_begin()")

  current_box := &flat_array[open_box]
  parent_idx := current_box.parent
  
  if current_box.size.w.type == .Fit || current_box.size.h.type == .Fit {
    if current_box.first_child != -1 {
      fit_size := vec2{0, 0}
      child_handle := current_box.first_child
      child_count := 0
      
      for child_handle >= 0 {
        child := &flat_array[child_handle]
        
        if current_box.layout_direction == .L_to_R {
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
        if current_box.layout_direction == .L_to_R {
          fit_size.x += current_box.child_gap * f32(child_count - 1)
        } else {
          fit_size.y += current_box.child_gap * f32(child_count - 1)
        }
      }
      
      fit_size += {
        current_box.padding.left + current_box.padding.right,
        current_box.padding.top + current_box.padding.bottom
      }
      
      if current_box.size.w.type == .Fit {
        current_box.resolved_size.x = fit_size.x
      }
      if current_box.size.h.type == .Fit {
        current_box.resolved_size.y = fit_size.y
      }
    }
  }

  open_box = parent_idx

  if parent_idx >= 0 {
    parent := &flat_array[parent_idx]
    layout := parent.layout_direction

    if layout == .T_to_B {
      cursor_position.x = current_box.position.x
      cursor_position.y = current_box.position.y + current_box.resolved_size.y + parent.child_gap
    } else if layout == .L_to_R {
      cursor_position.x = current_box.position.x + current_box.resolved_size.x + parent.child_gap
      cursor_position.y = current_box.position.y
    }
  }

  current_box.outer_rect.min = current_box.position
  current_box.outer_rect.max = current_box.position + current_box.resolved_size

  current_box.inner_rect.min = current_box.outer_rect.min + {current_box.padding.left,current_box.padding.top}
  current_box.inner_rect.max = current_box.outer_rect.max - {current_box.padding.right,current_box.padding.bottom}
}

ui_region_left :: proc() -> vec2 {
  if _ctx.open_box < 0 { return {} }
  box := _ctx.flat_array[_ctx.open_box]
  return {
    box.position.x + box.resolved_size.x - box.padding.right -  _ctx.cursor_position.x,
    box.position.y + box.resolved_size.y - box.padding.bottom - _ctx.cursor_position.y,
  }
}

ui_get_box :: proc(handle: UI_Handle) -> ^UI_Box {
  if handle < 0 || handle >= UI_Handle(_ctx.box_count) {
    return nil
  }
  return &_ctx.flat_array[handle]
}
