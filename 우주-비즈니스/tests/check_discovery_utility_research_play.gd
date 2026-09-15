extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/discovery-utilities-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"research fixture ready",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false);app.session.set_physics_process(false)
 var core:=app.session.authority
 if core.autonomous_pending():await until(func():return core.resolve_autonomous(),"pending fixture simulation complete",10)
 var world: Dictionary=core.world;var actor: String=world.crew.owner_id
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var standing:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(3,0,3);standing.y=app.surface_world.terrain.field.height(standing.x,standing.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing
 world.business.facility_research.erase("shell_refuge");world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 app.session._publish();app.session._publish_surface();app.open_station("ship");app.business_panel.vessel_terminal.cards.research.pressed.emit();await create_timer(.3).timeout
 var research: FrontierFacilityResearchPanel=app.stations.research_tabs.get_child(1);research.category.select(0);research.selected="shell_refuge";research.signature="";research.refresh()
 check(research.action.disabled and research.action.text.contains("재료"),"research honestly rejects empty resumed bag")
 world.business.bags[actor].iron=6;world.business.bags[actor].copper=4;app.session._publish();app.session._publish_surface();research.signature="";research.refresh()
 print("RESEARCH STATUS ",research.action.text)
 await until(func():return not research.action.disabled,"completed proof and real materials enable shell research",5)
 await capture("shell-research-960")
 var before: int=world.business.credits
 research.action.pressed.emit();await until(func():return FrontierFacilityResearch.owned(core.world.business,"shell_refuge"),"actual research button purchases shared design",20)
 check(int(core.world.business.credits)==before-200 and core.world.business.bags[actor].iron==0 and core.world.business.bags[actor].copper==0,"research charges exactly once")
 app.close_menus();check(await app.session.close_session(),"research state saves")
 app.queue_free();await process_frame;print("UTILITY_RESEARCH checks ",checks," failures ",failures);quit(1 if failures else 0)
