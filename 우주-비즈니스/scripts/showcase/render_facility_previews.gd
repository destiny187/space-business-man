extends SceneTree
## Refresh only the four changed facility cards with the production INK renderer.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(960,800)
	var scene: Node=load("res://scenes/showcase/ink_catalog.tscn").instantiate()
	root.add_child(scene);await process_frame
	for kind in ["atmosphere","thermal","water","biolab"]:
		for i in scene.samples.size():
			if scene.samples[i].id!=kind:continue
			scene.select_sample(i);scene.canvas.hide()
			await create_timer(.25).timeout;await RenderingServer.frame_post_draw
			var image:=root.get_texture().get_image();image.resize(480,400,Image.INTERPOLATE_LANCZOS)
			image.save_png("res://assets/ui/previews/"+kind+".png")
			print("FACILITY_PREVIEW ",kind);break
	quit()
