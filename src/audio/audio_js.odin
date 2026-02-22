package audio

foreign import "web_audio"

////////////////////////////////////////////////////////////////////////////////
// WebAudio binding.
////////////////////////////////////////////////////////////////////////////////

@(default_calling_convention="contextless")
foreign web_audio {
	web_audio_platform_init :: proc (sys: System)  ---

	web_audio_platform_init_source :: proc (src: Source_Handle, buf: Buffer_Handle) ---

	web_audio_make_sink :: proc () -> Sink_Handle ---

	web_audio_set_sink :: proc(src: Source_Handle, sink: Sink_Handle) ---

	web_audio_make_buffer :: proc (
		data: [^]u8,
		data_len: int,
		num_channels: int,
		num_samples:  int,
		sample_rate: int) -> Buffer_Handle ---

	web_audio_start_source :: proc(src: Source_Handle, sink: Sink_Handle) ---
}

@export
web_audio_source_buffer_on_ended :: proc (system: System, _src: Source_Handle) {
	system.sources[_src].busy = false
}

Sink_Handle   :: distinct int
Buffer_Handle :: distinct int

////////////////////////////////////////////////////////////////////////////////
// Platform implementation.
////////////////////////////////////////////////////////////////////////////////

Platform_System :: struct {
	buffers: map[string]Buffer_Handle
}

Platform_Source :: struct {

}

Platform_Sink :: struct {
	impl: Sink_Handle
}

platform_init :: proc (sys: ^System) -> (ok: bool) {
	web_audio_platform_init(sys^) // wasm passes structs as pointers.
	return true
}

platform_init_source :: proc (sys: ^System, it: ^Source) {
	buffer, found := sys.buffers[it.clip.name]
	if !found {
		buffer = web_audio_make_buffer(
			raw_data(it.clip.bytes),
			len(it.clip.bytes),
			it.clip.channels,
			it.clip.samples,
			it.clip.sample_rate)
		 sys.buffers[it.clip.name] = buffer
	}
	web_audio_platform_init_source(it.id, buffer)
}

platform_init_sink :: proc (sys: ^System, sink: ^Sink) {
}

platform_destroy_source :: proc (sys: ^System, handle: Source_Handle) {
}

platform_sink_set_volume :: proc (sink: Sink, volume: f32) {
	// 1. set volume on gain
}

platform_play :: proc (sys: System, sink: Sink, src: ^Source, volume: f32) {
	web_audio_start_source(src.id, sink.impl)
	// 1. ensure src is hooked to sink
	// 2. set voume on src's gain
}

// BufferSourceNodes are one-off.
// So busy flag of `false` actually means it's either spent or ready.
// on ended, just re-create the node in-place.
