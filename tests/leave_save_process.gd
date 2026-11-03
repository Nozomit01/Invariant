extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func run() -> void:
	var session = load("res://scripts/state/session_outcomes.gd")
	if not session.has_method("completed_outcomes"):
		check(false,"session exposes restored completed outcomes")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var mode := args[0]
	var expected := int(args[1])
	print("USER_DATA_DIR=" + OS.get_user_data_dir())
	check(session.completed_outcomes().size() == expected,"fresh process restores expected distinct outcomes")
	check(session.events().is_empty(),"restoration does not invent session departures")
	if mode == "inspect":
		quit(0 if failures == 0 else 1)
		return
	if mode == "hub":
		var hub = load("res://scenes/street_hub.tscn").instantiate()
		root.add_child(hub)
		current_scene = hub
		await frames(40)
		check(hub.ready_for_restart and session.completed_outcomes().size() == expected,"direct hub is not a completed outcome")
		quit(0 if failures == 0 else 1)
		return
	var roof = load("res://scenes/rooftop.tscn").instantiate()
	root.add_child(roof)
	current_scene = roof
	await frames(3)
	roof.player.position.x = 34.0
	await frames(3)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await frames(3)
	check(session.events().is_empty() and session.completed_outcomes().size() == expected,"starting departure cannot create completion")
	if mode == "interrupt":
		quit(0 if failures == 0 else 1)
		return
	await frames(100)
	check(current_scene.ready_for_restart and session.events().size() == 1,"real departure finishes and activates hub")
	check(session.completed_outcomes() == ["leave"],"completed ordinary variant maps to single leave outcome")
	if mode == "blocked":
		check(session.last_save_error != OK,"save failure is reported")
		check(current_scene.get_node("Status").text.contains("Не удалось сохранить"),"hub exposes failure without blocking gameplay")
		check(current_scene.get_node("Status").get_rect().end.y <= current_scene.get_node("Inspection").position.y,"save error does not overlap hub inspection")
	else:
		check(session.last_save_error == OK,"completed outcome was saved successfully")
	quit(0 if failures == 0 else 1)
