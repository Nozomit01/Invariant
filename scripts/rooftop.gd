extends Node2D
## First conversation with a local G4 state; scene geometry remains placeholder.

const RunState = preload("res://scripts/state/run_state.gd")
const DialogueData = preload("res://data/dialogue/first_conversation.gd")
const SceneSwitch = preload("res://scripts/technical_scene_switch.gd")

const SPEED := 80.0
const ACCELERATION := 520.0
const BRAKING := 700.0
const LEFT_EDGE := 22.0
const RIGHT_EDGE := 298.0
const INTERACTION_DISTANCE := 26.0
const EXIT_DISTANCE := 12.0

var horizontal_speed := 0.0
var run_state = RunState.new()
var demo_page := 0
var dialogue_pages: Array = DialogueData.PAGES
var conversation_finished := false
var leaving := false

@onready var player: Node2D = $PLACEHOLDER_NON_CANON
@onready var interaction_point: Node2D = $InteractionPoint
@onready var prompt: Label = $UI/Prompt
@onready var dialogue = $UI/Dialogue
@onready var exit_point: Node2D = $Exit_PLACEHOLDER_NON_CANON


func _ready() -> void:
	dialogue.choice_selected.connect(_on_dialogue_choice)
	start_new_run()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_focus_input.call_deferred()


func _release_focus_input() -> void:
	# The OS may lose finger releases; clearing actions alone leaves buttons captured.
	for button in find_children("*", "TouchScreenButton", true, false):
		if button.visible:
			button.hide()
			button.show()
	SceneSwitch.release_pressed_input()


func start_new_run() -> void:
	run_state.reset()
	demo_page = 0
	conversation_finished = false
	dialogue.stop()


func _on_dialogue_choice(index: int) -> void:
	if conversation_finished:
		return
	var option: Dictionary = dialogue_pages[demo_page]["choices"][index]
	var reply: String = option["reply"]
	var event: StringName = option.get("event", &"")
	if not event.is_empty():
		var reaction: StringName = run_state.apply_event(event)
		if option.has("replies"):
			reply = option["replies"][reaction]
	dialogue.show_reaction(reply)
	var next_page: int = option["next"]
	conversation_finished = next_page < 0
	if not conversation_finished:
		demo_page = next_page


func _physics_process(delta: float) -> void:
	if leaving:
		return
	var direction := Input.get_axis("move_left", "move_right")
	var rate := ACCELERATION if not is_zero_approx(direction) else BRAKING
	horizontal_speed = move_toward(horizontal_speed, direction * SPEED, rate * delta)
	var next_x := player.position.x + horizontal_speed * delta
	player.position.x = clampf(next_x, LEFT_EDGE, RIGHT_EDGE)
	if next_x < LEFT_EDGE or next_x > RIGHT_EDGE:
		horizontal_speed = 0.0

	var nearby := absf(player.position.x - interaction_point.position.x) <= INTERACTION_DISTANCE
	var near_exit := absf(player.position.x - exit_point.position.x) <= EXIT_DISTANCE
	$UI/ExitPrompt.visible = near_exit
	$UI/Interact/Label.text = "Уйти" if near_exit else "Действие"
	if not near_exit and dialogue.visible and not dialogue.awaiting_choice and not conversation_finished:
		$UI/Interact/Label.text = "Дальше"
	if near_exit and Input.is_action_just_pressed("interact"):
		leaving = true
		dialogue.stop()
		SceneSwitch.go_to.call_deferred(self, "res://scenes/street_hub.tscn")
		return
	if not nearby:
		dialogue.stop()
	elif Input.is_action_just_pressed("interact") and not conversation_finished:
		var page: Dictionary = dialogue_pages[demo_page]
		dialogue.start(page["line"], page["choices"])
	elif dialogue.awaiting_choice:
		for index in range(3):
			if Input.is_action_just_pressed("dialogue_choice_" + str(index + 1)):
				dialogue.choose(index)
				break
	prompt.visible = nearby and not dialogue.visible and not conversation_finished
	$UI/PointLabel.visible = not dialogue.visible
	$UI/ExitLabel.visible = not dialogue.visible
