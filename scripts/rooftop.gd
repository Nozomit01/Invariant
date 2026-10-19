extends Node2D
## G2 movement with one G3 technical exchange; PLACEHOLDER_NON_CANON.

const SPEED := 80.0
const ACCELERATION := 520.0
const BRAKING := 700.0
const LEFT_EDGE := 22.0
const RIGHT_EDGE := 298.0
const INTERACTION_DISTANCE := 26.0

var horizontal_speed := 0.0

@onready var player: Node2D = $PLACEHOLDER_NON_CANON
@onready var interaction_point: Node2D = $InteractionPoint
@onready var prompt: Label = $UI/Prompt
@onready var dialogue = $UI/Dialogue


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
		dialogue.start()
	elif dialogue.awaiting_choice:
		for index in range(3):
			if Input.is_action_just_pressed("dialogue_choice_" + str(index + 1)):
				dialogue.choose(index)
				break
	prompt.visible = nearby and not dialogue.visible
	$UI/PointLabel.visible = not dialogue.visible
