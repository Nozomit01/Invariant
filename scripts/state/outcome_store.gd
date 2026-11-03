extends RefCounted
## Immutable completed-outcome receipts. Existing files are never replaced or removed.
const DEFAULT_PATH := "user://outcomes_v1"
const RECORD := {"version": 1, "outcome": "leave", "completed": true}
var _path: String

func _init(path: String = DEFAULT_PATH) -> void:
	_path = path

func completed_outcomes() -> Array[String]:
	var directory := DirAccess.open(_path)
	if directory == null:
		return []
	for child in directory.get_directories():
		if not child.begins_with("receipt-") or directory.is_link(child):
			continue
		var folder := _path.path_join(child)
		var receipt_dir := DirAccess.open(folder)
		if receipt_dir != null and not receipt_dir.is_link("confirmed.json") and _valid_record(folder.path_join("confirmed.json")):
			return ["leave"]
	return []

func confirm_leave() -> Error:
	if not completed_outcomes().is_empty():
		return OK
	var error := DirAccess.make_dir_recursive_absolute(_path)
	if error != OK:
		return error
	# Atomic directory creation reserves a private destination, including across processes.
	var folder := ""
	for attempt in range(4):
		var candidate := _path.path_join("receipt-" + Crypto.new().generate_random_bytes(16).hex_encode())
		error = DirAccess.make_dir_absolute(candidate)
		if error == OK:
			folder = candidate
			break
		if error != ERR_ALREADY_EXISTS:
			return error
	if folder.is_empty():
		return ERR_ALREADY_EXISTS
	var pending := folder.path_join("record.pending")
	var confirmed := folder.path_join("confirmed.json")
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(RECORD))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	if not _valid_record(pending):
		return ERR_FILE_CORRUPT
	# Only our newly created pending file is renamed; no old save is a target.
	if FileAccess.file_exists(confirmed) or DirAccess.dir_exists_absolute(confirmed):
		return ERR_ALREADY_EXISTS
	error = DirAccess.rename_absolute(pending, confirmed)
	if error != OK:
		return error
	return OK if _valid_record(confirmed) else ERR_FILE_CORRUPT

func _valid_record(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() > 4096:
		file.close()
		return false
	var content := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return false
	var data = parser.data
	if not data is Dictionary or data.size() != 3:
		return false
	var version = data.get("version")
	return (version is int or version is float) and version == 1 and data.get("outcome") == "leave" and data.get("completed") is bool and data.completed
