extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures+=1;printerr("FAIL "+label)
 else:print("PASS "+label)
func run() -> void:
 var world:=FrontierWorldStore.new("/tmp/playtest-field-research/world.json").read_state()
 if world.is_empty():quit(2);return
 var actor: String=world.crew.owner_id
 var row: Dictionary={"id":"fixture:salt","body_id":world.location,"template":"salt_bloom","position":[0,0,0],"yaw":0.0}
 var stock: Dictionary=world.business.bags[actor].duplicate(true)
 var member: Dictionary=world.crew.members[actor].duplicate(true)
 FrontierExplorationDiscoveries.scan(world,row,actor)
 var result:=FrontierExplorationDiscoveries.result(world,row)
 check(FrontierExplorationDiscoveries.stage(world,row)==2 and result.action=="조사 완료","salt bloom completes on scan with no redundant F reward steps")
 check(world.business.bags[actor]==stock and world.crew.members[actor]==member,"catalogue scan grants neither minerals nor modules")
 check(FrontierExplorationDiscoveries.progress(world,row).discoverer==actor,"journal retains discoverer and location")
 FrontierExplorationDiscoveries.scan(world,row,actor)
 check(world.business.bags[actor]==stock,"repeat scan cannot reward")
 var definitions: Dictionary=FrontierExplorationDiscoveries.config().items
 check(definitions.values().all(func(d):return not d.get("catalogue_only",false) or d.reward.is_empty()),"natural discoveries have no material reward")
 check(not definitions.submerged_recorder.reward.is_empty() and definitions.lost_technology_archive.mode=="archive","physical salvage and blueprint recovery retained")
 print("CATALOGUE_REWARDS failures ",failures);quit(1 if failures else 0)
