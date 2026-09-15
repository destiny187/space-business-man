extends RefCounted
## Explicit write sets. Shared branches are read-only to the scoped operation.
## Unknown commands retain the conservative full transaction draft.
const Snapshot=preload("res://scripts/persistence/world_snapshot.gd")
static func personal_equipment(kind: String) -> bool:
	return kind in ["equipment_drop","equipment_pickup","equipment_weapon_lock","equipment_weapon_salvage","equipment_select","equipment_equip","equipment_craft","equipment_ammo_craft","equipment_upgrade","equipment_suit_upgrade"]
static func _crew(source: Dictionary,actors: Array) -> Dictionary:
	var draft:=source.duplicate();draft.crew=source.crew.duplicate();draft.crew.members=source.crew.members.duplicate()
	for actor in actors:
		if source.crew.members.has(actor):draft.crew.members[actor]=source.crew.members[actor].duplicate(true)
	return draft
static func request(source: Dictionary,actor: String,kind: String,args: Dictionary={}) -> Dictionary:
	if kind=="guide_progress":
		var d:=_crew(source,[actor]);d.crew.receipts=source.crew.receipts.duplicate()
		d.crew.play_guide=source.crew.get("play_guide",{}).duplicate();return d
	if (kind in ["business_produce","business_discovery_use"] or (kind=="business_facility_research" and FrontierDiscoveryIndustry.building(str(args.get("research",""))))) and source.has("business"):
		var local:=FrontierShuttles.context(source,actor)
		if source.business.sites.has(local.location):
			# Regional production may merge its facade back into this site's districts.
			# Retain that write set, while other planets and discovery records stay shared.
			var d:=_crew(source,[actor]);d.crew.receipts=source.crew.receipts.duplicate()
			d.business=source.business.duplicate();d.business.sites=source.business.sites.duplicate()
			d.business.sites[local.location]=source.business.sites[local.location].duplicate(true)
			if kind=="business_facility_research":
				d.business.facility_research=source.business.get("facility_research",[]).duplicate()
			if kind in ["business_facility_research","business_discovery_use"]:
				d.business.bags=source.business.bags.duplicate()
				d.business.bags[actor]=FrontierExpeditionBusiness.bag(source,actor).duplicate()
			return d
	var mission: Dictionary=source.get("incidents",{}).get("records",{}).get(str(args.get("id","")),{})
	if kind in ["surface_incident","surface_incident_tool"] and FrontierActiveMissions.enabled(mission):
		var d:=_crew(source,[actor]);d.crew.receipts=source.crew.receipts.duplicate()
		d.incidents=source.incidents.duplicate();d.incidents.records=source.incidents.records.duplicate()
		d.incidents.records[str(args.id)]=mission.duplicate(true)
		d.business=source.business.duplicate();d.business.bags=source.business.bags.duplicate()
		d.business.bags[actor]=FrontierExpeditionBusiness.bag(source,actor).duplicate()
		if FrontierShuttles.aboard(source,actor):
			d.crew.shuttles=source.crew.shuttles.duplicate();d.crew.shuttles[actor]=source.crew.shuttles[actor].duplicate()
		return d
	if kind.begins_with("station_skill_") and source.has("vessel") and source.has("business"):
		var skill_draft:=_crew(source,[actor]);skill_draft.crew.receipts=source.crew.receipts.duplicate()
		skill_draft.vessel=source.vessel.duplicate(true);skill_draft.business=source.business.duplicate()
		return skill_draft
	if not personal_equipment(kind) or not source.get("business",{}).has("bags"):return Snapshot.copy(source)
	var draft:=_crew(source,[actor]);draft.crew.receipts=source.crew.receipts.duplicate()
	draft.business=source.business.duplicate();draft.business.bags=source.business.bags.duplicate()
	draft.business.bags[actor]=FrontierExpeditionBusiness.bag(source,actor).duplicate()
	if kind in ["equipment_drop","equipment_pickup"]:draft.business.crates=source.business.crates.duplicate()
	if FrontierShuttles.aboard(source,actor):
		draft.crew.shuttles=source.crew.shuttles.duplicate();draft.crew.shuttles[actor]=source.crew.shuttles[actor].duplicate()
	return draft
