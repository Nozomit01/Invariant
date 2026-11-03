extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func frames(count := 3) -> void:
	for frame in range(count):
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
func touch(node: Node2D, pressed: bool, finger := 3) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = root.get_screen_transform() * node.global_position
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func second_question_interruptions(roof: Node, data: Script) -> void:
	var dialogue = roof.get_node("UI/Dialogue")
	for first in [0,1]:
		roof.start_new_run()
		roof.player.position.x = 236.0
		await frames()
		await tap(KEY_E)
		await tap(KEY_1 if first == 0 else KEY_2)
		await tap(KEY_E)
		var page: int = roof.demo_page
		var question: String = dialogue.line.text
		var state: Dictionary = roof.run_state.snapshot()
		check(page == first+1 and dialogue.awaiting_choice,"second question is open before interruption " + str(page))
		key(KEY_A,true)
		await frames(40)
		key(KEY_A,false)
		await frames(16)
		check(not dialogue.visible and dialogue.line.text.is_empty() and not dialogue.awaiting_choice,"walking away clears the open second question " + str(page))
		check(roof.demo_page == page and roof.run_state.snapshot() == state and not roof.conversation_finished,"walking away preserves second question without choosing " + str(page))
		await tap(KEY_1)
		touch(dialogue.choices[1],true)
		touch(dialogue.choices[1],false)
		await frames()
		check(roof.demo_page == page and roof.run_state.snapshot() == state and not roof.conversation_finished,"hidden second question ignores keyboard and touch " + str(page))
		roof.player.position.x = 236.0
		await frames()
		check(not dialogue.visible,"return does not reopen second question automatically " + str(page))
		await tap(KEY_E)
		check(dialogue.awaiting_choice and dialogue.line.text == question and dialogue.choices[0].get_node("Label").text == data.PAGES[page].choices[0].label,"interaction restores exact second question and choices " + str(page))
		var right := roof.get_node("UI/Right") as TouchScreenButton
		touch(right,true)
		key(KEY_D,true)
		await frames(2)
		check(right.is_pressed() and Input.is_action_pressed("move_right") and dialogue.awaiting_choice,"movement button and key are held during actual second question " + str(page))
		var lost := Node.NOTIFICATION_APPLICATION_FOCUS_OUT if first == 0 else Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT
		var restored := Node.NOTIFICATION_APPLICATION_FOCUS_IN if first == 0 else Node.NOTIFICATION_WM_WINDOW_FOCUS_IN
		root.propagate_notification(lost)
		await frames(16)
		root.propagate_notification(restored)
		check(not right.is_pressed() and not Input.is_action_pressed("move_right") and not Input.is_physical_key_pressed(KEY_D),"focus loss clears held touch and key in actual conversation " + str(page))
		var stopped_x: float = roof.player.position.x
		await frames(8)
		check(is_equal_approx(roof.player.position.x,stopped_x) and stopped_x < 262.0,"lost releases cannot move hero out of conversation range " + str(page))
		check(dialogue.awaiting_choice and dialogue.line.text == question and roof.demo_page == page and roof.run_state.snapshot() == state,"held-input focus recovery preserves exact narrative context " + str(page))
		touch(right,true,7)
		await frames(3)
		check(right.is_pressed() and roof.player.position.x > stopped_x,"fresh finger can move after conversation focus recovery " + str(page))
		touch(right,false,7)
		touch(right,false)
		key(KEY_D,false)
		await frames(16)
		check(not right.is_pressed() and not Input.is_action_pressed("move_right") and dialogue.awaiting_choice,"fresh and stale releases keep second question pending " + str(page))
		touch(dialogue.choices[2],true,8)
		await frames()
		touch(dialogue.choices[2],false,8)
		await frames()
		check(roof.conversation_finished and dialogue.line.text == data.PAGES[page].choices[2].reply and roof.run_state.snapshot() == state,"touch silence completes restored second question once " + str(page))
