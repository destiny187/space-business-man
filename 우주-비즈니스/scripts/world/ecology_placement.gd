class_name FrontierEcologyPlacement
extends RefCounted
## Stable candidates are independent of view order, actor cap, and terrain edits.
static func candidates(body: Dictionary,record: Dictionary,center: Vector3) -> Array[Dictionary]:
	var cfg:=FrontierEcologyCatalog.placement_config(body)
	var span: float=cfg.cell_span
	var anchor:=Vector2i(floori(center.x/span),floori(center.z/span))
	var extent:=ceili(float(cfg.active_radius)/span)+1
	var result: Array[Dictionary]=[]
	# A lineage's habitat is invariant across all cells in this selection.
	var pools: Dictionary={"surface":[],"cave":[]}
	for lineage in record.lineages:
		var layer: String="cave" if FrontierEcologyCatalog.form(lineage.form_id).environment=="cave" else "surface"
		pools[layer].append(lineage)
	if record.profile.origin!="sterile":
		for x in range(anchor.x-extent,anchor.x+extent+1):
			for z in range(anchor.y-extent,anchor.y+extent+1):
				for layer in ["surface","cave"]:
					var pool: Array=pools[layer]
					if pool.is_empty():continue
					for slot in 2:
						var id: String="%s:%d:%d:%d"%[layer,x,z,slot]
						if record.collected.has(id):continue
						var seed_value:=FrontierUniverse.derive(int(body.streams.ecology),id)
						var chosen: Dictionary=pool[FrontierUniverse.derive(seed_value,"lineage")%pool.size()]
						var point:=Vector3((float(x)+.18+.64*float(FrontierUniverse.derive(seed_value,"x")%1000)/1000.0)*span,0,(float(z)+.18+.64*float(FrontierUniverse.derive(seed_value,"z")%1000)/1000.0)*span)
						if Vector2(point.x,point.z).length()<13 or Vector2(point.x+12,point.z-12).length()<24:continue # clear lander hull, ramp and transport depot
						if Vector2(point.x-center.x,point.z-center.z).length()>float(cfg.active_radius):continue
						result.append({"id":id,"form_id":chosen.form_id,"look_id":chosen.look_id,"point":point,"layer":layer,"yaw":float(FrontierUniverse.derive(seed_value,"yaw")%1000)/1000.0*TAU,"introduced":false,"terrestrial":body.has("ecology_rules"),"combat_tier":int(body.get("planet_tier",1))})
	for row in record.introductions.values():
		var point:=Vector3(row.position[0],row.position[1],row.position[2])
		if point.distance_to(center)<=float(cfg.active_radius):result.append({"id":row.id,"form_id":row.form_id,"look_id":row.look_id,"point":point,"layer":row.layer,"yaw":0.0,"introduced":true})
	result.sort_custom(func(a: Dictionary,b: Dictionary):
		var da: float=Vector2(a.point.x-center.x,a.point.z-center.z).length_squared()
		var db: float=Vector2(b.point.x-center.x,b.point.z-center.z).length_squared()
		return a.id<b.id if is_equal_approx(da,db) else da<db)
	return result

static func ground(field: FrontierTerrainField,candidate: Dictionary) -> Vector3:
	var point: Vector3=candidate.point
	var surface: float=field.height(point.x,point.z)
	var start: float=surface+4 if candidate.layer=="surface" else surface-7
	var previous:=field.density_at_height(Vector3(point.x,start,point.z),surface)
	var top:=start
	for step in range(1,100):
		var bottom: float=start-float(step)
		if bottom<-68:break
		var current:=field.density_at_height(Vector3(point.x,bottom,point.z),surface)
		if previous<0 and current>=0:
			for iteration in 9:
				var mid: float=(top+bottom)*.5
				if field.density_at_height(Vector3(point.x,mid,point.z),surface)>0:bottom=mid
				else:top=mid
			point.y=(top+bottom)*.5+.06
			if candidate.layer=="surface" and surface-point.y>4:return Vector3.INF
			if candidate.layer=="cave" and surface-point.y<7:return Vector3.INF
			return point if fits(field,candidate,point) else Vector3.INF
		previous=current;top=bottom
	return Vector3.INF

