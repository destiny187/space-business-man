extends RefCounted
## Host-only finite-speed rounds. Swept segments cannot tunnel through thin cover.
const Targets=preload("res://scripts/domain/firearm_targets.gd")
var shots: Array=[]
var event_serial:=0
var history: RefCounted
func count() -> int:
	var n:=0
	for shot in shots:n+=shot.rounds.size()
	return n
func launch(world: Dictionary,actor: String,tool: Dictionary,event: Dictionary,ads: bool) -> void:
	tool=tool.duplicate();tool.shot_key=str(event.serial);tool.shot_origin=event.origin;tool.shot_damage=float(event.get("shot_damage",tool.damage))
	var rounds: Array=[]
	for initial in event.projectiles:
		rounds.append({"index":initial.get("index",rounds.size()),"point":FrontierCrewWorld.vector(event.origin),"velocity":FrontierCrewWorld.vector(initial.velocity),"time":float(event.get("fired_time",0)),"distance":0.0,"gravity":initial.gravity,"remaining":initial.range,"multiplier":initial.multiplier})
	shots.append({"actor":actor,"body_id":world.location,"tool":tool.duplicate(true),"rounds":rounds,"serial":event.serial,"ads":ads,"weak":false,"catchup":float(event.get("rewind_seconds",0))})
func step(world: Dictionary,delta: float,obstacle: Callable) -> Array:
	var events: Array=[];var candidates: Dictionary={}
	for index in range(shots.size()-1,-1,-1):
		var shot: Dictionary=shots[index];var actor: String=shot.actor
		if not world.crew.members.has(actor):shots.remove_at(index);continue
		var local:=FrontierShuttles.context(world,actor)
		var member: Dictionary=local.crew.members[actor]
		if local.location!=shot.body_id or member.area!="surface" or member.aboard:shots.remove_at(index);continue
		if not candidates.has(actor):candidates[actor]=Targets.candidates(local,actor)
		var contacts: Array=[];var targets: Dictionary={};var retired: Array=[]
		var totals: Dictionary={"damage":0.0,"shield":0.0,"broken":false,"weak":false,"killed":false,"organic":false}
		for i in range(shot.rounds.size()-1,-1,-1):
			var round: Dictionary=shot.rounds[i];var remaining:=delta+float(shot.get("catchup",0));var ended:=false
			while remaining>0 and not ended:
				var dt:=minf(remaining,float(FrontierFirearms.config().projectiles.step));remaining-=dt
				var origin: Vector3=round.point
				var displacement: Vector3=round.velocity*dt+Vector3.DOWN*float(round.gravity)*dt*dt*.5
				round.velocity+=Vector3.DOWN*float(round.gravity)*dt
				var direction:=displacement.normalized();var length:=minf(displacement.length(),float(round.remaining))
				var reach:=length
				if obstacle.is_valid():reach=minf(reach,float(obstacle.call(actor,origin,direction,reach)))
				else:reach=_terrain_distance(local,origin,direction,reach)
				var cover:=FrontierCombatCover.intercept(local,shot.body_id,origin,direction,reach)
				if not cover.is_empty():reach=minf(reach,float(cover.distance))
				var rows: Array=candidates[actor]
				if history!=null:
					var frame: Dictionary=history.at(actor,shot.body_id,float(round.time)+dt*.5)
					if not frame.is_empty():rows=frame.rows
				round.time+=dt
				var hit:=Targets.intersect(rows,origin,direction,reach)
				var point:=origin+direction*reach
				if not hit.is_empty():point=hit.point
				round.distance+=origin.distance_to(point);round.remaining-=origin.distance_to(point);round.point=point
				var surface: bool=reach<length-.001 or not cover.is_empty()
				if not hit.is_empty():
					var outcome:=_damage(local,shot,hit,float(round.distance),float(round.multiplier))
					_collect(targets,totals,hit,outcome)
					contacts.append(_contact(hit,outcome,direction));ended=true
					for extra in FrontierWeaponElements.followup(local,actor,shot.tool,hit,outcome,candidates[actor],direction,obstacle):
						_collect(targets,totals,extra.hit,extra.outcome)
						var contact:=_contact(extra.hit,extra.outcome,direction);contact.element_id=shot.tool.element_id;contact.legendary=true;contact.from=FrontierExpeditionBusiness.array(hit.point);contacts.append(contact)
				elif surface:
					if not cover.is_empty():FrontierCombatCover.damage(cover,float(shot.tool.get("shot_damage",shot.tool.damage))*float(round.multiplier))
					contacts.append({"point":FrontierExpeditionBusiness.array(point),"normal":FrontierExpeditionBusiness.array(-direction),"kind":"surface"});ended=true
				if ended and shot.tool.effect=="splash":
					_blast(local,shot,candidates[actor],point,hit.get("id",""),obstacle,contacts,targets,totals)
				if float(round.remaining)<=.001:ended=true
			if ended:retired.append(round.index);shot.rounds.remove_at(i)
		shot.catchup=0.0
		if not contacts.is_empty():
			event_serial+=1
			events.append({"actor":actor,"body_id":shot.body_id,"impact_only":true,"serial":event_serial,"shot_serial":shot.serial,"retired":retired,"family":shot.tool.firearm,"element_id":shot.tool.get("element_id","kinetic"),"effect":shot.tool.effect,"item_id":shot.tool.item_id,"contacts":contacts,"damage_targets":targets.values(),"hits":totals,"rays":[]})
			var state: Dictionary=member.loadout.get("weapon_states",{}).get(shot.tool.item_id,{})
			if not state.is_empty():
				if totals.broken:state.breach=true
			shot.weak=shot.weak or totals.weak
			FrontierShuttles.commit(world,local,actor)
		if shot.rounds.is_empty():
			var state: Dictionary=member.loadout.get("weapon_states",{}).get(shot.tool.item_id,{})
			if not state.is_empty():state.weak_streak=(int(state.weak_streak)+1)%3 if shot.weak else 0
			shots.remove_at(index)
	return events
