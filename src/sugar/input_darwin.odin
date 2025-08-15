package sugar

import NS "../../darwodin/darwodin-macos-lite/darwodin/AppKit"
import CG "../../darwodin/darwodin-macos-lite/darwodin/CoreGraphics"
import NSF "../../darwodin/darwodin-macos-lite/darwodin/Foundation"

Button :: enum {
	Escape      =0,
	Left_Mouse  =1,
	Right_Mouse =2,
	Left_Arrow  =3,
	Right_Arrow =4,
	Up_Arrow    =5,
	Down_Arrow  =6,
	Space_Bar   =7,
}

Feedback :: enum {
	None,
	Should_Exit,
	Resized, // the new resolution is already in global state.
}

@require_results
poll_events :: proc () -> (feedback: Feedback) {
	event: ^NS.Event
	event = NS.App->nextEventMatchingMask(
		mask = transmute(NS.EventMask) cast(u64) NS.AnyEventMask,
		expiration = nil,
		mode = NSF.DefaultRunLoopMode,
		deqFlag = true) // dequeue

	if event == nil {
		return .None
	}
	
	switch event->type() {
	case .LeftMouseDown      :
	case .LeftMouseUp        :
	case .RightMouseDown     :
	case .RightMouseUp       :
	case .MouseMoved         :
	case .LeftMouseDragged   :
	case .RightMouseDragged  :
	case .MouseEntered       :
	case .MouseExited        :
	case .KeyDown            :
	case .KeyUp              :
	case .FlagsChanged       :
	case .AppKitDefined      :
	case .SystemDefined      :
	case .ApplicationDefined :
	case .Periodic           :
	case .CursorUpdate       :
	case .Rotate             :
	case .BeginGesture       :
	case .EndGesture         :
	case .ScrollWheel        :
	case .TabletPoint        :
	case .TabletProximity    :
	case .OtherMouseDown     :
	case .OtherMouseUp       :
	case .OtherMouseDragged  :
	case .Gesture            :
	case .Magnify            :
	case .Swipe              :
	case .SmartMagnify       :
	case .QuickLook          :
	case .Pressure           :
	case .DirectTouch        :
	case .ChangeMode         :
	}

	NS.App->sendEvent(event)
	return .None
}