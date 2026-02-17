package audio

import "core:c"
import "core:log"
import "core:slice"
import "core:sys/windows"
import xa2 "vendor:windows/XAudio2"
import win "../windows"

Platform_System :: struct {
	xaudio: ^xa2.IXAudio2,
	mastering_voice: ^xa2.IXAudio2MasteringVoice,
}

Platform_Source :: struct {
	using source_voice: ^xa2.IXAudio2SourceVoice
}

Platform_Sink :: struct {
	using _: ^xa2.IXAudio2SubmixVoice
}

platform_init :: proc (sys: ^System) -> (ok: bool) {
	// assert CoInitializeEx called already.
	// false means it's already initialized.
	// RPC_E_CHANGED_MODE is the only documented error, but it's not defined in Odin.
	result := windows.CoInitializeEx()
assert(result == windows.S_OK || result == windows.S_FALSE)
	result, ok = win.ok(xa2.Create(&sys.xaudio))
	// This result is logged, it's just unclear whether Create will cause an error.
assert(ok)
	result, ok = win.ok(sys.xaudio->CreateMasteringVoice(&sys.mastering_voice))
assert(ok)
	return
}

init_platform_source :: proc (sys: System, it: ^Source) {
	wave_format: xa2.WAVEFORMATEX
	wave_format.wFormatTag = windows.WAVE_FORMAT_PCM
	wave_format.nChannels  = cast(u16) it.channels
	wave_format.wBitsPerSample = 16 // bits per sample
	wave_format.nSamplesPerSec = cast(c.uint) it.sample_rate
	wave_format.nBlockAlign = wave_format.nChannels * wave_format.wBitsPerSample / 8 // block align 2 channels sending 16bits (kind of a stride)
	wave_format.nAvgBytesPerSec = wave_format.nSamplesPerSec * u32(wave_format.nBlockAlign) //avgbytes/sec

	buffer: xa2.BUFFER
	buffer.AudioBytes = cast(u32) it.samples * (2 * 16 / 8)
	buffer.pAudioData = raw_data(it.bytes)
	buffer.Flags = { .END_OF_STREAM }
	result := sys.xaudio->CreateSourceVoice(&it.source_voice, &wave_format)
  switch result {
	case xa2.INVALID_CALL        : assert(false)
	case xa2.XMA_DECODER_ERROR   : assert(false)
	case xa2.XAPO_CREATION_FAILED: assert(false)
	case xa2.DEVICE_INVALIDATED  : assert(false)
  }
  ok: bool
	result, ok = win.ok(it.source_voice->SubmitSourceBuffer(&buffer))
assert(ok)
}

init_platform_sink :: proc () {
	unimplemented("TODO: submix voice")
}

platform_destroy_source :: proc (sys: ^System, handle: Source_Handle) {
unimplemented("TODO: free the xa2buffer and source voice.")
}

platform_play :: proc (sys: System, sink: Sink, clip: Source) {
	// TODO: check the ring for one that isn't playing. use it.
	//       if all are busy, make one (under a limit)
	//       NOTE: If lots of sounds are doing this you'll make lots of xa2.BUFFERs.
	result, ok := win.ok(clip.platform.source_voice->Start())
assert(ok)
}