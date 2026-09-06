extends SceneTree
var app: FrontierCrewExpedition
var folder: String
var role: String
var messages: Array=[]
var elapsed:=0.0
var responses: Array=[]
var capturing:=false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		if argument.contains("="):
			var pair:=argument.split("=",true,1);options[pair[0]]=pair[1]
	folder=options["--crew-folder"];role=options["--crew-role"]
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	app.profile=FrontierPlayerProfile.new(folder+"/profile.json");app.world_store=FrontierWorldStore.new(folder+"/world.json");app.port_input.value=int(options["--crew-port"]);app.name_input.text=role
	app.profile.ensure(role)
	if role.begins_with("guest"):
		app.profile.data.character.tint=int(role.trim_prefix("guest"))+1;app.profile.save()
	app.session.notice.connect(func(message: String):messages.append(message))
	app.session.response_received.connect(func(sequence: int,value: Dictionary):responses.append({"sequence":sequence,"result":value}))
	if role=="host":app.host_world()
	else:app.join_world()
func _process(delta: float) -> bool:
	if app==null:return false
	elapsed+=delta
	if elapsed<.05:return false
	elapsed=0
	var command_path:=folder+"/command.json"
	if FileAccess.file_exists(command_path):
		var command: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(command_path));DirAccess.remove_absolute(command_path)
		match command.kind:
			"request":app.session.send_request(command.action,command.get("args",{}))
			"move":app.test_direction=Vector2(command.direction[0],command.direction[1])
			"capture":capture(command.get("outside",false),command.get("view",""))
			"kick":app.session.kick(command.character_id)
			"close":close_peer()
	var state: Dictionary={"active":app.session.active,"snapshot":app.session.latest,"messages":messages,"responses":responses,"actors":app.actors.size(),"recovery_models":app.recovery_models.size()}
	var output:=FileAccess.open(folder+"/status.tmp",FileAccess.WRITE);output.store_string(JSON.stringify(state));output.close();DirAccess.rename_absolute(folder+"/status.tmp",folder+"/status.json")
	return false
func capture(outside: bool,view_name: String="") -> void:
	if capturing:return
	capturing=true;app.test_camera_position=Vector3.ZERO;app.pitch=-.03
	app.outside=outside;app.exterior_view.visible=outside;app.if_flight_view()
	if view_name=="recovery" and not app.recovery_models.is_empty():
		var target: Vector3=app.recovery_models.values()[0].position+Vector3(0,.35,0)
		var direction: Vector3=(target-app.camera.position).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw
	if view_name=="recovery":print("RECOVERY_FRAME ",app.camera.position," rotation ",app.camera.rotation," crate ",app.recovery_models.values()[0].position)
	root.get_texture().get_image().save_png(folder+("/recovery.png" if view_name=="recovery" else ("/exterior.png" if outside else "/cabin.png")))
	app.yaw=0;app.pitch=-.03;capturing=false
func close_peer() -> void:
	await app.session.close_session();quit()
