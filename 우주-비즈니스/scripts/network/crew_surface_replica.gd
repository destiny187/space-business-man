class_name FrontierCrewSurfaceReplica
extends RefCounted
## Current planet and local ecology deltas only. No full galaxy/history in movement snapshots.
static func packet(world: Dictionary,actor: String) -> Dictionary:
	if not FrontierCrewSurface.landed(world):return {}
	var id: String=world.crew.landing.body_id
	var source: Dictionary=world.ecology.planets[id]
	var position:=FrontierCrewWorld.vector(world.crew.members[actor].position)
	var record: Dictionary={"profile":source.profile.duplicate(true),"lineages":source.lineages.duplicate(true),"plot":source.plot.duplicate(true),"collected":{},"introductions":{}}
	var span: float=FrontierEcologyCatalog.config().cell_span
	var anchor:=Vector2i(floori(position.x/span),floori(position.z/span))
	var extent:=ceili(float(FrontierEcologyCatalog.config().active_radius)/span)+2
	for x in range(anchor.x-extent,anchor.x+extent+1):
		for z in range(anchor.y-extent,anchor.y+extent+1):
			for layer in ["surface","cave"]:
				for slot in 2:
					var key: String="%s:%d:%d:%d"%[layer,x,z,slot]
					if source.collected.has(key):record.collected[key]=source.collected[key]
	for key in source.introductions:
		if FrontierCrewWorld.vector(source.introductions[key].position).distance_to(position)<float(FrontierEcologyCatalog.config().active_radius)+span*2:record.introductions[key]=source.introductions[key].duplicate(true)
	var observations: Dictionary={}
	for row in source.lineages:
		var key: String=id+":"+row.form_id
		if world.ecology.observations.has(key):observations[key]=world.ecology.observations[key].duplicate(true)
	for row in record.introductions.values():
		var key: String=id+":"+row.form_id
		if world.ecology.observations.has(key):observations[key]=world.ecology.observations[key].duplicate(true)
	var cargo: Dictionary={}
	for key in world.ecology.specimens:
		var sample: Dictionary=world.ecology.specimens[key]
		if sample.state!="cargo":continue
		cargo[key]=sample.duplicate(true)
		var observation: String=sample.source_body+":"+sample.form_id
		if world.ecology.observations.has(observation):observations[observation]=world.ecology.observations[observation].duplicate(true)
	return {"water":FrontierSurfaceWater.packet(world.get("surface_water",{}).get(id,FrontierSurfaceWater.create()),position),"sky_region":world.get("celestial_regions",{}).get(id,{}).duplicate(true),"engineering":world.get("engineering",FrontierFieldEngineering.create()).duplicate(true),"business":FrontierExpeditionBusiness.public_view(world,actor),"version":1,"body_id":id,"epoch":world.crew.landing.epoch,"terrain_settings":world.terrain_settings.duplicate(true),"terrain_settings_hash":world.terrain_settings_hash,
		"edits":world.terrain_edits.get(id,[]).duplicate(true),"rules_hash":world.ecology.rules_hash,"catalog_hash":world.ecology.catalog_hash,
		"ecology":{"planets":{id:record},"observations":observations,"research":world.ecology.research.duplicate(true),"specimens":cargo}}

