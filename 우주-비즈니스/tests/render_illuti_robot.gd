extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[{"id":"illuti_dormant_combat_robot","title":"ILLUTI  /  COMBAT DIVISION","name":"폐기 전투로봇 · 경사 장갑 / 위협 센서 / 일체형 포신","model":"res://assets/models/incidents/robot.glb"}]
 direction=Vector3(1.0,.45,1.9).normalized()
 super._ready()
func capture_all() -> void:
 await get_tree().process_frame;helper.hide()
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/illuti-remodel/")
 for view in ["front","rear","dormant"]:
  direction=Vector3(-1,.6,-1.8).normalized() if view=="rear" else Vector3(1,.45,1.9).normalized()
  select_sample(0)
  if view=="dormant":
   var torso: Node3D=subject.find_child("Anim_Torso",true,false);torso.rotation.x+=1;torso.position.y-=.3
  var weak: Node3D=subject.find_child("Anim_Weak",true,false);weak.visible=false
  await get_tree().create_timer(.35).timeout;await RenderingServer.frame_post_draw
  var shot:=get_viewport().get_texture().get_image();shot.save_png(out+"godot-"+view+".png")
 # FIELD v1: UI card output uses alpha; studio quality captures above keep their backdrop.
 title.get_parent().hide();studio_ground.hide()
 get_viewport().transparent_bg=true;contour.set_shader_parameter("transparent_background",true)
 get_window().size=Vector2i(512,512);get_window().content_scale_size=Vector2i(512,512)
 direction=Vector3(1,.45,1.9).normalized();select_sample(0);subject.find_child("Anim_Weak",true,false).hide()
 await get_tree().create_timer(.35).timeout;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/discoveries/illuti_dormant_combat_robot.png"))
 print("ILLUTI_RENDER_OK");get_tree().quit()
