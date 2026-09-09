class_name FrontierVesselVisuals
extends Node3D
## Async loading keeps newly equipped GLBs off the networking frame.
var signature: String=""
var requested: Dictionary={}
var installed: Dictionary={}
var installed_paths: Dictionary={}
var cache: Dictionary={}
var flight_mode:=false
var landing_override: Dictionary={}
var gear: FrontierLandingGear
func _ready() -> void:
	gear=FrontierLandingGear.new();add_child(gear);gear.configure(get_parent())
	gear.deployment=0.0 if flight_mode else 1.0;gear.hatch=gear.deployment
	gear.present(1,flight_mode,landing_override)
var hull_id: String="kestrel"
var hull_node: Node3D
var requested_hull: String=""
func update_loadout(vessel: Dictionary) -> void:
	var next_hull: String=vessel.get("hull","kestrel")
	if next_hull!=hull_id:
		hull_id=next_hull;requested_hull=FrontierShuttles.config().model if hull_id=="finch" else ("res://assets/models/ships/kestrel.glb" if hull_id=="kestrel" else FrontierSpaceStation.config().hulls[hull_id].model)
		ResourceLoader.load_threaded_request(requested_hull)
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
	gear.present(_delta,flight_mode,landing_override)
	if not requested_hull.is_empty() and ResourceLoader.load_threaded_get_status(requested_hull)==ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene=ResourceLoader.load_threaded_get(requested_hull)
		if is_instance_valid(hull_node):hull_node.queue_free()
		hull_node=scene.instantiate();FrontierInkStyle.apply(hull_node,cache);add_child(hull_node)
		for child in get_parent().get_children():
			if child!=self and not child is FrontierVesselDriveEffects:_hide_base(child)
		for child in get_parent().get_children():
			if child is FrontierVesselDriveEffects:child.set_finch(hull_id=="finch")
		gear.refresh();gear.present(1,flight_mode,landing_override)
		requested_hull=""
	for slot in requested.keys():
		var path: String=requested[slot];var state:=ResourceLoader.load_threaded_get_status(path)
		if state==ResourceLoader.THREAD_LOAD_FAILED or state==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:push_error("Vessel module load failed: "+path);requested.erase(slot);continue
		if state!=ResourceLoader.THREAD_LOAD_LOADED:continue
		var scene: PackedScene=ResourceLoader.load_threaded_get(path)
		var node: Node3D=scene.instantiate();node.name=slot;node.position=FrontierCrewWorld.vector(FrontierVesselRefit.config().mounts[slot]);FrontierInkStyle.apply(node,cache);add_child(node);installed[slot]=node;installed_paths[slot]=path;requested.erase(slot);break

func _hide_base(node: Node) -> void:
	if node is GeometryInstance3D:node.hide()
	for child in node.get_children():_hide_base(child)
