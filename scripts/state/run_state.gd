extends RefCounted
## One run's hidden state. Unit increments are technical probes, not balance.

const EVENT_TARGETS := {
	&"sensitive_topic": &"anxiety",
	&"pressure": &"anger",
	&"canned_advice": &"boredom",
	&"functional_treatment": &"apathy",
}

var _values: Dictionary[StringName, int] = {
	&"anxiety": 0,
	&"anger": 0,
	&"boredom": 0,
	&"apathy": 0,
}


func apply_event(event: StringName) -> StringName:
	if not EVENT_TARGETS.has(event):
		return &"ignored"
	var parameter: StringName = EVENT_TARGETS[event]
	_values[parameter] += 1
	return &"first" if _values[parameter] == 1 else &"repeated"


func reset() -> void:
	for parameter in _values:
		_values[parameter] = 0


func snapshot() -> Dictionary:
	# Copy for tests/debugging only; the dialogue UI never reads these values.
	return _values.duplicate()
