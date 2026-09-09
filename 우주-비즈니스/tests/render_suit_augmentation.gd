extends SceneTree
var out: String="res://../docs/production/media/suit-augmentation/"
var appearances: Array[FrontierSuitAppearance]=[]
var models: Array[Node3D]=[]
var labels: Array[Label]=[]
var poses: Array[FrontierCrewPose]=[]
func _initialize() -> void:run.call_deferred()
func member(points: int) -> Dictionary:
	var own: Dictionary={"augmentation":FrontierCrewAugmentation.create(),"profile":{"tint":0}}
	for keys in FrontierSuitAppearance.config().branches.values():
		var left:=points
		for key in keys:own.augmentation.levels[key]=mini(left,5);left=maxi(0,left-5)
	return own
func shot(name_value: String) -> void:
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out+name_value+".png"))
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.msaa_3d=Viewport.MSAA_4X
	var stage:=Node3D.new();root.add_child(stage);current_scene=stage
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("15232b");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c2d5d8");env.ambient_light_energy=.6;world.environment=env;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-30,0);sun.light_energy=1.3;sun.shadow_enabled=true;stage.add_child(sun)
	var plane:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(100,100);plane.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("344a51");plane.material_override=FrontierInkStyle.material(mat,{});stage.add_child(plane)
	var camera:=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9.6;camera.keep_aspect=Camera3D.KEEP_WIDTH;stage.add_child(camera);camera.position=Vector3(0,2.8,10);camera.look_at(Vector3(0,.9,0));FrontierInkStyle.attach(stage,true)
	var canvas:=CanvasLayer.new();stage.add_child(canvas)
	var heading:=Label.new();heading.text="SURVEYOR  /  강화 외장 0–5단계";heading.position=Vector2(30,28);heading.add_theme_font_size_override("font_size",24);heading.theme=FrontierInterfaceStyle.theme();canvas.add_child(heading)
	var thresholds: Array=[0]+FrontierSuitAppearance.config().thresholds
	for i in 6:
		var model: Node3D=load("res://assets/models/"+FrontierSuitAppearance.config().model+".glb").instantiate();stage.add_child(model);model.position=Vector3((i-2.5)*1.5,0,0);model.rotation.y=PI;FrontierInkStyle.apply(model,{})
		var look:=FrontierSuitAppearance.new();look.configure(model);look.sync(member(thresholds[i]));appearances.append(look);models.append(model)
		assert(look.layers.size()==15);assert(look.paints.size()==18)
		assert(look.layers.keys().filter(func(node):return node.visible).size()==i*3)
		var pose:=FrontierCrewPose.new();stage.add_child(pose);pose.position=model.position;pose.configure(model);poses.append(pose);assert(pose.bones.size()==13)
		var label:=Label.new();label.text="%d단계"%i;label.theme=FrontierInterfaceStyle.theme();label.position=Vector2(100+i*200,610);canvas.add_child(label);labels.append(label)
	await shot("stages-ink")
	for i in 6:
		appearances[i].sync(member(16));labels[i].text=["대기","걷기","달리기","점프","수영","물에 뜨기"][i]
		var motion:=FrontierCrewLocomotion.create();motion.yaw=PI;motion.grounded=i<3;motion.state=["idle","walk","run","rise","swim","tread"][i];motion.phase=1.1;motion.swim_phase=.8;motion.velocity=[0,2 if i==3 else 0,-(5 if i==2 else 2)]
		for frame in 45:poses[i].animate(motion,1.0/60,false,false)
	heading.text="기존 관절 유지  /  대기 · 걷기 · 달리기 · 점프 · 수영 · 물에 뜨기"
	await shot("poses-ink")
	for i in 6:
		poses[i].reset();models[i].rotation.y=PI
		labels[i].text=["헬멧","흉부","팔","다리","배낭 (후면)","벨트"][i]
		if i==4:models[i].rotation.y=0
		var keys: Array=FrontierSuitAppearance.config().parts.keys();var colors: Array=["df783b","597ac9","ad4566","e1b65e","acc8bd","9f85b8"]
		assert(appearances[i].set_dye(keys[i],"primary",Color(colors[i])))
		assert(appearances[i].set_dye(keys[i],"secondary",Color(colors[i]).darkened(.3)))
		appearances[i].sync(member(16))
	heading.text="염색 연결 준비  /  헬멧 · 흉부 · 팔 · 다리 · 배낭 · 벨트"
	await shot("dye-parts-ink")
	assert(appearances[0].paints["DYE::chest::primary"]!=appearances[1].paints["DYE::chest::primary"])
	print("SUIT_ART_CHECK stages=6 bones=13 layers=15 dye_slots=18 isolated_materials=PASS")
	quit()
