extends SceneTree
var failures := 0
var roof: Node
const LINE := "Она: Чё пялишься?"
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
func touch(pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = Vector2(274,210)
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()
func new_roof() -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await frames()
	roof = load("res://scenes/rooftop.tscn").instantiate()
	root.add_child(roof)
	current_scene = roof
	await frames()
func run() -> void:
	await new_roof()
	var session = load("res://scripts/state/session_outcomes.gd")
	var state: Dictionary = roof.run_state.snapshot()
	var outcomes: Array = session.completed_outcomes()
	await frames(365)
	check(not roof.dialogue.visible,"waiting far away cannot start conversation")
	roof.player.position.x = 236.0
	await frames(350)
	check(not roof.dialogue.visible,"girl does not speak before six seconds nearby")
	await frames(15)
	check(roof.dialogue.visible and roof.dialogue.line.text == LINE,"girl initiates after six active seconds nearby")
	if not roof.dialogue.visible:
		quit(1)
		return
	check(not roof.dialogue.awaiting_choice and not roof.dialogue.choices[0].visible,"opening does not answer for player or expose reply choices")
	check(roof.get_node("UI/Interact/Label").text == "Ответить","existing action offers an explicit reply")
	check(roof.dialogue.line.get_minimum_size().x <= roof.dialogue.line.size.x,"canonical opening fits logical dialogue width")
	await tap(KEY_1)
	check(roof.dialogue.line.text == LINE and not roof.dialogue.awaiting_choice,"choice key cannot answer before player starts conversation")
	await frames(365)
	check(roof.dialogue.line.text == LINE and roof.run_state.snapshot() == state,"continued silence neither advances dialogue nor changes hidden state")
	check(session.events().is_empty() and session.completed_outcomes() == outcomes and not DirAccess.dir_exists_absolute("user://outcomes_v1"),"silence cannot award or save an outcome")
	var x_before: float = roof.player.position.x
	key(KEY_A,true)
	await frames(40)
	key(KEY_A,false)
	await frames(15)
	check(roof.player.position.x < x_before-26 and not roof.dialogue.visible,"movement stays available and walking away closes opening")
	roof.player.position.x = 236.0
	await frames(365)
	check(not roof.dialogue.visible,"returning does not repeat automatic opening this run")
	await tap(KEY_E)
	check(roof.dialogue.awaiting_choice and roof.dialogue.line.text.contains("Привет"),"player can initiate existing conversation after walking away")
	await new_roof()
	roof.player.position.x = 236.0
	await frames(200)
	roof.player.position.x = 100.0
	await frames()
	roof.player.position.x = 236.0
	await frames(200)
	check(not roof.dialogue.visible,"leaving zone resets accumulated silence")
	await frames(165)
	check(roof.dialogue.line.text == LINE,"continuous return eventually starts opening")
	# Timer tests below control simulation delta, but input still uses the real event pipeline.
	for window_focus in [false,true]:
		await new_roof()
		roof.player.position.x = 236.0
		await frames(3)
		roof.set_physics_process(false)
		roof._physics_process(2.0)
		var lost := Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT if window_focus else Node.NOTIFICATION_APPLICATION_FOCUS_OUT
		var gained := Node.NOTIFICATION_WM_WINDOW_FOCUS_IN if window_focus else Node.NOTIFICATION_APPLICATION_FOCUS_IN
		root.propagate_notification(lost)
		await frames()
		roof._physics_process(30.0)
		check(not roof.dialogue.visible,"unfocused time cannot start opening " + str(window_focus))
		root.propagate_notification(gained)
		roof._physics_process(3.0)
		check(not roof.dialogue.visible,"focus return preserves remaining delay " + str(window_focus))
		roof._physics_process(1.0)
		check(roof.dialogue.line.text == LINE,"focused time resumes opening " + str(window_focus))
		roof.set_physics_process(true)
		await tap(KEY_E)
		check(roof.dialogue.awaiting_choice and roof.dialogue.line.text.contains("Привет"),"keyboard reply works after focus return " + str(window_focus))
	# Player action wins on the exact threshold frame.
	await new_roof()
	roof.player.position.x = 236.0
	roof.set_physics_process(false)
	roof._physics_process(5.99)
	key(KEY_E,true)
	roof._physics_process(0.02)
	check(roof.dialogue.awaiting_choice and roof.dialogue.line.text.contains("Привет"),"player action takes priority on threshold frame")
	key(KEY_E,false)
	roof._physics_process(30.0)
	check(roof.dialogue.awaiting_choice and roof.dialogue.line.text.contains("Привет"),"automatic opening cannot replace an initiated conversation")
	roof.set_physics_process(true)
	# Manual physics calls do not advance Godot's just-pressed input tick.
	await frames()
	await tap(KEY_1)
	await tap(KEY_E)
	await tap(KEY_3)
	await tap(KEY_E)
	check(roof.dialogue.line.text.contains("дым в лицо"),"existing first conversation continues into smoke episode")
	# Touch, held contact and emulated mouse must not select a reply implicitly.
	var original_emulation := Input.emulate_mouse_from_touch
	for emulate in [false,true]:
		await new_roof()
		roof.player.position.x = 236.0
		roof._physics_process(6.0)
		Input.emulate_mouse_from_touch = emulate
		touch(true)
		await frames(12)
		check(roof.dialogue.awaiting_choice and roof.demo_page == 0,"held touch answers opening without choosing an option " + str(emulate))
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await frames()
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await frames()
		check(not roof.get_node("UI/Interact").is_pressed() and roof.dialogue.awaiting_choice,"focus loss clears held answer without choosing " + str(emulate))
		touch(false)
		await frames()
	Input.emulate_mouse_from_touch = original_emulation
	# Leave both before and after the automatic opening, then start a new run.
	for after_opening in [false,true]:
		await new_roof()
		roof.player.position.x = 236.0
		if after_opening: roof._physics_process(6.0)
		var count_before: int = session.events().size()
		roof.player.position.x = 34.0
		await frames()
		await tap(KEY_E)
		await frames(100)
		check(current_scene.scene_file_path == "res://scenes/street_hub.tscn" and current_scene.ready_for_restart,"leave remains available " + str(after_opening))
		check(session.events().size() == count_before+1 and session.completed_outcomes() == ["leave"],"only completed leave records the outcome " + str(after_opening))
		await tap(KEY_E)
		await frames(100)
		roof = current_scene
		roof.player.position.x = 236.0
		roof._physics_process(6.0)
		check(roof.dialogue.line.text == LINE,"real new cycle resets opening eligibility " + str(after_opening))
	print("Silence opening failures: ",failures)
	quit(0 if failures == 0 else 1)
