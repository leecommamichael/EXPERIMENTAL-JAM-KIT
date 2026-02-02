package audio

System :: struct {
	// xaudio: ^xa2.IXAudio2,
	// mastering_voice: ^xa2.IXAudio2MasteringVoice,
}

init :: proc () -> (sys: System, ok: bool) {
	return {}, true
}

load_from_bytes :: proc (bytes: []u8) -> (clip: Clip, ok: bool) {
	return {}, true
}

play :: proc (sys: System, it: Clip) {
}