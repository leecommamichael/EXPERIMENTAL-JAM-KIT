package main

import "core:mem"
import "core:log"
import "base:runtime"
import ngl "nord_gl"

////////////////////////////////////////////////////////////////////////////////
// A fixed array whose elements are padded to stride perfectly along an alignment.
//
// e.g. if the element is vec4 (four 4-byte floats)
//      but the alignment is 32 bytes,
//      then there will be 16 bytes of padding after each element.
////////////////////////////////////////////////////////////////////////////////

Aligned_Array :: struct($Element: typeid) {
	data: []byte,
	stride: int,
	alignment: int
}

make_aligned_array :: proc (
	$T: typeid,
	cap: int, // max number of elements
	alignment: int,
) -> Aligned_Array(T) {
	element_size :: size_of(T)
	stride := cast(int) align_up(element_size, cast(uint)alignment)
	buffer_size := cap * stride

	// make byte buffer which starts on the proper alignment.
	data, err := mem.make_aligned([]byte, buffer_size, alignment)
	log.assertf(err == .None, "%v", err)
	return Aligned_Array(T) {
		data = data,
		stride = stride,
		alignment = alignment
	}
}

align_up :: proc(x, align: uint) -> (aligned: uint) {
	assert(0 == (align & (align - 1)), "must align to a power of two")
	return (x + (align - 1)) &~ (align - 1)
}

subscript_aligned_array :: proc (buffer: ^Aligned_Array($T), index: int) -> ^T {
	assert((index * buffer.stride) % buffer.alignment == 0)
	byte_pointer := mem.ptr_offset(raw_data(buffer.data), index * buffer.stride)
	return transmute(^T) byte_pointer
}

// Enables a default of Triangles.
Ren_Mode :: enum u32 {
	Triangles,
	Lines,
	Line_Loop,
	Points,
}

ren_mode_to_primitive :: proc (mode: Ren_Mode) -> ngl.Primitive_Mode {
	switch mode {
	case .Triangles: return .TRIANGLES
	case .Lines:     return .LINES
	case .Line_Loop: return .LINE_LOOP
	case .Points:    return .POINTS
	case: panic("Unhandled primitive mode.")
	}
}
