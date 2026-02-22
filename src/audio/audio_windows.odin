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
	using voice: ^xa2.IXAudio2SourceVoice,
	buffer: xa2.BUFFER,
}

Platform_Sink :: struct {
	using voice: ^xa2.IXAudio2SubmixVoice,
}

platform_init :: proc (sys: ^System) -> (ok: bool) {
	// assert CoInitializeEx called already.
	// false means it's already initialized.
	// RPC_E_CHANGED_MODE is the only documented error, but it's not defined in Odin.
	result := windows.CoInitializeEx()
assert(result == windows.S_OK || result == windows.S_FALSE)
	result, ok = win.ok(xa2.Create(&sys.xaudio))
when ODIN_DEBUG {
	cfg: xa2.DEBUG_CONFIGURATION
	cfg.TraceMask = {.WARNINGS}
	sys.xaudio->SetDebugConfiguration(&cfg)
}
	// This result is logged, it's just unclear whether Create will cause an error.
assert(ok)
	result, ok = win.ok(sys.xaudio->CreateMasteringVoice(&sys.mastering_voice))
assert(ok)
	return
}

// ASSUMES PCM DATA
platform_init_source :: proc (sys: ^System, it: ^Source) {
	wave_format: xa2.WAVEFORMATEX
	wave_format.wFormatTag = windows.WAVE_FORMAT_PCM
	wave_format.nChannels  = cast(u16) it.channels
	wave_format.wBitsPerSample = 16 // bits per sample (stbv.decode_memory only outputs 16)
	wave_format.nSamplesPerSec = cast(c.uint) it.sample_rate

	// The following two are documented formulae
	wave_format.nBlockAlign = wave_format.nChannels * wave_format.wBitsPerSample / 8
	wave_format.nAvgBytesPerSec = wave_format.nSamplesPerSec * u32(wave_format.nBlockAlign)

	buffer: ^xa2.BUFFER = &it.platform.buffer
	buffer.AudioBytes = cast(u32) len(it.bytes)
	buffer.pAudioData = raw_data(it.bytes)
	buffer.pContext = it

	buffer.Flags = { .END_OF_STREAM }
	result := sys.xaudio->CreateSourceVoice(&it.voice, &wave_format, pCallback = &default_source_voice_callback)
  switch result {
	case xa2.INVALID_CALL        : assert(false)
	case xa2.XMA_DECODER_ERROR   : assert(false)
	case xa2.XAPO_CREATION_FAILED: assert(false)
	case xa2.DEVICE_INVALIDATED  : assert(false)
  }
}

default_source_voice_callback: xa2.IXAudio2VoiceCallback = { &_default_source_voice_callback }
_default_source_voice_callback: xa2.IXAudio2VoiceCallback_VTable = {
	// Called just before this voice's processing pass begins.
	OnVoiceProcessingPassStart = proc "system" (this: ^xa2.IXAudio2VoiceCallback, BytesRequired: u32) {

	},

	// Called just after this voice's processing pass ends.
	OnVoiceProcessingPassEnd = proc "system" (this: ^xa2.IXAudio2VoiceCallback) {

	},

	// Called when this voice has just finished playing a buffer stream (as marked with the END_OF_STREAM flag on the last buffer).
	OnStreamEnd = proc "system" (this: ^xa2.IXAudio2VoiceCallback) {

	},

	// Called when this voice is about to start processing a new buffer.
	OnBufferStart = proc "system" (this: ^xa2.IXAudio2VoiceCallback, pBufferContext: rawptr) {
	},

	// Called when this voice has just finished processing a buffer.
	// The buffer can now be reused or destroyed.
	OnBufferEnd = proc "system" (this: ^xa2.IXAudio2VoiceCallback, pBufferContext: rawptr) {
		// ASSUMES 1 Buffer to 1 Voice
		src := cast(^Source) pBufferContext
		src.busy = false
		result := src.platform.voice->Stop()
		assert_contextless(result == {})
	},

	// Called when this voice has just reached the end position of a loop.
	OnLoopEnd = proc "system" (this: ^xa2.IXAudio2VoiceCallback, pBufferContext: rawptr) {

	},

	// Called in the event of a critical error during voice processing, such as a failing xAPO or an error from the hardware XMA decoder.
	// The voice may have to be destroyed and re-created to recover from the error.
	// The callback arguments report which buffer was being processed when the error occurred, and its HRESULT code.
	OnVoiceError = proc "system" (this: ^xa2.IXAudio2VoiceCallback, pBufferContext: rawptr, Error: xa2.HRESULT) {

	}
}

platform_init_sink :: proc (sys: ^System, sink: ^Sink) {
	result := sys.xaudio->CreateSubmixVoice(&sink.voice, 2, 44100)
assert(result == windows.S_OK)
	send_desc := xa2.SEND_DESCRIPTOR { {}, sys.mastering_voice }
	sends: xa2.VOICE_SENDS
	sends.SendCount = 1
	sends.pSends = &send_desc
	sink.voice->SetOutputVoices(&sends)
}

platform_destroy_source :: proc (sys: ^System, handle: Source_Handle) {
unimplemented("TODO: free the xa2buffer and source voice.")
}

platform_sink_set_volume :: proc (sink: Sink, volume: f32) {
	result := sink.voice->SetVolume(volume)
	assert(result == windows.S_OK)
}

platform_play :: proc (sys: System, sink: Sink, src: ^Source, volume: f32) {
	sink := sink
	// TODO: Skip SetOutputVoices: array & Sink_Handle to store them on the source to diff.
	send_desc := xa2.SEND_DESCRIPTOR { {}, sink.voice }
	sends: xa2.VOICE_SENDS
	sends.SendCount = 1
	sends.pSends = &send_desc
	src.voice->SetOutputVoices(&sends)
	src.voice->SetVolume(volume)
	src.busy = true
	result := src.voice->SubmitSourceBuffer(&src.platform.buffer)
  switch result {
	case xa2.INVALID_CALL        : assert(false)
	case xa2.XMA_DECODER_ERROR   : assert(false)
	case xa2.XAPO_CREATION_FAILED: assert(false)
	case xa2.DEVICE_INVALIDATED  : assert(false)
  }
	result = src.platform.voice->Start()
  switch result {
	case xa2.INVALID_CALL        : assert(false)
	case xa2.XMA_DECODER_ERROR   : assert(false)
	case xa2.XAPO_CREATION_FAILED: assert(false)
	case xa2.DEVICE_INVALIDATED  : assert(false)
  }
}