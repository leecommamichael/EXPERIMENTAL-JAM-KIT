package main

import "base:runtime"
import "core:strings"
import "core:log"
import "core:slice"
import "core:fmt"
import "core:time"
import "base:intrinsics"
import "core:math/linalg"

////////////////////////////////////////////////////////////////////////////////
// Assorted Idioms
////////////////////////////////////////////////////////////////////////////////
NIBBLE :: 4 // half a byte
find :: slice.linear_search
contains :: slice.contains

// Returns a slice of the `n` elements from the end of `slice`.
slice_end :: proc "contextless" (slice: $Indistinct/[]$T, n: int) -> []T {
	slclen := len(slice)
	if n >= slclen {
		return slice
	}
	return slice[slclen - n:][:n]
}

string_start :: proc "contextless" (str: string, n: int) -> string {
	strlen := len(str)
	if n >= strlen {
		return str
	}
	return str[0 : n]
}

string_end :: proc "contextless" (str: string, n: int) -> string {
	strlen := len(str)
	if n >= strlen {
		return str
	}
	return str[strlen - n:][:n]
}

// Cast a pointer to a byte-slice.
pointee_bytes :: #force_inline proc "contextless" (data: ^$T) -> []u8 {
	return (cast([^]u8)data)[:size_of(T)]
}

// TODO: Check if debugger connected, then debug_trap if so.
debugger :: proc () {
	when ODIN_DEBUG {
		debug_trap()
	}
}

// Idiom (for WIP code) to do something despite one-time while in a loop.
// To run a statement only on the first iteration of the loop:
// ```
//   if !over_run_limit(1) { STATEMENT }
// ```
over_run_limit :: proc (limit: int, loc := #caller_location) -> bool {
	@static tickets: map[u64]int
	hash := code_location_hash(loc)
	val, found := tickets[hash]; if !found {
		tickets[hash] = 0
	}
	if val >= limit {
		tickets[hash] += 1
		return true
	}
	return false
}

////////////////////////////////////////////////////////////////////////////////
// Generics
////////////////////////////////////////////////////////////////////////////////
debug_trap :: intrinsics.debug_trap
is_subtype :: intrinsics.type_is_subtype_of
is_array   :: intrinsics.type_is_array
is_float   :: intrinsics.type_is_float
type_of_pointee :: intrinsics.type_elem_type
elem_type       :: intrinsics.type_elem_type
Empty_Struct :: struct {}

////////////////////////////////////////////////////////////////////////////////
// Conversions
////////////////////////////////////////////////////////////////////////////////
array_cast :: linalg.array_cast
clone_to_cstring :: strings.clone_to_cstring
unsafe_string_to_cstring :: strings.unsafe_string_to_cstring

// Converts slice into a dynamic array without cloning or allocating memory
@(require_results)
alias_slice_as_dynamic :: proc(a: $T/[]$E) -> [dynamic]E {
	s := transmute(runtime.Raw_Slice)a
	d := runtime.Raw_Dynamic_Array{
		data = s.data,
		len  = s.len,
		cap  = s.len,
		allocator = runtime.panic_allocator(),
	}
	return transmute([dynamic]E)d
}

@(require_results)
alias_slice_as_empty_dynamic :: proc(a: $T/[]$E) -> [dynamic]E {
	s := transmute(runtime.Raw_Slice)a
	d := runtime.Raw_Dynamic_Array{
		data = s.data,
		len  = 0,
		cap  = s.len,
		allocator = runtime.panic_allocator(),
	}
	return transmute([dynamic]E)d
}

// Convert a null-terminated fixed-size byte array to a string.
bats :: proc "contextless" (byte_array: []u8) -> string {
	return strings.truncate_to_byte(string(byte_array), 0)
}

////////////////////////////////////////////////////////////////////////////////
// Logging Utils
////////////////////////////////////////////////////////////////////////////////
// Sublime Text doesn't do ANSI color.
create_sublime_text_logger :: proc () -> log.Logger {
		return log.create_console_logger(lowest = log.Level.Debug, opt = { .Level, })
}
// A stopwatch timer for quick and dirty measurements.
@(thread_local)
log_timers: map[string]time.Tick

log_time :: proc (id: string) {
	if id in log_timers {
		tick := log_timers[id]
		duration := time.tick_diff(tick, time.tick_now())
		fmt.printfln("[TIMER] % 6.1fms %s", f64(duration) / f64(time.Millisecond), id)
		delete_key(&log_timers, id)
	} else {
		log_timers[id] = time.tick_now()
	}
}

startup_tick := time.tick_now()
log_runtime :: proc (message: string) {
	duration := time.tick_diff(startup_tick, time.tick_now())
	fmt.printfln("[TIMER] % 6.1fms into run. %s", f64(duration) / f64(time.Millisecond), message)
}
////////////////////////////////////////////////////////////////////////////////
// hash
////////////////////////////////////////////////////////////////////////////////
import "core:hash/xxhash"
import "core:reflect"

// WARNING: Strings, slices, pointers won't hash their actual data.
hash240_values :: proc (args: ..any) -> u64 {
	@static buf: [240]u8
	offset: int = 0
	for arg in args {
		slice := reflect.as_bytes(arg)
		size := len(slice)
		copy(buf[offset:size], slice)
		offset += size
	}
	return xxhash.XXH3_64(buf[:])
}

import "core:bufio"
// The underlying hash algorithm can take longer inputs than 240 bytes.
// 240 bytes is the largest input with the fewest tradeoffs in terms of:
// - collision-rate
// - performance
// - portability (32 bit support)
hash240 :: proc (buf: []u8) -> u64 {
	ensure(len(buf) <= 240)
  hash := xxhash.XXH3_64(buf)
  return hash
}

// Hashes a Source_Code_Location using the line, column, and file_path.
// CAVEAT: Only the final 56 bytes of the file_path are hashed.
code_location_hash :: proc (declaration: runtime.Source_Code_Location) -> u64 {
	loc := declaration
	hash_input := make([dynamic]u8, 0, len(loc.file_path) + 2*size_of(i32), context.temp_allocator)
	#assert(size_of(loc.line) == 4)
	#assert(size_of(loc.column) == 4)
	line := (transmute(^[4]u8) &loc.line)^[:]
	column := (transmute(^[4]u8) &loc.column)^[:]
	path_end := slice_end(transmute([]u8)loc.file_path, 64-8)
	append(&hash_input, ..line)
	append(&hash_input, ..column)
	append(&hash_input, ..path_end)
	hash := xxhash.XXH3_64(hash_input[:])
	delete(hash_input)
	return hash
}
