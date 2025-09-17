package verde

//////////////////////////////////
// ~geb: Constants

MAX_LEAF_COUNT  :: 8
MAX_TREE_NODES  :: 2 * MAX_LEAF_COUNT - 1
ROOT_PANE_HANDLE:: Pane_Handle(0)
INVALID_PANE_HANDLE :: Pane_Handle(-1)

SPLIT_NODE_KIND :: bit_set[Pane_Node_Kind] {.Split_Vertical, .Split_Horizontal}

//////////////////////////////////
// ~geb: Types

Pane_Render_Config :: struct {
  leaf_color:          Color,
  active_leaf_color:   Color,
  leaf_outline:        Color,
  active_leaf_outline: Color,
  text_color:          Color,

  split_gap:           f32,
  leaf_padding:        Panel_Padding,
}

Pane_Flag :: enum u8 {
  Line_Wrapping = 0,
}

Pane_Node_Kind :: enum u8 {
  None,
  Leaf,
  Split_Vertical,
  Split_Horizontal,
}

Pane_Handle :: i32

Pane_Node :: struct {
  child1, child2 : Pane_Handle, /* left-right or top-bottom */
  parent : Pane_Handle,
  split_ratio : f32, // child1 : child2
  kind : Pane_Node_Kind,
}

Pane_Tree :: struct {
  flat_array : [MAX_TREE_NODES]Pane_Node,
  node_count: u32,
  active_pane : Pane_Handle, // where tree actions take place
}

Pane_Move :: enum {
  Left,
  Right,
  Up,
  Down,
}

//////////////////////////////////
// ~geb: Usage procs

pane_tree_create :: proc() -> Pane_Tree {
  tree := Pane_Tree {}
  tree.node_count = 1
  tree.active_pane = 0
  
  root_node := &tree.flat_array[0]
  root_node^ = {
    child1 = INVALID_PANE_HANDLE,
    child2 = INVALID_PANE_HANDLE,
    parent = INVALID_PANE_HANDLE,
    split_ratio = 0.0,
    kind = .Leaf,
  }
  return tree
}

_find_free_slot :: proc(tree: ^Pane_Tree) -> (Pane_Handle, bool) {
  for i in 0..<MAX_TREE_NODES {
    if tree.flat_array[i].kind == .None {
      return Pane_Handle(i), true
    }
  }
  return INVALID_PANE_HANDLE, false
}

/*
  Splits the currently active pane
*/
pane_tree_split :: proc(tree: ^Pane_Tree, horizontal := false, ratio: f32 = 0.5) -> bool {
  if tree.active_pane < 0 || tree.active_pane >= i32(tree.node_count) { return false }
  
  active_node := &tree.flat_array[tree.active_pane]
  if active_node.kind != .Leaf { return false }
  
  child1_handle, found1 := _find_free_slot(tree)
  if !found1 { return false }
  
  tree.flat_array[child1_handle].kind = .Leaf
  
  child2_handle, found2 := _find_free_slot(tree)
  if !found2 {
    tree.flat_array[child1_handle].kind = .None
    return false
  }
  
  child1 := &tree.flat_array[child1_handle]
  child2 := &tree.flat_array[child2_handle]
  
  child1^ = {
    child1 = INVALID_PANE_HANDLE,
    child2 = INVALID_PANE_HANDLE,
    parent = tree.active_pane,
    split_ratio = 0.0,
    kind = .Leaf,
  }
  
  child2^ = {
    child1 = INVALID_PANE_HANDLE,
    child2 = INVALID_PANE_HANDLE,
    parent = tree.active_pane,
    split_ratio = 0.0,
    kind = .Leaf,
  }

  
  active_node.child1 = child1_handle
  active_node.child2 = child2_handle
  active_node.split_ratio = ratio
  active_node.kind = horizontal ? .Split_Horizontal : .Split_Vertical
  
  tree.active_pane = child2_handle
  
  max_used_index := max(i32(child1_handle), i32(child2_handle))
  if max_used_index >= i32(tree.node_count) {
    tree.node_count = u32(max_used_index + 1)
  }
  
  return true
}

