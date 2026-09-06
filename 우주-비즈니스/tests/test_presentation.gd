extends SceneTree
var app: Node
var checks: int = 0
var failures: int = 0
var destination: String
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func mouse(button: MouseButton,down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button; event.pressed = down; event.position = Vector2(640,400)
	Input.parse_input_event(event)
func key(code: Key,down: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = down; Input.parse_input_event(event)
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(destination.path_join(label+".png"))
func run() -> void:
	root.size = Vector2i(1280,800)
	destination = ProjectSettings.globalize_path("res://../test-results/presentation")
	DirAccess.make_dir_recursive_absolute(destination)
	app = load("res://scenes/app/main.tscn").instantiate(); root.add_child(app)
	app.smoke_mode = true; app.campaign.persistence_enabled = false
	app._new_game()
	await create_timer(0.3).timeout
	check(app.menu.find_children("*","Button",true,false).size() > 0,"contract has actionable controls")
	await capture("01-first-contract")
	app._buy_contract("basalt")
	await create_timer(0.2).timeout
	check(app.hud.guide.id == "move","one landing objective")
	await capture("02-landing")
	key(KEY_D,true); await create_timer(1.2).timeout; key(KEY_D,false)
	await create_timer(0.3).timeout
	check(app.hud.guide.id == "mine","physical movement advances objective")
	var ore: Dictionary = app.campaign.planet.nodes[0]
	app.world.player.position = Vector3(ore.position[0],0.1,ore.position[1]+4)
	app.world.player.rotation.y = 0; app.world.head.rotation.x = -0.18
	await create_timer(0.25).timeout
	var fan: Node3D = null
	for part in app.world.moving_parts:
		if part.name.begins_with("Anim_Fan"): fan = part
	check(fan != null,"Blender intake fan imported separately")
	var before_fan: Vector3 = fan.rotation if fan else Vector3.ZERO
	var before_ore: int = ore.amount
	mouse(MOUSE_BUTTON_LEFT,true)
	await create_timer(0.18).timeout
	check(app.world.effects.emitted.suction > 0,"real mouse mining spawns suction shards")
	check(app.world.effects.active.size() >= 4,"visible particles exist during absorption")
	var first: Dictionary = app.world.effects.active[0]
	var before_position: Vector3 = first.node.position
	await capture("03-suction-start")
	await create_timer(0.18).timeout
	check(first.node.position.distance_to(before_position) > 0.05,"absorption moves through space")
	check(fan == null or not fan.rotation.is_equal_approx(before_fan),"intake fan actually rotates")
	await capture("04-suction-flow")
	await create_timer(0.4).timeout
	mouse(MOUSE_BUTTON_LEFT,false)
	check(before_ore-ore.amount == FrontierCatalog.total(app.campaign.planet.player.cargo),"visual acquisition matches actual resource transfer")
	check(app.hud.guide.id == "deposit","gathering objective advances")
	await create_timer(1.0).timeout
	mouse(MOUSE_BUTTON_RIGHT,true)
	await create_timer(0.04).timeout
	check(app.world.effects.emitted.pulse > 0 and app.world.recoil > 0,"right mouse fires with recoil")
	await capture("05-pulse-fire")
	await create_timer(0.13).timeout
	check(app.world.effects.emitted.impact > 0,"projectile produces an impact")
	await capture("06-pulse-impact")
	await create_timer(3.0).timeout
	check(app.overheated,"sustained fire overheats tool")
	mouse(MOUSE_BUTTON_RIGHT,false)
	await capture("07-cooling")
	for i in range(20): app.world.effects.burst(app.world.player.position+Vector3.UP,Color.WHITE,24)
	check(app.world.effects.active.size() <= FrontierEffects.LIMIT,"effect count remains bounded")
	app._show_menu("pause")
	await process_frame; await process_frame
	var age: float = app.world.effects.active[0].age
	var heat: float = app.tool_heat
	await create_timer(0.25).timeout
	check(app.world.effects.active[0].age == age and app.tool_heat == heat,"menus pause effects and cooling")
	app._close_menu()
	await create_timer(4.0).timeout
	check(not app.overheated and app.world.effects.active.is_empty(),"cooldown and transient effect cleanup finish")
	check(app.world.effects.get_child_count() <= FrontierEffects.LIMIT,"effect meshes are reused")
	app.world.building_feedback(Vector2.ZERO)
	check(app.world.effects.emitted.construction == 1,"construction has a reveal effect")
	for page in ["build","technology","robots"]:
		app._show_menu(page); await create_timer(0.2).timeout
		check(app.menu.find_children("*","TextureRect",true,false).size() >= 3,"model portraits in "+page)
		await capture("08-"+page)
	app._smoke_setup()
	app.campaign.buy_technology("combat")
	check(app.campaign.craft("guardian").is_empty(),"guardian can be built for presentation fixture")
	for i in range(260): app.simulation.step(app.campaign,0.1)
	var civ: Dictionary = app.campaign.planet.events[3]
	app.campaign.planet.player.position = civ.position.duplicate()
	app.campaign.discover(civ.id)
	check(app.campaign.choose_event(civ.id,"destroy").is_empty(),"robot combat uses an approved operation")
	var guard: Dictionary = app.campaign.planet.robots[-1]
	guard.position = [civ.position[0]+7,civ.position[1]]
	app.world.rebuild(app.campaign.planet)
	app._close_menu()
	app.world.toggle_camera()
	app.world.orbital_camera.position = Vector3(civ.position[0]+14,11,civ.position[1]+14)
	app.world.orbital_camera.look_at(Vector3(civ.position[0],1,civ.position[1]))
	var old_pulses: int = app.world.effects.emitted.pulse
	await create_timer(1.1).timeout
	check(app.world.effects.emitted.pulse > old_pulses,"working guardian visibly fires")
	check(app.world.robot_nodes[guard.id].has_meta("turret"),"Blender turret and barrels have an aiming rig")
	await capture("09-robot-operation")
	print("PRESENTATION_TESTS checks=%d failures=%d" % [checks,failures])
	if failures == 0: app._quit_game()
	else: quit(1)
