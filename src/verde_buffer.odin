package verde

import "core:mem"

////////////////////////
// ~geb: Gap Buffur

Gap_Buffer :: struct {
  buffer: []u8,
  gap_start: int,
  gap_end: int,
  buffer_size: int,
}

