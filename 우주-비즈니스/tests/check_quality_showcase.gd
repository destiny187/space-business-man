extends SceneTree
## Load and construct the actual standalone scene without touching campaign saves.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: PackedScene = load("res://scenes/showcase/quality_showcase.tscn")
	assert(scene != null)
	var instance := scene.instantiate()
	root.add_child(instance)
	assert(instance.get_node_or_null("HeroM07") != null)
	assert(instance.camera != null)
	for i in range(3):
		instance.set_shot(i)
		assert(instance.camera.position.is_finite())
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	instance._unhandled_input(event)
	assert(instance.orbit)
	event.keycode = KEY_H
	instance._unhandled_input(event)
	assert(not instance.overlay.visible)
	print("SHOWCASE_CHECK_PASS: construction, hero, three cameras, orbit and UI toggle")
	instance.queue_free()
	await process_frame
	quit()
