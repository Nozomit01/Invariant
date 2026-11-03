extends RefCounted
## Session departures stay in memory; only a completed main outcome is persisted.
const OutcomeStore = preload("res://scripts/state/outcome_store.gd")
static var _store = OutcomeStore.new()
static var last_save_error: Error = OK
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
	last_save_error = _store.confirm_leave()
	return true

static func events() -> Array[Dictionary]:
	return _events.duplicate(true)

static func completed_outcomes() -> Array[String]:
	# A disk failure must not erase the outcome actually completed this session.
	if not _events.is_empty():
		return ["leave"]
	return _store.completed_outcomes()
