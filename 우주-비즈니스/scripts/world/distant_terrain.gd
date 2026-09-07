class_name FrontierDistantTerrain
extends MeshInstance3D
## World-aligned height samples keep mountains stable as the observer moves.
## CPU generation runs off-thread; the previous mesh remains until the swap.
var task_id: int=-1
var packet: Dictionary={}
var queued: Dictionary={}
var build_count:=0
var rendered_anchor:=Vector3i.ZERO
var has_rendered_anchor:=false

func request_rebuild(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,terrain_material: Material,view_distance: float) -> void:
	var unique_edits: Dictionary={}
	for chunk_edits in field.edits_by_chunk.values():
		for edit in chunk_edits:unique_edits[str(edit.center)+str(edit.radius)]=edit
	queued={"edits":unique_edits.values(),"seed":field.seed_value,"traits":field.traits.duplicate(true),"span":field.span,"anchor":anchor,"radius":radius_chunks,"distance":view_distance,"material":terrain_material}
	_start_job()

func _start_job() -> void:
	if task_id!=-1 or queued.is_empty():return
	var request:=queued;queued={};packet={"arrays":[],"material":request.material,"anchor":request.anchor}
	task_id=WorkerThreadPool.add_task(_build_job.bind(packet,request),false,"distant terrain")

func _build_job(result: Dictionary,request: Dictionary) -> void:
	var field:=FrontierTerrainField.new()
	field.configure(request.seed,request.edits,request.span,request.traits)
	result.arrays=_arrays(field,request.anchor,request.radius,request.distance)

func _process(_delta: float) -> void:
	if task_id==-1 or not WorkerThreadPool.is_task_completed(task_id):return
	WorkerThreadPool.wait_for_task_completion(task_id);task_id=-1
	rendered_anchor=packet.anchor;has_rendered_anchor=true
	_install(packet.arrays,packet.material)
	_start_job()

func _install(arrays: Array,terrain_material: Material) -> void:
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=result;material_override=terrain_material;build_count+=1

func rebuild(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,terrain_material: Material,view_distance: float=1060.0) -> void:
	rendered_anchor=anchor;has_rendered_anchor=true
	_install(_arrays(field,anchor,radius_chunks,view_distance),terrain_material)