static func fits(field: FrontierTerrainField,candidate: Dictionary,point: Vector3) -> bool:
	if candidate.get("terrestrial",false) and candidate.layer=="surface" and FrontierSurfaceDrainage.liquid(field.traits) and point.y< -2.5:return false
	var form:=FrontierEcologyCatalog.form(candidate.form_id)
	var look:=FrontierEcologyCatalog.look(candidate.form_id,candidate.look_id)
	var geometry: Dictionary=form.geometry.near
	var height: float=(float(geometry.max[1])-float(geometry.floor_y))*float(look.scale)
	var rx: float=maxf(absf(geometry.min[0]),absf(geometry.max[0]))*float(look.scale)
	var rz: float=maxf(absf(geometry.min[2]),absf(geometry.max[2]))*float(look.scale)
	var up:=field.normal(point)
	var basis_value:=surface_basis(up,float(candidate.yaw))
	if up.y<.85:return false
	for offset in [Vector3.ZERO,Vector3(rx,0,0),Vector3(-rx,0,0),Vector3(0,0,rz),Vector3(0,0,-rz),Vector3(rx,0,rz),Vector3(-rx,0,-rz),Vector3(rx,0,-rz),Vector3(-rx,0,rz)]:
		var p: Vector3=point+basis_value*offset
		if field.density(p+up*.55)>0 or field.density(p-up*.6)<0:return false
		for fraction in [.2,.5,1.0]:
			if field.density(p+up*maxf(.6,height*fraction))>0:return false
	return true

static func flight_pose(field: FrontierTerrainField,candidate: Dictionary,home: Vector3,time: float) -> Dictionary:
	var form:=FrontierEcologyCatalog.form(candidate.form_id)
	var grounded:=surface_basis(field.normal(home),float(candidate.yaw))
	var result: Dictionary={"point":home,"basis":grounded,"blend":0.0,"clock":time,"phase":"rest"}
	if form.get("locomotion_medium","")!="surface_air" or candidate.get("status","active")!="active":return result
	# Introduced specimens stay inside the supported isolation plot.
	if candidate.get("introduced",false):return result
	var cfg: Dictionary=form.flight
	var seed_phase: float=float(FrontierUniverse.derive(int(field.seed_value),"flight:"+str(candidate.id))%48000)/1000.0
	var cycle: float=float(cfg.cycle_seconds);var rest: float=float(cfg.rest_seconds);var transition: float=float(cfg.transition_seconds)
	var phase:=fposmod(time+seed_phase,cycle);result.clock=time+seed_phase
	if phase<rest:return result
	var air_time: float=phase-rest
	var airborne: float=cycle-rest
	var blend: float=smoothstep(0.0,transition,air_time)*(1.0-smoothstep(airborne-transition,airborne,air_time))
	var u: float=clampf((air_time-transition)/(airborne-transition*2.0),0.0,1.0)
	var angle: float=u*TAU;var radius: float=cfg.patrol_radius
	var offset:=Vector3(radius*(1.0-cos(angle)),0,radius*sin(angle))
	var yaw_basis:=Basis(Vector3.UP,float(candidate.yaw))
	var point:=home+yaw_basis*offset
	var safe_floor: float=maxf(home.y,field.height(point.x,point.z)+.08)
	point.y=lerpf(home.y,safe_floor+float(cfg.cruise_height),blend)
	var direction:=yaw_basis*Vector3(sin(angle),0,cos(angle))
	var heading: float=atan2(-direction.x,-direction.z)
	var basis_value:=surface_basis(Vector3.UP,heading)
	result.point=point;result.basis=grounded.slerp(basis_value,blend).orthonormalized();result.blend=blend
	result.phase="takeoff" if air_time<transition else ("landing" if air_time>airborne-transition else "flight")
	return result

static func resolve_identity(body: Dictionary,record: Dictionary,id: String) -> Dictionary:
	if id.begins_with("poi:"):return FrontierExplorationDiscoveries.sample_identity(body,record,id)
	var parts:=id.split(":")
	if parts.size()!=4 or parts[0] not in ["surface","cave"]:return {}
	for i in range(1,4):
		if not parts[i].is_valid_int() or str(int(parts[i]))!=parts[i]:return {}
	var limit:=preload("res://scripts/domain/surface_content_bounds.gd").identity_cells(body)
	if absi(int(parts[1]))>limit or absi(int(parts[2]))>limit or int(parts[3]) not in [0,1] or record.profile.origin=="sterile":return {}
	var pool: Array=[]
	for lineage in record.lineages:
		if (FrontierEcologyCatalog.form(lineage.form_id).environment=="cave")== (parts[0]=="cave"):pool.append(lineage)
	if pool.is_empty():return {}
	return pool[FrontierUniverse.derive(FrontierUniverse.derive(int(body.streams.ecology),id),"lineage")%pool.size()]

static func surface_basis(up: Vector3,yaw: float) -> Basis:
	var forward:=Basis(Vector3.UP,yaw)*Vector3.FORWARD
	forward=(forward-up*forward.dot(up)).normalized()
	return Basis(forward.cross(up).normalized(),up,-forward).orthonormalized()
