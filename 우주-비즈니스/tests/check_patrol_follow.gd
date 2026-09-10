extends SceneTree
func _initialize() -> void:
	var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),FrontierPlayerProfile.new_character("경비 추적",2),func(_w):return true)
	var world: Dictionary=core.world;var m: Dictionary=world.manifest;var nav: Dictionary=world.crew.navigation
	var point:=FrontierSpaceTraffic.berth(m,"solar_mars_port",0,1)+Vector3(800,500,0)
	nav.position=FrontierExpeditionBusiness.array(point);nav.traffic_observers=FrontierSpaceTraffic.observers(world);FrontierSpacePatrol.step(world)
	nav.orbit_time=4;nav.position=FrontierExpeditionBusiness.array(point+Vector3(100,40,0));nav.traffic_observers=FrontierSpaceTraffic.observers(world);FrontierSpacePatrol.step(world)
	var followed: bool=nav.traffic_patrols.solar_mars_port.target==nav.position and nav.traffic_patrols.solar_mars_port.target_id=="crew"
	var gap:=INF
	for t in range(0,1200,2):
		var rows:=FrontierSpaceTraffic.all(m,0,float(t),nav.traffic_observers,nav.traffic_patrols)
		for i in range(2,6):
			for j in range(i):gap=minf(gap,rows[i].position.distance_to(rows[j].position))
	var valid: bool=FrontierSpacePatrol.valid_state(nav.traffic_patrols)
	print("PATROL_FOLLOW ",followed," valid=",valid," NPC minimum gap=",gap)
	quit(0 if followed and valid and gap>100 else 1)