func mouse(node: Node2D, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = root.get_screen_transform() * node.global_position
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func _run() -> void:
	if not ResourceLoader.exists("res://data/dialogue/first_conversation.gd"):
		check(false,"first playable conversation data exists")
		quit(1)
		return
	var data = load("res://data/dialogue/first_conversation.gd")
	var roof = load("res://scenes/rooftop.tscn").instantiate()
	root.add_child(roof)
	current_scene = roof
	await frames()
	var dialogue = roof.get_node("UI/Dialogue")
	for first in range(3):
		for second in range(3):
			roof.start_new_run()
			roof.player.position.x = 236.0
			await frames()
			await tap(KEY_E)
			check(dialogue.line.text == data.PAGES[0].line and dialogue.awaiting_choice,"new run opens actual conversation " + str([first,second]))
			await frames(8)
			check(roof.demo_page == 0 and dialogue.awaiting_choice,"waiting does not select silence")
			await tap([KEY_1,KEY_2,KEY_3][first])
			var next: int = 2 if first == 1 else 1
			check(roof.demo_page == next and not dialogue.awaiting_choice,"first choice selects contextual continuation")
			check(dialogue.line.text == data.PAGES[0].choices[first].reply,"first choice shows its exact reply")
			var snapshot: Dictionary = roof.run_state.snapshot()
			check(snapshot[&"anger"] == (1 if first == 1 else 0) and snapshot[&"anxiety"] == 0 and snapshot[&"apathy"] == 0 and snapshot[&"boredom"] == 0,"only insistence applies pressure; no reward for other replies")
			await tap(KEY_2)
			check(roof.run_state.snapshot() == snapshot and roof.demo_page == next,"extra choice cannot skip a reaction")
			await tap(KEY_E)
			check(dialogue.line.text == data.PAGES[next].line and dialogue.awaiting_choice,"interaction continues into matching question")
			root.size = Vector2i(2400,1080) if second == 2 else Vector2i(320,240)
			await frames()
			if second == 0:
				# Native touch must work even without mouse emulation.
				Input.emulate_mouse_from_touch = false
				touch(dialogue.choices[second],true)
				await frames()
				touch(dialogue.choices[second],false)
				Input.emulate_mouse_from_touch = true
			elif second == 1:
				mouse(dialogue.choices[second],true)
				mouse(dialogue.choices[second],false)
			else:
				touch(dialogue.choices[second],true)
				await frames()
				touch(dialogue.choices[second],false)
			await frames()
			check(roof.conversation_finished and not dialogue.awaiting_choice and dialogue.line.text == data.PAGES[next].choices[second].reply,"touch/mouse finishes exact branch " + str([first,second]))
			await tap(KEY_E)
			await tap(KEY_1)
			check(roof.conversation_finished and roof.run_state.snapshot() == snapshot and not dialogue.awaiting_choice,"completed conversation cannot restart or farm state")
	root.size = Vector2i(320,240)
	roof.start_new_run()
	roof.player.position.x = 236.0
	await frames()
	await tap(KEY_E)
	key(KEY_A,true)
	await frames(6)
	key(KEY_A,false)
	await frames(10)
	check(roof.player.position.x < 236.0 and dialogue.awaiting_choice,"walking remains available during conversation")
	roof.player.position.x = 100.0
	await frames()
	check(not dialogue.visible and roof.demo_page == 0,"walking away cancels panel without choosing")
	roof.player.position.x = 236.0
	await frames()
	check(not dialogue.visible,"return alone does not reopen conversation")
	await tap(KEY_E)
	await tap(KEY_2)
	roof.player.position.x = 100.0
	await frames()
	roof.player.position.x = 236.0
	await frames()
	await tap(KEY_E)
	check(roof.demo_page == 2 and dialogue.line.text == data.PAGES[2].line,"return resumes continuation without repeating introduction")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(dialogue.awaiting_choice and roof.demo_page == 2,"focus recovery preserves actual conversation context")
	var before_silence: Dictionary = roof.run_state.snapshot()
	touch(dialogue.choices[2],true)
	await frames()
	touch(dialogue.choices[2],false)
	await frames()
	check(roof.conversation_finished and dialogue.line.text == data.PAGES[2].choices[2].reply,"touch silence works after actual conversation regains focus")
	check(roof.run_state.snapshot() == before_silence,"late silence adds no hidden state change")
	roof.player.position.x = 100.0
	await frames()
	roof.player.position.x = 236.0
	await frames()
	await tap(KEY_E)
	check(not dialogue.visible and roof.conversation_finished,"return after completion cannot replay conversation")
	await second_question_interruptions(roof,data)
	for page in data.PAGES:
		dialogue.start(page.line,page.choices)
		check(dialogue.line.get_minimum_size().x <= 296 and dialogue.line.get_minimum_size().y <= 32,"opening fits text area above choices")
		for index in range(3):
			var label: Label = dialogue.choices[index].get_node("Label")
			check(label.get_minimum_size().x <= 288 and label.get_minimum_size().y <= 30,"choice fits existing button")
			dialogue.show_reaction(page.choices[index].reply)
			check(dialogue.line.get_minimum_size().x <= 296 and dialogue.line.get_minimum_size().y <= 32,"reply fits text area above choices")
	# The actual roof/hub/roof sequence resets narrative progress as well as G4.
	roof.player.position.x = 34.0
	await frames()
	await tap(KEY_E)
	await frames(30)
	check(current_scene.scene_file_path == "res://scenes/street_hub.tscn","conversation allows leaving to hub")
	await tap(KEY_E)
	await frames(100)
	check(current_scene.scene_file_path == "res://scenes/rooftop.tscn" and current_scene.demo_page == 0 and not current_scene.conversation_finished,"new cycle resets actual conversation")
	print("First conversation failures: ",failures)
	quit(0 if failures == 0 else 1)
