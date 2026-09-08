extends Node
## Orbital meshes share one material and navigation body; only geometry changes.
var near_mesh: Mesh
var far_mesh: Mesh
var shell: MeshInstance3D
var target: MeshInstance3D
var distant:=false
func configure(body: MeshInstance3D,far_path: String,atmosphere: MeshInstance3D) -> void:
	target=body;near_mesh=body.mesh;shell=atmosphere
	var source:Node3D=load(far_path).instantiate()
	far_mesh=source.find_children("*","MeshInstance3D",true,false)[0].mesh
	source.free()
func _process(_delta: float) -> void:
	if target==null:return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var radius:=target.global_basis.get_scale().abs().max_axis_index()
	var scale_value:float=target.global_basis.get_scale().abs()[radius]
	var distance:=camera.global_position.distance_to(target.global_position)
	var next:=distance>scale_value*(10.0 if distant else 12.0)
	if next==distant:return
	distant=next;target.mesh=far_mesh if distant else near_mesh
	if shell!=null:shell.mesh=target.mesh
