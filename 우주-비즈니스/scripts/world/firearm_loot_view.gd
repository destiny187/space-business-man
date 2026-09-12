class_name FrontierFirearmLootView
extends RefCounted
## Reuses the exact seeded reward roll; the host commits inventory only on F recovery.
static func update(view: FrontierIncidentView,nodes: Dictionary,row: Dictionary) -> void:
	if not nodes.has("gun_loot"):
		var seed_value:=int(view.surface.session.manifest.get("seed",-1))
		if seed_value<0:return
		nodes.gun_loot=FrontierFirearms.loot(seed_value,row)
	if nodes.gun_loot.is_empty():return
	if not nodes.has("gun_model"):
		var definition: Dictionary=FrontierEquipment.config().items[nodes.gun_loot.definition]
		var path: String="res://assets/models/"+definition.model+".glb"
		if not view.requests.has(path):ResourceLoader.load_threaded_request(path);view.requests[path]=true
		if not view.scenes.has(path):
			if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:return
			view.scenes[path]=ResourceLoader.load_threaded_get(path)
		var model: Node3D=view.scenes[path].instantiate();nodes.cargo.add_child(model);model.position=Vector3(0,.85,0);model.rotation=Vector3(0,PI*.25,PI*.5)
		FrontierInkStyle.apply(model,view.materials);nodes.gun_model=model
		var color:=Color(str(FrontierFirearms.config().rarities[nodes.gun_loot.rarity].color))
		var signal_node:=view.beam(Vector3(0,.65,0),Vector3(0,1.8,0),Color(color,.5),.022,nodes.cargo);nodes.gun_signal=signal_node
	nodes.gun_model.visible=not row.claimed
	nodes.gun_signal.visible=not row.claimed
static func description(nodes: Dictionary) -> String:
	var reward: Dictionary=nodes.get("gun_loot",{})
	if reward.is_empty():return ""
	var definition: Dictionary=FrontierEquipment.config().items[reward.definition]
	return str(FrontierFirearms.config().rarities[reward.rarity].name)+" · "+str(definition.name)
