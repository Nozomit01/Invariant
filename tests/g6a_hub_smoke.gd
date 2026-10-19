extends SceneTree
## Stationary inspection and ordered return sequence in the real street scene.

const ROOF := "res://scenes/rooftop.tscn"
const HUB := "res://scenes/street_hub.tscn"
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
	if not ResourceLoader.exists(HUB):
		print("FAIL: G6a street hub does not exist yet")
		quit(1)
		return
	var hub_script = load("res://scripts/street_hub.gd")
	var first := (load(ROOF) as PackedScene).instantiate()
	root.add_child(first)
	current_scene = first
	await _frames()
	var initial: Dictionary = first.run_state.snapshot()
	for cycle in range(3):
		var roof = current_scene
		_check(roof.scene_file_path == ROOF and roof.run_state.snapshot() == initial, "fresh rooftop state in cycle " + str(cycle))
		roof.get_node("PLACEHOLDER_NON_CANON").position.x = 236.0
		await _frames()
		await _tap_key(KEY_E)
		await _tap_key(KEY_1)
		_check(roof.run_state.snapshot() != initial, "dialogue changed G4 before leaving")
		roof.get_node("PLACEHOLDER_NON_CANON").position.x = 34.0
		await _frames()
		await _tap_key(KEY_E)
		await _frames(30)
		var hub = current_scene
		if hub == null or hub.scene_file_path != HUB:
			_check(false, "rooftop exit reaches the street hub")
			quit(1)
			return
		var player := hub.get_node("Hub/PLACEHOLDER_NON_CANON") as Node2D
		var origin := player.position
		_check(hub.phase == hub_script.Phase.IDLE and hub.cigarette_lit, "ordinary hub starts standing and smoking")
		_check(hub.get_node("Status").text.contains("курит"), "smoking is labelled as a technical placeholder")
		var inspections: Array[String] = []
		await _tap_key(KEY_A)
		for index in range(3):
			if index > 0:
				await _tap_key(KEY_RIGHT)
			await _tap_key(KEY_SPACE)
			inspections.append(hub.get_node("Inspection").text)
			_check(hub.selected_point == index and player.position == origin, "keyboard inspection changes focus without walking " + str(index))
		_check(inspections[0] != inspections[1] and inspections[1] != inspections[2] and inspections[0] != inspections[2], "three environment points have distinct technical descriptions")
		for index in range(3):
			var point := hub.get_node("Hub/Points").get_child(index) as TouchScreenButton
			_touch(0, point.global_position, true)
			await _frames()
			_touch(0, point.global_position, false)
			_check(hub.selected_point == index and hub.get_node("Inspection").text == inspections[index], "touch selects and inspects point " + str(index))
		_check(player.position == origin and hub.cigarette_lit, "inspection never moves the hero or consumes the cigarette")
		var old_hub: WeakRef = weakref(hub)
		if cycle == 1:
			_touch(1, Vector2(256, 210), true)
		else:
			_key(KEY_E, true)
		var observed: Array[int] = []
		var moved_to_house := false
		var extinguished := false
		for frame in range(150):
			if current_scene != hub:
				break
			var phase: int = hub.phase
			if phase != hub_script.Phase.IDLE and (observed.is_empty() or observed.back() != phase):
				observed.append(phase)
			if phase == hub_script.Phase.ENTERING:
				extinguished = not hub.cigarette_lit
				moved_to_house = moved_to_house or player.position.x > origin.x
			_key(KEY_D, true)
			await _frames(1)
			_key(KEY_D, false)
		# Key input is buffered; change_scene_to_file completes at the end of a frame.
		await _frames()
		print("Observed return phases: ", observed)
		_check(observed == [hub_script.Phase.DISCARDING, hub_script.Phase.EXTINGUISHING, hub_script.Phase.ENTERING, hub_script.Phase.TRANSITION, hub_script.Phase.ROOF_DOOR], "return follows all cigarette-house-roof phases in order")
		_check(extinguished and moved_to_house, "cigarette is extinguished before scripted travel to the house")
		_check(current_scene != null and current_scene.scene_file_path == ROOF, "sequence returns to the original roof")
		_check(old_hub.get_ref() == null and root.get_child_count() == 1, "previous hub freed with only one active scene")
		_key(KEY_E, false)
		_touch(1, Vector2(256, 210), false)
		await _frames()
		_check(current_scene.run_state.snapshot() == initial and current_scene.demo_page == 0, "next attempt resets all G4 state and dialogue context")
		_check(is_equal_approx(current_scene.get_node("PLACEHOLDER_NON_CANON").position.x, 72.0), "hub input does not leak into rooftop movement")
	print("G6a hub failures: ", failures)
	quit(0 if failures == 0 else 1)
