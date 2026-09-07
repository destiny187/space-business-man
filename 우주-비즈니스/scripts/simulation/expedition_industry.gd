class_name FrontierExpeditionIndustry
extends RefCounted
static func tick(world: Dictionary,dt: float) -> void:
	var site:=FrontierExpeditionBusiness.site(world)
	if site.is_empty() or site.state!="active":return
	site.time=minf(10000000,site.time+dt)
	power(world,site)
	var ledger: Dictionary=world.business
	for id in site.jobs.keys():
		var job: Dictionary=site.jobs[id]
		var factory: Dictionary=site.buildings[job.factory_id]
		if not factory.active:continue
		job.progress=minf(float(job.seconds),float(job.progress)+dt*FrontierProductionTier2.factor(factory))
		if job.progress<float(job.seconds):continue
		var spawn:=Vector3.INF
		for i in 12:
			var center:=FrontierExpeditionBusiness.point(factory.position)
			var candidate:=center+Vector3(sin(i*TAU/12),0,cos(i*TAU/12))*5
			candidate=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world),candidate.x,candidate.z,.75)
			if candidate.is_finite() and clear(world,candidate):spawn=candidate;break
		if not spawn.is_finite():factory.status="출고 공간 필요";continue
		site.robots[id]={"id":id,"grade":job.grade,"position":FrontierExpeditionBusiness.array(spawn),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","path":[],"status":"작업 배정 대기","work":0.0,"charging":false}
		site.jobs.erase(id)
	for robot in site.robots.values():_robot(world,site,robot,dt)
	FrontierProductionTier2.tick(site,dt)
	FrontierFieldEngineering.tick(world,dt)
	environment(world,site,dt)
	if not site.production_paid and int(site.delivered)>=48 and not site.robots.is_empty():
		site.production_paid=true;ledger.credits+=int(FrontierExpeditionBusiness.config().production_milestone)
static func power(world: Dictionary,site: Dictionary) -> void:
	var supply:=2.0;var demand:=0.0
	for building in site.buildings.values():
		var def:=FrontierCatalog.entry("buildings",building.type)
		var p:=FrontierExpeditionBusiness.point(building.position)
		var supported:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world),p.x,p.z,float(def.radius)).is_finite()
		building.active=false;building.status="정지" if not building.enabled else "전력 대기"
		if not supported:building.status="토대 지지 필요";continue
		if not building.enabled:continue
		if float(def.power)<=0:building.active=true;building.status="발전 중" if def.power<0 else "사용 가능";supply-=float(def.power)*FrontierProductionTier2.factor(building)
		else:demand+=float(def.power)
	var remaining:=supply
	for kind in ["charger","factory","atmosphere","thermal","water","biolab"]:
		for building in site.buildings.values():
			if building.type!=kind or not building.enabled or building.status=="토대 지지 필요":continue
			var consumption: float=FrontierCatalog.entry("buildings",kind).power
			if remaining>=consumption:building.active=true;building.status="가동 중";remaining-=consumption
	site.power_supply=supply;site.power_demand=demand
static func obstacles(world: Dictionary) -> Array:
	var result: Array=[]
	for b in FrontierExpeditionBusiness.site(world).buildings.values():result.append({"position":b.position,"radius":float(FrontierCatalog.entry("buildings",b.type).radius)+.3})
	return result
static func clear(world: Dictionary,p: Vector3) -> bool:
	for b in obstacles(world):
		if Vector2(b.position[0]-p.x,b.position[2]-p.z).length()<b.radius+1:return false
	for r in FrontierExpeditionBusiness.site(world).robots.values():
		if FrontierExpeditionBusiness.point(r.position).distance_to(p)<2:return false
	return true
