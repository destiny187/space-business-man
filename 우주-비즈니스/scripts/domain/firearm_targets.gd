extends RefCounted
## Once per active shooter per physics batch; bullets only intersect these local shapes.
const Wildlife=preload("res://scripts/world/wildlife_behavior.gd")
const Anatomy=preload("res://scripts/actors/creatures/remodel_registry.gd")
static var _ground: Dictionary={}
static var _ground_body:=""
static func candidates(world: Dictionary,actor: String) -> Array:
	var member: Dictionary=world.crew.members[actor]
	var id: String=world.crew.landing.body_id
	var terrain_key:=str(world.crew.world_id)+id+":"+str(world.terrain_edits.get(id,[]).size())
	if _ground_body!=terrain_key:_ground.clear();_ground_body=terrain_key
	var wildlife_observers: Array[Vector3]=[]
	var body:=FrontierUniverse.body_from_id(world.manifest,id)
	var record: Dictionary=world.ecology.planets[id]
	var placement_rules:=FrontierEcologyCatalog.placement_config(body)
	var terrain:=FrontierCrewSurface.field(world)
	var position:=FrontierCrewWorld.vector(member.position)
	if wildlife_observers.is_empty():wildlife_observers=[position]
	var result: Array=[]
	var population:=0
	if _ground.size()>384:_ground.clear()
	for row in FrontierEcologyPlacement.candidates(body,record,position):
		if not _ground.has(row.id):_ground[row.id]=FrontierEcologyPlacement.ground(terrain,row)
		var point: Vector3=_ground[row.id]
		if not point.is_finite():continue
		var form:=FrontierEcologyCatalog.form(row.form_id)
		var state: String=FrontierEcology.status(record,form,point,row.layer)
		if row.introduced:state="active" if FrontierEcology.climate_at(record,point,row.layer).get("restored",false) else "dormant"
		if state=="absent" or (state=="dormant" and form.category=="animal" and not row.introduced):continue
		if point.distance_to(position)>float(placement_rules.active_radius):continue
		population+=1
		if population>int(placement_rules.max_actors):break
		if form.category!="animal":continue
		row.home_point=point
		row.status=state
		var motion:=FrontierEcologyPlacement.flight_pose(terrain,row,point,float(world.crew.navigation.orbit_time)) if form.get("locomotion_medium","")=="surface_air" else {}
		var basis:=Basis(Vector3.UP,float(row.get("yaw",0)))
		if not motion.is_empty():point=motion.point;basis=motion.basis
		if Wildlife.eligible(form,row):
			var behavior:=FrontierWildlifeCombat.pose(terrain,row,point,float(world.crew.navigation.orbit_time),wildlife_observers,world.crew,id)
			point=behavior.point;basis=behavior.basis;row.behavior_yaw=basis.get_euler().y
		var key: String=id+"/"+str(row.id)
		if int(world.crew.get("combat",{}).get(key,FrontierWildlifeCombat.health(row)))<=0:continue
		var scale_value:=float(FrontierEcologyCatalog.look(form.id,row.look_id).scale)
		var geometry: Dictionary=Anatomy.bounds(form)
		var minimum:=FrontierCrewWorld.vector(geometry.get("min",[-.5,0,-.5]))*scale_value
		var maximum:=FrontierCrewWorld.vector(geometry.max)*scale_value
		minimum.y-=float(geometry.floor_y)*scale_value;maximum.y-=float(geometry.floor_y)*scale_value
		row.point=point
		result.append({"kind":"animal","id":key,"row":row,"transform":Transform3D(basis,point),"bounds":AABB(minimum,maximum-minimum),"zone":"body","weak":false})
	for row in FrontierExplorationIncidents.records(world).values():
		if row.body_id!=world.location or row.claimed:continue
		var mode: String=FrontierExplorationIncidents.definition(row.template).mode
		var key:=FrontierExplorationIncidents.key(row)
		if mode=="drone" and not row.open:
			result.append({"kind":"drone","id":key,"transform":Transform3D(Basis.IDENTITY,FrontierExplorationIncidents.moving_point(row)),"bounds":AABB(Vector3.ONE*-.42,Vector3.ONE*.84),"zone":"body","weak":false})
		if mode!="robot" or row.hp<=0:continue
		var transform:=Transform3D(Basis(Vector3.UP,float(row.yaw)),FrontierCrewWorld.vector(row.position))
		var zones: Array=[['body',Vector3(-.55,.9,-.42),Vector3(1.1,.8,.84)],['head',Vector3(-.27,1.72,-.25),Vector3(.54,.5,.5)],['limb',Vector3(-.85,.8,-.22),Vector3(.3,.8,.44)],['limb',Vector3(.55,.8,-.22),Vector3(.3,.8,.44)],['limb',Vector3(-.5,.05,-.32),Vector3(.36,.85,.64)],['limb',Vector3(.14,.05,-.32),Vector3(.36,.85,.64)]]
		if row.phase=="cooling":zones.push_front(['core',Vector3(-.25,1.74,.27),Vector3(.5,.48,.3)])
		# Shield remains a continuous volume. Exposed armor uses separate parts.
		if float(row.get("shield",0))>0:zones=[['shield',Vector3(-.86,.55,-.6),Vector3(1.72,1.7,1.2)]]
		for zone in zones:result.append({"kind":"robot","id":key,"transform":transform,"bounds":AABB(zone[1],zone[2]),"zone":zone[0],"weak":zone[0] in ["core","head"],"anchor":transform.origin+Vector3.UP*2.5})
	return result
static func intersect(rows: Array,origin: Vector3,direction: Vector3,reach: float) -> Dictionary:
	var best:=reach+.001;var hit: Dictionary={}
	for row in rows:
		var inverse: Transform3D=row.transform.affine_inverse()
		var local_origin: Vector3=inverse*origin
		var point: Variant=row.bounds.intersects_segment(local_origin,inverse*(origin+direction*reach))
		if point==null:continue
		var global_point: Vector3=row.transform*point
		var distance:=origin.distance_to(global_point)
		if distance>=best:continue
		best=distance;hit=row.duplicate();hit.point=global_point
	return hit
