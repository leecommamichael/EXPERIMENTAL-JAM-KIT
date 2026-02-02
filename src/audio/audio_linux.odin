package audio

System :: struct {}
init :: proc () -> (sys: System, ok: bool) { return {}, true }
load_from_bytes :: proc (bytes: []u8) -> (clip: Clip, ok: bool) { return {}, true}