pane_tree_collapse :: proc(tree: ^Pane_Tree) -> bool {
  if tree.active_pane < 0 || tree.active_pane >= Pane_Handle(tree.node_count) { return false }
  if tree.active_pane == ROOT_PANE_HANDLE { return false }
  
  active_node := &tree.flat_array[tree.active_pane]
  if active_node.kind != .Leaf { return false }
  
  parent_handle := active_node.parent
  if parent_handle < 0 { return false }
  
  parent_node := &tree.flat_array[parent_handle]
  
  sibling_handle: Pane_Handle
  if parent_node.child1 == tree.active_pane {
    sibling_handle = parent_node.child2
  } else {
    sibling_handle = parent_node.child1
  }
  
  if sibling_handle < 0 { return false }
  
  sibling_node := &tree.flat_array[sibling_handle]
  
  next_focus_leaf: Pane_Handle = -1
  
  if sibling_node.kind == .Leaf {
    next_focus_leaf = parent_handle
    
    parent_node.child1 = INVALID_PANE_HANDLE
    parent_node.child2 = INVALID_PANE_HANDLE
    parent_node.split_ratio = 0.0
    parent_node.kind = .Leaf
    
    active_node.kind = .None
    sibling_node.kind = .None
    
  } else {
    next_focus_leaf = find_first_leaf(tree, sibling_handle)
    
    sibling_child1 := sibling_node.child1
    sibling_child2 := sibling_node.child2
    sibling_split_ratio := sibling_node.split_ratio
    sibling_kind := sibling_node.kind
    
    parent_node.child1 = sibling_child1
    parent_node.child2 = sibling_child2
    parent_node.split_ratio = sibling_split_ratio
    parent_node.kind = sibling_kind
    
    if sibling_child1 >= 0 {
      tree.flat_array[sibling_child1].parent = parent_handle
    }
    if sibling_child2 >= 0 {
      tree.flat_array[sibling_child2].parent = parent_handle
    }
    
    active_node.kind = .None
    sibling_node.kind = .None
  }
  
  if next_focus_leaf >= 0 && pane_tree_is_valid_handle(tree, next_focus_leaf) {
    tree.active_pane = next_focus_leaf
  } else {
    fallback_leaf := find_first_leaf(tree, ROOT_PANE_HANDLE)
    if fallback_leaf >= 0 {
      tree.active_pane = fallback_leaf
    } else {
      if tree.flat_array[ROOT_PANE_HANDLE].kind == .Leaf {
        tree.active_pane = ROOT_PANE_HANDLE
      }
    }
  }
  
  return true
}

pane_tree_focus :: proc(tree: ^Pane_Tree, handle: Pane_Handle) -> bool {
  if handle < 0 || handle >= i32(tree.node_count) { return false }
  
  pane := &tree.flat_array[handle]
  if pane.kind == .Leaf {
    tree.active_pane = handle
    return true
  }
  return false
}

pane_tree_is_valid_handle :: proc(tree: ^Pane_Tree, handle: Pane_Handle) -> bool {
  return handle >= 0 && handle < i32(tree.node_count) && tree.flat_array[handle].kind != .None
}

pane_tree_get_depth :: proc(tree: ^Pane_Tree, handle: Pane_Handle) -> int {
  if !pane_tree_is_valid_handle(tree, handle) { return -1 }
  
  depth := 0
  current := handle
  
  for current != ROOT_PANE_HANDLE && current >= 0 {
    parent := tree.flat_array[current].parent
    if parent < 0 { break }
    current = parent
    depth += 1
  }
  
  return depth
}

/*
Coord maps screen from top left to bottom right as (0, 0) -> (1, 1)
Finds the nearest split node to the given coordinate by calculating actual distances
*/
pane_tree_focus_move :: proc(tree: ^Pane_Tree, dir: Pane_Move) {

  leaf_idx := tree.active_pane
  if leaf_idx < 0 || leaf_idx >= len(tree.flat_array) do return

  leaf := &tree.flat_array[leaf_idx]
  if leaf.parent < 0 do return 

  node_kind: Pane_Node_Kind
  switch dir {
  case .Up, .Down: 
    node_kind = .Split_Horizontal
  case .Left, .Right: 
    node_kind = .Split_Vertical
  }

  current_idx := leaf_idx

  for current_idx >= 0 {
    current := &tree.flat_array[current_idx]

    if current.parent < 0 do break // Reached root

    parent := &tree.flat_array[current.parent]

    if parent.kind == node_kind {
      is_child1 := parent.child1 == current_idx

      target_child: Pane_Handle = -1

      switch dir {
      case .Up:
        if !is_child1 {
          target_child = parent.child1
        }
      case .Down:
        if is_child1 {
          target_child = parent.child2
        }
      case .Left:
        if !is_child1 {
          target_child = parent.child1
        }
      case .Right:
        if is_child1 {
          target_child = parent.child2
        }
      }

      if target_child >= 0 {
        new_leaf: Pane_Handle = -1

        switch dir {
        case .Up, .Left:
          new_leaf = find_last_leaf(tree, target_child)
        case .Down, .Right:
          new_leaf = find_first_leaf(tree, target_child)
        }

        if new_leaf >= 0 {
          tree.active_pane = new_leaf
        }
        return
      }
    }

    current_idx = current.parent
  }
}

pane_tree_resize :: proc(tree: ^Pane_Tree, handle: Pane_Handle, delta: f32) {
  if !pane_tree_is_valid_handle(tree, handle) { return }
  pane := tree.flat_array[handle]

  if pane.kind != .Leaf || pane.parent < 0 { return }

  parent_split := &tree.flat_array[pane.parent]
  parent_split.split_ratio += delta
}

////////////////////////////
// ~geb: Helper 

find_first_leaf ::  proc(tree: ^Pane_Tree, node_idx: Pane_Handle) -> Pane_Handle {
  if node_idx < 0 || node_idx >= len(tree.flat_array) do return -1

  node := &tree.flat_array[node_idx]
  if node.kind == .Leaf do return node_idx

  return find_first_leaf(tree, node.child1)
}

find_last_leaf :: proc(tree: ^Pane_Tree, node_idx: Pane_Handle) -> Pane_Handle {
  if node_idx < 0 || node_idx >= len(tree.flat_array) do return -1

  node := &tree.flat_array[node_idx]
  if node.kind == .Leaf do return node_idx

  return find_last_leaf(tree, node.child2)
}
