class_name FrontierSurfaceEcology
extends Node3D
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var body: Dictionary
var ecology: Dictionary
var terrain: FrontierTerrainStreamer
var viewer: Node3D
var actors: Dictionary={}
var encounters: Dictionary={}
var pending: Array[Dictionary]=[]
var refresh_timer:=0.0
var last_center:=Vector3.INF
var max_load_ms:=0.0
var dormant_count:=0
var active_count:=0
var resource_requests: Dictionary={}
var ground_cache: Dictionary={}
var max_refresh_ms:=0.0
var observers: Array[Vector3]=[]
var synchronous_resources:=DisplayServer.get_name()=="headless"

func configure(world_ecology: Dictionary,planet: Dictionary,stream: FrontierTerrainStreamer,player: Node3D) -> void:
	ecology=world_ecology;body=planet;terrain=stream;viewer=player
	terrain.geometry_changed.connect(invalidate)

func invalidate() -> void:
	last_center=Vector3.INF;refresh_timer=0;ground_cache.clear()

func _process(delta: float) -> void:
	refresh_timer-=delta
	if refresh_timer<=0:
		refresh_timer=.8
		refresh()
	# Packed scenes are requested off the main thread; only bounded node creation occurs here.
	for row in pending:
		if resource_requests.size()>=(1 if synchronous_resources else 2):break
		if resource_requests.has(row.id):continue
		var form:=FrontierEcologyCatalog.form(row.form_id)
		var paths: Array[String]=[]
		for lod in ["near","far"]:
			var path: String="res://"+str(form.lods[lod].path).trim_prefix("우주-비즈니스/")
			paths.append(path)
			if not synchronous_resources:ResourceLoader.load_threaded_request(path,"PackedScene")
		# The dummy renderer has no render-thread queue; keep RID creation on one thread.
		var scenes: Array=[]
		if synchronous_resources:
			for path in paths:scenes.append(load(path))
		resource_requests[row.id]={"paths":paths,"scenes":scenes}
	var budget: int=int(FrontierEcologyCatalog.config().load_per_frame)
	for row in pending.duplicate():
		if budget<=0:break
		if actors.has(row.id) or not resource_requests.has(row.id):continue
		var request: Dictionary=resource_requests[row.id]
		var ready:=true
		for path in ([] if synchronous_resources else request.paths):
			var status_value: int=ResourceLoader.load_threaded_get_status(path)
			if status_value==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:ResourceLoader.load_threaded_request(path,"PackedScene")
			if status_value!=ResourceLoader.THREAD_LOAD_LOADED:ready=false
		if not ready:continue
		var retained: Array=request.scenes
		if not synchronous_resources:
			for path in request.paths:retained.append(ResourceLoader.load_threaded_get(path))
		resource_requests.erase(row.id);pending.erase(row);budget-=1
		var start:=Time.get_ticks_usec()
		var actor:=Actor.new()
		actor.configure(FrontierEcologyCatalog.form(row.form_id),FrontierEcologyCatalog.look(row.form_id,row.look_id))
		actor.position=row.point;actor.basis=FrontierEcologyPlacement.surface_basis(terrain.field.normal(row.point),float(row.yaw))
		add_child(actor)
		actor.set_state("dormant" if row.status=="dormant" else "idle")
		actor.set_meta("encounter_id",row.id)
		_add_collision(actor,row)
		actors[row.id]=actor;encounters[row.id]=row
		max_load_ms=maxf(max_load_ms,float(Time.get_ticks_usec()-start)/1000.0)

