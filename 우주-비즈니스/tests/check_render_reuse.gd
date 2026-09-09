extends "res://tests/test_solo_entry.gd"
var preview_draws:=0
var watched: FrontierEquipmentPreview
func count_preview() -> void:
 if is_instance_valid(watched) and watched.viewport.render_target_update_mode==SubViewport.UPDATE_ONCE:preview_draws+=1
func frames(count: int=5) -> void:
 for i in count:await process_frame
 await RenderingServer.frame_post_draw
func picture_hash() -> int:return hash(watched.viewport.get_texture().get_image().get_data())
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.flight!=null and app.session.active and not app.arrival.active,"saved flight ready",60):quit(1);return
 app.onboarding.letter.hide();app.close_menus();app.outside=true;app.exterior_view.show();app.if_flight_view()
 await frames()
 check(root.disable_3d and app.main_render_suspended,"external view skips covered main 3D pass")
 check(app.space_view.render_target_update_mode!=SubViewport.UPDATE_DISABLED,"external space viewport keeps rendering")
 await capture("external")
 var reduced:=root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
 RenderingServer.frame_pre_draw.disconnect(app._sync_main_render);root.disable_3d=false
 await frames()
 var redundant:=root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
 print("MAIN VIEWPORT draw calls: covered pass enabled=",redundant," disabled=",reduced)
 RenderingServer.frame_pre_draw.connect(app._sync_main_render);app.main_render_suspended=false
 app.outside=false;app.exterior_view.hide();app.if_flight_view();await frames()
 check(not root.disable_3d and app.cabin_root.is_visible_in_tree(),"cabin return restores main 3D")
 await capture("cabin")
 app.outside=true;app.exterior_view.show();app.if_flight_view();await frames()
 app.arrival.active=true;app._sync_main_render()
 check(not root.disable_3d,"arrival keeps main render available for warmup")
 app.arrival.active=false
 var layer:=CanvasLayer.new();root.add_child(layer)
 watched=FrontierEquipmentPreview.new();watched.size=Vector2(400,320);layer.add_child(watched);watched.show_model("miner")
 RenderingServer.frame_pre_draw.connect(count_preview)
 await frames()
 var first:=picture_hash();var idle_draws:=preview_draws
 await frames(12)
 check(preview_draws==idle_draws and watched.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"static preview does not redraw while idle")
 var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;Input.parse_input_event(mouse)
 var motion:=InputEventMouseMotion.new();motion.relative=Vector2(70,0);watched._gui_input(motion)
 mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=false;Input.parse_input_event(mouse)
 await frames()
 check(preview_draws>idle_draws and picture_hash()!=first,"drag rotates and refreshes cached image")
 first=picture_hash();watched.camera.size*=1.4;await frames()
 check(picture_hash()!=first,"direct camera framing change refreshes image")
 watched.size=Vector2(480,260);await frames()
 check(watched.viewport.size==Vector2i(480,260),"resize updates preview render size")
 watched.hide();watched.show_model("ships/finch");idle_draws=preview_draws;await frames()
 check(preview_draws==idle_draws,"hidden model replacement waits for display")
 watched.show();await frames();first=picture_hash()
 check(preview_draws>idle_draws,"show renders latest model")
 watched.show_model("");await frames()
 check(watched.model==null and picture_hash()!=first,"empty selection clears previous model image")
 var research:=FrontierResearchPreview.new();research.size=Vector2(300,250);research.position.x=500;layer.add_child(research);research.present("analyzed","iron_ore")
 watched=research;await frames();idle_draws=preview_draws;await frames()
 check(preview_draws>idle_draws and research.continuous_rendering,"animated research preview continues rendering")
 research.hide();idle_draws=preview_draws;await frames()
 check(preview_draws==idle_draws,"animated preview stops rendering when hidden")
 RenderingServer.frame_pre_draw.disconnect(count_preview);watched=null;layer.queue_free();await process_frame
 await app.session.close_session();app.queue_free();await process_frame
 check(not root.disable_3d,"leaving expedition restores root viewport")
 print("RENDER REUSE checks ",checks," failures ",failures);quit(1 if failures else 0)
