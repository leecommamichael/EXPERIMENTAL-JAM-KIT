package main

import "base:runtime"
import "core:strings"
import "core:log"
import "core:fmt"
import "core:path/slashpath"

// It was created this tick, but is in cache! Thus we have API misuse.
// - 1. two entities with the same hash.
// - 2. one entity whose code was run twice in one step.
raise_error_hash_collision :: proc (entity: Entity, hash: Hash) {
	error_loc := locate_hash_input_source(hash)
	filename := slashpath.name(error_loc.file_path, false, context.temp_allocator)
	raise_error(
		"HASH_COLLISION",
		"An entity created the same hash as an existing entity.",
		fmt.tprintf(
			" - Colliding: Entity created by \"%s :: proc\" in %s.odin(%d)\n" +
			" -  Existing: %s\n",
			string_start(error_loc.procedure, 40), string_end(filename, 40), error_loc.line,
			entity.debug_name,
		),
		error_loc = error_loc
	)
}

raise_error :: proc (
	code: string,
	terse: string,
	long: string = "",
	error_loc: runtime.Source_Code_Location = #caller_location,
) {
	fmtstr := strings.builder_make_none(context.temp_allocator)
	args: = make([dynamic]any, len=0, cap=10, allocator=context.temp_allocator)

	strings.write_string(&fmtstr, "%s\n")
	append(&args, code)

	strings.write_string(&fmtstr, "%s\n")
	append(&args, terse)

	if len(long) > 0 {
		strings.write_string(&fmtstr, long)
		strings.write_string(&fmtstr, "\n")
	}

	strings.write_string(&fmtstr, "Machine Output Below:\n")
	strings.write_string(&fmtstr, "%s %s %s")
	append(&args, error_loc, code, terse)

	fmt.println(strings.to_string(fmtstr))
	log.errorf(strings.to_string(fmtstr), ..args[:])
	
	debugger()
}