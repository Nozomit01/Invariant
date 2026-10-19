extends Node2D
## G2/G3 with a local G4 run state; PLACEHOLDER_NON_CANON.

const RunState = preload("res://scripts/state/run_state.gd")
const DialogueData = preload("res://data/dialogue/g3_test_dialogue.gd")

const SPEED := 80.0
const ACCELERATION := 520.0
const BRAKING := 700.0
const LEFT_EDGE := 22.0
const RIGHT_EDGE := 298.0
const INTERACTION_DISTANCE := 26.0

var horizontal_speed := 0.0
var run_state = RunState.new()
var demo_page := 0

@onready var player: Node2D = $PLACEHOLDER_NON_CANON
@onready var interaction_point: Node2D = $InteractionPoint
@onready var prompt: Label = $UI/Prompt
@onready var dialogue = $UI/Dialogue


func _ready() -> void:
	dialogue.choice_selected.connect(_on_dialogue_choice)
	start_new_run()


func start_new_run() -> void:
	run_state.reset()
	demo_page = 0
	dialogue.stop()


func _on_dialogue_choice(index: int) -> void:
	if index == 2:
		return # Conscious silence has no assigned emotional effect in this probe.
	var event: StringName = DialogueData.DEMOS[demo_page][index]["event"]
	var reaction: StringName = run_state.apply_event(event)
	dialogue.show_reaction(DialogueData.REACTIONS[event][reaction])
	demo_page = (demo_page + 1) % DialogueData.DEMOS.size()


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var rate := ACCELERATION if not is_zero_approx(direction) else BRAKING
	horizontal_speed = move_toward(horizontal_speed, direction * SPEED, rate * delta)
	var next_x := player.position.x + horizontal_speed * delta
	player.position.x = clampf(next_x, LEFT_EDGE, RIGHT_EDGE)
	if next_x < LEFT_EDGE or next_x > RIGHT_EDGE:
		horizontal_speed = 0.0

	var nearby := absf(player.position.x - interaction_point.position.x) <= INTERACTION_DISTANCE
	if not nearby:
		dialogue.stop()
	elif Input.is_action_just_pressed("interact"):
		dialogue.start(demo_page)
	elif dialogue.awaiting_choice:
		for index in range(3):
			if Input.is_action_just_pressed("dialogue_choice_" + str(index + 1)):
				dialogue.choose(index)
				break
	prompt.visible = nearby and not dialogue.visible
	$UI/PointLabel.visible = not dialogue.visible
