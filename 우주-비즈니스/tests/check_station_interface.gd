extends SceneTree
var app: FrontierCrewExpedition
var failures:=0
var folder: String=""
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
 if not value:failures+=1;printerr("FAIL "+message)
func key(code: Key) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func capture(name_value: String) -> void:
 await create_timer(.3).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--crew-folder="):DirAccess.make_dir_recursive_absolute(argument.trim_prefix("--crew-folder="))
 folder=ProjectSettings.globalize_path("res://../test-results/space-station");DirAccess.make_dir_recursive_absolute(folder)
 FrontierInput.apply({});root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 app.start_solo(true);await create_timer(.7).timeout;app.onboarding.letter.hide()
 var world: Dictionary=app.session.authority.world
 var index: int=-1
 for i in range(1,100):
  if not FrontierSpaceStation.definition(world.manifest,i).is_empty():index=i;break
 check(index>0,"station exists")
 var station:=FrontierSpaceStation.definition(world.manifest,index)
 var nav: Dictionary=world.crew.navigation
 nav.mode="idle";nav.manual=true;nav.system=index;nav.target=FrontierUniverse.first_ordinal(world.manifest,index);nav.speed=0
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(station.position)+Vector3(0,360,1050));nav.direction=[0,-.25,-1]
 world.flight_position=nav.position.duplicate();world.location=FrontierUniverse.body_id(world.manifest,int(nav.target))
 world.business=FrontierExpeditionBusiness.create();world.business.credits=20000
 world.business.bags[world.crew.owner_id]=FrontierExpeditionBusiness.inventory();world.business.bags[world.crew.owner_id].iron=40
 app.session._publish();app.outside=true;app.exterior_view.show();app.if_flight_view()
 await create_timer(1).timeout;app.flight.transit_overlay.arrival_age=100
 await capture("station-flight")
 check(app.flight.station_model!=null,"station actual flight model")
 app.test_mode=false;app._sync_mouse_capture();app.open_trade_station()
 check(app.station_market.visible,"context opens market")
 check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"market releases mouse")
 check(app.station_market.hum.playing,"ElevenLabs ambience plays")
 await capture("market-goods")
 app.station_market.mode="ships";app.station_market.selected="";app.station_market.rebuild()
 await capture("market-ships")
 app.station_market.send("station_buy")
 check(not app.station_market.pending,"host acknowledgment clears pending")
 check(app.session.latest.vessel.hulls.size()==2,"purchase persists hull")
 app.station_market.mode="owned";app.station_market.selected=app.session.latest.vessel.hulls[1];app.station_market.rebuild()
 app.station_market.send("station_equip")
 await create_timer(.6).timeout
 check(app.flight.refits.hull_node!=null,"new ship actual flight hull")
 check(app.station_market.audio.last_played.has(FrontierSpaceStation.config().audio.hull),"purchase and replacement sound follows success")
 await capture("market-owned")
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 await capture("market-960")
 check(app.station_market.get_global_rect().end.x<=960 and app.station_market.buy.get_global_rect().end.y<=640,"market fits small screen")
 await key(KEY_I)
 check(app.inventory_panel.visible and not app.station_market.visible,"market to inventory")
 check(not app.station_market.hum.playing,"market ambience stops on close")
 await key(KEY_ESCAPE)
 check(not app.any_menu_open() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Esc restores flight capture")
 await capture("new-hull-flight")
 check(await app.session.close_session(),"save after trade")
 print("STATION INTERFACE failures ",failures)
 app.queue_free();await process_frame;quit(1 if failures else 0)
