extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
 var manifest:=FrontierUniverse.generate(61739)
 assert(FrontierUniverse.body(manifest,2).name=="Earth")
 var ordinal:=FrontierUniverse.first_ordinal(manifest,23)
 var body:=FrontierUniverse.body(manifest,ordinal)
 assert(body.name.ends_with(" b"))
 assert(body.name==FrontierUniverse.body(manifest,ordinal).name)
 var view:=FrontierCrewFlightView.new();view.state={"manifest":manifest};root.add_child(view)
 var point:=FrontierUniverse.entry_position(manifest,ordinal,0)
 var facing: Vector3=(FrontierUniverse.position(manifest,ordinal)-point).normalized()
 var nav: Dictionary={"system":23,"target":ordinal,"position":[point.x,point.y,point.z],"direction":[facing.x,facing.y,facing.z],"speed":0.0,"mode":"idle","orbit_time":0.0}
 view.update_navigation(nav);view.exterior=true
 await create_timer(1.5).timeout
 view.transit_overlay.arrival_age=2.0
 await RenderingServer.frame_post_draw
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/space-experience")
 DirAccess.make_dir_recursive_absolute(out)
 root.get_texture().get_image().save_png(out+"/arrival.png")
 view.transit_overlay.arrival_age=100
 view.set_process(false)
 view.transit_overlay.scan_body=body;view.transit_overlay.scan_progress=1.0
 var report:=FrontierOrbitalSurvey.report(body)
 assert(report.available and not report.resources.is_empty())
 assert(not FrontierOrbitalSurvey.report(FrontierUniverse.body(manifest,4)).available)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/scan.png")
 print("SPACE EXPERIENCE: English names, arrival and survey rendered")
 view.transit_overlay.scan_body={}
 var behind:=FrontierSpaceGuidance.project(view.camera,view.camera.global_position+view.camera.global_basis.z*100,Vector2(1280,800))
 assert(not behind.onscreen and Rect2(0,0,1280,800).has_point(behind.point))
 behind.kind="target";behind.label=body.name
 var danger:=FrontierSpaceGuidance.project(view.camera,Vector3.ZERO,Vector2(1280,800));danger.kind="hazard";danger.label="경고 경계까지 3.2 km"
 view.transit_overlay.guidance=[behind,danger]
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/guidance.png")
 var journal:=FrontierNavigationJournal.new();journal.manifest=manifest
 journal.path="user://space_journal_test.json"
 journal.scanned(ordinal);journal.favorite(ordinal)
 journal.observe({"crew":{"navigation":nav,"landing":{}},"location":body.id,"navigation_site":{"state":"active"}})
 var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(journal.path))
 assert(journal.valid(loaded) and loaded.favorites.has(body.id) and loaded.bodies[body.id].scanned)
 assert(journal.ordinals(2).has(ordinal))
 var records:=FrontierNavigationRecords.new();records.journal=journal;root.add_child(records);records.refresh();records.popup_centered()
 await create_timer(.2).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/records.png")
 assert(records.entries.item_count==1)
 records.hide();records.queue_free()
 DirAccess.remove_absolute(journal.path);DirAccess.remove_absolute(journal.path+".bak")
 print("NAVIGATION RECORDS: persistence, favorites, development filter and window OK")
 view.queue_free();await process_frame;quit()
