extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[]
 for key in FrontierDiscoveryExhibits.config().items:
  var d: Dictionary=FrontierDiscoveryExhibits.config().items[key]
  samples.append({"id":d.template,"title":d.name,"name":d.source_name,"model":"res://assets/models/"+d.model+".glb"})
 super._ready();get_viewport().screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
 capture_all.call_deferred()
func capture_all() -> void:
 helper.hide()
 var dest:="res://../output/discovery-exhibits/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/previews/exhibits"))
 var environment: Environment=find_children("*","WorldEnvironment",true,false)[0].environment
 var background:=environment.background_color
 var board:=Image.create(1920,1920,false,Image.FORMAT_RGBA8);board.fill(Color("f8f4e6"))
 for i in samples.size():
  select_sample(i);await get_tree().create_timer(.12).timeout;await RenderingServer.frame_post_draw
  var shot:=get_viewport().get_texture().get_image();shot.save_png(dest+samples[i].id+"-ink.png");shot.convert(Image.FORMAT_RGBA8);shot.resize(320,240,Image.INTERPOLATE_LANCZOS);board.blit_rect(shot,Rect2i(0,0,320,240),Vector2i((i%6)*320,(i/6)*240))
  title.get_parent().hide();studio_ground.hide();get_viewport().transparent_bg=true;environment.background_color=Color(0,0,0,0);contour.set_shader_parameter("transparent_background",true)
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  var icon:=get_viewport().get_texture().get_image();icon.resize(360,300,Image.INTERPOLATE_LANCZOS);icon.save_png("res://assets/ui/previews/exhibits/"+samples[i].id+".png")
  environment.background_color=background;contour.set_shader_parameter("transparent_background",false);title.get_parent().show();studio_ground.show();get_viewport().transparent_bg=false
 board.save_png(dest+"exhibits-contact.png");print("EXHIBIT_RENDERED ",samples.size());get_tree().quit()
