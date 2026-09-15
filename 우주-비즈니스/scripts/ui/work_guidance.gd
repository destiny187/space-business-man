extends RefCounted
## Read-only links through known, existing places. Never purchases or moves an actor.
static func navigate(app: FrontierCrewExpedition,request: Dictionary) -> void:
	if app.surface_world==null:return
	var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
	var kind: String=request.get("kind","warehouse")
	if kind=="environment":app.planet_map.modes.current_tab=1;app.open_menu(app.planet_map);app.planet_map.refresh();return
	var found: Dictionary={};var nearest:=INF
	var position:=FrontierCrewWorld.vector(app.session.latest.crew.members[app.session.latest.self_id].position)
	var candidates: Array=[]
	if request.has("position"):candidates.append(request)
	elif kind=="resource":
		for row in app.session.latest.crew.get("survey",{}).values():
			if row.body_id==app.surface_world.body.id and row.resource==request.get("resource",""):
				var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,str(row.vein_id))
				if not vein.is_empty():candidates.append(vein)
	else:
		if kind=="warehouse" and site.get("base_deployed",false) and not site.get("base_submerged",false):candidates.append({"id":"","type":"base","position":site.center})
		for id in site.get("buildings",{}):
			var row: Dictionary=site.buildings[id]
			if row.get("submerged",false):continue
			if (kind=="warehouse" and row.type=="storage") or (kind in ["factory","metalworks","equipment_workbench"] and row.type==kind) or (kind=="power" and row.type in ["solar","charger"]):
				var candidate:=row.duplicate();candidate.id=id;candidates.append(candidate)
	for row in candidates:
		var distance:=position.distance_to(FrontierCrewWorld.vector(row.position))
		if distance<nearest:nearest=distance;found=row
	if found.is_empty():
		if kind in ["factory","metalworks","equipment_workbench","warehouse","power"]:
			app.close_menus();app.toggle_business();app.business_panel.building_message.text="현장에 사용 가능한 "+{"factory":"제작소","metalworks":"금속 가공 공장","equipment_workbench":"장비 제작대","warehouse":"창고","power":"발전 / 충전 시설"}[kind]+"가 없습니다. 건설 카드를 선택하세요."
		else:app.feedback.show_cue("이 행성에서 확인한 산지가 없습니다. 스캔 기록을 더 모으세요.")
		return
	if nearest<=8 and kind in ["factory","metalworks","equipment_workbench","warehouse"]:
		app.open_station(found.type,str(found.get("id","")))
		if kind in ["factory","metalworks"]:
			app.business_panel.production_panel.selected_product=request.get("product","refined_iron")
			app.business_panel.production_panel.refresh()
		return
	app.planet_map.modes.current_tab=0;app.planet_map.refresh()
	app.planet_map.waypoint=Vector2(found.position[0],found.position[2]);app.planet_map.focus=app.planet_map.waypoint
	app.planet_map.layers.select(1 if kind=="resource" else 2)
	app.open_menu(app.planet_map);app.planet_map.update_detail();app.planet_map.canvas.queue_redraw()

static func robot_action(robot: Dictionary) -> Dictionary:
	var status: String=robot.get("status","")
	if "창고" in status:return {"kind":"warehouse","label":"창고 열기 / 위치 보기"}
	if "충전기" in status:return {"kind":"power","label":"발전  충전 시설 위치"}
	return {"kind":"location","position":robot.get("position",[0,0,0]),"label":"로봇 작업 위치 보기"}

static func asset_counts(site: Dictionary) -> Dictionary:
	var amount:=0;var equipment:=0
	var stocks: Array=site.get("regions",{}).values() if not site.get("regions",{}).is_empty() else [site]
	for stock in stocks:
		amount+=FrontierExpeditionBusiness.total(stock.get("inventory",{}));equipment+=stock.get("stored_equipment",{}).size()
	return {"buildings":site.get("buildings",{}).size(),"robots":site.get("robots",{}).size(),"inventory":amount,"equipment":equipment}

static func asset_summary(site: Dictionary) -> String:
	var counts:=asset_counts(site)
	return "시설 %d개  로봇 %d대  재고 %d개  보관 장비 %d개"%[counts.buildings,counts.robots,counts.inventory,counts.equipment]
