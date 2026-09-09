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
# Only the serialized worker jobs access this cache. Edits change density, not height.
var height_samples: Dictionary={}
var height_identity:=""
const TILE_SIZE:=512.0
const UPLOAD_BUDGET_USEC:=2000
var tiles: Dictionary={}
var tile_identity:=""
var upload_index:=0
var prepared_tiles: Dictionary={}
var last_built_tiles:=0
var last_build_ms:=0.0
var max_upload_ms:=0.0
var last_commit_ms:=0.0
var fallback_samples: Dictionary={}
var fallback_field: FrontierTerrainField
var fallback_revision:=-1
var fallback_cells: Array[Vector2i]=[]

func request_rebuild(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,terrain_material: Material,view_distance: float) -> void:
	var unique_edits: Dictionary={}
	for chunk_edits in field.edits_by_chunk.values():
		for edit in chunk_edits:unique_edits[str(edit.center)+str(edit.radius)]=edit
	queued={"edits":unique_edits.values(),"seed":field.seed_value,"traits":field.traits.duplicate(true),"span":field.span,"anchor":anchor,"radius":radius_chunks,"distance":view_distance,"material":terrain_material}
	_start_job()

func _start_job() -> void:
	if task_id!=-1 or queued.is_empty():return
	var request:=queued;queued={}
	request.identity=str([request.seed,request.span,request.traits])
	request.existing={}
	if request.identity==tile_identity:
		for key in tiles:request.existing[key]=tiles[key].signature
	packet={"arrays":[],"material":request.material,"anchor":request.anchor,"harvested":false}
	upload_index=0
	task_id=WorkerThreadPool.add_task(_build_job.bind(packet,request),false,"distant terrain")

func _build_job(result: Dictionary,request: Dictionary) -> void:
	var started:=Time.get_ticks_usec()
	var field:=FrontierTerrainField.new()
	field.configure(request.seed,request.edits,request.span,request.traits)
	if request.identity!=height_identity:height_samples.clear();height_identity=request.identity
	var center:=Vector2((request.anchor.x+.5)*field.span,(request.anchor.z+.5)*field.span)
	var bounds:=Rect2(center-Vector2.ONE*(request.distance+TILE_SIZE),Vector2.ONE*(request.distance+TILE_SIZE)*2)
	for key in height_samples.keys():
		if not bounds.has_point(key):height_samples.erase(key)
	result.arrays=_arrays(field,request.anchor,request.radius,request.distance,height_samples,false)
	var coarse:=16.0 if request.distance<=4096 else 32.0
	var inner: float=(request.radius+.5)*field.span
	var low: Vector2=((center-Vector2.ONE*inner)/coarse).floor()*coarse-Vector2.ONE*coarse
	var high: Vector2=((center+Vector2.ONE*inner)/coarse).ceil()*coarse+Vector2.ONE*coarse
	var join:=Rect2(low,high-low)
	var first: Vector2i=Vector2i(((center-Vector2.ONE*request.distance)/TILE_SIZE).floor())
	var end: Vector2i=Vector2i(((center+Vector2.ONE*request.distance)/TILE_SIZE).ceil())
	result.wanted={};result.updates=[];result.identity=request.identity
	for z in range(first.y,end.y):
		for x in range(first.x,end.x):
			var key:=Vector2i(x,z)
			var area:=Rect2(Vector2(key)*TILE_SIZE,Vector2.ONE*TILE_SIZE)
			var cut:=area.intersection(join) if area.intersects(join) else Rect2()
			var signature:=str([coarse,cut])
			result.wanted[key]=signature
			if request.existing.get(key)==signature:continue
			var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
			_append_grid(field,area,join,coarse,vertices,normals,indices,false,height_samples)
			result.updates.append({"key":key,"signature":signature,"arrays":_pack_arrays(vertices,normals,indices)})
	result.build_ms=(Time.get_ticks_usec()-started)/1000.0

