extends SceneTree
# Deterministic presentation recording. Only this scene uses staged late-game assets.
func _initialize() -> void: call_deferred("run")
func mouse(button: MouseButton,down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button; event.pressed = down; event.position = Vector2(640,400)
	Input.parse_input_event(event)
func run() -> void:
	root.size = Vector2i(1280,800)
	var app: Node = load("res://scenes/app/main.tscn").instantiate(); root.add_child(app)
	app.smoke_mode = true; app.campaign.persistence_enabled = false
	app._new_game()
	await create_timer(1.2).timeout
	app._buy_contract("basalt")
	var ore: Dictionary = app.campaign.planet.nodes[0]
	FrontierOnboarding.record(app.campaign.state,"travel",5)
	app.world.player.position = Vector3(ore.position[0],0.1,ore.position[1]+4)
	app.world.player.rotation.y = 0; app.world.head.rotation.x = -0.18
	await create_timer(0.6).timeout
	app.toast("M-02 / 좌클릭 유지 · 광물 흡입")
	mouse(MOUSE_BUTTON_LEFT,true)
	await create_timer(2.0).timeout
	mouse(MOUSE_BUTTON_LEFT,false)
	await create_timer(0.9).timeout
	app.toast("M-02 / 우클릭 · 펄스 파쇄")
	mouse(MOUSE_BUTTON_RIGHT,true)
	await create_timer(1.5).timeout
	mouse(MOUSE_BUTTON_RIGHT,false)
	await create_timer(0.8).timeout
	app._show_menu("build")
	await create_timer(1.5).timeout
	app._smoke_setup()
	app.campaign.buy_technology("combat")
	app.campaign.craft("guardian")
	for i in range(260): app.simulation.step(app.campaign,0.1)
	var civ: Dictionary = app.campaign.planet.events[3]
	app.campaign.planet.player.position = civ.position.duplicate()
	app.campaign.discover(civ.id)
	app.campaign.choose_event(civ.id,"destroy")
	app.campaign.planet.robots[-1].position = [civ.position[0]+7,civ.position[1]]
	app.world.rebuild(app.campaign.planet)
	app._close_menu(); app.world.toggle_camera()
	app.world.orbital_camera.position = Vector3(civ.position[0]+14,11,civ.position[1]+14)
	app.world.orbital_camera.look_at(Vector3(civ.position[0],1,civ.position[1]))
	app.toast("경비로봇 연출 시연 / 포탑 추적 · 발사 · 명중")
	await create_timer(3.0).timeout
	app._quit_game()
