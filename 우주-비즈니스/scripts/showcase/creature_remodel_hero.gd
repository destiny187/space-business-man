extends SceneTree
## Anatomy-only rendering does not load world, combat or save modules.
const Body=preload("res://scripts/actors/creatures/study_motion_actor.gd")
const Ink=preload("res://scripts/actors/ink_style.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var folder:=ProjectSettings.globalize_path("res://../output/creature-remodel/r01/hero")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X;root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
	var stage:=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;env.background_mode=Environment.BG_COLOR;env.background_color=Color("ced7d0")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("bdccce");env.ambient_light_energy=.52;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.shadow_enabled=true;sun.shadow_bias=.01;sun.shadow_normal_bias=.03;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=24;stage.add_child(sun)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(100,100);floor.mesh=plane;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("bbc6b7");floor.material_override=Ink.material(mat,{});floor.position.y=-.02;stage.add_child(floor)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05;camera.far=30;camera.current=true;stage.add_child(camera);Ink.attach(stage,true)
	var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_embolden=.5
	var title:=Label.new();title.position=Vector2(32,22);title.add_theme_font_override("font",font);title.add_theme_font_size_override("font_size",30);title.add_theme_color_override("font_color",Color("203a36"));root.add_child(title)
	var caption:=Label.new();caption.position=Vector2(34,68);caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",20);caption.add_theme_color_override("font_color",Color("37574d"));root.add_child(caption)
	var forms: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_r01.json")).forms
	for form in forms:
		if not form.id in ["annulus","pentafold","tethermaw"]:continue
		var actor:=Body.new();stage.add_child(actor);actor.load_form(form);title.text=form.name
		caption.text={"annulus":"근육 고리  안쪽 여과관  세 지지발","pentafold":"다섯 방사 관절  발끝 섭식부","tethermaw":"세 목 관절  몸통에서 떨어진 공격 머리"}[form.id]
		var center:=Vector3(0,1.0,.10 if form.id!="tethermaw" else 1.0)
		camera.size=4.8 if form.id!="tethermaw" else 5.6;camera.position=center+Vector3(4.0,3.2,7.5);camera.look_at(center)
		for warmup in 5:actor.advance(1.0/30);await process_frame
		await RenderingServer.frame_post_draw
		var img:=root.get_texture().get_image();img.resize(960,600,Image.INTERPOLATE_LANCZOS);img.save_png(folder+"/"+form.id+".png")
		print("R01_HERO ",form.id);actor.free()
	quit()
