package main

import "base:runtime"
import "core:strings"
import "core:log"
import "core:fmt"
import "core:path/slashpath"

EJK_VALIDATION_LEVEL_OFF :: 0
EJK_VALIDATION_LEVEL_WARNING :: 1
EJK_VALIDATION_LEVEL_ERROR :: 2

Validation_Level :: enum {
	Off     = EJK_VALIDATION_LEVEL_OFF,
	Warning = EJK_VALIDATION_LEVEL_WARNING,
	Error   = EJK_VALIDATION_LEVEL_ERROR,
}

DEFAULT_LEVEL :: EJK_VALIDATION_LEVEL_ERROR when ODIN_DEBUG else EJK_VALIDATION_LEVEL_OFF
EJK_VALIDATION_LEVEL :: #config(EJK_VALIDATION_LEVEL, DEFAULT_LEVEL)

raise_warning :: proc (
	code:  string,
	terse: string,
	long:  string = "",
	error_loc: runtime.Source_Code_Location = #caller_location
) {
	when EJK_VALIDATION_LEVEL >= EJK_VALIDATION_LEVEL_WARNING {
		raise_diagnostic(.Warning, code, terse, long, error_loc)
	}
}

raise_error :: proc (
	code:  string,
	terse: string,
	long:  string = "",
	error_loc: runtime.Source_Code_Location = #caller_location
) {
	when EJK_VALIDATION_LEVEL >= EJK_VALIDATION_LEVEL_ERROR {
		raise_diagnostic(.Error, code, terse, long, error_loc)
	}
}

raise_diagnostic :: proc (
	level: Validation_Level,
	code:  string,
	terse: string,
	long:  string,
	error_loc: runtime.Source_Code_Location,
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

////////////////////////////////////////////////////////////////////////////////
// Validations
////////////////////////////////////////////////////////////////////////////////

invalid_entity_depth :: proc (entity: ^Entity) -> bool {
	z := entity.position.z + entity.basis.position.z
	return z < FAR_Z || z > NEAR_Z
}

invalid_entity_hash :: proc (entity: ^Entity) -> bool {
	return entity.create_tick == globals.tick_counter
}

raise_warning_bad_depth :: proc (entity: ^Entity) {
	raise_warning(
		"Z COORDINATE OUT OF BOUNDS",
		fmt.tprintf("%s won't be visible. Z is %f."),
		fmt.tprintf(
			"In the final transformed position, a Z outside of [%d,%d] is not drawn.",
			`Transform(basis.z=%f, position.z=%f)`,
			FAR_Z, NEAR_Z,
			entity.basis.position.z, entity.position.z
		)
	)
}

// It was created this tick, but is in cache! Thus we have API misuse.
// - 1. two entities with the same hash.
// - 2. one entity whose code was run twice in one step.
raise_error_hash_collision :: proc (entity: ^Entity, hash: Hash) {
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
