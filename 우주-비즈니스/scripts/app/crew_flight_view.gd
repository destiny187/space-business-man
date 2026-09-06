class_name FrontierCrewFlightView
extends FrontierSpaceFlight
var navigation: Dictionary={}
var exterior:=false
func _ready() -> void:
	test_mode=true
	flight_config=state.manifest.settings.flight
	_setup_space();_build_ui();ui_root.hide()
	ship.get_child(0).scale=Vector3.ONE*2
	_load_system(0)
	set_physics_process(false);set_process_unhandled_input(false)
func update_navigation(value: Dictionary) -> void:
	if navigation.is_empty() or int(value.system)!=current_system:
		_load_system(int(value.system));ship.position=FrontierCrewWorld.vector(value.position)
	navigation=value.duplicate(true)
func _process(delta: float) -> void:
	if navigation.is_empty():return
	ship.position=ship.position.lerp(FrontierCrewWorld.vector(navigation.position),minf(delta*14,1))
	ship.quaternion=ship.quaternion.slerp(_flight_basis(FrontierCrewWorld.vector(navigation.direction)).get_rotation_quaternion(),minf(delta*6,1))
	camera.position=Vector3(0,16,57) if exterior else Vector3(0,2,-18)
	camera.rotation=Vector3(-.15,0,0) if exterior else Vector3.ZERO
	camera.fov=lerpf(camera.fov,90.0 if navigation.mode=="jump" else 65.0,minf(delta*3,1))
