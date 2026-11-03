extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func frames(n := 3) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func tap(code: Key) -> void:
	key(code,true)
	await frames()
	key(code,false)
	await frames()
func touch(node: Node2D, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 5
	e.position = root.get_screen_transform() * node.global_position
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func mouse(node: Node2D, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = root.get_screen_transform() * node.global_position
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func prepare(roof: Node, x: float) -> void:
	roof.start_new_run()
	roof.player.position.x = x
	await frames()
	await tap(KEY_E)
	await tap(KEY_2)
	await tap(KEY_E)
	await tap(KEY_3)
	await tap(KEY_E)
func walk_to(roof: Node, x: float) -> void:
	var code := KEY_D if roof.player.position.x < x else KEY_A
	key(code,true)
	for i in range(90):
		if (code == KEY_D and roof.player.position.x >= x) or (code == KEY_A and roof.player.position.x <= x): break
		await frames(1)
	key(code,false)
	await frames(16)
func run() -> void:
	if not ResourceLoader.exists("res://data/dialogue/smoke_and_space.gd"):
		check(false,"smoke and space episode exists")
		quit(1)
		return
	var data = load("res://data/dialogue/smoke_and_space.gd")
	var roof = load("res://scenes/rooftop.tscn").instantiate()
	root.add_child(roof)
	current_scene = roof
	await frames()
	var ui = roof.get_node("UI/Dialogue")
	check(roof.smoke_stage == -1,"episode is unavailable before introduction")
	for origin in [224.0,248.0]:
		await prepare(roof,origin)
		var initial_side: int = roof.smoke_origin_side
		var state_before: Dictionary = roof.run_state.snapshot()
		check(roof.smoke_stage == 0 and ui.awaiting_choice and ui.line.text == data.ENTRY.line,"invitation is open before leaving without a choice")
		await walk_to(roof,180.0 if origin < 236 else 280.0)
		check(not ui.visible and roof.smoke_stage == 0,"departure from invitation does not choose or advance")
		await walk_to(roof,248.0 if origin < 236 else 224.0)
		check(not ui.visible,"opposite-side return does not reopen invitation automatically")
		await tap(KEY_E)
		check(ui.line.text == data.MOVED.line and ui.awaiting_choice,"reopened invitation describes actual opposite side " + str(origin))
		check(roof.smoke_stage == 0 and roof.smoke_origin_side == initial_side and roof.run_state.snapshot() == state_before,"reopening preserves original side, pending choice and hidden state")
		for i in range(3):
			check(ui.choices[i].get_node("Label").text == data.ENTRY.choices[i].label,"contextual invitation preserves choice " + str(i))
		await tap(KEY_E)
		check(ui.line.text == data.MOVED.line and roof.smoke_stage == 0,"repeated interaction keeps contextual invitation pending")
		await walk_to(roof,origin)
		await tap(KEY_E)
		check(ui.line.text == data.ENTRY.line and roof.smoke_origin_side == initial_side,"return to original side restores original invitation")
		await walk_to(roof,248.0 if origin < 236 else 224.0)
		await tap(KEY_E)
		await tap(KEY_1)
		check(roof.smoke_stage == 1 and ui.line.text == data.ENTRY.choices[0].reply,"only explicit choice advances reopened invitation")
		await tap(KEY_E)
		check(ui.line.text == data.MOVED.line and roof.run_state.snapshot() == state_before,"observation keeps actual crossing after resumed invitation")
	check(data.ENTRY.line == "Она: Тебе весь дым в лицо.\nМожешь встать с другой стороны.","contextual pages do not mutate shared invitation data")
	for origin in [224.0,248.0]:
		for moved in [false,true]:
			for answer in range(3):
				await prepare(roof,origin)
				var state: Dictionary = roof.run_state.snapshot()
				check(roof.conversation_finished and roof.smoke_stage == 0 and ui.line.text == data.ENTRY.line,"new episode follows actual introduction")
				await tap(KEY_1)
				check(roof.smoke_stage == 1 and not ui.awaiting_choice,"promise waits for manual continuation")
				if moved: await walk_to(roof,248.0 if origin < 236 else 224.0)
				await tap(KEY_E)
				check(ui.line.text == (data.MOVED.line if moved else data.UNMOVED.line),"observation follows actual side " + str([origin,moved,answer]))
				if answer == 0:
					mouse(ui.choices[answer],true)
					mouse(ui.choices[answer],false)
				elif answer == 1:
					Input.emulate_mouse_from_touch = false
					touch(ui.choices[answer],true)
					await frames()
					touch(ui.choices[answer],false)
					Input.emulate_mouse_from_touch = true
				else: await tap(KEY_3)
				await frames()
				check(roof.smoke_stage == 2 and not ui.awaiting_choice and ui.line.text == data.page(1,moved).choices[answer].reply,"all movement and reply paths finish with matching text")
				await tap(KEY_E)
				await tap(KEY_1)
				check(roof.run_state.snapshot() == state and roof.smoke_stage == 2 and not ui.awaiting_choice,"no reward, pressure reset, or replay after episode")
	for answer in [1,2]:
		await prepare(roof,224.0)
		var state: Dictionary = roof.run_state.snapshot()
		await frames(12)
		check(ui.awaiting_choice and roof.smoke_stage == 0,"waiting does not choose silence")
		await tap(KEY_2 if answer == 1 else KEY_3)
		check(roof.smoke_stage == 2 and ui.line.text == data.ENTRY.choices[answer].reply and roof.run_state.snapshot() == state,"staying and silence finish without compliance reward")
	await prepare(roof,224.0)
	await tap(KEY_1)
	await walk_to(roof,228.0)
	await tap(KEY_E)
	check(ui.line.text == data.UNMOVED.line,"small movement on same side is not crossing")
	await walk_to(roof,248.0)
	await tap(KEY_E)
	check(ui.line.text == data.MOVED.line,"actual crossing updates observation")
	await walk_to(roof,224.0)
	mouse(ui.choices[0],true)
	mouse(ui.choices[0],false)
	await frames()
	check(ui.line.text == data.UNMOVED.choices[0].reply,"reply rechecks position after crossing back")
	await prepare(roof,224.0)
	await tap(KEY_1)
	await tap(KEY_E)
	var state: Dictionary = roof.run_state.snapshot()
	await walk_to(roof,180.0)
	check(not ui.visible and roof.smoke_stage == 1,"departure hides second question without finishing")
	await tap(KEY_1)
	check(roof.smoke_stage == 1 and roof.run_state.snapshot() == state,"hidden episode ignores answers")
	await walk_to(roof,248.0)
	check(not ui.visible,"return does not reopen episode automatically")
	await tap(KEY_E)
	check(ui.line.text == data.MOVED.line and ui.awaiting_choice,"return recomputes side while retaining episode")
	var right: TouchScreenButton = roof.get_node("UI/Right")
	touch(right,true)
	await frames(2)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(16)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not right.is_pressed() and not Input.is_action_pressed("move_right") and roof.smoke_stage == 1 and ui.awaiting_choice,"held-input focus loss preserves smoke episode")
	touch(right,false)
	root.size = Vector2i(2400,1080)
	await frames()
	touch(ui.choices[2],true)
	await frames()
	touch(ui.choices[2],false)
	await frames()
	check(roof.smoke_stage == 2 and ui.line.text == data.MOVED.choices[2].reply and roof.run_state.snapshot() == state,"wide-screen emulated touch finishes once after focus recovery")
	for page in [data.ENTRY,data.MOVED,data.UNMOVED]:
		ui.start(page.line,page.choices)
		check(ui.line.get_minimum_size().x <=296 and ui.line.get_minimum_size().y <=32,"episode line fits text area")
		for i in range(3):
			var label: Label = ui.choices[i].get_node("Label")
			check(label.get_minimum_size().x <=288 and label.get_minimum_size().y <=30,"episode choice fits button")
			ui.show_reaction(page.choices[i].reply)
			check(ui.line.get_minimum_size().x <=296 and ui.line.get_minimum_size().y <=32,"episode reply fits text area")
	root.size = Vector2i(320,240)
	roof.player.position.x = 34.0
	await frames()
	await tap(KEY_E)
	await frames(30)
	await tap(KEY_E)
	await frames(100)
	check(current_scene.scene_file_path == "res://scenes/rooftop.tscn" and current_scene.smoke_stage == -1 and not current_scene.conversation_finished,"real new cycle resets both episodes")
	print("Smoke and space failures: ",failures)
	quit(0 if failures == 0 else 1)
