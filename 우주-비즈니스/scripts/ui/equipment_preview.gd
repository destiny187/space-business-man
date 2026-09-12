class_name FrontierEquipmentPreview
extends SubViewportContainer
var viewport: SubViewport
var stage: Node3D
var model: Node3D
var camera: Camera3D
var model_path: String=""
# Animated subclasses opt in; static authored models reuse their last image.
var continuous_rendering:=false
var render_dirty:=true
var render_state: Array=[]
var specimen_bounds:=AABB()
func request_render() -> void:
	render_dirty=true
func _ready() -> void:
	stretch=true;mouse_default_cursor_shape=Control.CURSOR_DRAG;tooltip_text="드래그하여 장비 회전"
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.size=Vector2i(480,480);viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=FrontierInterfaceStyle.INK;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b5cbd4");env.ambient_light_energy=.65;world.environment=env;stage.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,-40,0);light.light_energy=1.4;stage.add_child(light)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;camera.near=.01;stage.add_child(camera)
	var contour:=FrontierInkStyle.attach(stage,true);contour.set_shader_parameter("transparent_background",true)
	visibility_changed.connect(request_render);resized.connect(request_render)
func show_model(path: String) -> void:
	if model_path==path:return
	specimen_bounds=AABB()
	model_path=path;request_render()
	if model!=null:stage.remove_child(model);model.queue_free();model=null
	if path.is_empty():return
	model=load("res://assets/models/"+path+".glb").instantiate();stage.add_child(model);FrontierInkStyle.apply(model,{})
	var bounds:=AABB();var first:=true
	for child in model.find_children("*","MeshInstance3D",true,false):
		var box: AABB=child.global_transform*child.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	var center:=bounds.get_center();model.position-=center
	camera.size=bounds.size.length()*1.16;camera.position=Vector3(1,.65,-1.5).normalized()*bounds.size.length()*3;camera.look_at(Vector3.ZERO)
	if path.begins_with("equipment/gun_"):
		frame_specimen(bounds)
		camera.position=Vector3(1,.35,-.45).normalized()*bounds.size.length()*3;camera.look_at(Vector3.ZERO);_fit_specimen()
	request_render()
func show_specimen(sample: Dictionary) -> void:
	var definition:=FrontierEcologyCatalog.form(sample.form_id)
	var path: String=FrontierEcologyCatalog.model_key(definition)
	show_model(path)
	var geometry: Dictionary=definition.get("geometry",{}).get("near",{})
	if geometry.has("min") and geometry.has("max"):
		var low:=Vector3(geometry.min[0],geometry.min[1],geometry.min[2]);var high:=Vector3(geometry.max[0],geometry.max[1],geometry.max[2])
		model.position=-(low+high)*.5
		frame_specimen(AABB(low,high-low))
	var look:=FrontierNativeIncidents.look(sample) if sample.has("variant") and sample.has("factor") else FrontierEcologyCatalog.look(sample.form_id,sample.look_id)
	for node in model.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null:continue
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if not material is ShaderMaterial:continue
			var role:=material.resource_name.trim_prefix("Bio_")
			var index: int=["main","secondary","accent"].find(role)
			if index>=0:material.set_shader_parameter("base_color",Color(look.palette[index]).linear_to_srgb())
	request_render()

func frame_specimen(bounds: AABB) -> void:
	specimen_bounds=AABB(-bounds.size*.5,bounds.size)
	camera.position=Vector3(1,.45,-1.4).normalized()*bounds.size.length()*3;camera.look_at(Vector3.ZERO)
	_fit_specimen()

func _fit_specimen() -> void:
	if not specimen_bounds.has_volume():return
	var projected:=AABB();var first:=true
	for i in 8:
		var point:=camera.global_basis.inverse()*specimen_bounds.get_endpoint(i)
		projected=AABB(point,Vector3.ZERO) if first else projected.expand(point);first=false
	var aspect:=maxf(size.x,1.0)/maxf(size.y,1.0)
	# Fit the projected anatomy to this panel's aspect, including flat colonies.
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=maxf(projected.size.y,projected.size.x/aspect)*1.2

func _gui_input(event: InputEvent) -> void:
	if model!=null and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):model.rotate_y(event.relative.x*.012);request_render()
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	_fit_specimen()
	# Callers also adjust framing directly after model changes. Detect those
	# inexpensive values, without walking meshes or hashing materials each frame.
	var current: Array=[size,viewport.size,camera.transform,camera.size,camera.fov,camera.projection,model.transform if is_instance_valid(model) else Transform3D.IDENTITY]
	if current!=render_state:render_state=current;render_dirty=true
	if render_dirty or continuous_rendering:
		render_dirty=false
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		if not RenderingServer.frame_post_draw.is_connected(_rendered):RenderingServer.frame_post_draw.connect(_rendered,CONNECT_ONE_SHOT)
	else:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func _rendered() -> void:
	if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
