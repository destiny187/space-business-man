extends RefCounted
## Local movement write set. Decisions, damage, discovery and durable saves stay at 4 Hz.
static func step(source: Dictionary,delta: float,actors: Array,obstacle: Callable) -> Dictionary:
	var fields: Dictionary={};var present: Dictionary={}
	for actor in actors:
		var local:=FrontierShuttles.context(source,actor)
		if not FrontierCrewSurface.landed(local) or source.crew.members[actor].aboard:continue
		if not fields.has(local.location):fields[local.location]=FrontierCrewSurface.field(local);present[local.location]=[]
		present[local.location].append(actor)
	var draft: Dictionary=source
	for id in source.get("incidents",{}).get("records",{}):
		var original: Dictionary=source.incidents.records[id]
		if not FrontierCooperTechSquads.enabled(original) or original.hp<=0 or not fields.has(original.body_id):continue
		var nearby: Array=[]
		for actor in present[original.body_id]:
			if FrontierCrewWorld.vector(source.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(original.position))<float(FrontierExplorationIncidents.config().activation_distance):nearby.append(actor)
		if nearby.is_empty():continue
		if original.phase in ["idle","waking","destroyed"] and FrontierCrewWorld.vector(original.get("move_velocity",[0,0,0])).is_zero_approx():continue
		if is_same(draft,source):
			draft=source.duplicate();draft.incidents=source.incidents.duplicate();draft.incidents.records=source.incidents.records.duplicate()
		# Arrays are replaced; no nested path, inventory, crew or terrain branch is written.
		var row:=original.duplicate();draft.incidents.records[id]=row
		row.motion_clock=float(row.get("motion_clock",row.age))+delta
		var f: FrontierTerrainField=fields[row.body_id]
		var at:=FrontierCrewWorld.vector(row.position)
		var target: String=row.get("drive_actor","")
		if target not in nearby:target=""
		var moved:=false
		if row.phase=="patrol":
			var goal:=FrontierCrewWorld.vector(row.path[int(row.patrol_index)])
			if at.distance_to(goal)>1.1:
				moved=FrontierCooperTechSquads.move(draft,row,f,goal,delta,nearby[0],obstacle)
				if not moved:row.patrol_index=(int(row.patrol_index)+1)%12
		elif row.phase=="pursuing":
			var goal:=FrontierCrewWorld.vector(row.home) if target.is_empty() or at.distance_to(FrontierCrewWorld.vector(row.home))>float(FrontierCooperTechSquads.config().leash) else FrontierCrewWorld.vector(source.crew.members[target].position)
			moved=FrontierCooperTechSquads.move(draft,row,f,goal,delta,nearby[0] if target.is_empty() else target,obstacle)
		elif not target.is_empty() and row.phase in ["aiming","firing","cooling","projectile"]:
			var cfg:=FrontierCooperTechSquads.spec(row)
			if cfg.attack!="mortar" or row.phase in ["aiming","cooling"]:moved=FrontierCooperTechSquads.maneuver(draft,row,f,target,delta,obstacle)
		if not moved:row.move_velocity=[0,0,0]
	return draft
