extends SceneTree
var folder: String
func _initialize() -> void:call_deferred("run")
func capture(id: String) -> void:
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+id+".png")
func label(parent: Node,text: String,p: Vector2,px: int=24) -> Label:
	var node:=Label.new();node.text=text;node.position=p;node.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));node.add_theme_font_size_override("font_size",px);parent.add_child(node);return node
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../docs/production/media/mineral-galaxy");DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800)
	var display:=Control.new();display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(display)
	var background:=ColorRect.new();background.color=Color("02040a");background.size=Vector2(1280,800);display.add_child(background)
	var viewport:=FrontierGalacticCore.preview(display,1024)
	var picture:=TextureRect.new();picture.texture=viewport.get_texture();picture.position=Vector2(0,0);picture.size=Vector2(820,800);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.size=Vector2(820,800);display.add_child(picture)
	label(display,"은하 중심",Vector2(36,30),36)
	label(display,"강착 원반 · 광자 고리 · 극축 제트",Vector2(38,84),19)
	var chart: Control=load("res://scripts/ui/galaxy_chart.gd").new();chart.position=Vector2(880,95);chart.size=Vector2(330,290);chart.manifest=FrontierUniverse.generate(71491);chart.galaxy=true;display.add_child(chart)
	label(display,"하나의 은하 · 1,000,000 행성",Vector2(860,425),22)
	label(display,"지구에서 시작하는 외곽 개척권\n외곽 T1 → 중심 T5 비중 증가\n\n행성별 지질과 광물 구성\n지표 탐사 · 지하 보석 채집",Vector2(860,476),19)
	await capture("galactic-core-game")
	viewport.get_texture().get_image().save_png(folder+"/black-hole-hero.png")
	var core_image:=viewport.get_texture().get_image()
	var bright_gas:=0
	for y in range(0,core_image.get_height(),8):
		for x in range(0,core_image.get_width(),8):
			var pixel:=core_image.get_pixel(x,y)
			if pixel.r>pixel.b*1.5 and pixel.g>.18:bright_gas+=1
	if bright_gas<100:printerr("Black hole emission missing");quit(1);return
	chart._show_core()
	await create_timer(.6).timeout;await RenderingServer.frame_post_draw
	for child in chart.get_children():
		if child is Window:
			child.get_texture().get_image().save_png(folder+"/black-hole-observatory.png")
			child.queue_free()
	if "--core-only" in OS.get_cmdline_user_args():
		print("CORE PREVIEW verified: ",bright_gas," luminous gas samples; live observatory opened")
		quit();return

	display.queue_free();await process_frame
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../test-results/mineral-world.json"))
	var body:=FrontierUniverse.body_from_id(saved.manifest,saved.location)
	var stage:=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();camera.position=Vector3(-12,28,35);camera.look_at_from_position(camera.position,Vector3(0,2,-5));camera.far=400;stage.add_child(camera);camera.current=true;FrontierInkStyle.attach(camera)
	root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("385367");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.5;environment.environment=env;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=1.2;sun.shadow_enabled=true;stage.add_child(sun)
	var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/terrain.gdshader")
	var terrain:=FrontierTerrainStreamer.new();terrain.configure(int(body.streams.terrain),[],material);stage.add_child(terrain);terrain.update_interests([Vector3(0,2,0)])
	var site:=FrontierBusinessSiteView.new();stage.add_child(site);site.configure(terrain,body);site.accept(saved.business)
	var layer:=CanvasLayer.new();stage.add_child(layer);label(layer,"지구 · T1 · "+FrontierMineralWorld.summary(body),Vector2(24,24),22)
	await create_timer(4).timeout
	await capture("earth-resource-field")
	var result={"renderer":RenderingServer.get_current_rendering_method(),"core":"Blender GLB in production chart preview","earth_models":site.nodes.size(),"terrain_chunks":terrain.chunks.size(),"scope":"actual GPU previews and production terrain/resource renderer; no full network playthrough"}
	var output:=FileAccess.open(folder+"/render-verification.json",FileAccess.WRITE);output.store_string(JSON.stringify(result,"\t"));output.close()
	print("GALAXY RENDER ",JSON.stringify(result));quit()
