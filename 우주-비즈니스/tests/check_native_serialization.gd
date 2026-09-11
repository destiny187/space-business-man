extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	load("res://tests/native_biota_fixture.gd").prepare()
	var world:=FrontierUniverse.new_world(71491)
	var before: Dictionary=world.manifest
	var after: Dictionary=JSON.parse_string(JSON.stringify(world,"",true,true)).manifest
	print("SERIAL ",world.manifest_hash," ",FrontierUniverse.fingerprint(before)," ",FrontierUniverse.fingerprint(after))
	FileAccess.open("/tmp/biota-serialized-before.json",FileAccess.WRITE).store_string(JSON.stringify(JSON.parse_string(JSON.stringify(before)),"",true))
	FileAccess.open("/tmp/biota-serialized-after.json",FileAccess.WRITE).store_string(JSON.stringify(JSON.parse_string(JSON.stringify(after)),"",true))
	quit(0 if FrontierUniverse.fingerprint(before)==FrontierUniverse.fingerprint(after) else 1)
