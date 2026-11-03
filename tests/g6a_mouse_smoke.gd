extends SceneTree
## Real hub controls with an observation-only counter for duplicate inspections.

class ObservedHub extends "res://scripts/street_hub.gd":
	var inspection_count := 0
	func _inspect() -> void:
		inspection_count += 1
		super._inspect()

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _frames(count := 3) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame

func _position(node: Node2D) -> Vector2:
	return root.get_screen_transform() * node.get_global_transform_with_canvas().origin

func _mouse(position: Vector2, pressed := true, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _click(node: Node2D) -> void:
	_mouse(_position(node))
	_mouse(_position(node), false)

func _touch(node: Node2D, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = _position(node)
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
	var hub = load("res://scenes/street_hub.tscn").instantiate()
	hub.set_script(ObservedHub)
	root.add_child(hub)
	current_scene = hub
	var points: Node2D = hub.get_node("Hub/Points")
	var bag: TouchScreenButton = hub.get_node("Hub/PLACEHOLDER_NON_CANON/BagAccess")
	var origin: Vector2 = hub.player.position
	_click(points.get_child(0))
	await _frames(28)
	_check(hub.phase == hub.Phase.IDLE and hub.inspection_count == 0, "arrival ignores point clicks")
	for size in [Vector2i(320,240), Vector2i(2400,1080)]:
		root.size = size
		await _frames()
		for index in range(3):
			var before: int = hub.inspection_count
			_click(points.get_child(index))
			await _frames()
			_check(hub.selected_point == index and hub.inspection_count == before + 1, "mouse inspects point once " + str(index) + " at " + str(size))
			_check(hub.get_node("Inspection").text == hub.PREFIX + "Осмотр: " + hub.POINT_NAMES[index] + " (заглушка)", "mouse uses existing inspection text " + str(index) + " at " + str(size))
	var before: int = hub.inspection_count
	_mouse(_position(points.get_child(0)), true, MOUSE_BUTTON_RIGHT)
	_mouse(_position(points.get_child(0)), false, MOUSE_BUTTON_RIGHT)
	_mouse(_position(points.get_child(0)), false)
	_mouse(Vector2(2,2))
	_mouse(Vector2(2,2), false)
	await _frames()
	_check(hub.inspection_count == before, "right click, release alone and outside click do not inspect")
	var original_emulation := Input.emulate_mouse_from_touch
	for emulate in [false,true]:
		Input.emulate_mouse_from_touch = emulate
		for index in range(3):
			before = hub.inspection_count
			_touch(points.get_child(index), true)
			await _frames()
			_touch(points.get_child(index), false)
			await _frames()
			_check(hub.selected_point == index and hub.inspection_count == before+1, "touch inspects once " + str(index) + " emulation=" + str(emulate))
	Input.emulate_mouse_from_touch = original_emulation
	_check(hub.player.position == origin and hub.cigarette_lit, "mouse and touch inspections keep hero stationary and cigarette lit")
	before = hub.inspection_count
	var selected: int = hub.selected_point
	_click(bag)
	_check(hub.device_state == hub.DeviceState.OPENING, "bag click opens player instead of inspecting")
	_click(points.get_child(0))
	_touch(points.get_child(0), true)
	_touch(points.get_child(0), false)
	_check(hub.inspection_count == before and hub.selected_point == selected, "opening player blocks point mouse and touch")
	await _frames(20)
	_check(hub.device_state == hub.DeviceState.OPEN, "player reaches open state")
	_click(points.get_child(1))
	_touch(points.get_child(1), true)
	_touch(points.get_child(1), false)
	await _frames()
	_check(hub.inspection_count == before and hub.selected_point == selected and hub.player.position == origin, "open player blocks inspection and movement")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(hub.device_state == hub.DeviceState.CLOSING, "escape closes player")
	_click(points.get_child(0))
	_touch(points.get_child(0), true)
	_touch(points.get_child(0), false)
	_check(hub.inspection_count == before and hub.selected_point == selected, "closing player blocks point mouse and touch")
	await _frames(20)
	_click(points.get_child(0))
	await _frames()
	_check(hub.device_state == hub.DeviceState.CLOSED and hub.selected_point == 0 and hub.inspection_count == before+1, "mouse inspection works again after player closes")
	_key(KEY_E, true)
	_key(KEY_E, false)
	before = hub.inspection_count
	_click(points.get_child(1))
	_touch(points.get_child(1), true)
	_touch(points.get_child(1), false)
	_check(hub.phase == hub.Phase.DISCARDING and hub.inspection_count == before, "return sequence blocks mouse and touch inspection")
	await _frames(100)
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/rooftop.tscn", "return sequence still reaches rooftop")
	print("G6a mouse failures: ", failures)
	quit(0 if failures == 0 else 1)
