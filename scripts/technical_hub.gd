extends Node2D
## PLACEHOLDER_NON_CANON: stationary technical hub, not the GDD's full hub.

const SceneSwitch = preload("res://scripts/technical_scene_switch.gd")
var ready_for_restart := false
var returning := false


func _ready() -> void:
	$Hub.hide()
	$Transition.show()
	# A short UI transition only; no narrative time or ending is simulated.
	await get_tree().create_timer(0.35).timeout
	SceneSwitch.release_pressed_input()
	$Transition.hide()
	$Hub.show()
	ready_for_restart = true


func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_restart or returning:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		returning = true
		SceneSwitch.go_to.call_deferred(self, "res://scenes/rooftop.tscn")
