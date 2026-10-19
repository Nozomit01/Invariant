extends Node2D
## A single technical exchange, with no global dialogue framework.

const DATA = preload("res://data/dialogue/g3_test_dialogue.gd")

var awaiting_choice := false
var line := Label.new()
var choices: Array[TouchScreenButton] = []


func _ready() -> void:
	line.name = "Line"
	line.position = Vector2(12, 28)
	line.size = Vector2(296, 28)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 10)
	add_child(line)
	for index in range(DATA.CHOICES.size()):
		var button := TouchScreenButton.new()
		button.name = "Choice" + str(index + 1)
		button.position = Vector2(160, 74 + index * 34)
		button.action = "dialogue_choice_" + str(index + 1)
		button.shape = RectangleShape2D.new()
		button.shape.size = Vector2(288, 30)
		button.shape_visible = false
		var background := Polygon2D.new()
		background.polygon = PackedVector2Array([
			Vector2(-144, -15), Vector2(144, -15), Vector2(144, 15), Vector2(-144, 15)
		])
		background.color = Color(0.28, 0.32, 0.36)
		button.add_child(background)
		var label := Label.new()
		label.name = "Label"
		label.position = Vector2(-144, -15)
		label.size = Vector2(288, 30)
		label.text = DATA.CHOICES[index]["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 10)
		button.add_child(label)
		add_child(button)
		choices.append(button)
	stop()


func start() -> void:
	line.text = DATA.OPENING
	awaiting_choice = true
	visible = true
	_show_choices(true)


func stop() -> void:
	awaiting_choice = false
	visible = false
	line.text = ""
	_show_choices(false)


func choose(index: int) -> void:
	if not awaiting_choice or index < 0 or index >= DATA.CHOICES.size():
		return
	line.text = DATA.CHOICES[index]["reaction"]
	awaiting_choice = false
	_show_choices(false)


func _show_choices(show_choices: bool) -> void:
	for button in choices:
		button.visible = show_choices