func refresh() -> void:
	if ecology.is_empty() or not ecology.planets.has(body.id):return
	var record: Dictionary=ecology.planets[body.id]
	var refresh_start:=Time.get_ticks_usec()
	var selected: Dictionary={}
	if ground_cache.size()>384:ground_cache.clear()
	pending.clear();active_count=0;dormant_count=0
	var interests: Array[Vector3]=[]
	if observers.is_empty():interests.append(viewer.position)
	else:interests.assign(observers)
	for observer in interests:
		var observer_count:=0
		for candidate in FrontierEcologyPlacement.candidates(body,record,observer):
			if observer_count>=int(FrontierEcologyCatalog.config().max_actors):break
			if not ground_cache.has(candidate.id):ground_cache[candidate.id]=FrontierEcologyPlacement.ground(terrain.field,candidate)
			var point: Vector3=ground_cache[candidate.id]
			if not point.is_finite() or not terrain.ready_at(point+Vector3.UP):continue
			if point.distance_to(observer)>float(FrontierEcologyCatalog.config().active_radius):continue
			var form:=FrontierEcologyCatalog.form(candidate.form_id)
			var status_value: String=FrontierEcology.status(record,form,point,candidate.layer)
			if candidate.introduced:status_value="active" if FrontierEcology.climate_at(record,point,candidate.layer).get("restored",false) else "dormant"
			if status_value=="absent":continue
			# A dormant animal lineage is a hidden seed-bank/refugium, not a full adult conjured from barren rock.
			if status_value=="dormant" and form.category=="animal" and not candidate.introduced:continue
			candidate.point=point;candidate.status=status_value
			observer_count+=1
			selected[candidate.id]=candidate
	for row in selected.values():
		if row.status=="active":active_count+=1
		else:dormant_count+=1
	for id in actors.keys():
		if not selected.has(id):actors[id].queue_free();actors.erase(id);encounters.erase(id)
	for row in selected.values():
		if actors.has(row.id):
			actors[row.id].position=row.point
			actors[row.id].basis=FrontierEcologyPlacement.surface_basis(terrain.field.normal(row.point),float(row.yaw))
			if encounters[row.id].status!=row.status:actors[row.id].set_state("dormant" if row.status=="dormant" else "idle")
			encounters[row.id]=row
		else:pending.append(row)
	# Drain obsolete asynchronous loads rather than retaining every crossed cell.
	for id in resource_requests.keys():
		if selected.has(id):continue
		var completed:=true
		for path in ([] if synchronous_resources else resource_requests[id].paths):
			var status_value: int=ResourceLoader.load_threaded_get_status(path)
			if status_value==ResourceLoader.THREAD_LOAD_IN_PROGRESS:completed=false
			elif status_value==ResourceLoader.THREAD_LOAD_LOADED:ResourceLoader.load_threaded_get(path)
		if completed:resource_requests.erase(id)
	last_center=viewer.position
	max_refresh_ms=maxf(max_refresh_ms,float(Time.get_ticks_usec()-refresh_start)/1000.0)

func target(camera: Camera3D) -> Dictionary:
	if terrain.field.density(camera.global_position)>0:return {}
	var closest: Dictionary={}
	var distance_limit: float=FrontierEcologyCatalog.config().scan_range
	for id in actors:
		var actor: Node3D=actors[id]
		var form:=FrontierEcologyCatalog.form(encounters[id].form_id)
		var height: float=(float(form.geometry.near.max[1])-float(form.geometry.near.floor_y))*float(FrontierEcologyCatalog.look(form.id,encounters[id].look_id).scale)
		var point:=actor.global_position+actor.global_basis.y*maxf(.35,height*.5)
		var displacement:=point-camera.global_position
		var distance:=displacement.length()
		if distance>distance_limit or distance<.001:continue
		var radius: float=clampf(height*.5,.65,2.2)
		var along: float=displacement.dot(-camera.global_basis.z)
		if along<=0 or (displacement+camera.global_basis.z*along).length()>radius:continue
		var query:=PhysicsRayQueryParameters3D.create(camera.global_position,point)
		if viewer is CollisionObject3D:query.exclude=[viewer.get_rid()]
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.get_meta("encounter_id","")!=id:continue
		closest=encounters[id];distance_limit=distance
	return closest

func _exit_tree() -> void:
	for request in resource_requests.values():
		for path in ([] if synchronous_resources else request.paths):
			if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:ResourceLoader.load_threaded_get(path)
	resource_requests.clear()

func _add_collision(actor: Node3D,row: Dictionary) -> void:
	var form:=FrontierEcologyCatalog.form(row.form_id)
	var look:=FrontierEcologyCatalog.look(row.form_id,row.look_id)
	var bounds: Dictionary=form.geometry.near
	var height: float=maxf(.25,(float(bounds.max[1])-float(bounds.floor_y))*float(look.scale))
	var radius: float=minf(height*.5,maxf(.18,minf(float(bounds.max[0])-float(bounds.min[0]),float(bounds.max[2])-float(bounds.min[2]))*float(look.scale)*.32))
	var collision_body:=StaticBody3D.new();collision_body.set_meta("encounter_id",row.id)
	var shape:=CapsuleShape3D.new();shape.radius=radius;shape.height=height
	var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=height*.5
	collision_body.add_child(collider);actor.add_child(collision_body)
