extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[]
 for id in FrontierExplorationDiscoveries.config().items:
  var d:=FrontierExplorationDiscoveries.definition(id)
  samples.append({"id":id,"title":"T%d / 탐험 발견"%int(d.tier),"name":d.name,"model":"res://assets/models/"+d.model+".glb"})
 super._ready()
func capture_all() -> void:
 await get_tree().process_frame
 helper.hide()
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/exploration-t2/")
 var icons:=ProjectSettings.globalize_path("res://assets/ui/discoveries/")
 DirAccess.make_dir_recursive_absolute(icons)
 var board:=Image.create(1800,1500,false,Image.FORMAT_RGBA8)
 for i in samples.size():
  select_sample(i)
  await get_tree().create_timer(.25).timeout;await RenderingServer.frame_post_draw
  var shot:=get_viewport().get_texture().get_image();shot.convert(Image.FORMAT_RGBA8);shot.resize(360,300,Image.INTERPOLATE_LANCZOS)
  board.blit_rect(shot,Rect2i(0,0,360,300),Vector2i((i%10%5)*360,(i%10/5)*300))
  title.get_parent().hide();await get_tree().process_frame;await RenderingServer.frame_post_draw
  var icon:=get_viewport().get_texture().get_image();icon.resize(480,400,Image.INTERPOLATE_LANCZOS);icon.save_png(icons+samples[i].id+".png")
  title.get_parent().show()
  if i%10==9:
   var trimmed:=board.get_region(Rect2i(0,0,1800,600));trimmed.save_png(out+"godot-t"+str(i/10+1)+".png")
  print("DISCOVERY_RENDER ",samples[i].id)
 get_tree().quit()
