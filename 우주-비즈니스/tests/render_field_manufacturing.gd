extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[]
 var names: Dictionary={"metalworks":"금속 가공 공장","equipment_workbench":"장비 제작대"}
 for id in names:samples.append({"id":id,"title":names[id],"name":"LOCUS / FIELD INDUSTRY","model":"res://assets/models/"+id+".glb"})
 super._ready();get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
 capture_industry.call_deferred()
func capture_industry() -> void:
 helper.hide()
 var dest:="res://../output/field-manufacturing/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
 var before:="--before" in OS.get_cmdline_user_args()
 var icons_only:="--icons-only" in OS.get_cmdline_user_args()
 var environment: Environment=find_children("*","WorldEnvironment",true,false)[0].environment
 var background: Color=environment.background_color
 var suffix:="before" if before else "after"
 var board:=Image.create(1440,600,false,Image.FORMAT_RGBA8)
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

 print("FIELD_MANUFACTURING_RENDER ",suffix);get_tree().quit()
