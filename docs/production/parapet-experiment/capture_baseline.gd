extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func capture(label: String) -> void:
	for i in range(5):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	assert(current_scene.scene_file_path == 'res://scenes/rooftop.tscn')
	if label == '02-dialogue': assert(current_scene.dialogue.visible)
	var error := root.get_texture().get_image().save_png('/workspace/scratch/parapet-experiment/baseline/' + label + '.png')
	print('CAPTURE ',label,' error=',error,' logical_size=',root.get_texture().get_size())
func run() -> void:
	root.size = Vector2i(960,720)
	var roof = load('res://scenes/rooftop.tscn').instantiate()
	root.add_child(roof)
	current_scene = roof
	await capture('01-entry')
	roof.player.position.x = 236.0
	for i in range(5): await physics_frame
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await capture('02-dialogue')
	e = InputEventKey.new()
	e.physical_keycode = KEY_E
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	for i in range(3): await physics_frame
	roof.player.position.x = 34.0
	for i in range(5): await physics_frame
	await capture('03-exit')
	quit()
