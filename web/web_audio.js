// https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API

// Duplicates potentially large buffers. Slow.
function planar_f32_from_interleaved_i16(odin, data_ptr, num_channels, num_samples) {
  const total_elements = num_samples * num_channels
  const i16_view = new Int16Array(odin.memory.buffer, data_ptr, total_elements)
  const planar_data = [] // Untracked allocation.
  
  for (let c = 0; c < num_channels; c++) {
    planar_data.push(new Float32Array(num_samples))
  }

  for (let i = 0; i < num_samples; i++) {
    for (let c = 0; c < num_channels; c++) {
      const interleaved_index = (i * num_channels) + c
      const sample_16 = i16_view[interleaved_index]
      planar_data[c][i] = sample_16 / 32768.0
    }
  }

  return planar_data
}

const web_audio_create_module = (odin) =>  {
	// Reserve the 0th index for an invalid value.
	const audio_buffers = [null, ]
	const src_nodes     = [null, ]
	const sink_nodes    = [null, ]
	const ctx = new AudioContext()
	const master_gain = ctx.createGain()
	master_gain.connect(ctx.destination)
	let audio_System = null

	return {

		web_audio_platform_init: (sys_ptr) => {
			audio_System = sys_ptr
		},

		web_audio_platform_init_source: (src_handle, buffer_handle) => {
			if (audio_System == null) {
				console.log(`[web_audio.js] ERROR. missing System pointer.`);
				return
			}

			const buffer = audio_buffers[buffer_handle]
			if (!buffer) {
				console.log(`[web_audio.js] ERROR. no buffer.`);
				return 
			}

			if (!src_handle) {
				console.log(`[web_audio.js] ERROR. nil Source_Handle.`);
				return 
			}
			
			let src_obj = src_nodes[src_handle]
			if (src_obj == null) {
				src_nodes[src_handle] = {}
				src_obj = src_nodes[src_handle]
			}

			const src_node = ctx.createBufferSource()
			src_node.buffer = buffer
			const gain_node = ctx.createGain()
			src_node.connect(gain_node)
			gain_node.connect(master_gain)

			src_obj = {
				node:      src_node,
				gain_node: gain_node,
				gain:      gain_node.gain,
				out_node:  master_gain
			}

			src_obj.node.onended = () => {
				const spent_node = src_obj.node
				src_obj.node = ctx.createBufferSource()
				src_obj.node.buffer = buffer
				src_obj.node.onended = spent_node.onended // reuse this event handler
				src_obj.node.connect(src_obj.out_node)
				spent_node = null
				odin.exports.web_audio_source_buffer_on_ended(audio_System, src_handle)
			}
		},

		web_audio_make_sink: () => {
			const handle = sink_nodes.length
			const sink_node = ctx.createGain()
			sink_node.connect(master_gain)
			sink_nodes.push(sink_node)
			return handle
		},

		web_audio_set_sink: (src_obj, new_out) => {
			try {
				if (!src_handle) {
					console.log(`[web_audio.js] ERROR. nil Source_Handle.`);
					return 
				}
				const src_obj = src_nodes[src_handle]
				try { src_obj.gain_node.disconnect(src_obj.out_node) } catch (e) {}
				src_obj.gain_node.connect(new_out)
				src_obj.out_node = new_out
			} catch (e) {
				console.log(`[web_audio.js] ERROR failed to set BufSrcNode output. ${e}`, e)
			}
		},

		web_audio_make_buffer: ( // -> Buffer_Handle
			data,         //: ^u8,
			data_len,     //: int
			num_channels, //: int,
			num_samples,  //:  int,
			sample_rate,  //: int)
		) => {
			const pcm_channels = planar_f32_from_interleaved_i16(odin, data, num_channels, num_samples)
			const audio_buffer = ctx.createBuffer(num_channels, num_samples, sample_rate)
			for (let c = 0; c < num_channels; c++) {
			  audio_buffer.getChannelData(c).set(pcm_channels[c]);
			}
			const len = audio_buffers.length
			audio_buffers.push(audio_buffer)
			return len
		},

		web_audio_start_source: (sys, src_handle) => {
			if (!src_handle) {
				console.log(`[web_audio.js] ERROR. nil Source_Handle.`);
				return 
			}
			const src_obj = src_nodes[src_handle]
			src_obj.node.start()
		}

	} // return {}
}