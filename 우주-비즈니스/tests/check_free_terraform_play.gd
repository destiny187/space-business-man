extends "res://tests/check_facility_interactions.gd"
var used_points: Dictionary={}
func fixture(kind: String,region_id: String,tier: int=1) -> Dictionary:
 var world: Dictionary=app.session.authority.world;var site:=FrontierExpeditionBusiness.site(world);var center: Array=site.free_terraform.source
 if not site.regions.has(region_id):site.regions[region_id]=FrontierFreeTerraform.district(site,region_id)
 var region: Dictionary=site.regions[region_id].duplicate();region.center=center
 var location:=Vector3.INF;var radius: float=maxf(3,FrontierCatalog.entry("buildings",kind).radius)
 for x in range(-54,55,7):
  if location.is_finite():break
  for z in range(-54,55,7):
   var point:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,region.center[0]+x,region.center[2]+z,radius)
   if not point.is_finite() or Vector2(x,z).length()<10 or Vector2(x,z).length()>110:continue
   var clear:=true
   for previous in used_points.values():
    if previous.distance_to(point)<7:clear=false
   if clear:location=point;break
 if not location.is_finite():return {}
 region_id=FrontierFreeTerraform.district_id(site,location)
 if not site.regions.has(region_id):site.regions[region_id]=FrontierFreeTerraform.district(site,region_id)
 var id: String="t3:play:"+str(site.buildings.size());used_points[id]=location
 var row: Dictionary={"id":id,"type":kind,"tier":tier,"position":FrontierExpeditionBusiness.array(location),"active":false,"enabled":true,"work":0.0,"status":"준비","yaw":0.0,"region_id":region_id}
 site.buildings[id]=row;return row
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 await process_frame;app.world_store.write(FrontierUniverse.new_world(71503));app.start_solo()
 if not await until(func():return app.session.active and app.flight!=null and not app.preparing_first_snapshot and not has_meta("startup_loader"),60):quit(1);return
 app.session.notice.connect(func(message):print("FREE_NOTICE ",message))
 app.onboarding.letter.hide()
 var world: Dictionary=app.session.authority.world;var ordinal:=206387;var body:=FrontierUniverse.body(world.manifest,ordinal)
 var nav: Dictionary=world.crew.navigation;nav.system=int(body.system_ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
 var p:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
 nav.position=[p.x,p.y,p.z];nav.direction=[0,0,-1];world.location=body.id
 app.session._publish();await process_frame;app.travel_action("land")
 check(await until(func():return app.surface_world!=null and not app.arrival.active,90),"land on seeded T3 planet")
 if app.surface_world==null:quit(1);return
 world=app.session.authority.world
 var site:=FrontierExpeditionBusiness.site(world);site.state="active";world.business.active=body.id;FrontierCoopWorkload.activate(site,body,1)
 for id in FrontierFacilityBlueprints.definitions():FrontierFacilityBlueprints.register(world,id,"exploration","fixture:integration")
 # Supplies and supporting installations are fixtures; production/upgrade use the live host path.
 var district_id:=FrontierFreeTerraform.district_id(site,FrontierCrewWorld.vector(site.free_terraform.source))
 var source:=fixture("source_control",district_id,3);var storage:=fixture("storage",district_id);var factory:=fixture("factory",district_id,3);var water:=fixture("water",district_id,2)
 for n in 7:fixture("solar",district_id,2)
 if source.is_empty() or storage.is_empty() or factory.is_empty() or water.is_empty():printerr("FREE_PLAY fixture placement missing");quit(1);return
 var atmosphere:=fixture("atmosphere",district_id,3)
 var district: Dictionary=site.regions[factory.region_id]
 var item: String=site.tier3.rules.profiles[site.tier3.profile].item
 for region in site.regions.values():region.inventory[item]=12;region.inventory.ice=30
 district.inventory[item]=12;district.inventory.ice=30
 FrontierExpeditionBusiness.transfer(district.inventory,FrontierProductionTier2.product(item).cost,1)
 FrontierExpeditionBusiness.transfer(site.regions[water.region_id].inventory,FrontierTerraformTier3.config().upgrades.water.cost,1)
 app.session._publish_surface()
 var location:=FrontierCrewWorld.vector(factory.position)
 move_to(location+Vector3(0,1,5));app.camera.look_at(location+Vector3.UP*1.5);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
 check(await until(func():return app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),90),"source district streamed")
 app.close_menus();await create_timer(2).timeout
 var count: int=district.inventory[item]
 print("FREE_PRODUCE ",app.session.send_request("business_produce",{"building_id":factory.id,"product":item}))
 check(await until(func():return int(FrontierExpeditionBusiness.site(app.session.authority.world).buildings.get(factory.id,{}).get("product_serial",0))>0,25),"actual host P3 production completes")
 site=FrontierExpeditionBusiness.site(app.session.authority.world);district=site.regions[district_id]
 location=FrontierCrewWorld.vector(water.position);move_to(location+Vector3(0,1,5));await process_frame
 app.session.send_request("business_facility_upgrade",{"building_id":water.id})
 check(await until(func():return int(FrontierExpeditionBusiness.site(app.session.authority.world).buildings.get(water.id,{}).get("tier",0))==3,10),"actual host water retrofit consumes parts and blueprint")
 site=FrontierExpeditionBusiness.site(app.session.authority.world)
 check(float(site.tier3.suppression)>.9,"live source control suppresses inflow")
 location=FrontierCrewWorld.vector(source.position);move_to(location+Vector3(7,2,9));app.camera.look_at(location+Vector3.UP*1.5);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
 app.session._publish_surface();await create_timer(2).timeout
 app.onboarding.hide();app.camera.look_at(location+Vector3.UP*1.7);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
 await create_timer(.3).timeout
 check(await until(func():return app.surface_world.business_view.nodes.has(water.id) and app.surface_world.business_view.nodes[water.id].has_meta("tier3_visual"),15),"Mk3 Blender module attached to actual facility")
 var node: Node3D=app.surface_world.business_view.nodes.get(source.id)
 check(node!=null and node.get_meta("parts",[]).size()>0,"source model moving parts connected")
 app.feedback._update_audio(true)
 check(app.feedback.audio.emitters.has(source.id),"source ElevenLabs work loop connected")
 await capture("source-running")
 app.toggle_navigation();app.planet_map.modes.current_tab=1;app.planet_map.refresh()
 var panel: FrontierTerraformPanel=app.planet_map.terraform
 panel.focus=Vector2(site.free_terraform.source[0],site.free_terraform.source[2]);panel.chosen=panel.focus
 for i in 4:
  panel.layer=i;panel.for_buttons();panel.refresh();await create_timer(.3).timeout;await capture("terraform-"+str(i))
 root.size=Vector2i(960,640);await create_timer(.5).timeout;await capture("terraform-960")
 check(panel.info.get_global_rect().end.y<=app.planet_map.get_global_rect().end.y,"four-layer terraforming panel fits small screen")
 check(bool(app.surface_world.terrain.material.get_shader_parameter("free_enabled")),"sparse free terrain texture connected")
 app.close_menus();app.begin_placement("water");await create_timer(.3).timeout
 check(app.placement_ghost.find_children("*","FrontierTerraformPlacement",true,false).size()>0 or app.placement_ghost.get_child_count()>0,"placement footprint instrument attached")
 app.cancel_placement()
 panel.rotation_y+=.7;panel.canvas.queue_redraw();app.open_menu(app.planet_map);await capture("terraform-rotated");app.close_menus()
 app.close_menus();root.size=Vector2i(1280,800)
 var err:=FrontierUniverse.validate_world(app.session.authority.world);check(err.is_empty(),"complete live world saves: "+err)
 await app.session.close_session();print("FREE_PLAY_FAILURES ",failures);quit(1 if failures else 0)
