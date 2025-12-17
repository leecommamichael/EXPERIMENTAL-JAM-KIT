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
////////////////////////////////////////////////////////////////////////////////
// Assorted Idioms
find :: slice.linear_search
contains :: slice.contains

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Generics
is_subtype :: intrinsics.type_is_subtype_of
is_array   :: intrinsics.type_is_array
is_float   :: intrinsics.type_is_float
type_of_pointee :: intrinsics.type_elem_type
elem_type       :: intrinsics.type_elem_type
Empty_Struct :: struct {}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Conversions
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
////////////////////////////////////////////////////////////////////////////////
// Logging Utils
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
////////////////////////////////////////////////////////////////////////////////
import "core:hash/xxhash"
code_location_hash :: proc (declaration: runtime.Source_Code_Location) -> u64 {
	loc := declaration
	hash_input := make([dynamic]u8, 0, len(loc.file_path) + 2*size_of(i32), context.temp_allocator)
	append(&hash_input, loc.file_path)
	append(&hash_input, ..(cast(^[4]u8)&loc.line)^[:])
	append(&hash_input, ..(cast(^[4]u8)&loc.column)^[:])
	hash := xxhash.XXH3_64(hash_input[:])
	delete(hash_input)
	return hash
}

// Idiom (for WIP code) to do somethin despite re-entry.
// if under_run_limit(1) do stuff()
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