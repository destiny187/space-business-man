extends "res://tests/check_incident_play.gd"
func run() -> void:
 if "--crew-folder=/tmp/coopertech-clues-play" not in OS.get_cmdline_user_args():quit(2);return
 var save_folder:="/tmp/coopertech-clues-play";DirAccess.make_dir_recursive_absolute(save_folder)
 folder=ProjectSettings.globalize_path("res://../docs/production/media/coopertech-clues");root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var owner:=FrontierPlayerProfile.new_character("CooperTech 현장 추적",2);incident_actor=owner.character_id
 var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"start")
 var w: Dictionary=core.world;var trace:=FrontierCorporateTraces.definition(w.manifest,"trace:corp_2805_0")
 w.crew.corporate_traces={trace.id:2};FrontierCooperTechClues.capture(w,trace)
 var clue:=FrontierCooperTechClues.describe(w,trace.id);var planet:=FrontierUniverse.body(w.manifest,clue.body)
 w.location=planet.id;w.navigation_target=planet.id;w.crew.navigation.system=planet.system_ordinal;w.crew.navigation.target=clue.body
 w.crew.navigation.position=FrontierExplorationIncidents.array(FrontierCrewNavigation.center(clue.body,w.manifest,0)+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
 w.crew.members[incident_actor].ready=true
 check(FrontierCrewSurface.apply(w,incident_actor,"land",{},{1:incident_actor}).is_empty(),"land at actual clue planet")
 var loadout: Dictionary=w.crew.members[incident_actor].loadout;loadout.items["fixture:pulse_2"]="pulse_2";loadout.slots[2]="fixture:pulse_2"
 var store:=FrontierWorldStore.new(save_folder+"/world.json");check(store.write(w),"isolated linked save "+store.last_error)
 var profile:=FrontierPlayerProfile.new(save_folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ linked planet opens",80):quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.category.select(4);app.survey_journal.search.text="CooperTech";app.survey_journal.refresh();await create_timer(.4).timeout
 check(app.survey_journal.selected_entry.get("kind","")=="coopertech_clue","J exposes ground coordinates and original robot preview")
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("coopertech-clue-journal-960")
 check(app.survey_journal.detail_column.get_global_rect().end.x<=960,"clue dossier fits narrow screen")
 app.close_menus();app.planet_map.show_clue(clue);await create_timer(.3).timeout;await capture("coopertech-ground-coordinate-map")
 check(app.planet_map.selected==trace.id and app.planet_map.waypoint==Vector2(clue.position[0],clue.position[2]),"J target becomes same ground map waypoint")
 if "--journal-only" in OS.get_cmdline_user_args():
  app.queue_free();await process_frame;quit(1 if failures else 0);return
 app.close_menus();root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var row: Dictionary=app.session.authority.world.incidents.records[clue.incident]
 if not await visit(row,FrontierExplorationIncidents.point(row,Vector3(0,0,14)),FrontierExplorationIncidents.point(row,Vector3(0,1.5,0))):quit(1);return
 await until(func():return app.session.authority.world.incidents.records[clue.incident].phase=="aiming","robot telegraphs actual attack",15)
 check(int(app.session.latest.coopertech_clues[trace.id].stage)==1,"ground discovery updates orbital clue snapshot")
 await capture("coopertech-linked-robot-aim")
 var view:=app.surface_world.incidents
 check(view.audio.stream("sfx_incident_robot_wake")!=null and view.audio.last_played.has("sfx_incident_robot_wake"),"existing ElevenLabs robot wake plays in linked encounter")
 for i in 15:
  if app.session.authority.world.incidents.records[clue.incident].hp<=0:break
  await action(row,"robot",true,2)
 await action(row,"cargo",false,2)
 check(app.session.authority.world.incidents.records[clue.incident].claimed and int(app.session.latest.coopertech_clues[trace.id].stage)==2,"actual weapon and F recovery close same orbital clue")
 await capture("coopertech-linked-robot-recovered")
 app.toggle_research();app.research_frame.tabs.current_tab=1;app.survey_journal.search.text="폐기 로봇 추적";app.survey_journal.refresh();await create_timer(.4).timeout;await capture("coopertech-closed-dossier")
 check(await app.session.close_session(),"save linked ground completion")
 var saved:=store.read_state();check(not saved.is_empty() and FrontierCooperTechClues.describe(saved,trace.id).stage==2,"reload preserves actual same-ID completion")
 app.queue_free();await process_frame;await process_frame;print("COOPERTECH_CLUE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
