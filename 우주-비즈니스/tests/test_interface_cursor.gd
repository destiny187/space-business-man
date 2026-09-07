extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func run() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	change_scene_to_file("res://scenes/app/main.tscn")
	await process_frame;await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"home releases inherited capture")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await process_frame;await process_frame
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"home maintains visible cursor")
	change_scene_to_file("res://scenes/app/crew_expedition.tscn")
	await process_frame;await process_frame
	var app: FrontierCrewExpedition=current_scene
	app.set_process(false);app.set_physics_process(false)
	for child in app.find_children("*","Node",true,false):
		child.set_process(false);child.set_physics_process(false)
	app.session.active=true;app.session.latest={"phase":"playing"}
	app.waiting_screen.hide();app.lobby.hide();app.navigation_frame.hide();app.onboarding.letter.hide()
	check(app._mouse_look_allowed(),"gameplay permits mouse look")
	for panel in [app.navigation_frame,app.inventory_panel,app.business_panel,app.shipyard_panel,app.research_frame,app.onboarding.letter]:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;panel.show();app._sync_mouse_capture()
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not app._mouse_look_allowed(),"interactive panel releases capture: "+str(panel.name))
		panel.hide()
	var popup:=AcceptDialog.new();app.add_child(popup);popup.dialog_text="커서 확인";popup.popup_centered()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;app._sync_mouse_capture()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not app._mouse_look_allowed(),"modal equipment/dialog window blocks capture")
	popup.hide();popup.queue_free();await process_frame
	var settings:=FrontierClientSettings.current(self);settings.open();app._sync_mouse_capture()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not app._mouse_look_allowed(),"settings blocks capture")
	settings.close()
	check(app._mouse_look_allowed(),"closing UI restores gameplay eligibility")
	app.waiting_screen.show();app._sync_mouse_capture()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not app._mouse_look_allowed(),"waiting/home UI overrides playing session")
	app.session.active=false;app.session.latest={}
	print("CURSOR failures ",failures)
	quit(0 if failures==0 else 1)
