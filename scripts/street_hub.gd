extends Node2D
## PLACEHOLDER_NON_CANON: street, physical player shell and scripted return.

const SceneSwitch = preload("res://scripts/technical_scene_switch.gd")
const PREFIX := "PLACEHOLDER_NON_CANON\n"
const POINT_NAMES := ["Улица", "Дом", "Вход"]
enum Phase { ARRIVING, IDLE, DISCARDING, EXTINGUISHING, ENTERING, TRANSITION, ROOF_DOOR }
enum DeviceState { CLOSED, OPENING, OPEN, CLOSING }

var phase := Phase.ARRIVING
var selected_point := 1
var cigarette_lit := true
var ready_for_restart := false
var device_state := DeviceState.CLOSED
var _active_touches: Dictionary = {}
var _close_animation_finished := false

@onready var player: Node2D = $Hub/PLACEHOLDER_NON_CANON
@onready var cigarette: Node2D = $Hub/PLACEHOLDER_NON_CANON/Cigarette


func _ready() -> void:
	$Hub.hide()
	$Controls.hide()
	$Transition.show()
	$Hub/PLACEHOLDER_NON_CANON/BagAccess.pressed.connect(_request_player_open)
	$PlayerView.close_requested.connect(_request_player_close)
	_set_phase(Phase.ARRIVING, "Переход на улицу")
	for index in range(POINT_NAMES.size()):
		var point := $Hub/Points.get_child(index) as TouchScreenButton
		point.pressed.connect(_on_point_tapped.bind(index))
	await get_tree().create_timer(0.35).timeout
	SceneSwitch.release_pressed_input()
	$Transition.hide()
	$Hub.show()
	$Controls.show()
	_set_phase(Phase.IDLE, "Стоит и курит")
	ready_for_restart = true
	_select_point(1)


func _input(event: InputEvent) -> void:
	# Hiding a TouchScreenButton releases its action, not the actual finger.
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = true
		else:
			_active_touches.erase(event.index)
			_try_finish_player_close.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_focus_input.call_deferred()


func _release_focus_input() -> void:
	_active_touches.clear()
	# Godot retains TouchScreenButton finger ownership if the OS loses release.
	# Preserve visibility, but reset the actual controls as well as our tracker.
	for button in find_children("*", "TouchScreenButton", true, false):
		if button.visible:
			button.hide()
			button.show()
	SceneSwitch.release_pressed_input()
	_try_finish_player_close()


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.IDLE or event.is_echo():
		return
	if event.is_action_pressed("hub_player_toggle"):
		if device_state == DeviceState.CLOSED:
			_request_player_open()
		elif device_state == DeviceState.OPEN:
			_request_player_close()
		get_viewport().set_input_as_handled()
		return
	if not _can_use_hub():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var bag := $Hub/PLACEHOLDER_NON_CANON/BagAccess as TouchScreenButton
		var shape := bag.shape as RectangleShape2D
		var local_position: Vector2 = bag.get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(-shape.size * 0.5, shape.size).has_point(local_position):
			_request_player_open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_begin_return()
	elif event.is_action_pressed("move_left"):
		_select_point(maxi(0, selected_point - 1))
	elif event.is_action_pressed("move_right"):
		_select_point(mini(POINT_NAMES.size() - 1, selected_point + 1))
	elif event.is_action_pressed("hub_inspect"):
		_inspect()


func _select_point(index: int) -> void:
	if not _can_use_hub():
		return
	selected_point = index
	$Inspection.text = PREFIX + "Выбрано: " + POINT_NAMES[index]
	for point_index in range(POINT_NAMES.size()):
		var point := $Hub/Points.get_child(point_index) as TouchScreenButton
		point.modulate = Color(1.0, 0.85, 0.4) if point_index == index else Color.WHITE
	var target := $Hub/Points.get_child(index) as Node2D
	$Hub/PLACEHOLDER_NON_CANON/Look.scale.x = -1.0 if target.position.x < player.position.x else 1.0


func _on_point_tapped(index: int) -> void:
	if _can_use_hub():
		_select_point(index)
		_inspect()


func _inspect() -> void:
	if _can_use_hub():
		$Inspection.text = PREFIX + "Осмотр: " + POINT_NAMES[selected_point] + " (заглушка)"


func _can_use_hub() -> bool:
	return phase == Phase.IDLE and device_state == DeviceState.CLOSED


func _request_player_open() -> void:
	if not _can_use_hub():
		return
	device_state = DeviceState.OPENING
	ready_for_restart = false
	$Controls.hide()
	$Hub/Points.hide()
	$Inspection.hide()
	SceneSwitch.release_pressed_input.call_deferred()
	var held := $Hub/PLACEHOLDER_NON_CANON/HeldPlayer as Node2D
	held.position = Vector2(12, 2)
	held.show()
	await _animate(held, "position", Vector2(12, -16), 0.20)
	$PlayerView.show_device()
	device_state = DeviceState.OPEN


func _request_player_close() -> void:
	if device_state != DeviceState.OPEN:
		return
	device_state = DeviceState.CLOSING
	_close_animation_finished = false
	$PlayerView.hide_device()
	SceneSwitch.release_pressed_input.call_deferred()
	await _animate($Hub/PLACEHOLDER_NON_CANON/HeldPlayer, "position", Vector2(12, 2), 0.20)
	$Hub/PLACEHOLDER_NON_CANON/HeldPlayer.hide()
	_close_animation_finished = true
	_try_finish_player_close()


func _try_finish_player_close() -> void:
	if device_state != DeviceState.CLOSING or not _close_animation_finished or not _active_touches.is_empty():
		return
	device_state = DeviceState.CLOSED
	_close_animation_finished = false
	$Controls.show()
	$Hub/Points.show()
	$Inspection.show()
	ready_for_restart = true


func _set_phase(next_phase: Phase, description: String) -> void:
	phase = next_phase
	$Status.text = PREFIX + description


func _animate(node: Node, property: NodePath, destination: Variant, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, property, destination, duration)
	await tween.finished


func _begin_return() -> void:
	if not _can_use_hub():
		return
	ready_for_restart = false
	_set_phase(Phase.DISCARDING, "Выбрасывает сигарету")
	$Controls.hide()
	$Hub/Points.hide()
	$Inspection.hide()
	SceneSwitch.release_pressed_input.call_deferred()
	cigarette.reparent($Hub)
	await _animate(cigarette, "position", Vector2(player.position.x + 12, 170), 0.22)
	_set_phase(Phase.EXTINGUISHING, "Тушит сигарету")
	await _animate($Hub/PLACEHOLDER_NON_CANON/Foot, "position:x", 12.0, 0.16)
	cigarette_lit = false
	cigarette.modulate = Color(0.25, 0.25, 0.25)
	await _animate($Hub/PLACEHOLDER_NON_CANON/Foot, "position:x", 3.0, 0.10)
	_set_phase(Phase.ENTERING, "Направляется в дом")
	await _animate(player, "position:x", 250.0, 0.48)
	_set_phase(Phase.TRANSITION, "Переход в дом")
	$Hub.hide()
	$Transition.text = PREFIX + "Переход в дом"
	$Transition.show()
	await get_tree().create_timer(0.18).timeout
	_set_phase(Phase.ROOF_DOOR, "Открывается дверь крыши")
	$Transition.text = PREFIX + "Дверь крыши"
	$RoofDoor.show()
	await _animate($RoofDoor, "scale:x", 0.08, 0.24)
	SceneSwitch.go_to.call_deferred(self, "res://scenes/rooftop.tscn")
