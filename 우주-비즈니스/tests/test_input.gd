extends SceneTree

var app: Node
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func run() -> void:
	root.size = Vector2i(1280,800)
	app = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(app)
	app.smoke_mode = true
	app.campaign.persistence_enabled = false
	app.campaign.store = FrontierSaveStore.new("user://test_input.json")
	await process_frame
	app._new_game()
	await process_frame
	await process_frame
	var buy: Button = null
	for button in app.menu.find_children("*","Button",true,false):
		if button.text.contains("2,400 Cr"): buy = button; break
	check(buy != null,"first planet purchase UI present")
	if buy == null: quit(1); return
	await click_control(buy)
	check(app.screen.is_empty() and not app.campaign.planet.is_empty(),"mouse activates purchase and enters field")
	if app.campaign.planet.is_empty(): quit(1); return
	await create_timer(0.1).timeout
	var start: Vector3 = app.world.player.position
	key(KEY_D,true)
	await create_timer(0.65).timeout
	key(KEY_D,false)
	check(app.world.player.position.x-start.x > 2,"physical input moves CharacterBody")
	var yaw: float = app.world.player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30,0)
	Input.parse_input_event(motion)
	await process_frame
	check(absf(app.world.player.rotation.y-yaw) > 0.02,"mouse motion rotates view")
	var ore: Dictionary = app.campaign.planet.nodes[0]
	app.world.player.position = Vector3(ore.position[0],0.1,ore.position[1]+4)
	app.world.player.rotation.y = 0
	app.world.head.rotation.x = -0.18
	await create_timer(0.12).timeout
	check(app.world.target.get("kind","") == "resource","physics ray finds ore")
	var before: int = ore.amount
	mouse(MOUSE_BUTTON_LEFT,true,Vector2(640,400))
	await create_timer(0.45).timeout
	mouse(MOUSE_BUTTON_LEFT,false,Vector2(640,400))
	check(ore.amount < before and FrontierCatalog.total(app.campaign.planet.player.cargo) > 0,"held mouse mines into actual cargo")
	app.world.player.position = Vector3(0,0.1,5)
	app.world.player.rotation.y = PI
	await create_timer(0.1).timeout
	await press_key(KEY_E)
	check(FrontierCatalog.total(app.campaign.planet.player.cargo) == 0 and app.campaign.planet.inventory.iron > 0,"interact key deposits cargo")
	await press_key(KEY_B)
	check(app.screen == "build" and not app.world.controls_enabled,"build key opens menu and pauses control")
	var planet_time: float = app.campaign.planet.time
	await create_timer(0.25).timeout
	check(app.campaign.planet.time == planet_time,"menu pauses simulation")
	await press_key(KEY_ESCAPE)
	check(app.screen.is_empty(),"escape resumes field")
	await press_key(KEY_V)
	check(app.world.orbit_mode,"camera action selects overview")
	await press_key(KEY_V)
	check(not app.world.orbit_mode,"camera action returns to first person")
	await press_key(KEY_F1)
	check(app.screen == "help","help opens using keyboard")
	app._show_menu("settings")
	app.campaign.profile.settings.volume = 0.25
	app.campaign.profile.settings.sensitivity = 0.003
	check(FrontierInput.rebind(app.campaign.profile.settings,"help",KEY_H).is_empty(),"save custom help key")
	app.campaign.persistence_enabled = true
	check(app.campaign.save().is_empty(),"save configured input profile")
	app.campaign.profile.settings.volume = 1.0
	app._continue_game()
	check(is_equal_approx(AudioServer.get_bus_volume_db(0),linear_to_db(0.25)),"loaded audio volume applied")
	await press_key(KEY_H)
	check(app.screen == "help","restored custom binding opens help")
	for size in [Vector2i(960,640),Vector2i(1920,1080)]:
		root.size = size
		await process_frame
		await process_frame
		check(app.menu.size.x > 0 and app.menu.size.y > 0,"menu exists at "+str(size))
	app.campaign.persistence_enabled = false
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists("user://test_input.json"+suffix): DirAccess.remove_absolute("user://test_input.json"+suffix)
	print("INPUT_TESTS checks=%d failures=%d" % [checks,failures.size()])
	if failures.is_empty(): app._quit_game()
	else: quit(1)

func key(code: int,down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.pressed = down
	Input.parse_input_event(event)
func press_key(code: int) -> void:
	key(code,true)
	await process_frame
	key(code,false)
	await process_frame
func mouse(button: MouseButton,down: bool,position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = position
	Input.parse_input_event(event)
func click_control(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	mouse(MOUSE_BUTTON_LEFT,true,point)
	await process_frame
	mouse(MOUSE_BUTTON_LEFT,false,point)
	await process_frame
