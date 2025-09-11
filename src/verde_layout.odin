package verde

import "core:fmt"

//////////////////////////////////
// ~geb: Constants

MAX_PANEL_COUNT :: 2048

//////////////////////////////////
// ~geb: Types
 
Panel_Flags :: bit_set[Panel_Flag; u32]
Panel_Flag :: enum {
  Invisible,
  Container,
  Text,
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

  outline_color    :vec4_f32,
  outline_thickness:f32,
  text:             string,
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

DEFAULT_PANE_CONFIG := Pane_Render_Config {
  leaf_color          = hex_color(0x282828),  
  active_leaf_color   = hex_color(0x282828),  
  leaf_outline        = hex_color(0x3c3836),  

  active_leaf_outline = hex_color(0x504945),  
  text_color          = hex_color(0xebdbb2),
  split_gap           = 1,                    
  leaf_radius         = 0,                    
  leaf_padding        = {4,4,4,4},            
}

layout_panes_recursive :: proc(tree: ^Pane_Tree, handle: Pane_Handle, config: Pane_Render_Config = DEFAULT_PANE_CONFIG) {
  if !pane_tree_is_valid_handle(tree, handle) do return

  node := &tree.flat_array[handle]

  calculate_child_size :: proc(is_horizontal: bool, split_ratio: f32, split_gap: f32) -> Panel_Size {
    region := layout_region_left()
    if is_horizontal {
      available_height := region.y - split_gap
      child_height := available_height * split_ratio
      return {size_fill(), size_fixed(child_height)}
    } else {
      available_width := region.x - split_gap
      child_width := available_width * split_ratio
      return {size_fixed(child_width), size_fill()}
    }
  }

  render_child_panel :: proc(tree: ^Pane_Tree, child_handle: Pane_Handle, size: Panel_Size, config: Pane_Render_Config) {
    panel_begin({
      size = size,
      child_gap = config.split_gap,
      flags = {.Invisible},
    })
    defer panel_end()
    layout_panes_recursive(tree, child_handle, config)
  }

  #partial switch node.kind {
  case .Split_Vertical, .Split_Horizontal:
    is_horizontal := node.kind == .Split_Horizontal
    panel_begin({
      size = {size_fill(), size_fill()},
      layout_direction = is_horizontal ? .Vertical : .Horizontal,
      child_gap = config.split_gap,
      flags = {.Invisible},
    })
    defer panel_end()

    if node.child1 >= 0 {
      child1_size := calculate_child_size(is_horizontal, node.split_ratio, config.split_gap)
      render_child_panel(tree, node.child1, child1_size, config)
    }

    if node.child2 >= 0 {
      child2_size := Panel_Size{size_fill(), size_fill()}
      render_child_panel(tree, node.child2, child2_size, config)
    }

  case .Leaf:
    is_active := handle == tree.active_pane
    panel_begin({
      size = {size_fill(), size_fill()},
      layout_direction = .Vertical,
      color = is_active ? config.active_leaf_outline : config.leaf_outline,
      radius=config.leaf_radius,
      padding = {1,1,1,1},
      child_gap = 1
    })
    defer panel_end()

    region := layout_region_left()

    // Main content area
    panel_begin({
      size = {size_fill(), size_fixed(region.y - 25)},
      color = is_active ? config.active_leaf_color : config.leaf_color,
      radius = {config.leaf_radius-1, config.leaf_radius-1, 0, 0},
      padding = config.leaf_padding,
      flags = {.Container}
    }); panel_end()


    panel_begin({
      size = {size_fill(), size_fill()},
      flags = {.Invisible},
      padding = {3,3,3,3},
      child_gap = 3,
      layout_direction = .Horizontal
    }) 
    defer panel_end()

    panel_begin({
      size = {size_fill(), size_fill()},
      color = config.text_color,
      text = "src/main.c",
      flags = {.Text}
    }); panel_end()
  }
}
