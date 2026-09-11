class_name FrontierUpgradeAccess
extends RefCounted
## The same physical stations serve personal refits and shared research.
static func station_for(kind: String,args: Dictionary) -> String:
	if kind in ["equipment_upgrade","equipment_suit_upgrade","rover_research","rover_research2"]:return "augmentation"
	if kind=="business_efficiency":return "research" if args.get("field")=="industry" else "augmentation"
	if kind in ["surface_study","surface_analyze","surface_restore","surface_introduce","surface_resupply"]:return "research"
	return ""
static func reason(world: Dictionary,actor: String,key: String,station: Dictionary) -> String:
	var title: String="증강 장치" if key=="augmentation" else "표본 연구대"
	if world.has("local_shuttle") or FrontierShuttles.aboard(world,actor):return "공동 원정선의 "+title+"를 이용하세요."
	if not FrontierCrewSurface.landed(world):return "착륙 후 "+title+"에서 작업하세요."
	var member: Dictionary=world.crew.members.get(actor,{})
	if member.get("area")!="surface" or member.get("aboard",true):return "착륙선 밖 "+title+"에 접근하세요."
	if station.get("enabled")!=true or not station.get("position") is Vector3 or station.get("area")!="surface" or station.get("body_id")!=world.crew.landing.body_id:return "사용 가능한 "+title+"가 없습니다."
	if FrontierCrewWorld.vector(member.position).distance_to(station.position)>(float(FrontierCrewSurface.config().boarding_distance) if station.get("ship_terminal",false) else float(FrontierCrewAugmentation.config().interaction_range)):return title+" 가까이에서 F로 작업하세요."
	return ""
