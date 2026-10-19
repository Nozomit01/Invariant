extends SceneTree
## Real scene/input checks; no external test framework.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		print("FAIL: ", description)


func _frames(count: int = 2) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_key(code: Key) -> void:
	_key(code, true)
	await _frames()
	_key(code, false)
	await _frames()


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)


func _run() -> void:
	var rooftop := (load("res://scenes/rooftop.tscn") as PackedScene).instantiate()
	root.add_child(rooftop)
	await _frames()
	if not rooftop.has_node("UI/Dialogue"):
		print("FAIL: G3 dialogue does not exist yet")
		rooftop.queue_free()
		await process_frame
		quit(1)
		return
	var dialogue := rooftop.get_node("UI/Dialogue") as Node2D
	var line := dialogue.get_node("Line") as Label
	var player := rooftop.get_node("PLACEHOLDER_NON_CANON") as Node2D
	_check(not dialogue.visible, "dialogue hidden at spawn")
	await _tap_key(KEY_E)
	await _tap_key(KEY_1)
	_check(not dialogue.visible and line.text.is_empty(), "interaction and choices ignored outside range")
	player.position.x = 236.0
	await _frames()
	await _tap_key(KEY_E)
	var opening := line.text
	_check(dialogue.visible and dialogue.get("awaiting_choice"), "E opens the existing point's dialogue")
	await _frames(15)
	_check(line.text == opening and dialogue.get("awaiting_choice"), "waiting does not choose silence automatically")

	var reactions: Array[String] = []
	for index in range(3):
		await _tap_key(KEY_E)
		await _tap_key([KEY_1, KEY_2, KEY_3][index])
		reactions.append(line.text)
		_check(not dialogue.get("awaiting_choice") and line.text != opening, "number key selects response " + str(index + 1))
		_check(line.text.begins_with("PLACEHOLDER_NON_CANON\n"), "reaction marked non-canon " + str(index + 1))
		await _tap_key(KEY_1)
		_check(line.text == reactions[index], "completed response is not overwritten by another choice")
	_check(reactions[0] != reactions[1] and reactions[0] != reactions[2] and reactions[1] != reactions[2], "two answers and silence have distinct reactions")
	_check(reactions[2].contains("молчание"), "third choice explicitly records silence")

	await _tap_key(KEY_E)
	var start_x := player.position.x
	_key(KEY_A, true)
	await _frames(5)
	_key(KEY_A, false)
	await _frames(10)
	_check(player.position.x < start_x and dialogue.visible, "keyboard movement continues during dialogue")
	_key(KEY_D, true)
	_key(KEY_2, true)
	await _frames(5)
	_key(KEY_2, false)
	_key(KEY_D, false)
	await _frames(10)
	_check(line.text == reactions[1], "movement and keyboard reply work together")
	_key(KEY_A, true)
	await _frames(60)
	_key(KEY_A, false)
	await _frames(15)
	_check(not dialogue.visible and line.text.is_empty(), "physically walking away cancels and clears dialogue")
	await _tap_key(KEY_3)
	_check(not dialogue.visible and line.text.is_empty(), "silence cannot act on a cancelled conversation")
	player.position.x = 236.0
	await _frames()
	_check(not dialogue.visible, "returning alone does not reopen the dialogue")
	await _tap_key(KEY_E)
	_check(line.text == opening and dialogue.get("awaiting_choice"), "interacting after return restarts from the beginning")

	root.size = Vector2i(2400, 1080)
	await _frames()
	for index in range(3):
		player.position.x = 236.0
		await _tap_key(KEY_E)
		var button := dialogue.get_node("Choice" + str(index + 1)) as TouchScreenButton
		var shape := button.shape as RectangleShape2D
		var bounds := Rect2(button.global_position - shape.size * 0.5, shape.size)
		_check(Rect2(0, 26, 320, 138).encloses(bounds), "response button stays above G2 controls " + str(index + 1))
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(root.get_screen_transform() * bounds), "response visible on wide screen " + str(index + 1))
		var label := button.get_node("Label") as Label
		_check(label.text.begins_with("PLACEHOLDER_NON_CANON\n"), "choice marked non-canon " + str(index + 1))
		_touch(0, Vector2(98, 210), true)
		_touch(1, button.global_position, true)
		await _frames(4)
		_check(line.text == reactions[index] and player.position.x > 236.0, "finger reply while holding movement " + str(index + 1))
		_touch(1, button.global_position, false)
		_check(Input.is_action_pressed("move_right"), "reply does not release held movement " + str(index + 1))
		_touch(0, Vector2(98, 210), false)
		await _frames(15)
		_check(not Input.is_action_pressed("dialogue_choice_" + str(index + 1)), "reply touch is not stuck after panel change")
	_check(opening.begins_with("PLACEHOLDER_NON_CANON\n"), "opening is explicitly non-canon")
	print("G3 smoke failures: ", failures)
	rooftop.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
