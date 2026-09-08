class_name FrontierTerrainMesher
extends RefCounted
## Indexed marching tetrahedra. CPU arrays only; safe for a worker-local field.
const CORNERS := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,0,1),Vector3i(0,0,1),Vector3i(0,1,0),Vector3i(1,1,0),Vector3i(1,1,1),Vector3i(0,1,1)]
const TETRA := [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
const EDGES := [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]
var positions := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
var cache: Dictionary = {}
var field: FrontierTerrainField
var origin: Vector3
var grid := PackedFloat32Array()
var grid_points := PackedVector3Array()

func build(source: FrontierTerrainField,chunk: Vector3i,cells: int=12,cell_size: float=2.0) -> Dictionary:
	var started:=Time.get_ticks_usec()
	field=source
	origin=Vector3(chunk)*cells*cell_size
	positions.clear();normals.clear();colors.clear();indices.clear();cache.clear()
	var width:=cells+1
	grid.resize(width*width*width)
	grid_points.resize(grid.size())
	var low:=INF
	var high:=-INF
	for y in width:
		for z in width:
			for x in width:
				var index: int=x+z*width+y*width*width
				var p:=Vector3(x,y,z)*cell_size
				var d: float=field.density(origin+p)
				grid[index]=d;grid_points[index]=p
				low=minf(low,d);high=maxf(high,d)
	if low<0 and high>=0:
		for y in cells:
			for z in cells:
				for x in cells:
					var cube: Array[int]=[]
					var count:=0
					for offset in CORNERS:
						var id: int=x+offset.x+(z+offset.z)*width+(y+offset.y)*width*width
						cube.append(id)
						if grid[id]>=0:count+=1
					if count==0 or count==8:continue
					for tetra in TETRA:
						var polygon: Array[int]=[]
						for edge in EDGES:
							var a: int=cube[tetra[edge[0]]]
							var b: int=cube[tetra[edge[1]]]
							if (grid[a]>=0)==(grid[b]>=0):continue
							var vertex:=_intersection(a,b)
							var duplicate:=false
							for previous in polygon:
								if positions[previous].distance_squared_to(positions[vertex])<.00000001:duplicate=true;break
							if not duplicate:polygon.append(vertex)
						_polygon(polygon)
	return {"vertices":positions,"normals":normals,"colors":colors,"indices":indices,"build_ms":(Time.get_ticks_usec()-started)/1000.0}

func _intersection(a: int,b: int) -> int:
	var edge:=Vector2i(mini(a,b),maxi(a,b))
	if cache.has(edge):return cache[edge]
	var t: float=grid[a]/(grid[a]-grid[b])
	var p: Vector3=grid_points[a].lerp(grid_points[b],t)
	var index:=positions.size()
	positions.append(p)
	normals.append(field.normal(origin+p))
	var wp:=origin+p
	var depth:=field.height(wp.x,wp.z)-wp.y
	# Excavated and cave surfaces expose geology, never projected surface snow/ecology.
	colors.append(Color(1.0-smoothstep(1.0,3.5,depth),0,0,1))
	cache[edge]=index
	return index

func _polygon(polygon: Array[int]) -> void:
	if polygon.size()<3:return
	var center:=Vector3.ZERO
	var normal:=Vector3.ZERO
	for id in polygon:center+=positions[id];normal+=normals[id]
	center/=polygon.size()
	normal=normal.normalized()
	if normal.length_squared()<.001:return
	var axis: Vector3=(positions[polygon[0]]-center).normalized()
	var side: Vector3=normal.cross(axis)
	polygon.sort_custom(func(a: int,b: int) -> bool:
		var pa: Vector3=positions[a]-center
		var pb: Vector3=positions[b]-center
		return atan2(pa.dot(side),pa.dot(axis))<atan2(pb.dot(side),pb.dot(axis)))
	for i in range(1,polygon.size()-1):
		var a: int=polygon[0];var b: int=polygon[i];var c: int=polygon[i+1]
		var cross_value: Vector3=(positions[b]-positions[a]).cross(positions[c]-positions[a])
		if cross_value.length_squared()<.00000001:continue
		if cross_value.dot(normal)>0:
			var temporary:=b;b=c;c=temporary
		indices.append_array(PackedInt32Array([a,b,c]))

static func mesh(data: Dictionary) -> ArrayMesh:
	var result:=ArrayMesh.new()
	if data.indices.is_empty():return result
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices
	arrays[Mesh.ARRAY_NORMAL]=data.normals
	if data.has("colors"):arrays[Mesh.ARRAY_COLOR]=data.colors
	arrays[Mesh.ARRAY_INDEX]=data.indices
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
