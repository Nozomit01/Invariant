extends RefCounted
## Shared cleanup for the two G5 scene replacements; no persistent manager.


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


static func go_to(owner: CanvasItem, path: String) -> void:
	# Hiding first releases TouchScreenButton finger ownership as well as actions.
	owner.hide()
	release_pressed_input()
	var error := owner.get_tree().change_scene_to_file(path)
	if error != OK:
		owner.show()
		push_error("G5 technical scene replacement failed: " + error_string(error))
