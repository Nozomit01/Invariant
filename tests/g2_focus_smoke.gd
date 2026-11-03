extends SceneTree
## Lost OS releases must not leave rooftop controls captured after focus returns.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + description)
	if not ok:
		failures += 1


func _frames(count: int = 3) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _run() -> void:
	for window_focus in [false, true]:
		var roof = load("res://scenes/rooftop.tscn").instantiate()
		root.add_child(roof)
		current_scene = roof
		await _frames()
		var right := roof.get_node("UI/Right") as TouchScreenButton
		var interact := roof.get_node("UI/Interact") as TouchScreenButton
		var dialogue = roof.get_node("UI/Dialogue")
		roof.player.position.x = 236.0
		_touch(0, right.position, true)
		_touch(1, interact.position, true)
		await _frames(3)
		_check(right.is_pressed() and interact.is_pressed() and dialogue.awaiting_choice, "two fingers move and open dialogue before focus loss " + str(window_focus))
		# Some OS paths clear Input actions themselves; button ownership must also reset.
		if window_focus:
			Input.action_release("move_right")
			Input.action_release("interact")
		var state_before: Dictionary = roof.run_state.snapshot()
		var page_before: int = roof.demo_page
		root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT if window_focus else Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _frames()
		_check(not right.is_pressed() and not interact.is_pressed(), "focus loss releases captured fingers " + str(window_focus))
		_check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("interact"), "focus loss clears movement and interaction " + str(window_focus))
		await _frames(16)
		var stopped_x: float = roof.player.position.x
		await _frames(8)
		_check(is_equal_approx(stopped_x, roof.player.position.x) and stopped_x < 270.0, "lost release brakes movement without reaching boundary " + str(window_focus))
		root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN if window_focus else Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_check(roof.run_state.snapshot() == state_before and roof.demo_page == page_before, "focus change does not choose a reply or change state " + str(window_focus))
		_check(dialogue.awaiting_choice and dialogue.choices[0].visible, "pending dialogue stays available after focus change " + str(window_focus))
		# New finger IDs: a control still owned by the old finger would ignore these.
		roof.player.position.x = 150.0
		await _frames(16)
		_touch(7, right.position, true)
		await _frames(5)
		_check(right.is_pressed() and Input.is_action_pressed("move_right") and roof.player.position.x > 150.0, "fresh finger can move after focus returns " + str(window_focus))
		_touch(7, right.position, false)
		await _frames(16)
		_check(not right.is_pressed() and not Input.is_action_pressed("move_right"), "fresh finger release stops movement " + str(window_focus))
		_touch(0, right.position, false)
		_touch(1, interact.position, false)
		roof.player.position.x = 236.0
		await _frames()
		_touch(8, interact.position, true)
		await _frames()
		_touch(8, interact.position, false)
		await _frames()
		_check(dialogue.awaiting_choice, "interaction still opens dialogue after focus returns " + str(window_focus))
		_key(KEY_1, true)
		await _frames()
		_key(KEY_1, false)
		await _frames()
		_check(not dialogue.awaiting_choice and not dialogue.choices[0].visible, "fresh keyboard choice still works " + str(window_focus))
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		await _frames()
		_check(not dialogue.choices[0].visible, "repeated focus notifications preserve hidden choices " + str(window_focus))
		_key(KEY_A, true)
		await _frames(3)
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _frames(16)
		_check(not Input.is_action_pressed("move_left") and not Input.is_physical_key_pressed(KEY_A), "focus loss releases held keyboard input " + str(window_focus))
		_key(KEY_A, false)
		roof.queue_free()
		await _frames()
	print("G2 focus failures: ", failures)
	quit(0 if failures == 0 else 1)
