extends SceneTree

var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func run() -> void:
	root.size = Vector2i(1280,800)
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(app)
	app.smoke_mode = true
	app._smoke_setup()
	app.set_process(false)
	check(app.world.graphics_key == "balanced","old settings select balanced rendering")
	check(FrontierSaveStore.validate(app.campaign.state).is_empty(),"legacy save without graphics remains valid")
	app._show_menu("settings")
	var selector: OptionButton = app.menu.find_child("GraphicsQuality",true,false)
	check(selector != null and selector.item_count == 3,"graphics settings reachable in game")
	for key in FrontierGraphics.data().profiles:
		var index: int = FrontierGraphics.data().profiles.keys().find(key)
		selector.select(index)
		selector.item_selected.emit(index)
		await create_timer(.3).timeout
		check(app.world.graphics_key == key and app.campaign.profile.settings.graphics == key,"UI applies and stores "+key)
		check(app.world.environment.ssao_enabled == (key != "performance"),"AO policy "+key)
		check(app.world.environment.ssil_enabled == (key == "high") and app.world.environment.ssr_enabled == (key == "high"),"indirect lighting and reflections policy "+key)
		check(FrontierSaveStore.validate(app.campaign.state).is_empty(),"valid save for "+key)
		check(app.world.practical_lights.filter(func(lamp: OmniLight3D): return lamp.visible).size() <= FrontierGraphics.data().profiles[key].local_lights,"bounded local lights "+key)
	var invalid: Dictionary = app.campaign.state.duplicate(true)
	invalid.profile.settings.graphics = "unknown"
	check(not FrontierSaveStore.validate(invalid).is_empty(),"reject unknown graphics profile")
	invalid.profile.settings.graphics = 3
	check(not FrontierSaveStore.validate(invalid).is_empty(),"reject malformed graphics profile")
	var temp_path: String = "user://graphics-test-%d.json" % OS.get_process_id()
	var store := FrontierSaveStore.new(temp_path)
	check(store.write(app.campaign.state),"save selected quality to disk")
	var loaded: Dictionary = store.read_state()
	check(loaded.profile.settings.graphics == "high","quality survives save roundtrip")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(temp_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path+suffix))
	app.campaign.state = loaded
	app.world.apply_graphics("performance")
	app._apply_settings()
	check(app.world.graphics_key == "high","loading applies persisted quality")
	app.world.rebuild(app.campaign.planet)
	check(app.world.graphics_key == "high" and app.world.environment.ssr_enabled,"world rebuild preserves quality")
	var chassis: StandardMaterial3D
	var steel: StandardMaterial3D
	var enamel: StandardMaterial3D
	for material in app.world.material_cache.values():
		if material.resource_name.contains("Graphite"): chassis = material
		if material.resource_name.contains("Edge steel"): steel = material
		if material.resource_name.contains("Ceramic enamel"): enamel = material
	check(chassis != null and steel != null and enamel != null,"imported material identities retained")
	check(steel.roughness < enamel.roughness and enamel.roughness < chassis.roughness,"metal enamel chassis have distinct highlights")
	for i in range(3):
		var asset: Node3D = app.world.model("mesa_"+str(i))
		check(asset.find_children("*","MeshInstance3D",true,false).size() == 1,"mesa %d imported as one draw mesh" % i)
		asset.free()
	app._close_menu()
	app.world.toggle_camera()
	app.world.apply_graphics("balanced")
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var rendered: Image = root.get_texture().get_image()
	check(not rendered.is_empty() and rendered.get_pixel(640,400).a > .9,"render target available after preset switches")
	print("GRAPHICS_TESTS checks=%d failures=%d" % [checks,failures])
	if failures == 0: app._shutdown()
	else: quit(1)
