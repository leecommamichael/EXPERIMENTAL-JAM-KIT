package sugar

import "core:time"
import "core:log"
import "core:sys/windows"
import win "../windows"
import wgi "vendor:windows/GameInput"

init_native_input :: proc () {
	result, ok := win.ok(wgi.Create(&game_input))
  assert(ok)
}

//////////////////////////////////////////////////////////////////////
// Gamepad
//////////////////////////////////////////////////////////////////////
game_input:     ^wgi.IGameInput
gamepad_device: ^wgi.IGameInputDevice

Gamepad_Button :: enum u32 {
	Start          = cast(u32) wgi.GamepadButtonsFlag.Menu,
	Select         = cast(u32) wgi.GamepadButtonsFlag.View,
	A              = cast(u32) wgi.GamepadButtonsFlag.A,
	B              = cast(u32) wgi.GamepadButtonsFlag.B,
	X              = cast(u32) wgi.GamepadButtonsFlag.X,
	Y              = cast(u32) wgi.GamepadButtonsFlag.Y,
	Up             = cast(u32) wgi.GamepadButtonsFlag.DPadUp,
	Down           = cast(u32) wgi.GamepadButtonsFlag.DPadDown,
	Left           = cast(u32) wgi.GamepadButtonsFlag.DPadLeft,
	Right          = cast(u32) wgi.GamepadButtonsFlag.DPadRight,
	Left_Shoulder  = cast(u32) wgi.GamepadButtonsFlag.LeftShoulder,
	Right_Shoulder = cast(u32) wgi.GamepadButtonsFlag.RightShoulder,
	Left_Stick     = cast(u32) wgi.GamepadButtonsFlag.LeftThumbstick,
	Right_Stick    = cast(u32) wgi.GamepadButtonsFlag.RightThumbstick,
}

//////////////////////////////////////////////////////////////////////
// Keyboard & Mouse
//////////////////////////////////////////////////////////////////////

// A virtual key code. Suitable for games if users have the same
// keyboard layout. e.g. QWERTY, AZERTY, etc
Key :: enum {
	Escape      = windows.VK_ESCAPE,
	Left_Mouse  = windows.VK_LBUTTON,
	Right_Mouse = windows.VK_RBUTTON,
	Left_Arrow  = windows.VK_LEFT,
	Right_Arrow = windows.VK_RIGHT,
	Up_Arrow    = windows.VK_UP,
	Down_Arrow  = windows.VK_DOWN,
	Space = windows.VK_SPACE,
	W   = windows.VK_W,
	A   = windows.VK_A,
	S   = windows.VK_S,
	D   = windows.VK_D,
	_   = 0xFF,
}

@private
on_key_down :: proc (message: windows.MSG) {
	if message.wParam < windows.VK_LBUTTON || message.wParam > windows.VK_OEM_CLEAR { return }
	virtual_keycode := cast(Key) message.wParam
	down := win.Key_LPARAM(message.lParam)
	// Don't process key repeats. Those are for text editing, not games.
	if down.was_down { return }

	set_pressed(virtual_keycode)
}

@private
on_key_up :: proc (message: windows.MSG) {
	if message.wParam < windows.VK_LBUTTON || message.wParam > windows.VK_OEM_CLEAR { return }
	virtual_keycode := cast(Key) message.wParam
	set_released(virtual_keycode)
}

@private
on_mousemove :: proc (message: windows.MSG) {
	size_y := cast(f32)(viewport_size.y)
	mouse_position.x = cast(f32) windows.GET_X_LPARAM(message.lParam)
	mouse_position.y = size_y - cast(f32) windows.GET_Y_LPARAM(message.lParam)
}

// returns Should_Exit when the application should stop executing.
@require_results
poll_events :: proc () -> (feedback: bit_set[Feedback]) {
	begin_input_frame()

	poll_game_input :: proc () {
		reading: ^wgi.IGameInputReading
		if win.is_ok(game_input->GetCurrentReading({.Gamepad}, gamepad_device, &reading)) {
			if gamepad_device == nil {
				// SCENARIO: First input in this run.
				reading->GetDevice(&gamepad_device)
			}
			state: wgi.GamepadState
			reading->GetGamepadState(&state)
			new_button_bits := transmute(bit_set[Gamepad_Button; u32]) transmute(u32) state.buttons
			for button in new_button_bits - input.gamepad.button_bits {
				set_pressed(cast(Gamepad_Button) button)
			}
			for button in input.gamepad.button_bits - new_button_bits {
				set_released(cast(Gamepad_Button) button)
			}
			input.gamepad.button_bits = new_button_bits
			input.gamepad.left_trigger = state.leftTrigger
			input.gamepad.right_trigger = state.rightTrigger
			input.gamepad.left_stick = {state.leftThumbstickX, state.leftThumbstickY}
			input.gamepad.right_stick = {state.rightThumbstickX, state.rightThumbstickY}
			reading->Release()
		} else if gamepad_device != nil {
			// Assume the error means the device was disconnected.
			// I could use callbacks to confirm.
			gamepad_device->Release()
			gamepad_device = nil
			return
		}
	}
	poll_game_input()

	get_raw_input :: proc () {
		byte_count: windows.UINT
		_, size_query_ok := win.zero(windows.GetRawInputBuffer(nil, &byte_count, size_of(windows.RAWINPUTHEADER)))
		if !size_query_ok {
			// No remarks in docs for when this happens.
		}
		N :: 32 // Messages per frame. 60fps * 32samples ~ 1800hz
		byte_count *= N
		messages: [N]windows.RAWINPUT
		messages_written, ok := win.not_negative_one(windows.GetRawInputBuffer(&messages[0], &byte_count, size_of(windows.RAWINPUTHEADER)))
		if !ok {
			// No remarks in docs for when this happens.
		}

		for i in 0..<messages_written {
			// WARN: The message array can be heterogeneous.
			//       Don't request more than mouse input as raw input.
			mouse := messages[i].data.mouse
			mouse_delta.x += f32(mouse.lLastX)
			mouse_delta.y += f32(mouse.lLastY)
		}
	}
	get_raw_input()

  message: windows.MSG
  for {
    has_more_messages := windows.PeekMessageW(
      lpMsg = &message,
      hWnd = {}, // thread-level, not window (to get WM_QUIT)
      wMsgFilterMin = 0,
      wMsgFilterMax = 0,
      wRemoveMsg = windows.PM_REMOVE
    )
    if message.message == windows.WM_QUIT {
    	feedback += {.Should_Exit}
    	return
    }
    switch (message.message) {
    case windows.WM_ENTERSIZEMOVE:
  	case windows.WM_KEYDOWN:   on_key_down(message)
  	case windows.WM_KEYUP:     on_key_up(message)
  	case windows.WM_MOUSEMOVE: on_mousemove(message)
  	case windows.WM_LBUTTONDOWN:
			set_pressed(Key.Left_Mouse)
  	case windows.WM_LBUTTONUP:
  		set_released(Key.Left_Mouse)
    }
    if g_window_resized {
    	g_window_resized = false // set by peek
    	feedback += {.Window_Resized}
    }
    if g_scale_factor_changed {
    	g_scale_factor_changed = false // set by peek
    	feedback += {.Window_Scale_Factor_Changed}
    }

    if !has_more_messages { break }
    windows.TranslateMessage(&message)
    windows.DispatchMessageW(&message)
  }
  
  return
}