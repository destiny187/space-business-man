extends SceneTree
const Batch=preload("res://scripts/actors/static_mineral_batch.gd")
var failures:=0
var folder:=""
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func frames() -> void:
	for i in 16:await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-root="):folder=arg.trim_prefix("--audit-root=")
	if folder.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(960,640);root.disable_3d=true
	var viewport:=SubViewport.new();viewport.size=root.size;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var picture:=TextureRect.new();picture.texture=viewport.get_texture();root.add_child(picture)
	var stage:=Node3D.new();viewport.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("52677a");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.shadow_enabled=true;stage.add_child(sun)
	var camera:=Camera3D.new();stage.add_child(camera);camera.current=true
	FrontierInkStyle.attach(stage)
	var style: Dictionary={};var cache: Dictionary={};var results: Array=[]
	for distance in [12.0,45.0]:
		var items: Array[Node3D]=[];var names: Array[String]=["ore_iron","ore_stone","ore_copper"]
		for i in names.size():
			var item: Node3D=load("res://assets/models/"+names[i]+".glb").instantiate();FrontierInkStyle.apply(item,style);stage.add_child(item);item.position.x=(i-1)*4.0;item.rotation.y=.37;items.append(item)
		camera.position=Vector3(0,distance*.35,distance);camera.look_at(Vector3(0,1,0))
		await frames()
		var before:=viewport.get_texture().get_image();before.convert(Image.FORMAT_RGBA8)
		var draws:=viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var merged:=true
		for i in items.size():merged=Batch.apply(items[i],cache,names[i]) and merged
		await frames()
		var after:=viewport.get_texture().get_image();after.convert(Image.FORMAT_RGBA8)
		var next_draws:=viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var a:=before.get_data();var b:=after.get_data();var error:=0.0;var changed:=0
		for i in range(0,a.size(),4):
			var delta:=absi(a[i]-b[i])+absi(a[i+1]-b[i+1])+absi(a[i+2]-b[i+2]);error+=delta
			if delta>15:changed+=1
		var average:=error/(float(a.size()/4)*3.0*255.0)
		check(merged and next_draws<draws,"ore parts use fewer draw calls at "+str(distance)+"m")
		check(average<.003 and changed<float(a.size()/4)*.01,"batched ore preserves rendered shape and shading at "+str(distance)+"m")
		results.append({"distance":distance,"draws_before":draws,"draws_after":next_draws,"mean_rgb_error":average,"changed_pixels":changed})
		before.save_png(folder+"/ore-before-"+str(int(distance))+".png");after.save_png(folder+"/ore-after-"+str(int(distance))+".png")
		for item in items:item.queue_free()
		await process_frame
	FileAccess.open(folder+"/mineral-batch.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	viewport.queue_free();await process_frame
	quit(1 if failures else 0)
