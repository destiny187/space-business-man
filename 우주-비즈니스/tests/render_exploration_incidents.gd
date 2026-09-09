extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[]
 for id in FrontierExplorationIncidents.config().items:
  var d:=FrontierExplorationIncidents.definition(id)
  samples.append({"id":id,"title":"T%d / 현장 사건"%int(d.tier),"name":d.name,"model":"res://assets/models/"+d.model+".glb"})
 super._ready()
func capture_all() -> void:
 await get_tree().process_frame;helper.hide()
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/incidents-t2/")
 var icons:=ProjectSettings.globalize_path("res://assets/ui/discoveries/")
 var board:=Image.create(1600,800,false,Image.FORMAT_RGBA8)
 for i in samples.size():
  select_sample(i);await get_tree().create_timer(.25).timeout;await RenderingServer.frame_post_draw
  var shot:=get_viewport().get_texture().get_image();shot.convert(Image.FORMAT_RGBA8);shot.resize(400,400,Image.INTERPOLATE_LANCZOS);board.blit_rect(shot,Rect2i(0,0,400,400),Vector2i(i%4*400,i/4*400))
  shot.save_png(icons+samples[i].id+".png");print("INCIDENT_RENDER ",samples[i].id)
 board.save_png(out+"godot.png");get_tree().quit()
