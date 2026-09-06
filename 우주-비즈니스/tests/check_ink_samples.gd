extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var studio: Node = load("res://scenes/showcase/ink_samples.tscn").instantiate()
	root.add_child(studio)
	for i in range(4):
		studio.select_sample(i)
		assert(studio.stage.get_child_count() == 1)
		var b: AABB = studio.bounds(studio.subject)
		assert(b.size.x > 0 and b.size.y > 0 and b.size.z > 0)
		assert(studio.camera.position.is_finite())
		assert(studio.title.text == studio.SAMPLES[i].title)
		await process_frame
	var toggle := InputEventKey.new()
	toggle.pressed=true
	toggle.keycode=KEY_O
	studio._unhandled_input(toggle)
	assert(is_equal_approx(studio.contour.get_shader_parameter("strength"),0.0))
	studio._unhandled_input(toggle)
	assert(is_equal_approx(studio.contour.get_shader_parameter("strength"),1.0))
	toggle.keycode=KEY_SPACE
	studio._unhandled_input(toggle)
	assert(studio.orbit)
	print("INK_CHECK_PASS: four assets, finite bounds/cameras, one active subject, labels, outline toggle, orbit")
	studio.queue_free()
	await process_frame
	quit()