var last_main_ms:=0.0
var max_main_ms:=0.0
func _process(_delta: float) -> void:
	var started:=Time.get_ticks_usec()
	_stream()
	last_main_ms=(Time.get_ticks_usec()-started)/1000.0
	max_main_ms=maxf(max_main_ms,last_main_ms)

func _stream() -> void:
	if task_id==-1:return
	if not packet.harvested and not WorkerThreadPool.is_task_completed(task_id):return
	if not packet.harvested:
		WorkerThreadPool.wait_for_task_completion(task_id)
		packet.harvested=true
		last_built_tiles=packet.updates.size();last_build_ms=packet.build_ms
	var deadline:=Time.get_ticks_usec()+UPLOAD_BUDGET_USEC
	while upload_index<packet.updates.size():
		var started:=Time.get_ticks_usec()
		var row: Dictionary=packet.updates[upload_index]
		var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,row.arrays)
		prepared_tiles[row.key]={"mesh":result,"signature":row.signature}
		# Release CPU arrays after upload, not after the whole batch.
		row.erase("arrays");upload_index+=1
		max_upload_ms=maxf(max_upload_ms,(Time.get_ticks_usec()-started)/1000.0)
		if Time.get_ticks_usec()>=deadline:return
	# Swap the near ring and its clipped coarse tiles together. Until this point
	# the old ring, old cutouts and streaming fallback continue to cover the ground.
	var started:=Time.get_ticks_usec()
	for key in tiles.keys():
		if not packet.wanted.has(key):
			tiles[key].node.free();tiles.erase(key)
	for key in prepared_tiles:
		var visual: MeshInstance3D
		if tiles.has(key):visual=tiles[key].node
		else:
			visual=MeshInstance3D.new();visual.name="Far_%d_%d"%[key.x,key.y];add_child(visual)
		visual.mesh=prepared_tiles[key].mesh
		tiles[key]={"node":visual,"signature":prepared_tiles[key].signature}
	for tile in tiles.values():tile.node.material_override=packet.material
	prepared_tiles.clear();tile_identity=packet.identity
	rendered_anchor=packet.anchor;has_rendered_anchor=true
	_install(packet.arrays,packet.material)
	last_commit_ms=(Time.get_ticks_usec()-started)/1000.0
	task_id=-1;packet={}
	_start_job()

func terrain_bounds() -> AABB:
	var bounds:=mesh.get_aabb() if mesh!=null else AABB()
	for tile in tiles.values():bounds=bounds.merge(tile.node.mesh.get_aabb())
	return bounds

func _install(arrays: Array,terrain_material: Material) -> void:
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=result;material_override=terrain_material;build_count+=1
	var fallback:=get_node_or_null("StreamingFallback") as MeshInstance3D
	if fallback!=null:fallback.material_override=terrain_material

func rebuild(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,terrain_material: Material,view_distance: float=1060.0) -> void:
	if task_id!=-1 and not packet.get("harvested",false):WorkerThreadPool.wait_for_task_completion(task_id)
	task_id=-1;packet={};queued={};prepared_tiles.clear()
	for tile in tiles.values():tile.node.free()
	tiles.clear();tile_identity=""
	rendered_anchor=anchor;has_rendered_anchor=true
	_install(_arrays(field,anchor,radius_chunks,view_distance),terrain_material)

static func _arrays(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,view_distance: float,samples: Dictionary={},include_outer: bool=true) -> Array:
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
	_append_grid(field,join,hole,4.0,vertices,normals,indices,true,samples)
	if include_outer:_append_grid(field,Rect2(outer_low,outer_high-outer_low),join,coarse,vertices,normals,indices,false,samples)
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
	return _pack_arrays(vertices,normals,indices)

static func _pack_arrays(vertices: PackedVector3Array,normals: PackedVector3Array,indices: PackedInt32Array) -> Array:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	var exposure:=PackedColorArray();exposure.resize(vertices.size());exposure.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR]=exposure
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	return arrays

