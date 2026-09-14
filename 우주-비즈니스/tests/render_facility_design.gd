extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[]
 var names: Dictionary={"solar":"태양광 발전기","charger":"로봇 충전기","factory":"현장 제작소","storage":"현장 창고","atmosphere":"대기 처리기","thermal":"온도 조절기","water":"물 추출기","biolab":"생태 배양기","reactor":"소형 원자로"}
 for id in names:samples.append({"id":id,"title":names[id],"name":"LOCUS / FIELD INDUSTRY","model":"res://assets/models/"+id+".glb"})
 super._ready();get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
 capture_industry.call_deferred()
func capture_industry() -> void:
 helper.hide()
 var dest:="res://../docs/production/media/facility-design/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
 var before:="--before" in OS.get_cmdline_user_args()
 var icons_only:="--icons-only" in OS.get_cmdline_user_args()
 var environment: Environment=find_children("*","WorldEnvironment",true,false)[0].environment
 var background: Color=environment.background_color
 var suffix:="before" if before else "after"
 var board:=Image.create(2160,1800,false,Image.FORMAT_RGBA8)
 for i in samples.size():
  select_sample(i);await get_tree().create_timer(.25).timeout;await RenderingServer.frame_post_draw
  if not icons_only:
   var shot:=get_viewport().get_texture().get_image();shot.save_png(dest+samples[i].id+"-"+suffix+".png")
   shot.convert(Image.FORMAT_RGBA8);shot.resize(720,600,Image.INTERPOLATE_LANCZOS)
   board.blit_rect(shot,Rect2i(0,0,720,600),Vector2i((i%3)*720,(i/3)*600))
  if not before:
   title.get_parent().hide();studio_ground.hide();get_viewport().transparent_bg=true
   environment.background_color=Color(0,0,0,0);contour.set_shader_parameter("transparent_background",true)
   await get_tree().process_frame;await RenderingServer.frame_post_draw
   var icon:=get_viewport().get_texture().get_image();icon.resize(480,400,Image.INTERPOLATE_LANCZOS);icon.save_png("res://assets/ui/previews/"+samples[i].id+".png")
   assert(icon.get_pixel(0,0).a==0.0,"Preview background must be transparent")
   environment.background_color=background;contour.set_shader_parameter("transparent_background",false)
   title.get_parent().show();studio_ground.show();get_viewport().transparent_bg=false
 if not icons_only:board.save_png(dest+"facilities-"+suffix+".png")
 if not before and not icons_only:await capture_mixed(dest)
 print("FACILITY_DESIGN_RENDER ",suffix);get_tree().quit()

func capture_mixed(dest: String) -> void:
 stage.remove_child(subject);subject.queue_free();studio_ground.position.y=-.025
 var i:=0
 for row in samples:
  var model: Node3D=load(row.model).instantiate();stage.add_child(model);model.position=Vector3((i%3-1)*6,0,(i/3-1)*6);FrontierInkStyle.apply(model,cache);i+=1
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=48;camera.position=Vector3(17,17,23);camera.look_at(Vector3(0,1,0))
 var light: DirectionalLight3D
 for child in get_children():
  if child is DirectionalLight3D:light=child;break
 for mode in ["day","shade","backlight"]:
  light.rotation_degrees=Vector3(-48,-32,0) if mode!="backlight" else Vector3(-18,150,0)
  light.light_energy=.25 if mode=="shade" else 1.35
  title.text="FIELD INDUSTRY / "+mode;subtitle.text="9종 · 동일 제작 규격 · 역할별 구조"
  await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(dest+"mixed-"+mode+".png")
