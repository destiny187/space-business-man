class_name FrontierDiscoveryIndex
extends RefCounted
## Read-only, bounded pages of actual crew discoveries. Never enumerate generated life.
const PAGE_SIZE:=24
static func page(world: Dictionary,query: String,kind: String,body_id: String,page_index: int) -> Dictionary:
	var entries: Array=[]
	var needle:=query.strip_edges().to_lower()
	for category in ["mineral","biology"]:
		if kind!="all" and kind!=category:continue
		var source: Dictionary=world.crew.get("survey",{}) if category=="mineral" else world.ecology.observations
		for key in source:
			var row: Dictionary=source[key]
			if not body_id.is_empty() and row.body_id!=body_id:continue
			var title: String=FrontierCatalog.entry("resources",row.resource).name if category=="mineral" else FrontierEcologyCatalog.form(row.form_id).name
			if not needle.is_empty() and not title.to_lower().contains(needle):continue
			entries.append({"key":category+":"+str(key),"kind":category,"row":row.duplicate(true),"name":title,"icon":row.resource if category=="mineral" else FrontierResourceIcons.specimen_id(FrontierEcologyCatalog.form(row.form_id))})
	entries.sort_custom(func(a,b):return a.key<b.key if a.name==b.name else a.name.naturalnocasecmp_to(b.name)<0)
	var index:=clampi(page_index,0,maxi(0,(entries.size()-1)/PAGE_SIZE))
	return {"entries":entries.slice(index*PAGE_SIZE,(index+1)*PAGE_SIZE),"total":entries.size(),"page":index}
