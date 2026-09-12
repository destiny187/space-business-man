extends SceneTree
## Refresh only the ground combat model cards with the production INK renderer.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(960,800)
	var scene: Node=load("res://scenes/showcase/ink_catalog.tscn").instantiate()
	root.add_child(scene);await process_frame
	for kind in ["gun_carbine","gun_pistol","gun_smg","gun_shotgun","gun_lmg","gun_marksman","gun_sniper","gun_plasma","combat_barrier","combat_barricade","combat_cover_kit"]:
		for i in scene.samples.size():
			if scene.samples[i].id!=kind:continue
			scene.select_sample(i);scene.canvas.hide()
			await create_timer(.25).timeout;await RenderingServer.frame_post_draw
			var image:=root.get_texture().get_image();image.save_png("res://../docs/production/media/ground-combat/"+kind+"-godot.png")
			var world: WorldEnvironment=scene.find_children("*","WorldEnvironment",true,false)[0]
			var old_mode:=world.environment.background_mode
			scene.contour.set_shader_parameter("transparent_background",true)
			world.environment.background_mode=Environment.BG_CLEAR_COLOR;RenderingServer.set_default_clear_color(Color.TRANSPARENT);scene.studio_ground.hide()
			var viewport:=SubViewport.new();viewport.size=Vector2i(480,400);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;root.add_child(viewport);scene.reparent(viewport,false);scene.camera.current=true
			await process_frame
			await RenderingServer.frame_post_draw
			image=viewport.get_texture().get_image()
			assert(image.get_pixel(0,0).a<.01,"Icon background must be transparent")
			image.save_png("res://assets/ui/previews/"+kind+".png")
			if kind=="combat_cover_kit":image.save_png("res://assets/ui/resources/"+kind+".png")
			scene.contour.set_shader_parameter("transparent_background",false)
			scene.reparent(root,false);scene.camera.current=true;viewport.queue_free();world.environment.background_mode=old_mode;scene.studio_ground.show()
			print("FACILITY_PREVIEW ",kind);break
	quit()
