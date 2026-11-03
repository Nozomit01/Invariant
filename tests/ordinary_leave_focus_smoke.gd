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
func run() -> void:
	var session = load("res://scripts/state/session_outcomes.gd")
	for window_signal_only in [false,true]:
		var count_before: int = session.events().size()
		var roof = load("res://scenes/rooftop.tscn").instantiate()
		root.add_child(roof)
		current_scene = roof
		await frames()
		roof.player.position.x = 34.0
		await frames()
		roof.tree_exiting.connect(func():
			if not window_signal_only:
				root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			root.focus_exited.emit()
		)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_E
		e.pressed = true
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await frames(110)
		var hub = current_scene
		check(hub.scene_file_path == "res://scenes/street_hub.tscn" and hub.leave_stage == hub.LeaveStage.LEAVING and not hub.ready_for_restart,"focus loss during scene handoff keeps departure paused " + str(window_signal_only))
		check(session.events().size() == count_before,"handoff without focus cannot record an outcome")
		if not window_signal_only:
			root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			await frames(100)
			check(not hub.ready_for_restart and session.events().size() == count_before,"application focus alone cannot override missing window focus")
		root.focus_entered.emit()
		await frames(100)
		check(hub.ready_for_restart and session.events().size() == count_before+1,"full focus recovery completes departure exactly once")
		hub.queue_free()
		await frames()
	# Application recovery can also occur while neither gameplay scene exists.
	var count_before: int = session.events().size()
	var roof = load("res://scenes/rooftop.tscn").instantiate()
	root.add_child(roof)
	current_scene = roof
	await frames()
	roof.player.position.x = 34.0
	await frames()
	roof.tree_exiting.connect(func():
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		root.focus_exited.emit()
	)
	roof.tree_exited.connect(func():
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		root.focus_entered.emit()
	)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await frames(110)
	check(current_scene.ready_for_restart and session.events().size() == count_before+1,"recovery in scene gap cannot leave departure stuck")
	print("Ordinary leave focus failures: ",failures)
	quit(0 if failures == 0 else 1)
