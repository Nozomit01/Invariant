extends SceneTree
## Real scene replacement and input across repeated technical runs.

const ROOF := "res://scenes/rooftop.tscn"
const HUB := "res://scenes/technical_hub.tscn"
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


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
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


func _clean_input() -> bool:
	for code in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_E, KEY_1, KEY_2, KEY_3]:
		if Input.is_physical_key_pressed(code):
			return false
	for action in [&"move_left", &"move_right", &"interact", &"dialogue_choice_1", &"dialogue_choice_2", &"dialogue_choice_3"]:
		if Input.is_action_pressed(action):
			return false
	return true


func _scene_count() -> int:
	var count := 0
	for node in root.get_children():
		if node.scene_file_path in [ROOF, HUB]:
			count += 1
	return count


func _run() -> void:
	if not ResourceLoader.exists(HUB):
		print("FAIL: G5 technical hub does not exist yet")
		quit(1)
		return
	var first := (load(ROOF) as PackedScene).instantiate()
	root.add_child(first)
	current_scene = first
	await _frames()
	var initial: Dictionary = first.run_state.snapshot()
	for cycle in range(4):
		var rooftop = current_scene
		_check(rooftop.scene_file_path == ROOF and _scene_count() == 1, "one rooftop at cycle " + str(cycle))
		_check(rooftop.run_state.snapshot() == initial and rooftop.demo_page == 0, "fresh G4 state and dialogue context")
		var player := rooftop.get_node("PLACEHOLDER_NON_CANON") as Node2D
		_check(is_equal_approx(player.position.x, 72.0), "new run starts at the original spawn")
		if cycle in [1, 2]:
			player.position.x = 236.0
			await _frames()
			for choice in [KEY_1, KEY_1, KEY_2, KEY_2]:
				await _tap_key(KEY_E)
				await _tap_key(choice)
			_check(rooftop.run_state.snapshot() == {&"anxiety": 1, &"anger": 1, &"boredom": 1, &"apathy": 1}, "dialogue updates all four G4 states before exit")
		if cycle <= 1:
			_key(KEY_A, true)
			await _frames(180 if cycle == 1 else 55)
		else:
			player.position.x = 34.0
			await _frames()
		_check(current_scene == rooftop, "walking to the exit does not leave automatically")
		_check(rooftop.get_node("UI/ExitPrompt").visible and rooftop.get_node("UI/Interact/Label").text == "Уйти", "exit advertises the explicit leave action")
		var old_roof: WeakRef = weakref(rooftop)
		if cycle <= 1:
			_key(KEY_1, true)
			_key(KEY_E, true)
		else:
			_touch(0, Vector2(38, 210), true)
			_touch(1, Vector2(274, 210), true)
		await _frames()
		if current_scene == null or current_scene.scene_file_path != HUB:
			_check(false, "leave reaches the technical hub")
			quit(1)
			return
		var hub = current_scene
		_check(hub.get_node("Transition").visible and not hub.get_node("Hub").visible, "brief technical transition precedes hub controls")
		_check(old_roof.get_ref() == null and _scene_count() == 1, "old roof freed without duplicate scenes")
		_check(_clean_input(), "exit clears held keyboard or multitouch actions")
		await _frames(30)
		_check(current_scene == hub and hub.ready_for_restart, "held exit input does not skip the hub")
		var hub_player := hub.get_node("Hub/PLACEHOLDER_NON_CANON") as Node2D
		var fixed_position := hub_player.position
		_key(KEY_A, true)
		await _frames(8)
		_key(KEY_A, false)
		_check(hub_player.position == fixed_position, "hub character cannot walk")
		_key(KEY_E, true, true)
		await _frames()
		_check(current_scene == hub, "keyboard auto-repeat cannot start a run")
		_key(KEY_E, false)
		_key(KEY_1, false)
		_touch(0, Vector2(38, 210), false)
		_touch(1, Vector2(274, 210), false)
		await _frames()
		var old_hub: WeakRef = weakref(hub)
		if cycle <= 1:
			_key(KEY_E, true)
		else:
			_touch(2, Vector2(160, 210), true)
		await _frames(4)
		_check(current_scene != null and current_scene.scene_file_path == ROOF, "new-run action returns to the roof")
		_check(old_hub.get_ref() == null and _scene_count() == 1, "old hub freed without duplicate scenes")
		_check(_clean_input(), "new roof inherits no held actions")
		_key(KEY_E, false)
		_touch(2, Vector2(160, 210), false)
		await _frames(8)
		_check(is_equal_approx(current_scene.get_node("PLACEHOLDER_NON_CANON").position.x, 72.0), "new run stays still without fresh movement input")
		_check(current_scene.run_state.snapshot() == initial, "all old run parameters were discarded")
	var final_player := current_scene.get_node("PLACEHOLDER_NON_CANON") as Node2D
	_key(KEY_D, true)
	await _frames(8)
	_key(KEY_D, false)
	_check(final_player.position.x > 72.0, "fresh movement input works after repeated cycles")
	print("G5 cycle failures: ", failures)
	quit(0 if failures == 0 else 1)