static func _move(world: Dictionary,r: Dictionary,target: Vector3,dt: float) -> bool:
	var field:=FrontierCrewSurface.field(world)
	var current:=FrontierExpeditionBusiness.point(r.position)
	if current.distance_to(target)<2.5:r.path=[];return true
	var cfg: Dictionary=FrontierSurfaceLogistics.config().navigation
	if r.path.is_empty():
		var navigator:=FrontierTerrainNavigation.new()
		var result:=navigator.find_path(field,current,target,cfg,obstacles(world))
		if result.points.is_empty():r.status="경로 막힘 · 통로 확보 필요";return false
		for p in result.points:r.path.append(FrontierExpeditionBusiness.array(p))
		if r.path.size()>1:r.path.pop_front()
	var travel: float=float(FrontierCatalog.entry("robots","miner").speed)*float(FrontierCatalog.entry("grades",r.grade).multiplier)*dt*(float(FrontierProductionTier2.config().robot_upgrade.speed_factor) if int(r.get("tier",1))==2 else 1.0)
	while travel>0 and not r.path.is_empty():
		var goal:=FrontierExpeditionBusiness.point(r.path[0]);var distance:=current.distance_to(goal)
		var step: float=minf(distance,travel)
		var next:=current.move_toward(goal,step)
		var navigator:=FrontierTerrainNavigation.new();navigator.field=field;navigator.settings=cfg;navigator.obstacles=obstacles(world)
		if not navigator.clear_at(next) or (step>.1 and not navigator.segment_clear(current,next)):r.path=[];r.status="통로 변경 · 재탐색";return false
		current=next;travel-=step;r.battery=maxf(0,r.battery-step*float(FrontierExpeditionBusiness.config().robot_battery_per_meter))
		r.position=FrontierExpeditionBusiness.array(current)
		if distance<=step+.001:r.path.pop_front()
		if step<.001:break
	return current.distance_to(target)<2.5
static func _robot(world: Dictionary,site: Dictionary,r: Dictionary,dt: float) -> void:
	var cfg:=FrontierExpeditionBusiness.config()
	FrontierRobotWork.ensure(r)
	r.search_wait=maxf(0,float(r.search_wait)-dt)
	if float(r.battery)<=0:r.status="배터리 고갈 · 근접 긴급 충전";return
	if float(r.battery)<25 and not r.charging:r.charging=true;r.path=[]
	if r.charging:
		var charger: Dictionary={};var distance:=INF
		for b in site.buildings.values():
			if b.type!="charger" or not b.active:continue
			var delta:=FrontierExpeditionBusiness.point(b.position).distance_to(FrontierExpeditionBusiness.point(r.position))
			if delta<distance:distance=delta;charger=b
		if charger.is_empty():r.status="전원이 켜진 충전기 필요";return
		var goal:=FrontierExpeditionBusiness.point(charger.position)+Vector3(3,0,0);goal.y=FrontierCrewSurface.field(world).height(goal.x,goal.z)
		r.status="충전기 복귀"
		if _move(world,r,goal,dt):
			r.status="충전 중";r.battery=minf(100,float(r.battery)+float(cfg.robot_charge_rate)*dt*FrontierProductionTier2.factor(charger))
			if r.battery>=99:r.charging=false;r.path=[]
		return
	if r.phase=="idle":
		if not r.auto_enabled:r.status="자동 채광 정지";return
		if r.search_wait<=0:
			r.search_wait=float(FrontierRobotWork.config().search_interval)
			FrontierRobotWork.search(world,r)
		return
	if r.phase=="return":
		r.status="창고로 운반"
		if _move(world,r,FrontierExpeditionBusiness.point(site.center)+Vector3(3,0,0),dt):
			for resource in r.cargo:
				var amount:=mini(int(r.cargo[resource]),FrontierItemInventory.warehouse_room(site,resource))
				site.inventory[resource]=int(site.inventory.get(resource,0))+amount;r.cargo[resource]-=amount;site.delivered+=amount
			if FrontierExpeditionBusiness.total(r.cargo)>0:r.status="창고 가득 참 · 하역 대기";return
			r.phase="outbound" if not r.target.is_empty() and int(site.remaining.get(r.target,0))>0 else "idle";r.path=[]
		return
	var vein:=FrontierExpeditionBusiness.find_vein(FrontierUniverse.body_from_id(world.manifest,world.location),r.target)
	if not FrontierRobotWork.reason(world,r,vein).is_empty():
		r.manual_target="";r.target="";r.phase="return" if FrontierExpeditionBusiness.total(r.cargo)>0 else "idle";r.path=[];r.search_wait=0.0;return
	var goal:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world),vein.position[0],vein.position[2])
	if not goal.is_finite():r.status="광맥의 토대가 무너졌습니다";return
	r.status="광맥으로 이동"
	if not _move(world,r,goal,dt):return
	r.status="채광 중";r.work+=dt*float(FrontierCatalog.entry("grades",r.grade).multiplier)
	if r.work<1:return
	r.work=maxf(0,r.work-1)
	var amount:=mini(int(site.remaining[r.target]),mini((int(FrontierProductionTier2.config().robot_upgrade.mine_amount) if int(r.get("tier",1))==2 else int(cfg.robot_mine_amount)),FrontierProductionTier2.robot_capacity(r)-FrontierExpeditionBusiness.total(r.cargo)))
	site.remaining[r.target]-=amount;r.cargo[vein.resource]=int(r.cargo.get(vein.resource,0))+amount;r.battery=maxf(0,float(r.battery)-float(cfg.robot_battery_per_work))
	if site.remaining[r.target]<=0:r.manual_target="";r.target=""
	if FrontierExpeditionBusiness.total(r.cargo)>=FrontierProductionTier2.robot_capacity(r) or r.target.is_empty():r.phase="return";r.path=[]
