extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[]
 for id in ["source_control","atmosphere_module","water_module","thermal_module","biolab_module"]:
  samples.append({"id":id,"title":"T3  /  지역 환경 설비","name":{"source_control":"유입원 제어 장치","atmosphere_module":"선택성 대기 모듈","water_module":"폐쇄 순환 모듈","thermal_module":"지역 열교환 모듈","biolab_module":"선구종 정착 모듈"}[id],"model":"res://assets/models/terraform3/"+id+".glb"})
 super._ready()
func capture_all() -> void:
 await get_tree().process_frame;helper.hide()
 var folder:=ProjectSettings.globalize_path("res://../docs/production/media/terraform3/")
 var board:=Image.create(1800,1200,false,Image.FORMAT_RGBA8)
 for i in samples.size():
  select_sample(i);await get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
  if i==0:
   var icons:=ProjectSettings.globalize_path("res://assets/ui/previews/terraform3/");DirAccess.make_dir_recursive_absolute(icons)
   title.get_parent().hide();await RenderingServer.frame_post_draw
   var icon:=get_viewport().get_texture().get_image();icon.resize(480,400,Image.INTERPOLATE_LANCZOS);icon.save_png(icons+"source_control.png")
   title.get_parent().show();await RenderingServer.frame_post_draw
  var shot:=get_viewport().get_texture().get_image();shot.convert(Image.FORMAT_RGBA8);shot.resize(600,600,Image.INTERPOLATE_LANCZOS)
  board.blit_rect(shot,Rect2i(0,0,600,600),Vector2i(i%3*600,i/3*600))
 board.save_png(folder+"godot-facilities.png");print("T3_INK_RENDER_COMPLETE");get_tree().quit()
