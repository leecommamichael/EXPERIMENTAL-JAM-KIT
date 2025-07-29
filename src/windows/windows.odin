package windows

import "core:sys/windows"
import "base:intrinsics"
import "core:log"

@require_results
nonzero :: proc (result: $T, caller_expr := #caller_expression) -> (T, bool)
where intrinsics.type_is_integer(T) || intrinsics.type_is_pointer(T) || intrinsics.type_is_boolean(T) {
  if result == {} {
    log_error(caller_expr)
    return {}, false
  }

  return result, true
}

@require_results
zero :: proc (result: $T, caller_expr := #caller_expression) -> (T, bool)
where intrinsics.type_is_integer(T) || intrinsics.type_is_pointer(T) || intrinsics.type_is_boolean(T) {
  if result != {} {
    log_error(caller_expr)
    return {}, false
  }

  return result, true
}

@require_results
not_negative_one :: proc (result: $T, caller_expr := #caller_expression) -> (T, bool)
where intrinsics.type_is_integer(T) || intrinsics.type_is_pointer(T) || intrinsics.type_is_boolean(T) {
  if result == transmute(T)(i32(-1)) {
    log_error(caller_expr)
    return {}, false
  }

  return result, true
}

log_error :: proc (caller_expr: string) {
  err_code: windows.DWORD = windows.GetLastError()
  flags: windows.DWORD : 
    windows.FORMAT_MESSAGE_ALLOCATE_BUFFER |
    windows.FORMAT_MESSAGE_FROM_SYSTEM |
    windows.FORMAT_MESSAGE_IGNORE_INSERTS
  lang := windows.MAKELANGID(windows.LANG_NEUTRAL, windows.SUBLANG_DEFAULT)
  err_msg: windows.LPWSTR
  err_msg_len := windows.FormatMessageW(flags, nil, err_code, lang, cast(windows.LPWSTR)&err_msg, 0, nil)
  defer windows.LocalFree(err_msg)
  x := (cast([^]u16) err_msg)[:err_msg_len-1] // they write a newline, I don't like it.

  log.errorf(
    "%s failed with code 0x%X (%d in decimal)" +
    "\n\t%s",
    caller_expr,
    err_code,
    err_code,
    x,
  )
}

// Applies to WM_KEYDOWN and WM_KEYUP
//
// Because of the autorepeat feature, more than one WM_KEYDOWN 
// message may be posted before a WM_KEYUP message is posted.
// https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-keydown
Key_LPARAM:: bit_field windows.LPARAM {
	repeat_count:    u16  | 16,
	oem_scan_code:   u8   | 8,
	extended_key:    bool | 1,
	_: u8                 | 4,
	context_code:    u8   | 1,
	was_down:        bool | 1,
	trasition_state: bool | 1,
}

/*
Q: Why W and L param?
A: W for WORD, L for LONG.
   16 (DOS) and 32|64 bit slots for generic data.
   In the name of compatibility.
*/