func _terrain_distance(world: Dictionary,origin: Vector3,direction: Vector3,reach: float) -> float:
	var field:=FrontierCrewSurface.field(world)
	var steps:=maxi(1,ceili(reach/.20))
	for index in range(1,steps+1):
		var distance:=reach*index/steps
		if field.density(origin+direction*distance)<=0:continue
		var low:=reach*(index-1)/steps;var high:=distance
		for refine in 6:
			var middle: float=(low+high)*.5
			if field.density(origin+direction*middle)>0:high=middle
			else:low=middle
		return low
	return reach
func _damage(world: Dictionary,shot: Dictionary,hit: Dictionary,distance: float,multiplier: float) -> Dictionary:
	var start:=float(shot.tool.range)*float(shot.tool.get("falloff_start",.6))
	var amount:=float(shot.tool.get("shot_damage",shot.tool.damage))*multiplier*lerpf(1,.55,clampf((distance-start)/(float(shot.tool.range)-start),0,1))
	return FrontierFirearms._damage(world,shot.actor,hit,amount,shot.tool,shot.ads)
func _collect(targets: Dictionary,totals: Dictionary,hit: Dictionary,result: Dictionary) -> void:
	FrontierFirearms._record_damage(targets,hit,result)
	for key in ["damage","shield"]:totals[key]+=float(result[key])
	for key in ["broken","weak","killed"]:totals[key]=totals[key] or result[key]
	if hit.kind=="animal":totals.organic=true
func _contact(hit: Dictionary,result: Dictionary,direction: Vector3) -> Dictionary:
	return {"point":FrontierExpeditionBusiness.array(hit.point),"normal":FrontierExpeditionBusiness.array(-direction),"kind":"break" if result.broken else "shield" if result.shield>0 else "organic" if hit.kind=="animal" else "armor"}
func _blast(world: Dictionary,shot: Dictionary,rows: Array,point: Vector3,direct: String,obstacle: Callable,contacts: Array,targets: Dictionary,totals: Dictionary) -> void:
	var visited: Dictionary={direct:true};var radius:=float(shot.tool.blast_radius)
	for row in rows:
		if visited.has(row.id):continue
		var center: Vector3=row.transform*row.bounds.get_center();var gap:=point.distance_to(center)
		if gap>radius or gap<.05:continue
		visited[row.id]=true
		var direction: Vector3=(center-point)/gap
		if not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(world),point+direction*.06,center):continue
		if not FrontierCombatCover.intercept(world,shot.body_id,point+direction*.06,direction,gap).is_empty():continue
		if obstacle.is_valid() and float(obstacle.call(shot.actor,point+direction*.06,direction,gap))<gap-.4:continue
		var hit: Dictionary=row.duplicate();hit.point=center;hit.weak=false;hit.zone="body"
		var splash_tool: Dictionary=shot.tool.duplicate();splash_tool.legendary_id="";splash_tool.splash_secondary=true;splash_tool.splash_factor=.6*(1-gap/radius)
		var outcome:=FrontierFirearms._damage(world,shot.actor,hit,float(shot.tool.get("shot_damage",shot.tool.damage))*.6*(1-gap/radius),splash_tool,false)
		_collect(targets,totals,hit,outcome);contacts.append(_contact(hit,outcome,-direction))