static func validate(value: Variant,manifest: Dictionary) -> bool:
	if not value is Dictionary or not FrontierSurfaceWater.valid(value.get("water",FrontierSurfaceWater.create()),int(FrontierSurfaceWater.config().snapshot_cells)):return false
	if not value is Dictionary or value.get("version")!=1 or not value.get("body_id") is String or FrontierUniverse.ordinal_of(manifest,value.body_id)<0:return false
	if not FrontierUniverse._finite(value.get("epoch"),1,9007199254740000):return false
	if FrontierPlanetaryCycles.enabled(manifest) and not FrontierPlanetaryCycles.valid_region(value.get("sky_region")):return false
	if value.get("rules_hash")!=FrontierUniverse.fingerprint(FrontierEcologyCatalog.config()) or value.get("catalog_hash")!=FrontierEcologyCatalog.signature():return false
	if not value.get("edits") is Array or value.edits.size()>int(FrontierCrewSurface.config().maximum_edits_per_planet):return false
	var terrain_world: Dictionary={"manifest":manifest,"terrain_edits":{value.body_id:value.edits},"terrain_settings":value.get("terrain_settings"),"terrain_settings_hash":value.get("terrain_settings_hash")}
	if not FrontierUniverse._validate_terrain(terrain_world).is_empty():return false
	var ecology: Variant=value.get("ecology")
	if not ecology is Dictionary:return false
	for key in ["planets","observations","research","specimens"]:
		if not ecology.get(key) is Dictionary:return false
	if ecology.planets.size()!=1 or not ecology.planets.has(value.body_id) or ecology.specimens.size()>int(FrontierEcologyCatalog.config().cargo_capacity) or ecology.research.size()>11 or ecology.observations.size()>80:return false
	var record: Variant=ecology.planets[value.body_id]
	if not record is Dictionary:return false
	for key in ["profile","plot","collected","introductions"]:
		if not record.get(key) is Dictionary:return false
	var expected:=FrontierEcology.ensure_planet({"planets":{}},FrontierUniverse.body_from_id(manifest,value.body_id))
	if FrontierUniverse.fingerprint(record.profile)!=FrontierUniverse.fingerprint(expected.profile) or record.get("lineages")!=expected.lineages:return false
	if record.collected.size()>400 or record.introductions.size()>600:return false
	for key in record.collected:
		if not key is String or not record.collected[key] is String or record.collected[key].length()!=64:return false
		if FrontierEcologyPlacement.resolve_identity(FrontierUniverse.body_from_id(manifest,value.body_id),expected,key).is_empty():return false
	if not record.plot.is_empty():
		var plot: Dictionary=record.plot
		if plot.get("environment") not in [record.profile.environment,"cave"] or not FrontierUniverse._vector3_array(plot.get("center")) or not FrontierUniverse._finite(plot.get("biomass"),0,100) or not FrontierUniverse._finite(plot.get("age_seconds"),0,1000000) or not FrontierUniverse._finite(plot.get("support_remaining"),0,float(FrontierEcologyCatalog.config().plot_support_seconds)):return false
	for row in record.introductions.values():
		if not row is Dictionary or not FrontierEcology._identity_valid(row) or not row.get("id") is String or not FrontierUniverse._vector3_array(row.get("position")) or row.get("layer") not in ["surface","cave"]:return false
	for row in ecology.observations.values():
		if not row is Dictionary or not FrontierEcology._identity_valid(row) or not row.get("body_id") is String or FrontierUniverse.ordinal_of(manifest,row.body_id)<0:return false
	for key in ecology.research:
		var row: Variant=ecology.research[key]
		if not row is Dictionary or not row.get("form_id") is String or row.get("stage")!="analyzed" or FrontierEcologyCatalog.form(row.form_id).get("environment")!=key:return false
	for key in ecology.specimens:
		var row: Variant=ecology.specimens[key]
		if not row is Dictionary or not FrontierEcology._identity_valid(row) or row.get("state")!="cargo" or row.get("id")!=key or not row.get("source_body") is String or not row.get("source_encounter") is String:return false
		if FrontierUniverse.ordinal_of(manifest,row.source_body)<0 or key!=(row.source_body+":"+row.source_encounter).sha256_text():return false
	if value.has("business") and (not value.business is Dictionary or (not value.business.is_empty() and not FrontierExpeditionBusiness.validate(value.business,manifest).is_empty())):return false
	if value.has("engineering") and not FrontierFieldEngineering.validate(value.engineering,manifest).is_empty():return false
	for site in value.get("business",{}).get("sites",{}).values():
		for b in site.buildings.values():
			if not b.get("engineering","").is_empty() and value.get("engineering",{}).get("projects",{}).get(b.engineering,{}).get("stage")!="certified":return false
	return true

static func encode(value: Dictionary) -> PackedByteArray:
	var raw:=JSON.stringify(value).to_utf8_buffer()
	if raw.size()>int(FrontierCrewSurface.config().maximum_packet_bytes):return PackedByteArray()
	var encoded:=raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return encoded if encoded.size()<=int(FrontierCrewSurface.config().maximum_compressed_bytes) else PackedByteArray()
static func decode(data: PackedByteArray,manifest: Dictionary) -> Dictionary:
	if data.is_empty() or data.size()>int(FrontierCrewSurface.config().maximum_compressed_bytes):return {}
	var raw:=data.decompress_dynamic(int(FrontierCrewSurface.config().maximum_packet_bytes),FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():return {}
	var value: Variant=JSON.parse_string(raw.get_string_from_utf8())
	return value if validate(value,manifest) else {}
