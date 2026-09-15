extends SceneTree
func _initialize():run.call_deferred()
func run():
 var world:=FrontierWorldStore.new("/tmp/discovery-exhibits-play/world.json").read_state()
 if world.is_empty():quit(2);return
 var actor: String=world.crew.owner_id;var destination: String=world.location
 var wanted: Array=["shell_shelter","luminous_tidepool","submerged_recorder","singing_stones"];var found: Dictionary={};var sampled:=false
 world.business.bags[actor]={"iron":150,"stone":200,"copper":100,"ice":0,"crystal":0};world.business.credits=10000
 for ordinal in world.manifest.native_biota.planets.keys()+[8,22,35]:
  var n:=int(ordinal)
  if wanted.is_empty() and sampled:break
  var body:=FrontierUniverse.body(world.manifest,n)
  if not FrontierUniverse.landable(body) :continue
  var eligible:=false
  for key in wanted:
   if FrontierExplorationDiscoveries.eligible(body,FrontierExplorationDiscoveries.definition(key)):eligible=true
  if not eligible:continue
  var field:=FrontierTerrainField.new();field.configure(int(body.streams.terrain),[],24.,body.get("terrain_traits",{}))
  for poi in FrontierExplorationDiscoveries.nearby(body,field,Vector3.ZERO):
   if poi.template not in wanted:continue
   world.location=body.id;FrontierExplorationDiscoveries.scan(world,poi,actor)
   var record:=FrontierExplorationDiscoveries.progress(world,poi);record.stage=FrontierExplorationDiscoveries.definition(poi.template).stages.size();record.scanned_stage=record.stage;record.claimed=true
   found[poi.template]=body.id;wanted.erase(poi.template)
   if poi.template=="luminous_tidepool":
    var error:=FrontierExplorationDiscoveries._sample(world,actor,poi,record)
    if not error.is_empty():print("SAMPLE ERROR ",error)
    for key in world.business.bags[actor]:
     if FrontierDiscoveryUtilities.specimen_allowed(key):sampled=true
 if not sampled:
  for ordinal in world.manifest.native_biota.planets:
   var n:=int(ordinal)
   if sampled:break
   var body:=FrontierUniverse.body(world.manifest,n)
   if not FrontierUniverse.landable(body):continue
   var profile:=FrontierEcology.profile(body)
   if profile.origin=="sterile" or profile.environment not in ["wetland","marine","temperate"]:continue
   var record:=FrontierEcology.ensure_planet(world.ecology,body)
   for encounter in FrontierEcologyPlacement.candidates(body,record,Vector3.ZERO):
    var key: String=FrontierSpecimenItems.resource({"id":"fixture".sha256_text(),"source_body":body.id,"form_id":encounter.form_id,"look_id":encounter.look_id})
    if not FrontierDiscoveryUtilities.specimen_allowed(key):continue
    world.location=body.id;FrontierEcology.scan(world.ecology,body.id,encounter)
    sampled=FrontierSpecimenItems.collect(world,actor,encounter).is_empty()
    if sampled:break
 world.location=destination
 for key in FrontierDiscoveryUtilities.config().buildings:world.business.facility_research.erase(key)
 print("ACTUAL DISCOVERIES ",found," specimen ",sampled," missing ",wanted)
 if not wanted.is_empty() or not sampled:quit(1);return
 DirAccess.make_dir_recursive_absolute("/tmp/discovery-utilities-play")
 var store:=FrontierWorldStore.new("/tmp/discovery-utilities-play/world.json");var saved:=store.write(world);print("UTILITY FIXTURE ",saved," ",store.last_error)
 DirAccess.copy_absolute("/tmp/discovery-exhibits-play/profile.json","/tmp/discovery-utilities-play/profile.json")
 quit(0 if saved else 1)
