extends SceneTree
## Model and scene integration checks; snapshots are test diagnostics only.

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


func _tap_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames()
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await _frames()


func _run() -> void:
	if not ResourceLoader.exists("res://scripts/state/run_state.gd"):
		print("FAIL: G4 run-state model does not exist yet")
		quit(1)
		return
	var model_script = load("res://scripts/state/run_state.gd")
	var state = model_script.new()
	var initial: Dictionary = state.snapshot()
	_check(initial == {&"anxiety": 0, &"anger": 0, &"boredom": 0, &"apathy": 0}, "four independent initial parameters")
	var events := [&"sensitive_topic", &"pressure", &"canned_advice", &"functional_treatment"]
	var parameters := [&"anxiety", &"anger", &"boredom", &"apathy"]
	for index in range(events.size()):
		state.reset()
		_check(state.apply_event(events[index]) == &"first", "first event reaction token: " + str(events[index]))
		var expected := initial.duplicate()
		expected[parameters[index]] = 1
		_check(state.snapshot() == expected, "event changes only " + str(parameters[index]))
		_check(state.apply_event(events[index]) == &"repeated", "repeated event reaction token: " + str(events[index]))
		expected[parameters[index]] = 2
		_check(state.snapshot() == expected, "repeat preserves parameter isolation")
		print("TRACE: ", events[index], " -> ", state.snapshot())
	var before_unknown: Dictionary = state.snapshot()
	_check(state.apply_event(&"unknown_event") == &"ignored" and state.snapshot() == before_unknown, "unknown event leaves all parameters unchanged")
	var copy: Dictionary = state.snapshot()
	copy[&"anxiety"] = 999
	_check(state.snapshot() == before_unknown, "diagnostic snapshot cannot mutate the model")
	state.reset()
	var replay = model_script.new()
	var sequence := [&"sensitive_topic", &"pressure", &"sensitive_topic", &"functional_treatment", &"canned_advice"]
	for event in sequence:
		var token: StringName = state.apply_event(event)
		_check(replay.apply_event(event) == token and replay.snapshot() == state.snapshot(), "deterministic replay step " + str(event))
	state.reset()
	_check(state.snapshot() == initial, "reset restores initial state")
	_check(replay.snapshot() != initial, "model instances do not share state")

	var rooftop := (load("res://scenes/rooftop.tscn") as PackedScene).instantiate()
	root.add_child(rooftop)
	await _frames()
	var player := rooftop.get_node("PLACEHOLDER_NON_CANON") as Node2D
	var dialogue := rooftop.get_node("UI/Dialogue") as Node2D
	var line := dialogue.get_node("Line") as Label
	player.position.x = 236.0
	await _frames()
	var reactions: Array[String] = []
	for index in range(events.size()):
		rooftop.start_new_run()
		if index >= 2:
			await _tap_key(KEY_E)
			await _tap_key(KEY_1)
			rooftop.run_state.reset()
		await _tap_key(KEY_E)
		var before: Dictionary = rooftop.run_state.snapshot()
		await _tap_key(KEY_1 if index % 2 == 0 else KEY_2)
		var expected := before.duplicate()
		expected[parameters[index]] += 1
		_check(rooftop.run_state.snapshot() == expected, "dialogue demo applies " + str(events[index]))
		_check(line.text.begins_with("PLACEHOLDER_NON_CANON\n"), "state reaction is explicitly non-canon")
		reactions.append(line.text)
		var after: Dictionary = rooftop.run_state.snapshot()
		dialogue.choose(0)
		_check(rooftop.run_state.snapshot() == after, "completed dialogue cannot apply an event twice")
	_check(reactions[0] != reactions[1] and reactions[0] != reactions[2] and reactions[0] != reactions[3] and reactions[1] != reactions[2] and reactions[1] != reactions[3] and reactions[2] != reactions[3], "four semantic events have distinct technical reactions")

	rooftop.start_new_run()
	await _tap_key(KEY_E)
	await _tap_key(KEY_1)
	var first_reaction := line.text
	var saved_state: Dictionary = rooftop.run_state.snapshot()
	player.position.x = 100.0
	await _frames()
	_check(not dialogue.visible and rooftop.run_state.snapshot() == saved_state, "leaving stops dialogue without resetting run state")
	player.position.x = 236.0
	await _frames()
	await _tap_key(KEY_E)
	_check(rooftop.run_state.snapshot() == saved_state, "reopening dialogue does not reset the run")
	await _tap_key(KEY_3)
	_check(rooftop.run_state.snapshot() == saved_state and line.text.contains("молчание"), "conscious silence stays neutral and distinct")
	await _tap_key(KEY_E)
	await _tap_key(KEY_1)
	await _tap_key(KEY_E)
	await _tap_key(KEY_1)
	_check(line.text != first_reaction and line.text.begins_with("PLACEHOLDER_NON_CANON\n"), "repeated state event changes the technical reaction")
	rooftop.start_new_run()
	_check(rooftop.run_state.snapshot() == initial and not dialogue.visible, "new run resets state and closes the old dialogue")
	await _tap_key(KEY_E)
	await _tap_key(KEY_1)
	_check(line.text == first_reaction, "new run reproduces the initial reaction")
	print("G4 smoke failures: ", failures)
	rooftop.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
