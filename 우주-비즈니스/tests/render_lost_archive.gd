extends "res://scripts/showcase/ink_samples.gd"
func _ready() -> void:
 samples=[{"id":"archive","title":"T3  /  로스트 테크놀로지","name":"기록 회수 → 전원 복구 → 공동 설계 복원","model":"res://assets/models/discoveries/lost_technology_archive.glb"}]
 super._ready()
func capture_all() -> void:
 await get_tree().process_frame;helper.hide()
 var folder:=ProjectSettings.globalize_path("res://../docs/production/media/t3-progression/")
 await get_tree().create_timer(.5).timeout;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(folder+"archive-ink.png")
 studio_ground.hide();title.get_parent().hide();get_viewport().transparent_bg=true
 var environment: WorldEnvironment=find_children("*","WorldEnvironment",true,false)[0];environment.environment.background_mode=Environment.BG_CLEAR_COLOR
 await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
 var icon:=get_viewport().get_texture().get_image();icon.resize(480,400,Image.INTERPOLATE_LANCZOS);icon.save_png(ProjectSettings.globalize_path("res://assets/ui/discoveries/lost_technology_archive.png"))
 print("ARCHIVE_INK_COMPLETE");get_tree().quit()
