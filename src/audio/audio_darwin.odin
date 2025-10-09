package audio

import "core:c"
import "core:log"
import "core:slice"
import "core:sys/windows"
import stbv "vendor:stb/vorbis"

System :: struct {
	// xaudio: ^xa2.IXAudio2,
	// mastering_voice: ^xa2.IXAudio2MasteringVoice,
}

init :: proc () -> (sys: System, ok: bool) {
	return {}, true
}

// A clip. A collection of samples.
Clip :: struct {
	bytes: []u8 `cbor:"-" fmt:"-"`,
	samples: int,
	seconds: f64,
	channels: int,
	sample_rate: int,
}

load_from_bytes :: proc (bytes: []u8) -> (clip: Clip, ok: bool) {
	return {}, true
}

play :: proc (sys: System, it: Clip) {
}