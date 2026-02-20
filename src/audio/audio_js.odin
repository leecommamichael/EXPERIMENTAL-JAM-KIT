package audio

Platform_System :: struct {
}

Platform_Source :: struct {
}

Platform_Sink :: struct {
}

platform_init :: proc (sys: ^System) -> (ok: bool) {
	return true
}

// ASSUMES PCM DATA
platform_init_source :: proc (sys: System, it: ^Source) {
}

platform_init_sink :: proc (sys: ^System, sink: ^Sink) {
}

platform_destroy_source :: proc (sys: ^System, handle: Source_Handle) {
}

platform_sink_set_volume :: proc (sink: Sink, volume: f32) {
}

platform_play :: proc (sys: System, sink: Sink, src: ^Source, volume: f32) {
}