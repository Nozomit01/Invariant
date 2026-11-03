extends SceneTree
## Existing dialogue choices must work with desktop mouse and touch emulation.

var failures := 0
var selections: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures += 1


func _frames(count: int = 2) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse(position: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _open(roof: Node) -> void:
	roof.get_node("PLACEHOLDER_NON_CANON").position.x = 236.0
	await _frames()
	_key(KEY_E, true)
	await _frames()
	_key(KEY_E, false)
	await _frames()


func _run() -> void:
	var roof = load("res://scenes/rooftop.tscn").instantiate()
	root.add_child(roof)
	current_scene = roof
	await _frames()
	var dialogue = roof.get_node("UI/Dialogue")
	dialogue.choice_selected.connect(func(index: int): selections.append(index))
	_mouse(Vector2(160, 74), true)
	_mouse(Vector2(160, 74), false)
	await _frames()
	_check(selections.is_empty(), "hidden dialogue ignores mouse")
	for index in range(3):
		await _open(roof)
		var target: Vector2 = dialogue.choices[index].global_position
		var before := selections.size()
		_mouse(target, true, MOUSE_BUTTON_RIGHT)
		_mouse(target, false, MOUSE_BUTTON_RIGHT)
		_mouse(Vector2(4, 4), true)
		_mouse(Vector2(4, 4), false)
		_mouse(target, false)
		await _frames()
		_check(selections.size() == before and dialogue.awaiting_choice, "right click, outside click and release alone do not select " + str(index))
		var state_before: Dictionary = roof.run_state.snapshot()
		_mouse(target, true)
		await _frames()
		_mouse(target, false)
		await _frames()
		_check(selections.size() == before + 1 and selections.back() == index, "left mouse selects existing choice exactly once " + str(index))
		_check(not dialogue.awaiting_choice and not dialogue.choices[index].visible, "mouse selection shows reaction and hides choices " + str(index))
		_check(roof.run_state.snapshot() == state_before if index == 2 else roof.run_state.snapshot() != state_before, "mouse preserves existing state and silence semantics " + str(index))
		_mouse(target, true)
		_mouse(target, false)
		await _frames()
		_check(selections.size() == before + 1, "repeat click on hidden choices cannot select again " + str(index))
	# Actual Input pipeline may deliver both touch and emulated mouse.
	await _open(roof)
	var before := selections.size()
	_touch(dialogue.choices[0].global_position, true)
	await _frames()
	_touch(dialogue.choices[0].global_position, false)
	await _frames()
	_check(selections.size() == before + 1 and selections.back() == 0, "touch plus emulated mouse produces one selection")
	await _open(roof)
	before = selections.size()
	_key(KEY_2, true)
	await _frames()
	_key(KEY_2, false)
	await _frames()
	_check(selections.size() == before + 1 and selections.back() == 1, "keyboard choice still works")
	root.size = Vector2i(2400, 1080)
	await _frames()
	await _open(roof)
	before = selections.size()
	var screen_target: Vector2 = root.get_screen_transform() * dialogue.choices[2].global_position
	_mouse(screen_target, true)
	_mouse(screen_target, false)
	await _frames()
	_check(selections.size() == before + 1 and selections.back() == 2, "mouse hit area follows viewport scaling on a wide window")
	root.size = Vector2i(320, 240)
	await _frames()
	await _open(roof)
	var initial_x: float = roof.get_node("PLACEHOLDER_NON_CANON").position.x
	_key(KEY_D, true)
	_mouse(dialogue.choices[2].global_position, true)
	_mouse(dialogue.choices[2].global_position, false)
	await _frames(8)
	_key(KEY_D, false)
	_check(roof.get_node("PLACEHOLDER_NON_CANON").position.x > initial_x, "mouse choice does not block held movement")
	print("G3 mouse failures: ", failures)
	quit(0 if failures == 0 else 1)
