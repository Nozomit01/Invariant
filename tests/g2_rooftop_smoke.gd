extends SceneTree
## Run with Godot 4.7.2 --headless --path . --script tests/g2_rooftop_smoke.gd.

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


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)


func _run() -> void:
	if not ResourceLoader.exists("res://scenes/rooftop.tscn"):
		print("FAIL: G2 rooftop scene does not exist yet")
		quit(1)
		return
	var packed := load("res://scenes/rooftop.tscn") as PackedScene
	var rooftop := packed.instantiate()
	root.add_child(rooftop)
	var player := rooftop.get_node("PLACEHOLDER_NON_CANON") as Node2D
	var prompt := rooftop.get_node("UI/Prompt") as Label
	var message := rooftop.get_node("UI/Message") as Label
	await _frames()
	_check(not prompt.visible and message.text.is_empty(), "no prompt or interaction at spawn")
	_key(KEY_E, true)
	await _frames()
	_key(KEY_E, false)
	_check(message.text.is_empty(), "E does nothing away from the point")

	var start_x := player.position.x
	_key(KEY_D, true)
	await _frames(8)
	var first_distance := player.position.x - start_x
	await _frames(8)
	_check(player.position.x - start_x > first_distance * 2.0, "D accelerates smoothly to the right")
	_key(KEY_D, false)
	await _frames(16)
	var stopped_x := player.position.x
	await _frames(8)
	_check(is_equal_approx(player.position.x, stopped_x), "release brakes to a full stop")
	for code in [KEY_A, KEY_LEFT, KEY_RIGHT]:
		start_x = player.position.x
		_key(code, true)
		await _frames(12)
		_key(code, false)
		await _frames(16)
		var expected_direction := 1.0 if code == KEY_RIGHT else -1.0
		_check((player.position.x - start_x) * expected_direction > 0, "keyboard binding " + str(code))

	player.position.x = 296.0
	_key(KEY_D, true)
	await _frames(30)
	_check(player.position.x <= 298.0, "right boundary holds under sustained input")
	_key(KEY_D, false)
	await _frames()
	player.position.x = 24.0
	_key(KEY_A, true)
	await _frames(30)
	_check(player.position.x >= 22.0, "left boundary holds under sustained input")
	_key(KEY_A, false)
	await _frames(16)
	player.position.x = 236.0
	await _frames()
	_check(prompt.visible, "prompt appears near the interaction point")
	_key(KEY_E, true)
	await _frames()
	_key(KEY_E, false)
	_check(message.text == "Взаимодействие работает", "E shows only the technical message")
	player.position.x = 100.0
	await _frames()
	_check(not prompt.visible and message.text.is_empty(), "leaving the point clears prompt and message")

	root.size = Vector2i(2400, 1080)
	await _frames()
	var transform := root.get_screen_transform()
	print("Wide screen: ", root.size, "; viewport: ", root.get_visible_rect().size, "; transform: ", transform)
	_check(root.get_visible_rect().size == Vector2(320, 240), "wide screen retains 320x240 logical viewport")
	for name in ["Left", "Right", "Interact"]:
		var button := rooftop.get_node("UI/" + name) as TouchScreenButton
		var bounds := Rect2(button.position - Vector2(26, 20), Vector2(52, 40))
		_check(Rect2(0, 184, 320, 56).encloses(bounds), name + " fits below the roof in the 4:3 viewport")
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(transform * bounds), name + " stays visible on 2400x1080")

	player.position.x = 236.0
	await _frames()
	_touch(0, Vector2(98, 210), true)
	_touch(1, Vector2(274, 210), true)
	await _frames(4)
	_check(player.position.x > 236.0 and message.text == "Взаимодействие работает", "two fingers move and interact together")
	_touch(1, Vector2(274, 210), false)
	await _frames()
	_check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("interact"), "releasing interaction keeps movement held")
	_touch(2, Vector2(38, 210), true)
	await _frames(16)
	stopped_x = player.position.x
	await _frames(8)
	_check(is_equal_approx(player.position.x, stopped_x), "opposite fingers cancel movement")
	_touch(0, Vector2(98, 210), false)
	await _frames(8)
	_check(player.position.x < stopped_x, "releasing right keeps left held independently")
	_touch(2, Vector2(38, 210), false)
	await _frames(16)
	_check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "all touch releases clear movement")
	print("G2 smoke failures: ", failures)
	rooftop.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
