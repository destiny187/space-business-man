extends "res://tests/test_solo_entry.gd"
var submitted:=0
var modal_commands: Array=[]
func modal(owner_node: Node) -> FrontierGameModal:
	for child in owner_node.get_children():
		if child is FrontierGameModal and child.visible:return child
	return null
func fit(dialog: FrontierGameModal,label: String) -> void:
	check(dialog.borderless and dialog.exclusive,label+" uses game shell and exclusive input")
	check(dialog.position.x>=0 and dialog.position.y>=0 and dialog.position.x+dialog.size.x<=root.content_scale_size.x and dialog.position.y+dialog.size.y<=root.content_scale_size.y,label+" fits viewport")
	check(dialog.primary.get_global_rect().end.y<=dialog.size.y and dialog.primary.get_global_rect().end.x<=dialog.size.x,label+" fixed action remains reachable")
func run() -> void:
	var source:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
		if arg.begins_with("--source-folder="):source=arg.trim_prefix("--source-folder=")
	assert(not source.is_empty() and not folder.is_empty() and source!=folder)
	DirAccess.make_dir_recursive_absolute(folder)
	for file in ["world.json","profile.json"]:assert(DirAccess.copy_absolute(source+"/"+file,folder+"/"+file)==OK)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not app.preparing_first_snapshot and not app.arrival.active,"saved ground scene ready",120):quit(1);return
	if "--actions-only" in OS.get_cmdline_user_args():
		await salvage_action();return
	app.close_menus();app.business_panel.set_context("ship");app.open_menu(app.business_panel)
	app.business_panel.update(app.session.surface.business,app.surface_world.body.id,app.session.latest.self_id,int(app.surface_world.body.planet_tier),{},{},app.surface_world.body)
	app.business_panel.command.connect(func(kind: String,args: Dictionary):modal_commands.append([kind,args]))
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app.business_panel.confirm_settlement(false)
	var dialog:=modal(app.business_panel)
	await capture("settlement-1280");fit(dialog,"settlement")
	check(FrontierCursorPolicy.modal_open(self) and app.feedback.blocked(),"modal blocks gameplay and feedback immediately")
	check(dialog.secondary.has_focus(),"transfer initially focuses return")
	var credits: int=app.session.authority.world.business.credits
	check(dialog.content.get_child_count()==3,"settlement separates payment, affected assets, retained assets and validation")
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	dialog.push_input(escape);await process_frame
	check(modal_commands.is_empty() and int(app.session.authority.world.business.credits)==credits,"Escape makes no transaction")
	check(not FrontierCursorPolicy.modal_open(self),"Escape releases modal guard without closing underlying menu")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	FrontierClientSettings.ensure(self).values.ui_scale=1.3;FrontierUIScale.apply_tree(self,1.3)
	app.business_panel.confirm_settlement(false);dialog=modal(app.business_panel)
	await capture("settlement-960-130");fit(dialog,"settlement 130 percent")
	dialog.scroll.scroll_vertical=10000;await capture("settlement-bottom-960-130")
	dialog.accept();dialog.accept()
	await process_frame
	check(modal_commands.size()==1 and modal_commands[0][0]=="business_settle","repeated confirmation submits once")
	await create_timer(.5).timeout
	check(int(app.session.authority.world.business.credits)==credits,"unready site rejection does not credit preview amount")
	app.business_panel.confirm_settlement(true);dialog=modal(app.business_panel)
	await capture("retained-960-130");fit(dialog,"retained settlement");dialog.cancel();await process_frame
	var inventory:=FrontierResourceListDialog.new();app.add_child(inventory)
	inventory.show_stock("Procyon 25799 e  /  현장 창고",{"iron":120,"copper":40,"stone":80,"ice":65,"refined_iron":12,"control_circuit":8})
	inventory.present(Vector2i(660,560));await capture("resources-960-130");fit(inventory,"resource browser")
	inventory.browser.search.text="없는 자원";inventory.refresh();check(inventory.empty.visible,"resource filter empty state visible")
	inventory.cancel();await process_frame
	app.inventory_panel._open_use({"name":"정제 철","where":"Mk.2 제작소에서 생산","model":"products/refined_iron","cost":{"iron":2},"target":"product","id":"refined_iron"})
	dialog=app.inventory_panel.usage_dialog;await capture("use-960-130");fit(dialog,"resource use");dialog.cancel();await process_frame
	app.open_menu(app.shipyard_panel)
	app.shipyard_panel.tabs.current_tab=1
	app.shipyard_panel.update_snapshot(app.session.latest,app.session.surface.business)
	app.shipyard_panel.send("vessel_draw");dialog=modal(app.shipyard_panel)
	await capture("draw-960-130");fit(dialog,"vessel draw");dialog.cancel();await process_frame
	# Open a real generated module through the inventory's existing module panel.
	var modules: FrontierSuitModulePanel
	for child in app.inventory_panel.tabs.get_children():
		if child is FrontierSuitModulePanel:modules=child
	modules.member={"modules":FrontierSuitModules.create()};modules.member.modules.items["modal-preview"]=FrontierSuitModules.roll(931,2,"discovery");modules.selected="modal-preview"
	modules.confirm_salvage();dialog=modal(modules)
	await capture("salvage-960-130");fit(dialog,"suit salvage");dialog.cancel();await process_frame
	app.navigation_records.refresh();app.navigation_records.present(Vector2i(760,620))
	await capture("records-960-130");fit(app.navigation_records,"navigation records");app.navigation_records.cancel();await process_frame
	# Orbital personal equipment uses the same real handler; restore the ground pointer before any frame.
	var ground:=app.surface_world;app.surface_world=null;app.show_equipment();app.surface_world=ground
	dialog=modal(app);await capture("equipment-960-130");fit(dialog,"personal equipment");dialog.cancel();await process_frame
	var shell:=Control.new();app.ui.add_child(shell)
	var legacy=load("res://scripts/app/main.gd").new();legacy.ui=shell
	legacy._confirm("시설을 철거하고 건설 재료를 보관함으로 반환합니다.",func():submitted+=1)
	dialog=modal(shell);await capture("legacy-confirm-960-130");fit(dialog,"legacy confirmation")
	var second:=FrontierGameModal.new();shell.add_child(second);second.configure("두 번째 작업","닫기");second.present(Vector2i(620,400))
	check(not dialog.visible and second.visible and submitted==0,"opening another modal cancels earlier confirmation without executing")
	second.cancel();second.queue_free();await process_frame;legacy.free()
	var flight:=FrontierSpaceFlight.new();flight.ui_root=shell
	flight.state={"manifest":{"catalog":{"records":[{"name":"관측 자료 표시 검사","values":{"radius":{"value":1.2},"equilibrium_temperature":{"value":280}}}]}}}
	flight._observations();dialog=modal(shell);await capture("observations-960-130");fit(dialog,"legacy observations");dialog.cancel();await process_frame;flight.free()
	var closing:=FrontierGameModal.new();shell.add_child(closing);closing.configure("시설 작업","확정","시설", "build",true);closing.present();shell.hide();await process_frame
	check(not closing.visible and not FrontierCursorPolicy.modal_open(self),"closing owner releases its modal and input guard")
	shell.queue_free();await process_frame
	check(modal_commands.size()==1,"all canceled preview flows remain read-only")
	FrontierClientSettings.ensure(self).values.ui_scale=1.0;FrontierUIScale.apply_tree(self,1.0)
	check(await app.session.close_session(),"isolated session closes normally")
	app.queue_free();await process_frame
	print("GAME_MODALS checks=",checks," failures=",failures);quit(1 if failures else 0)