static func bodies(source: Dictionary,actors: Array) -> Array:
	var result: Array=[]
	for actor in actors:
		var local:=FrontierShuttles.context(source,actor)
		if FrontierCrewSurface.landed(local) and not local.location in result:result.append(local.location)
	return result
static func weather(source: Dictionary,actors: Array) -> Dictionary:
	var draft:=_crew(source,actors)
	if source.has("weather"):
		draft.weather=source.weather.duplicate();draft.weather.planets=source.weather.planets.duplicate()
		for id in bodies(source,actors):
			if source.weather.planets.has(id):draft.weather.planets[id]=source.weather.planets[id].duplicate(true)
	return draft
static func _sites(draft: Dictionary,source: Dictionary,ids: Array,cover: bool=false) -> void:
	if not source.has("business"):return
	draft.business=source.business.duplicate();draft.business.sites=source.business.sites.duplicate()
	for id in ids:
		if not source.business.sites.has(id):continue
		var row: Dictionary=source.business.sites[id];draft.business.sites[id]=row.duplicate()
		if cover:
			draft.business.sites[id].buildings=row.buildings.duplicate()
			for key in row.buildings:
				if FrontierCombatCover.is_cover(row.buildings[key]):draft.business.sites[id].buildings[key]=row.buildings[key].duplicate(true)
static func incidents(source: Dictionary,actors: Array) -> Dictionary:
	var draft:=_crew(source,actors);var ids:=bodies(source,actors)
	if source.has("incidents"):
		draft.incidents=source.incidents.duplicate();draft.incidents.records=source.incidents.records.duplicate()
		for key in source.incidents.records:
			var row: Dictionary=source.incidents.records[key]
			# A disconnected carrier can drop cargo even outside the active regions.
			if _near_incident(source,actors,row) or not str(row.get("carrier","")).is_empty() or not str(row.get("battery_carrier","")).is_empty():draft.incidents.records[key]=row.duplicate(true)
	draft.terrain_edits=source.terrain_edits.duplicate()
	for id in ids:
		if source.terrain_edits.has(id):draft.terrain_edits[id]=source.terrain_edits[id].duplicate(true)
	_sites(draft,source,ids,true)
	return draft
static func _near_incident(source: Dictionary,actors: Array,row: Dictionary) -> bool:
	for actor in actors:
		if not FrontierExplorationIncidents.is_present(source,actor,row):continue
		var at:=FrontierCrewWorld.vector(source.crew.members[actor].position)
		if minf(at.distance_to(FrontierCrewWorld.vector(row.position)),at.distance_to(FrontierCrewWorld.vector(row.relay)))<float(FrontierExplorationIncidents.config().activation_distance)+float(FrontierCooperTechSquads.config().group_alarm_radius):return true
	return false
static func water(source: Dictionary,actors: Array) -> Dictionary:
	var draft:=source.duplicate();var ids:=bodies(source,actors)
	draft.surface_water=source.get("surface_water",{}).duplicate()
	for id in ids:
		if draft.surface_water.has(id):draft.surface_water[id]=draft.surface_water[id].duplicate(true)
	_sites(draft,source,ids)
	return draft
static func plots(source: Dictionary,ids: Array) -> Dictionary:
	var draft:=source.duplicate();draft.ecology=source.ecology.duplicate();draft.ecology.planets=source.ecology.planets.duplicate()
	for id in ids:
		var row: Dictionary=source.ecology.planets[id]
		draft.ecology.planets[id]=row.duplicate();draft.ecology.planets[id].plot=row.plot.duplicate(true)
	return draft

static func industry(source: Dictionary) -> Dictionary:
	# Industry writes operating sites, shared credits, assembly, field trials and
	# supply deliveries. Geological edits and biological discovery history are read-only.
	var draft:=source.duplicate()
	for key in ["crew","lotus","rovers","engineering","expedition_research"]:
		if source.has(key):draft[key]=source[key].duplicate(true)
	if source.has("business"):
		draft.business=source.business.duplicate();draft.business.sites=source.business.sites.duplicate()
		for id in source.business.sites:
			if FrontierPlanetSupply.operating(source.business.sites[id]):draft.business.sites[id]=source.business.sites[id].duplicate(true)
	return draft
