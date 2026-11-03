extends RefCounted
## Shared transition input cleanup and focus tracking; no autoload.

class FocusNotifications extends Node:
	var receive: Callable

	func _notification(what: int) -> void:
		if receive.is_valid():
			receive.call(what)

static var _application_has_focus := true
static var _window_has_focus := true


static func observe_window(window: Window) -> void:
	# The root Window survives scene replacement, including the gap between scenes.
	if not window.focus_exited.is_connected(_on_window_focus_exited):
		window.focus_exited.connect(_on_window_focus_exited)
		window.focus_entered.connect(_on_window_focus_entered)
		# Window signals alone do not relay application focus while scenes are absent.
		var notifications := FocusNotifications.new()
		notifications.name = "TechnicalTransitionFocus"
		notifications.receive = track_focus
		window.add_child.call_deferred(notifications, false, Node.INTERNAL_MODE_BACK)
		if DisplayServer.get_name() != "headless":
			_window_has_focus = DisplayServer.window_is_focused(window.get_window_id())


static func track_focus(what: int) -> void:
	match what:
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT:
			_application_has_focus = false
		Node.NOTIFICATION_APPLICATION_FOCUS_IN:
			_application_has_focus = true
		Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_window_has_focus = false
		Node.NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_window_has_focus = true


static func has_focus() -> bool:
	return _application_has_focus and _window_has_focus


static func _on_window_focus_exited() -> void:
	_window_has_focus = false


static func _on_window_focus_entered() -> void:
	_window_has_focus = true


static func release_pressed_input() -> void:
	Input.flush_buffered_events()
	for action in InputMap.get_actions():
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey:
				var released := binding.duplicate() as InputEventKey
				released.pressed = false
				released.echo = false
				Input.parse_input_event(released)
		Input.action_release(action)
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(button):
			var released := InputEventMouseButton.new()
			released.button_index = button
			Input.parse_input_event(released)
	Input.flush_buffered_events()


static func go_to(owner: CanvasItem, path: String) -> Error:
	# Hiding first releases TouchScreenButton finger ownership as well as actions.
	owner.hide()
	release_pressed_input()
	var error := owner.get_tree().change_scene_to_file(path)
	if error != OK:
		owner.show()
		push_error("G5 technical scene replacement failed: " + error_string(error))
	return error