static func _arrays(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,view_distance: float) -> Array:
	var center:=Vector2((anchor.x+.5)*field.span,(anchor.z+.5)*field.span)
	var inner: float=(radius_chunks+.5)*field.span
	var hole:=Rect2(center-Vector2.ONE*inner,Vector2.ONE*inner*2)
	# Both grids align to world coordinates, never to the camera direction.
	var coarse:=16.0 if view_distance<=4096 else 32.0
	var low: Vector2=(hole.position/ coarse).floor()*coarse-Vector2.ONE*coarse
	var high: Vector2=(hole.end/coarse).ceil()*coarse+Vector2.ONE*coarse
	var join:=Rect2(low,high-low)
	var outer_low: Vector2=((center-Vector2.ONE*view_distance)/coarse).floor()*coarse
	var outer_high: Vector2=((center+Vector2.ONE*view_distance)/coarse).ceil()*coarse
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	_append_grid(field,join,hole,4.0,vertices,normals,indices,true)
	_append_grid(field,Rect2(outer_low,outer_high-outer_low),join,coarse,vertices,normals,indices,false)
	# A short skirt seals the fine/coarse T junction without changing hilltops.
	for side in 4:
		var length: float=join.size.x if side%2==0 else join.size.y
		for i in int(length/4):
			var a: Vector2
			var b: Vector2
			if side==0:a=Vector2(low.x+i*4,low.y);b=a+Vector2(4,0)
			elif side==1:a=Vector2(high.x,low.y+i*4);b=a+Vector2(0,4)
			elif side==2:a=Vector2(low.x+i*4,high.y);b=a+Vector2(4,0)
			else:a=Vector2(low.x,low.y+i*4);b=a+Vector2(0,4)
			var start:=vertices.size()
			for xy in [a,b]:
				var y: float=field.height(xy.x,xy.y)
				vertices.append(Vector3(xy.x,y,xy.y));vertices.append(Vector3(xy.x,y-8,xy.y))
				normals.append(Vector3.UP);normals.append(Vector3.UP)
			indices.append_array(PackedInt32Array([start,start+1,start+2,start+2,start+1,start+3,start+2,start+1,start,start+3,start+1,start+2]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	return arrays

static func _append_grid(field: FrontierTerrainField,area: Rect2,hole: Rect2,step: float,vertices: PackedVector3Array,normals: PackedVector3Array,indices: PackedInt32Array,caves: bool) -> void:
	var nx:=roundi(area.size.x/step);var nz:=roundi(area.size.y/step)
	var base:=vertices.size()
	for z in range(nz+1):
		for x in range(nx+1):
			var px: float=area.position.x+x*step;var pz: float=area.position.y+z*step
			vertices.append(Vector3(px,field.height(px,pz),pz))
			var dx: float=field.height(px+.5,pz)-field.height(px-.5,pz)
			var dz: float=field.height(px,pz+.5)-field.height(px,pz-.5)
			normals.append(Vector3(-dx,1,-dz).normalized())
	for z in nz:
		for x in nx:
			var xy:=area.position+Vector2((x+.5)*step,(z+.5)*step)
			if hole.has_point(xy):continue
			if caves and field.density(Vector3(xy.x,field.height(xy.x,xy.y)-.5,xy.y))<0:continue
			var a:=base+z*(nx+1)+x;var b:=a+1;var d:=a+nx+1;var c:=d+1
			indices.append_array(PackedInt32Array([a,b,c,a,c,d]))

func _exit_tree() -> void:
	if task_id!=-1:WorkerThreadPool.wait_for_task_completion(task_id)

## Temporary surface tiles cover not-yet-built fine chunks, then disappear.
## No collision and no edits: the authoritative streamer still owns both.
func rebuild_fallback(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,chunks: Dictionary) -> void:
	var fallback:=get_node_or_null("StreamingFallback") as MeshInstance3D
	if fallback==null:
		fallback=MeshInstance3D.new();fallback.name="StreamingFallback";add_child(fallback)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
	var current_low:=Vector2((anchor.x-radius_chunks)*field.span,(anchor.z-radius_chunks)*field.span)
	var size:=Vector2.ONE*(radius_chunks*2+1)*field.span
	var previous_low:=Vector2((rendered_anchor.x-radius_chunks)*field.span,(rendered_anchor.z-radius_chunks)*field.span) if has_rendered_anchor else current_low
	var low:=current_low.min(previous_low);var high: Vector2=(current_low+size).max(previous_low+size)
	var current_area:=Rect2(current_low,size);var previous_area:=Rect2(previous_low,size)
	for x in int((high.x-low.x)/4):
		for z in int((high.y-low.y)/4):
			var origin:=Vector3(low.x+x*4,0,low.y+z*4)
			var xy:=Vector2(origin.x+2,origin.z+2)
			if not current_area.has_point(xy) and not previous_area.has_point(xy):continue
			var probe:=origin+Vector3(2,0,2);probe.y=field.height(probe.x,probe.z)
			if chunks.has(field.key_at(probe)) and chunks.has(field.key_at(probe-Vector3.UP*2)):continue
			if field.density(probe-Vector3.UP*.5)<0:continue
			var start:=vertices.size()
			for offset in [Vector3.ZERO,Vector3(4,0,0),Vector3(4,0,4),Vector3(0,0,4)]:
				var p: Vector3=origin+offset;p.y=field.height(p.x,p.z)-.15;vertices.append(p);normals.append(Vector3.UP)
			indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	if vertices.is_empty():fallback.mesh=null;return
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	fallback.mesh=result;fallback.material_override=material_override
