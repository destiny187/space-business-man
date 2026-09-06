class_name FrontierVesselVisuals
extends Node3D
## Async loading keeps newly equipped GLBs off the networking frame.
var signature: String=""
var requested: Dictionary={}
var installed: Dictionary={}
var installed_paths: Dictionary={}
var cache: Dictionary={}
func update_loadout(vessel: Dictionary) -> void:
	var desired: Dictionary={}
	for slot in vessel.get("loadout",{}):
		var id: String=vessel.loadout[slot]
		if not id.is_empty():desired[slot]="res://assets/models/"+FrontierVesselRefit.definition(vessel.modules[id].type).model+".glb"
	var next:=FrontierUniverse.fingerprint(desired)
	if next==signature:return
	signature=next;requested.clear()
	for slot in installed.keys():
		if desired.get(slot)==installed_paths[slot]:continue
		installed[slot].queue_free();installed.erase(slot);installed_paths.erase(slot)
	for slot in desired:
		if installed.has(slot):continue
		requested[slot]=desired[slot];ResourceLoader.load_threaded_request(desired[slot])
func _process(_delta: float) -> void:
	for slot in requested.keys():
		var path: String=requested[slot];var state:=ResourceLoader.load_threaded_get_status(path)
		if state==ResourceLoader.THREAD_LOAD_FAILED or state==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:push_error("Vessel module load failed: "+path);requested.erase(slot);continue
		if state!=ResourceLoader.THREAD_LOAD_LOADED:continue
		var scene: PackedScene=ResourceLoader.load_threaded_get(path)
		var node: Node3D=scene.instantiate();node.name=slot;node.position=FrontierCrewWorld.vector(FrontierVesselRefit.config().mounts[slot]);FrontierInkStyle.apply(node,cache);add_child(node);installed[slot]=node;installed_paths[slot]=path;requested.erase(slot);break