static func _append_grid(field: FrontierTerrainField,area: Rect2,hole: Rect2,step: float,vertices: PackedVector3Array,normals: PackedVector3Array,indices: PackedInt32Array,caves: bool,samples: Dictionary={}) -> void:
	var nx:=roundi(area.size.x/step);var nz:=roundi(area.size.y/step)
	var base:=vertices.size()
	for z in range(nz+1):
		for x in range(nx+1):
			var px: float=area.position.x+x*step;var pz: float=area.position.y+z*step
			var key:=Vector2(px,pz)
			if not samples.has(key):
				var dx: float=field.height(px+.5,pz)-field.height(px-.5,pz)
				var dz: float=field.height(px,pz+.5)-field.height(px,pz-.5)
				var normal:=Vector3(-dx,1,-dz).normalized()
				samples[key]=Vector4(field.height(px,pz),normal.x,normal.y,normal.z)
			var sample: Vector4=samples[key]
			vertices.append(Vector3(px,sample.x,pz));normals.append(Vector3(sample.y,sample.z,sample.w))
	for z in nz:
		for x in nx:
			var xy:=area.position+Vector2((x+.5)*step,(z+.5)*step)
			if hole.has_point(xy):continue
			if caves and field.density(Vector3(xy.x,field.height(xy.x,xy.y)-.5,xy.y))<0:continue
			var a:=base+z*(nx+1)+x;var b:=a+1;var d:=a+nx+1;var c:=d+1
			indices.append_array(PackedInt32Array([a,b,c,a,c,d]))

func _exit_tree() -> void:
	if task_id!=-1 and not packet.get("harvested",false):WorkerThreadPool.wait_for_task_completion(task_id)

## Temporary surface tiles cover not-yet-built fine chunks, then disappear.
## No collision and no edits: the authoritative streamer still owns both.
func rebuild_fallback(field: FrontierTerrainField,anchor: Vector3i,radius_chunks: int,chunks: Dictionary) -> void:
	var fallback:=get_node_or_null("StreamingFallback") as MeshInstance3D
	if fallback==null:
		fallback=MeshInstance3D.new();fallback.name="StreamingFallback";add_child(fallback)
	if fallback_field!=field or fallback_revision!=field.revision:
		fallback_samples.clear();fallback_cells.clear();fallback_field=field;fallback_revision=field.revision
		fallback.mesh=null
	var cells: Array[Vector2i]=[]
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
			var key:=Vector2i(roundi(origin.x/4),roundi(origin.z/4))
			if not fallback_samples.has(key):
				var probe:=origin+Vector3(2,0,2);probe.y=field.height(probe.x,probe.z)
				fallback_samples[key]={"probe":probe,"top":field.key_at(probe),"floor":field.key_at(probe-Vector3.UP*2)}
			var sample: Dictionary=fallback_samples[key]
			if chunks.has(sample.top) and chunks.has(sample.floor):continue
			if not sample.has("supported"):sample.supported=field.density(sample.probe-Vector3.UP*.5)>=0
			if sample.supported:cells.append(key)
	if fallback_samples.size()>4096:
		var retained:=Rect2(low-Vector2.ONE*24,high-low+Vector2.ONE*48)
		for key in fallback_samples.keys():
			if not retained.has_point(Vector2(key)*4):fallback_samples.erase(key)
	if cells==fallback_cells:return
	fallback_cells=cells
	for key in cells:
		var sample: Dictionary=fallback_samples[key]
		if not sample.has("vertices"):
			var points:=PackedVector3Array();var directions:=PackedVector3Array()
			for offset in [Vector3.ZERO,Vector3(4,0,0),Vector3(4,0,4),Vector3(0,0,4)]:
				var p: Vector3=Vector3(key.x*4,0,key.y*4)+offset;p.y=field.height(p.x,p.z)-.15
				points.append(p);directions.append(field.normal(p))
			sample.vertices=points;sample.normals=directions
		var start:=vertices.size()
		vertices.append_array(sample.vertices);normals.append_array(sample.normals)
		indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	if vertices.is_empty():fallback.mesh=null;return
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	var exposure:=PackedColorArray();exposure.resize(vertices.size());exposure.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR]=exposure
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	fallback.mesh=result;fallback.material_override=material_override
