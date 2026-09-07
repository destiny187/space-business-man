class_name FrontierSurfaceDetails
extends Node3D
## Cosmetic geology. Stable tile seeds, no collision, loot or scan targets.
var terrain: FrontierTerrainStreamer
var viewer: Node3D
var body: Dictionary
var settings: Dictionary
var meshes: Array[Mesh]=[]
var tiles: Dictionary={}
var exclusions: Array[Vector4]=[]
var building_signature:=""
var cluster:=FastNoiseLite.new()
var anchor:=Vector2i(99999,99999)
var dirty:=true
var instance_total:=0
var material_cache: Dictionary={}

func configure(stream: FrontierTerrainStreamer,planet: Dictionary,observer: Node3D) -> void:
	terrain=stream;body=planet;viewer=observer
	settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_details.json"))
	var family: String=body.get("traits",{}).get("id","")
	if not settings.families.has(family):set_process(false);return
	cluster.seed=FrontierUniverse.derive(int(body.seed),"surface-clusters-v1")
	cluster.frequency=.062;cluster.fractal_octaves=2
	for path in settings.families[family].models:
		var scene: Node3D=load(path).instantiate()
		var nodes:=scene.find_children("*","MeshInstance3D",true,false)
		if not scene is MeshInstance3D and nodes.is_empty():
			push_error("Surface detail has no mesh: "+str(path));scene.free();continue
		var source: MeshInstance3D=scene if scene is MeshInstance3D else nodes[0]
		var mesh: Mesh=source.mesh.duplicate()
		for i in mesh.get_surface_count():
			var original: Material=source.get_active_material(i)
			if original is StandardMaterial3D:mesh.surface_set_material(i,FrontierInkStyle.material(original,material_cache))
		meshes.append(mesh);scene.free()
	terrain.geometry_changed.connect(invalidate)

func invalidate() -> void:
	dirty=true

func accept(ledger: Dictionary) -> void:
	var site: Dictionary=ledger.get("sites",{}).get(body.id,{})
	var buildings: Dictionary=site.get("buildings",{})
	var signature: String=str(site.get("center",[]))
	var keys: Array=buildings.keys();keys.sort()
	for key in keys:
		var b: Dictionary=buildings[key]
		signature+=str([key,b.type,b.position])
	if signature==building_signature:return
	building_signature=signature;exclusions.clear()
	if site.has("center"):
		var p: Array=site.center;exclusions.append(Vector4(p[0],p[1],p[2],5))
	for key in keys:
		var b: Dictionary=buildings[key];var p: Array=b.position
		exclusions.append(Vector4(p[0],p[1],p[2],float(FrontierCatalog.entry("buildings",b.type).radius)+1.2))
	invalidate()

func _blocked(p: Vector3) -> bool:
	var ship: Array=FrontierCrewSurface.config().ship_position
	if Vector2(p.x-float(ship[0]),p.z-float(ship[2])).length()<13:return true
	for area in exclusions:
		if absf(p.y-area.y)<3 and Vector2(p.x-area.x,p.z-area.z).length()<area.w:return true
	return false

func candidates(key: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(body.seed),"surface-details-v1:%d:%d"%[key.x,key.y])
	var span: float=settings.tile_size
	var family: Dictionary=settings.families[body.traits.id]
	for index in int(settings.candidates_per_tile):
		var p:=Vector3((key.x+rng.randf())*span,0,(key.y+rng.randf())*span)
		var variant: int=rng.randi_range(0,3)
		var scale_value: float=rng.randf_range(float(settings.scale_min),float(settings.scale_max))
		var yaw: float=rng.randf()*TAU
		var roll: float=rng.randf()
		var patch: float=smoothstep(-.35,.35,cluster.get_noise_2d(p.x,p.z))
		if roll>(.10+patch*patch*.85)*float(family.density):continue
		p.y=terrain.field.height(p.x,p.z)
		var traits: Dictionary=terrain.field.traits
		if float(traits.get("water",0))>15 and float(traits.get("temperature",-100))>0 and p.y<float(settings.water_height)+.15:continue
		if _blocked(p):continue
		# A footprint check also suppresses fragments over cave openings or excavations.
		var supported:=true
		for offset in [Vector3.ZERO,Vector3(.45,0,0),Vector3(-.45,0,0),Vector3(0,0,.45),Vector3(0,0,-.45)]:
			if terrain.field.density(p+offset-Vector3.UP*.25)<0:supported=false;break
		if not supported:continue
		var up:=terrain.field.normal(p)
		if up.y<float(settings.minimum_normal_y):continue
		var basis:=Basis(Quaternion(Vector3.UP,up))*Basis(Vector3.UP,yaw)
		p-=up*.035*scale_value
		result.append({"id":"%d:%d:%d"%[key.x,key.y,index],"variant":variant,"transform":Transform3D(basis.scaled(Vector3.ONE*scale_value),p)})
	return result

func _build(key: Vector2i) -> void:
	var root:=Node3D.new();root.name="Details_%d_%d"%[key.x,key.y];add_child(root)
	var rows:=candidates(key)
	for variant in meshes.size():
		var transforms: Array[Transform3D]=[]
		for row in rows:
			if int(row.variant)==variant:transforms.append(row.transform)
		if transforms.is_empty():continue
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=meshes[variant];mm.instance_count=transforms.size()
		for i in transforms.size():mm.set_instance_transform(i,transforms[i])
		var visual:=MultiMeshInstance3D.new();visual.multimesh=mm
		visual.visibility_range_end=float(settings.visible_distance);visual.visibility_range_end_margin=12
		visual.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(visual)
	tiles[key]={"node":root,"count":rows.size()};instance_total+=rows.size()

func _process(_dt: float) -> void:
	if meshes.is_empty() or viewer==null:return
	if dirty:
		for row in tiles.values():row.node.queue_free()
		tiles.clear();instance_total=0;dirty=false
	var span: float=settings.tile_size
	anchor=Vector2i(floori(viewer.position.x/span),floori(viewer.position.z/span))
	var radius: int=settings.radius_tiles
	for key in tiles.keys():
		if maxi(absi(key.x-anchor.x),absi(key.y-anchor.y))>radius:
			instance_total-=int(tiles[key].count);tiles[key].node.queue_free();tiles.erase(key)
	var pending: Array[Vector2i]=[]
	for x in range(anchor.x-radius,anchor.x+radius+1):
		for z in range(anchor.y-radius,anchor.y+radius+1):
			var key:=Vector2i(x,z)
			if not tiles.has(key):pending.append(key)
	pending.sort_custom(func(a: Vector2i,b: Vector2i)->bool:return (a-anchor).length_squared()<(b-anchor).length_squared())
	var built:=0
	for key in pending:
		var p:=Vector3((key.x+.5)*span,0,(key.y+.5)*span);p.y=terrain.field.height(p.x,p.z)
		if not terrain.ready_at(p+Vector3.UP):continue
		_build(key);built+=1
		if built>=int(settings.builds_per_frame):break