func salvage_action() -> void:
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var actor: String=app.session.latest.self_id
	var member: Dictionary=app.session.authority.world.crew.members[actor]
	FrontierSuitModules.ensure(member)
	member.modules.items["modal-owned"]=FrontierSuitModules.roll(931,2,"discovery")
	var before:=int(FrontierExpeditionBusiness.bag(app.session.authority.world,actor).get("refined_iron",0))
	app.session._publish()
	app.open_menu(app.inventory_panel)
	var modules: FrontierSuitModulePanel
	for child in app.inventory_panel.tabs.get_children():
		if child is FrontierSuitModulePanel:modules=child;app.inventory_panel.tabs.current_tab=child.get_index()
	await process_frame
	modules.member=app.session.latest.crew.members[actor];modules.selected="modal-owned";modules.confirm_salvage()
	var dialog:=modal(modules)
	check(dialog!=null,"owned module opens actual salvage confirmation")
	modules.selected="another-selection"
	dialog.accept();dialog.accept()
	await until(func():return not app.session.authority.world.crew.members[actor].modules.items.has("modal-owned"),"confirmed modal salvages the originally shown item",10)
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,actor).get("refined_iron",0))==before+2,"host returns materials exactly once")
	check(app.feedback.audio.last_played.has("sfx_build_place"),"confirmed salvage triggers existing success sound")
	var stored:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not stored.crew.members[actor].modules.items.has("modal-owned"),"salvage result is durably stored")
	app.open_menu(app.shipyard_panel);app.shipyard_panel.tabs.current_tab=0
	app.shipyard_panel.update_snapshot(app.session.latest,app.session.surface.business)
	# A local display fixture exercises the other confirmation branch, without sending a transaction.
	app.shipyard_panel.vessel=app.shipyard_panel.vessel.duplicate(true)
	app.shipyard_panel.vessel.modules["display-module"]={"type":"drive","grade":"improved"}
	app.shipyard_panel.rebuild();app.shipyard_panel.send("vessel_salvage")
	dialog=modal(app.shipyard_panel);await capture("vessel-salvage-960");fit(dialog,"vessel salvage");dialog.cancel();await process_frame
	check(await app.session.close_session(),"action fixture closes normally")
	app.queue_free();await process_frame;print("GAME_MODAL_ACTION checks=",checks," failures=",failures);quit(1 if failures else 0)
