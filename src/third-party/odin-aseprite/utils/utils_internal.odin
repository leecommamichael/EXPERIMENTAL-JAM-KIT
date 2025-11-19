package aseprite_file_handler_utility

import ir "base:intrinsics"
import "base:runtime"
import "core:reflect"
import "core:strconv"

@(require) import "core:fmt"
@(require) import "core:log"

_ :: reflect


@(private)
fast_log_str :: proc(lvl: log.Level, str: string, loc := #caller_location) {
    logger := context.logger
    if logger.procedure == nil { return }
    if lvl < logger.lowest_level { return }
    logger.procedure(logger.data, lvl, str, logger.options, loc)
}

@(private)
fast_log_str_enum :: proc(lvl: log.Level, str: string, val: $T, sep := " ", loc := #caller_location) where ir.type_is_enum(T) {
    logger := context.logger
    if logger.procedure == nil { return }
    if lvl < logger.lowest_level { return }

    s := reflect.enum_string(val)
    buf := make([]u8, len(str) + len(sep) + len(s))
    defer delete(buf)

    n := copy(buf[:], str)
    n += copy(buf[n:], sep)
    copy(buf[n:], s)

    logger.procedure(logger.data, lvl, string(buf), logger.options, loc)
}

@(private)
fast_log_str_num :: proc(lvl: log.Level, str: string, val: $T, sep := " ", loc := #caller_location) where ir.type_is_numeric(T) {
    logger := context.logger
    if logger.procedure == nil { return }
    if lvl < logger.lowest_level { return }

    nb: [32]u8
    s := strconv.write_int(nb[:], i64(val), 10)
    buf := make([]u8, len(str) + len(sep) + len(s))
    defer delete(buf)

    n := copy(buf[:], str)
    n += copy(buf[n:], sep)
    copy(buf[n:], s)

    logger.procedure(logger.data, lvl, string(buf), logger.options, loc)
}

@(private)
fast_log :: proc {fast_log_str, fast_log_str_enum, fast_log_str_num}