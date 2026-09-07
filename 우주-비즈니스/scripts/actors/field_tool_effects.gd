class_name FrontierFieldToolEffects
extends Node3D
## Transient optics only: mineral fragments and rewards come from accepted commands.
var flow := MeshInstance3D.new()
var geometry := ImmediateMesh.new()
var scan_shell := MeshInstance3D.new()
var scan_material := ShaderMaterial.new()
var flow_material := ShaderMaterial.new()
var clock := 0.0
var surface_material := ShaderMaterial.new()
var scanned_subject: Node3D
var overlays: Array[Dictionary]=[]

func _ready() -> void:
	flow_material.shader=load("res://assets/materials/intake_flow.gdshader")
	flow.mesh=geometry;flow.material_override=flow_material
	flow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flow)
	var shell:=SphereMesh.new()
	shell.radius=1;shell.height=2;shell.radial_segments=48;shell.rings=24
	scan_material.shader=load("res://assets/materials/survey_shell.gdshader")
	surface_material.shader=load("res://assets/materials/survey_surface.gdshader")
	scan_shell.mesh=shell;scan_shell.material_override=scan_material
	scan_shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scan_shell);reset()

func reset() -> void:
	flow.hide();stop_survey();geometry.clear_surfaces()

func update_intake(origin: Vector3,intake: Vector3,camera: Camera3D,strength: float,delta: float) -> void:
	clock+=delta;geometry.clear_surfaces();flow.visible=strength>.02
	if not flow.visible:return
	var axis:=intake-origin
	if axis.length_squared()<.01:return
	var direction:=axis.normalized()
	var side:=direction.cross(Vector3.UP).normalized()
	if side.length_squared()<.01:side=Vector3.RIGHT
	var up:=side.cross(direction).normalized()
	flow_material.set_shader_parameter("strength",strength)
	flow_material.set_shader_parameter("phase",clock)
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in 4:
		for segment in 32:
			var t0:=float(segment)/32.0
			var t1:=float(segment+1)/32.0
			var p0:=_flow_point(origin,intake,side,up,t0,strand)
			var p1:=_flow_point(origin,intake,side,up,t1,strand)
			var width: Vector3=(p1-p0).cross(camera.global_position-(p0+p1)*.5).normalized()*.012
			for vertex in [[p0-width,Vector2(0,t0)],[p0+width,Vector2(1,t0)],[p1+width,Vector2(1,t1)],[p0-width,Vector2(0,t0)],[p1+width,Vector2(1,t1)],[p1-width,Vector2(0,t1)]]:
				geometry.surface_set_uv(vertex[1]);geometry.surface_add_vertex(to_local(vertex[0]))
	geometry.surface_end()

func _flow_point(origin: Vector3,intake: Vector3,side: Vector3,up: Vector3,t: float,strand: int) -> Vector3:
	var radius:=lerpf(.38,.035,t)*sin(minf(t*8,1.0)*PI*.5)
	var angle:=t*TAU*1.2+float(strand)*TAU/4-clock*3
	return origin.lerp(intake,t)+(side*cos(angle)+up*sin(angle))*radius

func survey(point: Vector3,progress: float,complete: bool=false,radius: float=1.25,subject: Node3D=null) -> void:
	if subject!=scanned_subject:
		stop_survey();scanned_subject=subject
		if is_instance_valid(subject):_attach_survey(subject)
	surface_material.set_shader_parameter("progress",progress)
	surface_material.set_shader_parameter("complete",complete)
	scan_shell.visible=overlays.is_empty();scan_shell.global_position=point
	scan_shell.scale=Vector3.ONE*radius
	scan_material.set_shader_parameter("progress",progress)
	scan_material.set_shader_parameter("complete",complete)

func stop_survey() -> void:
	scan_shell.hide()
	for row in overlays:
		if is_instance_valid(row.mesh):row.mesh.material_overlay=row.previous
	overlays.clear();scanned_subject=null

func _attach_survey(subject: Node3D) -> void:
	var low:=INF
	var high:=-INF
	var meshes:=subject.find_children("*","MeshInstance3D",true,false)
	if subject is MeshInstance3D:meshes.append(subject)
	for node in meshes:
		var mesh: MeshInstance3D=node
		if mesh.mesh==null or not mesh.is_visible_in_tree():continue
		var bounds:=mesh.get_aabb()
		for corner in 8:
			var position_value:=mesh.to_global(bounds.get_endpoint(corner))
			low=minf(low,position_value.y);high=maxf(high,position_value.y)
		overlays.append({"mesh":mesh,"previous":mesh.material_overlay})
		mesh.material_overlay=surface_material
	if not overlays.is_empty():
		surface_material.set_shader_parameter("bottom",low)
		surface_material.set_shader_parameter("top",high)

func _exit_tree() -> void:
	stop_survey()
