extends SceneTree
## Real input integration: missing modal guards must fail these checks.

const HUB := "res://scenes/street_hub.tscn"
const ROOF := "res://scenes/rooftop.tscn"
var failures := 0


class MouseProbe extends Node:
	var emulated_presses := 0

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.device == -1 and event.pressed:
			emulated_presses += 1


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


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)


func _parsed_touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	# Unlike push_input, exercise the project's touch-to-mouse Input pipeline.
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _wait_device(hub: Node, state: int) -> bool:
	for frame in range(90):
		if hub.device_state == state:
			return true
		await _frames(1)
	_check(false, "device state reached within 90 frames: " + str(state))
	return false


func _run() -> void:
	if not ResourceLoader.exists("res://scenes/ui/hub_player.tscn"):
		_check(false, "G6b physical player scene exists")
		quit(1)
		return
	var hub_script = load("res://scripts/street_hub.gd")
	var hub = (load(HUB) as PackedScene).instantiate()
	root.add_child(hub)
	current_scene = hub
	await _tap_key(KEY_ESCAPE)
	_check(hub.device_state == hub_script.DeviceState.CLOSED, "arrival rejects opening")
	await _frames(30)
	var origin: Vector2 = hub.get_node("Hub/PLACEHOLDER_NON_CANON").position
	var bag := hub.get_node("Hub/PLACEHOLDER_NON_CANON/BagAccess") as TouchScreenButton
	_check(bag.global_position.x > origin.x and bag.is_visible_in_tree(), "bag stays on the hero's right")
	var selected: int = hub.selected_point
	var description: String = hub.get_node("Inspection").text
	for cycle in range(3):
		await _tap_key(KEY_ESCAPE)
		_check(hub.device_state == hub_script.DeviceState.OPENING, "retrieval precedes close-up")
		await _tap_key(KEY_ESCAPE)
		if not await _wait_device(hub, hub_script.DeviceState.OPEN):
			quit(1)
			return
		_check(hub.get_node("PlayerView").visible, "Esc opens one close-up in cycle " + str(cycle))
		_check(hub.get_node("Hub").visible and bag.visible, "street and attached bag remain visible")
		_check(not hub.get_node("Controls").visible and not hub.get_node("Hub/Points").visible, "underlying touch controls are hidden")
		_key(KEY_ESCAPE, true, true)
		await _frames()
		_check(hub.device_state == hub_script.DeviceState.OPEN, "held Escape echo cannot close the player")
		_key(KEY_ESCAPE, false)
		for code in [KEY_E, KEY_A, KEY_D, KEY_SPACE]:
			await _tap_key(code)
		for point in hub.get_node("Hub/Points").get_children():
			_touch(0, point.global_position, true)
			await _frames()
			_touch(0, point.global_position, false)
			await _frames()
		_check(hub.phase == hub_script.Phase.IDLE and hub.selected_point == selected and hub.get_node("Inspection").text == description, "modal input cannot restart or inspect the street")
		_check(hub.get_node("Hub/PLACEHOLDER_NON_CANON").position == origin and hub.cigarette_lit, "player usage leaves hero and cigarette unchanged")
		await _tap_key(KEY_ESCAPE)
		_check(hub.device_state == hub_script.DeviceState.CLOSING, "putting away precedes returning control")
		await _tap_key(KEY_E)
		if not await _wait_device(hub, hub_script.DeviceState.CLOSED):
			quit(1)
			return
		_check(hub.phase == hub_script.Phase.IDLE and hub.get_node("Controls").visible, "closing restores the same hub without restarting")
		_check(not hub.get_node("PlayerView").visible and root.get_child_count() == 1, "closing leaves no duplicate scenes")
	# Mobile: a second finger closes while the first is still held on the bag.
	_touch(0, bag.global_position, true)
	await _frames()
	if not await _wait_device(hub, hub_script.DeviceState.OPEN):
		quit(1)
		return
	var back := hub.get_node("PlayerView/Back") as TouchScreenButton
	_touch(1, back.global_position, true)
	await _frames()
	_touch(1, back.global_position, false)
	await _frames(24)
	_check(hub.device_state == hub_script.DeviceState.CLOSING and not hub.get_node("Controls").visible, "held finger cannot leak into restored hub controls")
	_touch(0, bag.global_position, false)
	await _frames()
	_check(hub.device_state == hub_script.DeviceState.CLOSED and hub.phase == hub_script.Phase.IDLE, "last finger release completes safe close")
	# The real Input pipeline must deliver emulated mouse events without a second action.
	var mouse_probe := MouseProbe.new()
	hub.add_child(mouse_probe)
	_parsed_touch(0, bag.global_position, true)
	await _frames()
	_parsed_touch(0, bag.global_position, false)
	if not await _wait_device(hub, hub_script.DeviceState.OPEN):
		quit(1)
		return
	_check(mouse_probe.emulated_presses > 0, "parsed touch exercises mouse emulation")
	_check(hub.phase == hub_script.Phase.IDLE and hub.selected_point == selected and hub.get_node("PlayerView").visible, "touch plus emulated mouse opens once without a hub action")
	var presses_before_back := mouse_probe.emulated_presses
	_parsed_touch(0, back.global_position, true)
	await _frames()
	_parsed_touch(0, back.global_position, false)
	await _wait_device(hub, hub_script.DeviceState.CLOSED)
	_check(mouse_probe.emulated_presses > presses_before_back, "Back tap also exercises mouse emulation")
	_check(hub.phase == hub_script.Phase.IDLE and hub.get_node("Controls").visible and not hub.get_node("PlayerView").visible, "emulated Back closes without reopening or restarting")
	mouse_probe.queue_free()
	await _frames()
	# Cancellation is an OS release, including when other fingers are still held.
	_parsed_touch(0, bag.global_position, true)
	await _frames()
	_parsed_touch(0, bag.global_position, false)
	await _wait_device(hub, hub_script.DeviceState.OPEN)
	_parsed_touch(0, Vector2(256, 210), true)
	_parsed_touch(1, Vector2(32, 150), true)
	_parsed_touch(2, back.global_position, true)
	await _frames(24)
	_parsed_touch(2, back.global_position, false)
	_parsed_touch(0, Vector2(256, 210), false, true)
	await _frames()
	_check(hub.device_state == hub_script.DeviceState.CLOSING and not hub.get_node("Controls").visible, "partial cancellation must not restore hub controls while another finger is held")
	_parsed_touch(1, Vector2(32, 150), false, true)
	await _frames()
	_check(hub.device_state == hub_script.DeviceState.CLOSED and hub.get_node("Controls").visible and hub.ready_for_restart, "last cancellation restores usable hub controls")
	_check(hub.phase == hub_script.Phase.IDLE and hub.get_node("Hub/PLACEHOLDER_NON_CANON").position == origin and hub.cigarette_lit, "canceling a finger over restart cannot start a new run")
	_parsed_touch(0, bag.global_position, true)
	await _frames()
	_parsed_touch(0, bag.global_position, false)
	if not await _wait_device(hub, hub_script.DeviceState.OPEN):
		quit(1)
		return
	_check(hub.get_node("PlayerView").visible, "fresh tap opens player after canceled touches")
	await _tap_key(KEY_ESCAPE)
	await _wait_device(hub, hub_script.DeviceState.CLOSED)
	# Genuine mouse input must work as well as Android touch.
	_mouse(bag.global_position, true)
	await _frames()
	_mouse(bag.global_position, false)
	if not await _wait_device(hub, hub_script.DeviceState.OPEN):
		quit(1)
		return
	_mouse(back.global_position, true)
	await _frames()
	_mouse(back.global_position, false)
	await _wait_device(hub, hub_script.DeviceState.CLOSED)
	_check(hub.phase == hub_script.Phase.IDLE, "mouse close consumes its input without restarting")
	# A lost OS release must reset the actual TouchScreenButton finger owner.
	_touch(0, bag.global_position, true)
	await _wait_device(hub, hub_script.DeviceState.OPEN)
	_touch(1, back.global_position, true)
	await _frames(24)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(hub.device_state == hub_script.DeviceState.CLOSED and not bag.is_pressed(), "focus loss releases the bag's captured finger")
	_touch(0, bag.global_position, true)
	if not await _wait_device(hub, hub_script.DeviceState.OPEN):
		quit(1)
		return
	_check(hub.get_node("PlayerView").visible, "fresh touch reopens the bag after focus loss")
	root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _frames()
	root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_touch(0, back.global_position, true)
	await _frames()
	_touch(0, back.global_position, false)
	await _wait_device(hub, hub_script.DeviceState.CLOSED)
	_check(not back.is_pressed() and hub.phase == hub_script.Phase.IDLE, "focus loss while open preserves working Back and hub")
	# Wide logical viewport and disabled content controls: no invented playback.
	root.size = Vector2i(2400, 1080)
	await _tap_key(KEY_ESCAPE)
	await _wait_device(hub, hub_script.DeviceState.OPEN)
	var view := hub.get_node("PlayerView")
	for button in view.get_node("ContentButtons").get_children():
		var rect: Rect2 = button.get_global_rect()
		_check(Rect2(0, 0, 320, 240).encloses(rect) and button.disabled, "content button remains inside logical viewport and unavailable")
	_check(Rect2(0, 0, 320, 240).has_point(back.global_position), "Back stays inside logical viewport on wide screen")
	await _tap_key(KEY_ESCAPE)
	await _wait_device(hub, hub_script.DeviceState.CLOSED)
	root.size = Vector2i(320, 240)
	# Real full cycles after using the player; Escape cannot interrupt return.
	for cycle in range(3):
		var old_hub: WeakRef = weakref(hub)
		_key(KEY_E, true)
		await _frames(2)
		for frame in range(150):
			if current_scene != hub:
				break
			_key(KEY_ESCAPE, true)
			await _frames(1)
			_key(KEY_ESCAPE, false)
		await _frames()
		_key(KEY_E, false)
		_check(current_scene != null and current_scene.scene_file_path == ROOF, "player does not interrupt return to roof " + str(cycle))
		_check(old_hub.get_ref() == null and root.get_child_count() == 1, "old player and hub are freed with the scene")
		if current_scene == null or current_scene.scene_file_path != ROOF:
			quit(1)
			return
		_check(is_equal_approx(current_scene.get_node("PLACEHOLDER_NON_CANON").position.x, 72.0), "player input does not leak into roof movement")
		if cycle < 2:
			current_scene.get_node("PLACEHOLDER_NON_CANON").position.x = 34.0
			await _frames()
			await _tap_key(KEY_E)
			await _frames(100) # Includes ordinary leave before the next hub.
			hub = current_scene
			_check(hub.scene_file_path == HUB and hub.device_state == hub_script.DeviceState.CLOSED, "next hub starts with player safely closed")
			await _tap_key(KEY_ESCAPE)
			await _wait_device(hub, hub_script.DeviceState.OPEN)
			await _tap_key(KEY_ESCAPE)
			await _wait_device(hub, hub_script.DeviceState.CLOSED)
	print("G6b player failures: ", failures)
	quit(0 if failures == 0 else 1)
