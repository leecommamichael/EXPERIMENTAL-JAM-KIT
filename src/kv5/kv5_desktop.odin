#+build !js
package kv5

import "core:encoding/json"
import "core:os/os2"
import "core:log"

//////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////

STORAGE_LIMIT :: 5_000_000 // 5MB
_BACKING_FILE :: "kv5.json"
_backing_map: map[string]string
_flush_to_disk :: proc () {
	file, err := os2.open(_BACKING_FILE, {.Read, .Trunc, .Create})
	if err != nil {
		log.errorf("KV5 failed to write to disk. Data will be lost. %v", err)
		return
	}
	defer os2.close(file)
	writer := os2.to_writer(file)
	opt: json.Marshal_Options
	marshal_err := json.marshal_to_writer(writer, _backing_map, &opt)
	if marshal_err != nil {
		log.errorf("KV5 failed to write to disk. Data will be lost. %v", err)
		return
	}
}

//////////////////////////////////////////////////////////////////////
// Interface
//////////////////////////////////////////////////////////////////////

store :: proc (key: string, value: string) -> (success: bool) {
	_backing_map[key] = value
	_flush_to_disk()
	return true
}

// The allocator proc is for JS.
load :: proc (key: string, allocator := context.allocator) -> (data: string, found: bool) {
	data, found = _backing_map[key]
	return
}

delete :: proc (key: string) {
	delete_key(&_backing_map, key)
	_flush_to_disk()
}

measure :: proc (key: string) -> (length: int) {
	return len(_backing_map[key])
}
