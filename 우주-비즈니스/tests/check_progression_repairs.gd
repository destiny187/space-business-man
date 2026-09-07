extends "res://tests/test_solo_entry.gd"
## Scoped regression from an isolated restored-site save; pass --crew-folder with world/profile.
var owner: String
func world() -> Dictionary:return app.session.authority.world
func site() -> Dictionary:return FrontierExpeditionBusiness.site(world())
func move_to(p: Vector3) -> void:
 app.actors[owner].position=p;app.session.authority.update_position(1,p);app.session._publish()
func press_button(parent: Node,caption: String) -> bool:
 for button in parent.find_children("*","Button",true,false):
  if button.is_visible_in_tree() and button.text.contains(caption):button.pressed.emit();return true
 check(false,"visible button "+caption);return false
func tab_named(name_value: String) -> void:
 for i in app.business_panel.tabs.get_tab_count():
  if app.business_panel.tabs.get_tab_control(i).name==name_value:app.business_panel.tabs.current_tab=i;return
 check(false,"tab "+name_value)
func run() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 await process_frame;app.start_solo()
 if not await until(func():return app.session.active and app.surface_world!=null and not app.arrival.active,"restored site opens",60):quit(1);return
 owner=app.session.latest.self_id
 if "--repair-layout-only" in OS.get_cmdline_user_args():
  root.size=Vector2i(960,640);root.content_scale_size=root.size
  move_to(FrontierCrewWorld.vector(site().center));app.open_station("base");await capture("warehouse-960")
  app.inventory_panel.warehouse_management.pressed.emit();await create_timer(.2).timeout;await capture("supply-960")
  tab_named("로봇");await capture("recovery-960")
  app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));app.open_station("ship");tab_named("환경·계약");await capture("settlement-960")
  await app.session.close_session();print("REPAIR_LAYOUT_DONE");quit();return
 var old_remaining: Dictionary=site().remaining.duplicate(true)
 var ice:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,"landing:ice")
 check(not ice.is_empty(),"existing T1 save gains additive ice deposit")
 var p:=FrontierMineralWorld.point(FrontierCrewSurface.field(world()),ice)
 move_to(p+Vector3(0,0,2));app.session.send_request("business_mine",{"vein_id":ice.id})
 check(int(site().remaining.get(ice.id,400))==396,"Mk.2 mines new ice without gifts")
 for id in old_remaining:check(site().remaining[id]==old_remaining[id],"existing depletion preserved "+id)
 if not await until(func():return app.surface_world.business_view.nodes.has("landing:ice"),"Blender ice model appears on actual surface",20):quit(1);return
 app.test_camera_position=p+Vector3(5,4,7);app.yaw=.6;app.pitch=-.25;await capture("landing-ice")
 app.test_camera_position=Vector3.ZERO;app.pitch=0;app.yaw=0
 move_to(FrontierCrewWorld.vector(site().center));app.open_station("base")
 await create_timer(.4).timeout
 check(app.inventory_panel.visible and app.inventory_panel.tabs.current_tab==2,"F warehouse preserves drag inventory")
 check(app.inventory_panel.warehouse_management.is_visible_in_tree() and not app.inventory_panel.warehouse_management.disabled,"warehouse management visible near warehouse")
 app.inventory_panel._transfer_cargo({"resource":"ice","amount":4,"source":"bag"});await process_frame
 check(FrontierExpeditionBusiness.total(FrontierExpeditionBusiness.bag(world(),owner))==0,"drag transfer preserved")
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("warehouse-960")
 app.inventory_panel.warehouse_management.pressed.emit();await create_timer(.4).timeout
 check(app.business_panel.context_kind=="base" and app.business_panel.visible and not app.inventory_panel.visible,"warehouse management opens real business tabs")
 for i in app.business_panel.supply.item_count:
  if app.business_panel.supply.get_item_metadata(i)=="ice":app.business_panel.supply.select(i)
 var credits: int=world().business.credits;var ice_before: int=site().inventory.ice
 press_button(app.business_panel,"보급 20개 인수");await process_frame
 check(int(world().business.credits)==credits-100 and int(site().inventory.ice)==ice_before+20,"UI purchases ice and charges exact budget")
 await capture("supply-960")
 tab_named("로봇");await create_timer(.2).timeout
 var robot: String=world().business.hangar.keys()[0]
 press_button(app.business_panel,"운송한 로봇 재파견");await create_timer(.3).timeout
 check(site().robots.has(robot),"UI deploys recovered robot with same identity")
 await capture("recovery-960")
 press_button(app.business_panel,"창고 근처 로봇을 격납고로 회수");await process_frame
 check(world().business.hangar.has(robot) and not site().robots.has(robot),"UI recovers robot to hangar")
 # Reject an unsupported target without changing robot orders.
 press_button(app.business_panel,"운송한 로봇 재파견");await process_frame
 var invalid: String=""
 for row in FrontierExpeditionBusiness.veins(app.surface_world.body):
  if not row.get("underground",false) and int(site().remaining.get(row.id,row.capacity))>0 and not FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world()),row.position[0],row.position[2]).is_finite():invalid=row.id;break
 check(not invalid.is_empty(),"reproduction seed has unsupported robot target")
 move_to(FrontierCrewWorld.vector(site().robots[robot].position))
 app.session.send_request("business_assign",{"robot_id":robot,"vein_id":invalid})
 check(site().robots[robot].target=="" and app.status.value.contains("평탄한 토대"),"host rejects unsupported vein before starting job")
 move_to(FrontierCrewWorld.vector(site().center));app.session.send_request("business_robot_recover",{"robot_id":robot})
 app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));app.yaw=0;app.pitch=0
 await create_timer(.4).timeout;app.navigation_ui._update_context()
 check(app.navigation_ui.context_kind=="launch" and app.navigation_ui.context.text.contains("단말"),"ship context advertises terminal")
 var event:=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;Input.parse_input_event(event);await process_frame
 check(app.business_panel.visible and app.business_panel.context_kind=="ship" and FrontierCrewSurface.landed(world()),"actual F opens ship terminal without auto-launch")
 tab_named("환경·계약");await capture("settlement-960")
 credits=int(world().business.credits)
 press_button(app.business_panel,"지역 복원 계약 정산")
 await process_frame
 var confirmation: ConfirmationDialog=null
 for node in app.business_panel.get_children():
  if node is ConfirmationDialog and node.visible:confirmation=node
 check(confirmation!=null,"settlement confirmation reachable")
 if confirmation!=null:confirmation.confirmed.emit()
 await process_frame
 check(site().state=="settled" and int(world().business.credits)==credits+6000,"UI confirmation settles once and pays reward")
 tab_named("착륙선");await create_timer(.2).timeout
 press_button(app.business_panel,"탑승 ·")
 check(not FrontierCrewSurface.landed(world()),"explicit boarding button launches after settlement")
 await until(func():return app.surface_world==null and not app.arrival.active,"departure returns to space",45)
 check(app.feedback.audio.last_played.has("sfx_build_invalid"),"rejected command keeps existing ElevenLabs failure feedback")
 check(await app.session.close_session(),"isolated upgraded world saves")
 var restored:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(not restored.is_empty(),"updated save reloads")
 print("PROGRESSION_REPAIR_CHECKS ",checks," FAILURES ",failures)
 quit(1 if failures else 0)
