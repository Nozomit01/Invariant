extends RefCounted
## In-memory technical events only. No autoload, save file, unlocks or ending UI.
static var _next_id := 1
static var _active_id := 0
static var _claimed := false
static var _events: Array[Dictionary] = []

static func begin_leave() -> int:
	if _active_id == 0:
		_active_id = _next_id
		_next_id += 1
		_claimed = false
	return _active_id

static func claim_leave() -> int:
	if _claimed:
		return 0
	_claimed = _active_id != 0
	return _active_id

static func cancel_leave(departure_id: int) -> void:
	if departure_id == _active_id:
		_active_id = 0
		_claimed = false

static func complete_leave(departure_id: int) -> bool:
	if departure_id == 0 or departure_id != _active_id or not _claimed:
		return false
	_events.append({"departure_id": departure_id, "outcome": &"ordinary_leave", "technical_presentation": true})
	cancel_leave(departure_id)
	return true

static func events() -> Array[Dictionary]:
	return _events.duplicate(true)
