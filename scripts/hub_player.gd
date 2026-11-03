extends Node2D
## PLACEHOLDER_NON_CANON: physical device shell; no audio or progress data.

signal close_requested


func _ready() -> void:
	$Back.pressed.connect(_request_close)
	hide_device()


func show_device() -> void:
	show()


func hide_device() -> void:
	hide()


func _request_close() -> void:
	if is_visible_in_tree():
		close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var shape := $Back.shape as RectangleShape2D
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2($Back.position - shape.size * 0.5, shape.size).has_point(local_position):
			_request_close()
			get_viewport().set_input_as_handled()
