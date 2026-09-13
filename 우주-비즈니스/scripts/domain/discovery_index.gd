class_name FrontierDiscoveryIndex
extends RefCounted
## Read-only, bounded pages of actual crew discoveries. Never enumerate generated life.
const PAGE_SIZE:=24
static func page(world: Dictionary,query: String,kind: String,body_id: String,page_index: int) -> Dictionary:
	var entries: Array=[]
	var needle:=query.strip_edges().to_lower()
	if kind in ["all","corporation"]:
		for id in FrontierCorporations.records(world):
			var row: Dictionary=FrontierCorporations.records(world)[id]
			var company:=FrontierCorporations.company(id)
			if not body_id.is_empty() and row.body_id!=body_id:continue
			if not needle.is_empty() and not (str(company.name)+" "+str(company.get("name_ko",""))+" "+str(company.role)).to_lower().contains(needle):continue
			entries.append({"key":"corporation:"+id,"kind":"corporation","company":id,"row":row.duplicate(true),"name":company.name,"icon":"scan"})
		for id in FrontierCorporateTraces.records(world):
			var row:=FrontierCorporateTraces.definition(world.manifest,id)
			if row.is_empty() or (not body_id.is_empty() and row.body_id!=body_id):continue
			if not needle.is_empty() and not (str(row.name)+" "+str(row.activity)+" "+str(FrontierCorporations.company(row.company).get("name_ko",""))).to_lower().contains(needle):continue
			row.stage=int(FrontierCorporateTraces.records(world)[id])
			if int(row.stage)<2:row.evidence=""
			entries.append({"key":id,"kind":"corporate_trace","company":row.company,"row":row,"name":row.name,"icon":"scan"})
	for category in ["mineral","biology"]:
		if kind!="all" and kind!=category:continue
		var source: Dictionary=world.crew.get("survey",{}) if category=="mineral" else world.ecology.observations
		for key in source:
			var row: Dictionary=source[key]
			if not body_id.is_empty() and row.body_id!=body_id:continue
			var title: String=FrontierCatalog.entry("resources",row.resource).name if category=="mineral" else FrontierSpeciesNames.display(world.ecology,row.form_id)
			var identity:=FrontierSpeciesNames.identity(world.ecology,row.form_id) if category=="biology" else {}
			if not needle.is_empty() and not (title+" "+str(identity.get("code",""))).to_lower().contains(needle):continue
			var view:=row.duplicate(true)
			if category=="biology":view.identity=identity.duplicate();view.species_studied=world.ecology.get("species_research",{}).has(row.form_id)
			entries.append({"key":category+":"+str(key),"kind":category,"row":view,"name":title,"icon":row.resource if category=="mineral" else FrontierResourceIcons.specimen_id(FrontierEcologyCatalog.form(row.form_id))})
	if kind in ["all","discovery"]:
		for key in FrontierExplorationDiscoveries.records(world):
			var row: Dictionary=FrontierExplorationDiscoveries.records(world)[key]
			var d:=FrontierExplorationDiscoveries.definition(row.template)
			if not body_id.is_empty() and row.body_id!=body_id:continue
			if not needle.is_empty() and not str(d.name).to_lower().contains(needle):continue
			var view:=row.duplicate(true)
			if not row.sample.is_empty():view.sample_name=FrontierSpeciesNames.display(world.ecology,row.sample.form_id)
			entries.append({"key":"discovery:"+key,"kind":"discovery","row":view,"name":d.name,"icon":"scan"})
	if kind in ["all","incident"]:
		for id in FrontierCooperTechClues.records(world):
			var clue:=FrontierCooperTechClues.describe(world,id)
			if clue.is_empty() or (not body_id.is_empty() and clue.body_id!=body_id):continue
			if not needle.is_empty() and not (str(clue.name)+" 쿠퍼테크").to_lower().contains(needle):continue
			entries.append({"key":"clue:"+id,"kind":"coopertech_clue","row":clue,"name":clue.name,"icon":"scan"})
		for id in FrontierFreightSalvage.records(world):
			var row:=FrontierFreightSalvage.definition(world.manifest,id)
			if row.is_empty() or (not body_id.is_empty() and row.body_id!=body_id):continue
			if not needle.is_empty() and not (str(row.name)+" Space Y "+str(row.port_name)+" "+str(row.cargo)).to_lower().contains(needle):continue
			row.merge(FrontierFreightSalvage.records(world)[id],true)
			entries.append({"key":id,"kind":"freight_incident","row":row,"name":row.name,"icon":"scan"})
		for key in FrontierExplorationIncidents.records(world):
			var row: Dictionary=FrontierExplorationIncidents.records(world)[key]
			var d:=FrontierExplorationIncidents.definition(row.template)
			if not row.seen or (not body_id.is_empty() and row.body_id!=body_id):continue
			if not needle.is_empty() and not str(d.name).to_lower().contains(needle):continue
			var view:=row.duplicate(true)
			if row.has("native"):view.native_name=FrontierNativeIncidents.title(row.native,world.ecology)
			entries.append({"key":"incident:"+key,"kind":"incident","row":view,"name":d.name,"icon":"scan"})
	if kind in ["all","weather"]:
		for key in world.get("weather",{}).get("observations",{}):
			var row: Dictionary=world.weather.observations[key];var info:=FrontierPlanetWeather.info(row)
			if not body_id.is_empty() and row.body_id!=body_id:continue
			if not needle.is_empty() and not str(info.name).contains(needle):continue
			entries.append({"key":key,"kind":"weather","row":row.duplicate(),"name":info.name,"icon":"scan"})
	entries.sort_custom(func(a,b):
		var left: String=a.row.get("identity",{}).get("code",a.name) if a.kind=="biology" else a.name
		var right: String=b.row.get("identity",{}).get("code",b.name) if b.kind=="biology" else b.name
		return a.key<b.key if left==right else left.naturalnocasecmp_to(right)<0)
	var index:=clampi(page_index,0,maxi(0,(entries.size()-1)/PAGE_SIZE))
	return {"entries":entries.slice(index*PAGE_SIZE,(index+1)*PAGE_SIZE),"total":entries.size(),"page":index}
