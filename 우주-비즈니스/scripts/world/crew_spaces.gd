class_name FrontierCrewSpaces
extends RefCounted
## Host collision worlds for crew on other planets. Rendering is disabled; each planet owns its terrain.
var app: FrontierCrewExpedition
var spaces: Dictionary={}
func configure(owner_app: FrontierCrewExpedition) -> void:app=owner_app
func sync() -> void:
	if not app.session.hosting or app.session.latest.is_empty():return
	var world: Dictionary=app.session.authority.world
	var own:=FrontierShuttles.area_key(world,app.session.latest.self_id)
	var needed: Dictionary={}
	for peer in app.session.authority.peers:
		var id: String=app.session.authority.peers[peer]
		if not app.actors.has(id):continue
		var key:=FrontierShuttles.area_key(world,id)
		var actor: CharacterBody3D=app.actors[id]
		if key==own:
			if actor.get_parent()!=app:actor.reparent(app,false)
			continue
		needed[key]=true
		if not spaces.has(key):
			var viewport:=SubViewport.new();viewport.size=Vector2i(16,16);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;app.add_child(viewport)
			var stage:=Node3D.new();viewport.add_child(stage)
			var entry: Dictionary={"viewport":viewport,"root":stage,"terrain":null,"edits":0,"business":null,"wildlife":{}}
			if key.begins_with("surface:"):
				var body_id:=key.trim_prefix("surface:");var body:=FrontierUniverse.body_from_id(world.manifest,body_id)
				var material:=ShaderMaterial.new();material.shader=load("res://assets/materials/space/terrain.gdshader")
				var terrain:=FrontierTerrainStreamer.new();terrain.configure(int(body.streams.terrain),world.terrain_edits.get(body_id,[]),material,world.terrain_settings,body.get("terrain_traits",{}));stage.add_child(terrain)
				entry.terrain=terrain;entry.edits=world.terrain_edits.get(body_id,[]).size()
				var business:=FrontierBusinessSiteView.new();stage.add_child(business);business.configure(terrain,body);business.accept(world.get("business",{}));entry.business=business
			spaces[key]=entry
		if actor.get_parent()!=spaces[key].root:actor.reparent(spaces[key].root,false)
	for key in spaces.keys():
		if not needed.has(key):
			for node in spaces[key].root.get_children():
				if node is CharacterBody3D:node.reparent(app,false)
			spaces[key].viewport.queue_free();spaces.erase(key);continue
		var entry: Dictionary=spaces[key]
		if entry.terrain==null:continue
		var body_id:=str(key).trim_prefix("surface:")
		var edits: Array=world.terrain_edits.get(body_id,[])
		if entry.edits<edits.size() and entry.terrain.batch.is_empty():
			var edit: Dictionary=edits[entry.edits]
			entry.terrain.dig(FrontierCrewWorld.vector(edit.center),float(edit.radius));entry.edits+=1
		var points: Array[Vector3]=[]
		for peer in app.session.authority.peers:
			var id: String=app.session.authority.peers[peer]
			if FrontierShuttles.area_key(world,id)==key and app.actors.has(id):points.append(app.actors[id].position)
		entry.terrain.update_interests(points)
		entry.business.accept(world.get("business",{}))
		_sync_wildlife(entry,world,body_id)
func terrain_for(actor: String) -> FrontierTerrainStreamer:
	var key:=FrontierShuttles.area_key(app.session.authority.world,actor)
	if spaces.has(key):return spaces[key].terrain
	return app.surface_world.terrain if app.surface_world!=null else null

func terrain_for_body(body_id: String) -> FrontierTerrainStreamer:
	var key: String="surface:"+body_id
	if spaces.has(key):return spaces[key].terrain
	return app.surface_world.terrain if app.surface_world!=null and app.surface_world.body.id==body_id else null
func root_for_body(body_id: String) -> Node3D:
	return spaces["surface:"+body_id].root if spaces.has("surface:"+body_id) else app

func _sync_wildlife(entry: Dictionary,world: Dictionary,body_id: String) -> void:
	var retained: Dictionary={}
	for row in world.crew.get("wildlife_encounters",{}).values():
		if row.body_id!=body_id:continue
		retained[row.encounter_id]=true
		if not entry.wildlife.has(row.encounter_id):
			var solid:=AnimatableBody3D.new();solid.sync_to_physics=false;solid.set_meta("encounter_id",row.encounter_id)
			var shape:=CapsuleShape3D.new();var profile:=FrontierWildlifeCombat.profile(row)
			shape.radius=minf(profile.radius,profile.height*.5);shape.height=profile.height
			var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=profile.height*.5
			solid.add_child(collision);entry.root.add_child(solid);entry.wildlife[row.encounter_id]=solid
		entry.wildlife[row.encounter_id].position=FrontierWildlifeCombat.body_position(row)
	for id in entry.wildlife.keys():
		if not retained.has(id):entry.wildlife[id].queue_free();entry.wildlife.erase(id)
