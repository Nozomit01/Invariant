extends Node2D
## PLACEHOLDER_NON_CANON: G6a geometry, inspection and scripted return only.

const SceneSwitch = preload("res://scripts/technical_scene_switch.gd")
const PREFIX := "PLACEHOLDER_NON_CANON\n"
const POINT_NAMES := ["Улица", "Дом", "Вход"]
enum Phase { ARRIVING, IDLE, DISCARDING, EXTINGUISHING, ENTERING, TRANSITION, ROOF_DOOR }

var phase := Phase.ARRIVING
var selected_point := 1
var cigarette_lit := true
var ready_for_restart := false

@onready var player: Node2D = $Hub/PLACEHOLDER_NON_CANON
@onready var cigarette: Node2D = $Hub/PLACEHOLDER_NON_CANON/Cigarette


func _ready() -> void:
	$Hub.hide()
	$Controls.hide()
	$Transition.show()
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


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.IDLE or event.is_echo():
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
	if phase != Phase.IDLE:
		return
	selected_point = index
	$Inspection.text = PREFIX + "Выбрано: " + POINT_NAMES[index]
	for point_index in range(POINT_NAMES.size()):
		var point := $Hub/Points.get_child(point_index) as TouchScreenButton
		point.modulate = Color(1.0, 0.85, 0.4) if point_index == index else Color.WHITE
	var target := $Hub/Points.get_child(index) as Node2D
	$Hub/PLACEHOLDER_NON_CANON/Look.scale.x = -1.0 if target.position.x < player.position.x else 1.0


func _on_point_tapped(index: int) -> void:
	if phase == Phase.IDLE:
		_select_point(index)
		_inspect()


func _inspect() -> void:
	$Inspection.text = PREFIX + "Осмотр: " + POINT_NAMES[selected_point] + " (заглушка)"


func _set_phase(next_phase: Phase, description: String) -> void:
	phase = next_phase
	$Status.text = PREFIX + description


func _animate(node: Node, property: NodePath, destination: Variant, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, property, destination, duration)
	await tween.finished


func _begin_return() -> void:
	if phase != Phase.IDLE:
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
