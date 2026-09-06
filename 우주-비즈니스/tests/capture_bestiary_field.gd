extends SceneTree
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
const Ink=preload("res://scripts/actors/ink_style.gd")
var scene: Node3D
var camera: Camera3D
var actors: Array=[]
var frames: Array[float]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1280,800)
 root.content_scale_size=Vector2i(1280,800)
 root.msaa_3d=Viewport.MSAA_4X
 root.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
 scene=Node3D.new();root.add_child(scene)
 var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("b8c8b8")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("9db7c8");env.ambient_light_energy=.4
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 env.ssao_enabled=true
 var world:=WorldEnvironment.new();world.environment=env;scene.add_child(world)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-32,0);light.light_energy=1.3;light.shadow_enabled=true;light.directional_shadow_max_distance=70;scene.add_child(light)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);ground.mesh=plane
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("9aa784");ground.material_override=Ink.material(mat,{});ground.position.y=-.04;scene.add_child(ground)
 camera=Camera3D.new();camera.current=true;camera.fov=48;camera.position=Vector3(12,12,19);scene.add_child(camera);camera.look_at(Vector3(0,1,0))
 Ink.attach(scene)
 var forms: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/forms.json")).forms
 var ids: Array=["bio_grazer_01","bio_grazer_03","bio_runner_06","bio_stalker_01","bio_winged_06","bio_mist_leaf_16","bio_mist_leaf_18","bio_canopy_tree_01","bio_canopy_tree_04","bio_oxygen_reef_01","bio_oxygen_reef_03","bio_grazer_05"]
 for i in range(ids.size()):
  var row: Dictionary={}
  for form in forms:
   if form.id==ids[i]:row=form;break
  var actor:=Actor.new();scene.add_child(actor);actor.configure(row)
  actor.position=Vector3((i%4-1.5)*4,0,(i/4-1)*4.5)
  actor.motion_phase=i*.41;actor.rotation.y=i*.63;actor.set_state("move" if row.category=="animal" else "idle")
  actors.append(actor)
 for i in range(3):
  var rock: Node3D=load("res://assets/models/mesa_%d.glb"%i).instantiate();scene.add_child(rock)
  var bounds:=AABB();var first:=true
  for mesh in rock.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
  var scale_value:=6./maxf(bounds.size.y,.1)
  rock.scale=Vector3.ONE*scale_value
  rock.position=Vector3((i-1)*12,-bounds.position.y*scale_value,-15)
  Ink.apply(rock,{})
 var ui:=CanvasLayer.new();scene.add_child(ui)
 var label:=Label.new();label.text="생물 혼합 배치 · 온대 외형 12개 · 렌더 검수용 환경";label.position=Vector2(30,25)
 var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_opentype={2003265652:650}
 label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",23);label.add_theme_color_override("font_color",Color("19383b"));ui.add_child(label)
 var dest:=ProjectSettings.globalize_path("res://../docs/production/media/bestiary/")
 for i in range(30):await process_frame;RenderingServer.force_draw(false)
 for mode in ["near","play","far","backlight"]:
  camera.position={"near":Vector3(8,7,12),"play":Vector3(12,12,19),"far":Vector3(24,19,36),"backlight":Vector3(12,12,19)}[mode]
  camera.look_at(Vector3(0,1,0))
  if mode=="backlight":light.rotation_degrees=Vector3(-25,145,0)
  await process_frame;RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(dest+"field-"+mode+".png")
 light.rotation_degrees=Vector3(-48,-32,0)
 var last:=Time.get_ticks_usec()
 for i in range(180):
  await process_frame;RenderingServer.force_draw(false)
  var now:=Time.get_ticks_usec();frames.append((now-last)/1000.);last=now
 var total:=0.
 for value in frames:total+=value
 frames.sort()
 var report: Dictionary={"actors":12,"environment":"Temperate visual fixture with three existing mesa assets. Not the streaming gameplay world.","resolution":[1280,800],"frames":180,"average_ms":total/180.,"p95_ms":frames[170],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"note":"Local contention may affect timing; explicit render/readback fixture, not a shipping gameplay FPS guarantee."}
 FileAccess.open(dest+"performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BESTIARY_FIELD ",JSON.stringify(report));quit()
