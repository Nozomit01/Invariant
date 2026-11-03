extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func write_fixture(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
func run() -> void:
	if not ResourceLoader.exists("res://scripts/state/outcome_store.gd"):
		check(false,"persistent outcome store exists")
		quit(1)
		return
	var store_script = load("res://scripts/state/outcome_store.gd")
	var sandbox := "user://save-test-" + Crypto.new().generate_random_bytes(16).hex_encode()
	if DirAccess.make_dir_absolute(sandbox) != OK:
		check(false,"test fixture directory must be newly reserved")
		quit(1)
		return
	var path := sandbox.path_join("store")
	var store = store_script.new(path)
	check(store.completed_outcomes().is_empty() and not DirAccess.dir_exists_absolute(path),"missing store loads empty without writing")
	write_fixture(path + "/personal.txt","KEEP THIS FILE")
	write_fixture(path + "/receipt-broken/confirmed.json","{")
	var valid := '{"version":1,"outcome":"leave","completed":true}'
	write_fixture(path + "/receipt-pending/record.pending",valid)
	write_fixture(path + "/receipt-future/confirmed.json",valid.replace('"version":1','"version":2'))
	write_fixture(path + "/receipt-other/confirmed.json",valid.replace('"leave"','"jump"'))
	write_fixture(path + "/receipt-started/confirmed.json",valid.replace('true','false'))
	write_fixture(path + "/receipt-wrong-type/confirmed.json",valid.replace('true','1'))
	check(store.completed_outcomes().is_empty(),"broken pending unknown and incomplete records cannot award an outcome")
	check(store.confirm_leave() == OK,"completed leave persists beside existing files")
	check(store_script.new(path).completed_outcomes() == ["leave"],"independent store reloads one completed leave")
	var directory := DirAccess.open(path)
	var before := directory.get_directories()
	check(store.confirm_leave() == OK and directory.get_directories() == before,"repeat does not add another record")
	check(FileAccess.get_file_as_string(path + "/personal.txt") == "KEEP THIS FILE" and FileAccess.get_file_as_string(path + "/receipt-broken/confirmed.json") == "{","existing files remain unchanged")
	write_fixture(path + "/receipt-duplicate/confirmed.json",valid)
	check(store_script.new(path).completed_outcomes() == ["leave"],"duplicate valid records remain one distinct outcome")
	for child in directory.get_directories():
		var record := path.path_join(child).path_join("confirmed.json")
		if FileAccess.file_exists(record) and FileAccess.get_file_as_string(record) == valid:
			write_fixture(record,"corrupt")
	# Also corrupt the actual writer's JSON, whose formatting is deliberately unspecified.
	for child in directory.get_directories():
		var record := path.path_join(child).path_join("confirmed.json")
		if FileAccess.file_exists(record):
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(record)) != OK:
				continue
			var parsed = parser.data
			if parsed is Dictionary and parsed.get("version") == 1 and parsed.get("outcome") == "leave" and parsed.get("completed") is bool and parsed.completed:
				write_fixture(record,"corrupt")
	check(store_script.new(path).completed_outcomes().is_empty(),"corruption cannot fabricate a loaded outcome")
	check(store.confirm_leave() == OK and store_script.new(path).completed_outcomes() == ["leave"],"new confirmed completion can recover beside damaged files")
	check(FileAccess.get_file_as_string(path + "/receipt-duplicate/confirmed.json") == "corrupt","recovery preserves damaged original")
	var blocked := path + "/blocked"
	write_fixture(blocked,"DO NOT OVERWRITE")
	var denied = store_script.new(blocked)
	check(denied.confirm_leave() != OK and denied.completed_outcomes().is_empty(),"unwritable destination reports failure without awarding disk progress")
	check(FileAccess.get_file_as_string(blocked) == "DO NOT OVERWRITE","failed save preserves obstructing file")
	print("Leave save failures: ",failures)
	quit(0 if failures == 0 else 1)
