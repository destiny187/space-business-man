class_name FrontierEquipmentPreview
extends SubViewportContainer
var viewport: SubViewport
var stage: Node3D
var model: Node3D
var camera: Camera3D
var model_path: String=""
func _ready() -> void:
	stretch=true;mouse_default_cursor_shape=Control.CURSOR_DRAG;tooltip_text="드래그하여 장비 회전"
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.size=Vector2i(480,480);viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=FrontierInterfaceStyle.INK;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b5cbd4");env.ambient_light_energy=.65;world.environment=env;stage.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,-40,0);light.light_energy=1.4;stage.add_child(light)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;camera.near=.01;stage.add_child(camera)
	var contour:=FrontierInkStyle.attach(stage,true);contour.set_shader_parameter("transparent_background",true)
func show_model(path: String) -> void:
	if model_path==path:return
	model_path=path
	if model!=null:stage.remove_child(model);model.queue_free();model=null
	if path.is_empty():return
	model=load("res://assets/models/"+path+".glb").instantiate();stage.add_child(model);FrontierInkStyle.apply(model,{})
	var bounds:=AABB();var first:=true
	for child in model.find_children("*","MeshInstance3D",true,false):
		var box: AABB=child.global_transform*child.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	var center:=bounds.get_center();model.position-=center
	camera.size=bounds.size.length()*1.16;camera.position=Vector3(1,.65,-1.5).normalized()*bounds.size.length()*3;camera.look_at(Vector3.ZERO)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
func _gui_input(event: InputEvent) -> void:
	if model!=null and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):model.rotate_y(event.relative.x*.012);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
func _process(_delta: float) -> void:
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
