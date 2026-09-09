extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func frames() -> void:
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 var market:=FrontierStationMarketPanel.new();root.add_child(market)
 market.update_snapshot({"self_id":"test","crew":{"owner_id":"test","landing":{},"navigation":{"mode":"idle","speed":0,"position":[0,0,0]}},"station":{"name":"Preview","credits":1000,"position":[0,0,0],"stock":{"hull:swift":1,"hull:mule":1},"prices":{"hull:swift":100,"hull:mule":100}},"inventory":{},"vessel":{"hull":"kestrel","hulls":["kestrel"]}})
 market.mode="ships";market.selected="hull:swift";market.show();market.rebuild();await frames()
 var before:=hash(market.preview.get_texture().get_image().get_data())
 check(market.preview.render_target_update_mode==SubViewport.UPDATE_DISABLED and not market.preview_dirty,"static market hull stops rendering")
 market.selected="hull:mule";market.refresh_detail();check(market.preview_dirty,"hull selection invalidates market image")
 await frames()
 check(hash(market.preview.get_texture().get_image().get_data())!=before,"new market hull appears in rendered image")
 market.hide();market.selected="hull:swift";market.refresh_detail();await frames()
 check(market.preview_dirty and market.preview.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden market defers refresh")
 market.show();await frames();check(not market.preview_dirty,"market reopening refreshes deferred hull")
 market.queue_free();await process_frame
 var module_view:=FrontierShipModulePreview.new();root.add_child(module_view);module_view.size=Vector2(500,400)
 var vessel:=FrontierVesselRefit.create(123,"preview")
 module_view.show_vessel(vessel);await frames()
 var id:=FrontierVesselRefit.add_module(vessel,"drive","standard");vessel.loadout.propulsion=id
 module_view.show_vessel(vessel)
 check(module_view.view.render_dirty,"same-hull module change invalidates image")
 await frames();check(not module_view.view.render_dirty and module_view.view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"module preview redraws then stops")
 module_view.queue_free();await process_frame
 print("PREVIEW DETAILS failures ",failures);quit(1 if failures else 0)