static func environment(world: Dictionary,site: Dictionary,dt: float) -> void:
	if FrontierUniverse.body_from_id(world.manifest,world.location).get("origin","")=="solar_reference":return
	var e: Dictionary=site.environment;var cfg:=FrontierExpeditionBusiness.config()
	for b in site.buildings.values():
		if not b.active:continue
		var engineering: float=FrontierFieldEngineering.factor(world,b)*FrontierProductionTier2.factor(b)
		FrontierProductionTier2.restore(site,b,dt)
		match b.type:
			"atmosphere":
				e.oxygen=move_toward(float(e.oxygen),.21,float(cfg.oxygen_rate)*dt*FrontierProductionTier2.factor(b));e.pressure=move_toward(float(e.pressure),1,float(cfg.pressure_rate)*dt*FrontierProductionTier2.factor(b));e.toxicity=move_toward(float(e.toxicity),0,float(cfg.toxicity_rate)*dt*FrontierProductionTier2.factor(b))
			"thermal":e.temperature=move_toward(float(e.temperature),18,float(cfg.thermal_rate)*dt*engineering)
			"water":
				if e.water>=100:b.status="목표 달성";continue
				b.work+=dt
				if b.work>=float(cfg.water_cycle_seconds)/engineering:
					if site.inventory.ice<=0:b.status="얼음 보급 필요";b.work=minf(b.work,float(cfg.water_cycle_seconds)/engineering)
					else:site.inventory.ice-=1;e.water=minf(100,float(e.water)+float(cfg.water_per_ice));b.work=maxf(0.0,float(b.work)-float(cfg.water_cycle_seconds)/engineering)
			"biolab":
				var score:=FrontierEvaluator.scores(e)
				if minf(score.atmosphere,minf(score.temperature,score.water))<60:b.status="대기·온도·수질 안정화 필요";continue
				if not FrontierProductionTier2.restoration_ready(site):b.status="Mk.2 담수 처리·토양 개량 필요";continue
				if e.ecology>=100:b.status="배양 목표 달성";continue
				if site.inventory.ice<=0:b.status="배양 수분 공급 필요";continue
				b.work+=dt
				if b.work>=float(cfg.biolab_nutrient_seconds):site.inventory.ice-=1;b.work=0.0
				e.ecology=minf(100,float(e.ecology)+float(cfg.biolab_rate)*dt*engineering)
	var scores:=FrontierEvaluator.scores(e)
	if FrontierProductionTier2.restoration_ready(site) and minf(scores.atmosphere,minf(scores.temperature,scores.water))>=60:e.stable_seconds=minf(120,e.stable_seconds+dt)
	else:e.stable_seconds=0.0
