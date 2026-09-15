extends Node3D
## Match the local landing silhouettes in a host's non-rendered remote world.
const Collision=preload("res://scripts/world/vessel_ground_collision.gd")
var terrain: FrontierTerrainStreamer
var ship: Node3D
var refits: FrontierVesselVisuals
var signature:=""
var shuttles: Dictionary={}
var base_clearance:=0.0
func configure(source: FrontierTerrainStreamer) -> void:
	terrain=source;terrain.collision_gate=ready
	ship=load("res://assets/models/ships/kestrel.glb").instantiate();add_child(ship)
	for mesh in ship.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB=ship.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		base_clearance=maxf(base_clearance,-bounds.position.y)
	ship.position=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	var spawn:=FrontierCrewWorld.vector(FrontierCrewSurface.config().landing_spawn_positions[0])+Vector3(-4,0,0)
	ship.rotation.y=atan2(spawn.x-ship.position.x,spawn.z-ship.position.z)
	refits=FrontierVesselVisuals.new();ship.add_child(refits)
func sync(world: Dictionary,actor: String) -> void:
	var local:=FrontierShuttles.context(world,actor)
	var mother:=not local.has("local_shuttle")
	refits.update_loadout(world.get("vessel",{}) if mother else {"hull":"finch"})
	if refits.requested_hull.is_empty() and refits.requested.is_empty():
		var next:=refits.hull_id+":"+refits.signature
		if next!=signature:
			var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_arrival.json"))
			ship.position.y=terrain.field.height(ship.position.x,ship.position.z)+float(cfg.clearance.get(refits.hull_id,base_clearance))
			Collision.install(ship);signature=next
	var fleet:=FrontierShuttles.fleet(world)
	for id in shuttles.keys():
		if not mother or not fleet.has(id) or not FrontierShuttles.deployed(fleet[id],local.location):
			shuttles[id].queue_free();shuttles.erase(id)
	if not mother:return
	for id in fleet:
		if not FrontierShuttles.deployed(fleet[id],local.location):continue
		if not shuttles.has(id):
			var model: Node3D=load(FrontierShuttles.config().model).instantiate();add_child(model);Collision.install(model);shuttles[id]=model
		var deployment: Dictionary=fleet[id].deployment
		var ready: bool=float(world.crew.navigation.orbit_time)-float(deployment.time)>=float(FrontierShuttles.config().deployment_seconds)
		shuttles[id].position=FrontierCrewWorld.vector(deployment.position);shuttles[id].rotation.y=float(deployment.yaw)
		shuttles[id].get_node("GroundHullCollision").collision_layer=1 if ready else 0

func ready() -> bool:
	return refits!=null and refits.requested_hull.is_empty() and refits.requested.is_empty() and signature==refits.hull_id+":"+refits.signature
