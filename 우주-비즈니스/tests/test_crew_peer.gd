extends SceneTree
var crew: FrontierCrewSession
var folder: String
var role: String
var identity: FrontierPlayerProfile
var messages: Array=[]
var responses: Array=[]
var elapsed:=0.0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		if argument.contains("="):
			var pair:=argument.split("=",true,1);options[pair[0]]=pair[1]
	folder=options["--crew-folder"];role=options["--crew-role"]
	identity=FrontierPlayerProfile.new(folder+"/profile.json")
	if not identity.ensure(role):printerr(identity.error);quit(1);return
	crew=FrontierCrewSession.new();crew.name="Coop";root.add_child(crew)
	crew.notice.connect(func(message: String):messages.append(message))
	crew.response_received.connect(func(sequence: int,result: Dictionary):responses.append({"sequence":sequence,"result":result}))
	if options.has("--crew-relay"):
		await crew.connect_relay(identity,FrontierWorldStore.new(folder+"/world.json"),options["--crew-relay"],role=="host",options.get("--crew-code",""))
	elif role=="host":crew.host(identity,FrontierWorldStore.new(folder+"/world.json"),int(options["--crew-port"]),"127.0.0.1")
	else:crew.join(identity,"127.0.0.1",int(options["--crew-port"]))
func _process(delta: float) -> bool:
	if crew==null:return false
	elapsed+=delta
	if elapsed<.05:return false
	elapsed=0
	var command_path:=folder+"/command.json"
	if FileAccess.file_exists(command_path):
		var command: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(command_path));DirAccess.remove_absolute(command_path)
		match command.kind:
			"request":crew.send_request(command.action,command.get("args",{}))
			"kick":crew.kick(command.character_id)
			"input":crew.send_input(Vector2(command.direction[0],command.direction[1]))
			"close":close_peer()
	var state: Dictionary={"active":crew.active,"invite_code":crew.invite_code,"snapshot":crew.latest,"messages":messages,"responses":responses,"character":identity.data.character}
	if crew.hosting:
		state.slots=crew.authority.slots();state.saved=crew.authority.world.crew
	var output:=FileAccess.open(folder+"/status.tmp",FileAccess.WRITE);output.store_string(JSON.stringify(state));output.close()
	DirAccess.rename_absolute(folder+"/status.tmp",folder+"/status.json")
	return false
func close_peer() -> void:
	await crew.close_session();quit()
