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
func run() -> void:
	if not ResourceLoader.exists("res://scripts/state/session_outcomes.gd"):
		check(false,"session outcome memory exists")
		quit(1)
		return
	var session = load("res://scripts/state/session_outcomes.gd")
	check(session.events().is_empty(),"fresh process starts without recorded outcomes")
	var ticket: int = session.begin_leave()
	check(session.begin_leave() == ticket,"duplicate begin reuses pending departure")
	check(session.claim_leave() == ticket and session.claim_leave() == 0,"only one scene can claim departure")
	session.cancel_leave(ticket)
	check(not session.complete_leave(ticket) and session.events().is_empty(),"canceled departure cannot record an event")
	var interrupted_id: int = session.begin_leave()
	var interrupted_hub = load("res://scenes/street_hub.tscn").instantiate()
	root.add_child(interrupted_hub)
	current_scene = interrupted_hub
	await frames()
	interrupted_hub.queue_free()
	await frames()
	check(not session.complete_leave(interrupted_id) and session.events().is_empty(),"destroying unfinished presentation cancels its event")
	var direct_hub = load("res://scenes/street_hub.tscn").instantiate()
	root.add_child(direct_hub)
	current_scene = direct_hub
	await frames(100)
	check(direct_hub.ready_for_restart and session.events().is_empty(),"opening hub directly cannot award an outcome")
	await tap(KEY_E)
	await frames(100)
	for context in range(5):
		var roof = current_scene
		check(roof.scene_file_path == "res://scenes/rooftop.tscn","cycle starts on roof " + str(context))
		if context > 0:
			roof.player.position.x = 236.0
			await frames()
			await tap(KEY_E)
		if context > 1:
			await tap(KEY_2)
			await tap(KEY_E)
			await tap(KEY_3)
		if context > 2: await tap(KEY_E)
		if context > 3: await tap(KEY_2)
		roof.player.position.x = 34.0
		await frames()
		await tap(KEY_E)
		var hub = current_scene
		if hub == roof:
			check(false,"exit begins departure scene")
			quit(1)
			return
		check(hub.scene_file_path == "res://scenes/street_hub.tscn" and not hub.ready_for_restart,"departure uses existing street before enabling hub")
		var origin: Vector2 = hub.player.position
		var observed: Array[int] = []
		var focus_checked := false
		var wait_seen := false
		var turn_seen := false
		for i in range(180):
			if hub.ready_for_restart: break
			var stage: int = hub.leave_stage
			if observed.is_empty() or observed.back() != stage:
				observed.append(stage)
				check(session.events().size() == context,"unfinished stage cannot record outcome " + str(stage))
			if i == 0:
				check(not hub.get_node("Controls").visible and hub.phase == hub.Phase.ARRIVING,"hub input remains blocked during leave stage " + str(stage))
			if stage == hub.LeaveStage.WAITING:
				wait_seen = hub.get_node("Hub").visible and hub.get_node("Hub/PLACEHOLDER_NON_CANON/Look").scale.x == -1.0
				if context == 2 and not focus_checked:
					root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
					await frames(30)
					check(hub.leave_stage == stage and session.events().size() == context,"focus loss pauses departure before recording")
					root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
					focus_checked = true
			if stage == hub.LeaveStage.TURNING:
				turn_seen = hub.get_node("Hub").visible and hub.get_node("Hub/PLACEHOLDER_NON_CANON/Look").scale.x == 1.0
			key(KEY_E,true)
			key(KEY_ESCAPE,true)
			key(KEY_D,true)
			await frames(1)
			key(KEY_E,false)
			key(KEY_ESCAPE,false)
			key(KEY_D,false)
		check(observed == [hub.LeaveStage.LEAVING,hub.LeaveStage.WAITING,hub.LeaveStage.IMPACT_CUE,hub.LeaveStage.TURNING,hub.LeaveStage.TRANSITION],"ordinary departure stages remain in canonical order " + str(context))
		check(wait_seen and turn_seen and hub.player.position == origin,"frame stays on hero and existing facing marker turns after cue")
		check(hub.ready_for_restart and hub.phase == hub.Phase.IDLE and hub.device_state == hub.DeviceState.CLOSED,"repeated inputs cannot skip departure or open player")
		check(session.events().size() == context+1,"departure records exactly one event " + str(context))
		var event: Dictionary = session.events().back()
		check(event.outcome == &"ordinary_leave" and event.technical_presentation,"event explicitly describes a technical ordinary leave")
		check(not session.complete_leave(event.departure_id) and session.events().size() == context+1,"duplicate completion cannot record twice")
		await tap(KEY_SPACE)
		check(hub.get_node("Inspection").text.contains("Осмотр:"),"hub inspection works after departure")
		await tap(KEY_ESCAPE)
		await frames(18)
		check(hub.device_state == hub.DeviceState.OPEN,"hub player opens after departure")
		await tap(KEY_ESCAPE)
		await frames(18)
		check(hub.device_state == hub.DeviceState.CLOSED,"hub player closes after departure")
		await tap(KEY_E)
		await frames(100)
		check(current_scene.scene_file_path == "res://scenes/rooftop.tscn" and session.events().size() == context+1,"new roof retains session history without saving")
	var copy: Array = session.events()
	copy[0]["outcome"] = &"changed"
	check(session.events()[0].outcome == &"ordinary_leave","event snapshots cannot mutate session history")
	print("Ordinary leave failures: ",failures)
	quit(0 if failures == 0 else 1)
