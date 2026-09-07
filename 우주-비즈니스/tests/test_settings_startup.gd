extends SceneTree
## Use the engine's initial scene path, rather than adding an already-built scene.
func _initialize() -> void:
	change_scene_to_file("res://scenes/app/main.tscn")
	verify.call_deferred()

func verify() -> void:
	await process_frame
	await process_frame
	var settings := FrontierClientSettings.current(self)
	if settings == null or not settings.is_node_ready():
		printerr("FAIL: settings must be attached and ready after initial scene setup")
		quit(1)
		return
	current_scene.find_child("Settings", true, false).pressed.emit()
	if not settings.is_open():
		printerr("FAIL: title settings button must open the initialized overlay")
		quit(1)
		return
	settings.close()
	# Remove the shared node to cover a direct expedition launch with no title.
	settings.free()
	change_scene_to_file("res://scenes/app/crew_expedition.tscn")
	await process_frame
	await process_frame
	settings = FrontierClientSettings.current(self)
	if settings == null or not settings.is_node_ready():
		printerr("FAIL: direct expedition launch must initialize settings")
		quit(1)
		return
	settings.open()
	if not settings.is_open():
		printerr("FAIL: expedition settings overlay must open")
		quit(1)
		return
	settings.close()
	print("SETTINGS_STARTUP PASS: initial title, settings button, direct expedition")
	quit(0)
