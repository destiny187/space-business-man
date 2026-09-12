extends SceneTree
const Draft=preload("res://scripts/persistence/world_draft.gd")
const Snapshot=preload("res://scripts/persistence/world_snapshot.gd")
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func incident(body_id: String,at: Array,mode: String) -> Dictionary:
 var template:=""
 for id in FrontierExplorationIncidents.config().items:
  if FrontierExplorationIncidents.definition(id).mode==mode:template=id;break
 return FrontierExplorationIncidents.create({"id":"scope:"+mode,"template":template,"body_id":body_id,"position":at.duplicate(),"relay":at.duplicate(),"battery_position":at.duplicate(),"yaw":0.0,"tier":2,"path":[]})
func timings(world: Dictionary,actor: String) -> Dictionary:
 var result: Dictionary={}
 for kind in ["full","equipment","weather","incidents"]:
  var samples: Array=[]
  for i in 5:
   var start:=Time.get_ticks_usec();var draft: Dictionary
   match kind:
    "full":draft=Snapshot.copy(world)
    "equipment":draft=Draft.request(world,actor,"equipment_select")
    "weather":draft=Draft.weather(world,[actor])
    "incidents":draft=Draft.incidents(world,[actor])
   samples.append((Time.get_ticks_usec()-start)/1000.0)
   if draft.is_empty():failures+=1
  samples.sort();result[kind]=samples[2]
 return result
func run() -> void:
 var source_folder:="";var folder:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source-folder="):source_folder=arg.trim_prefix("--source-folder=")
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if source_folder.is_empty() or folder.is_empty() or source_folder==folder:quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var store:=FrontierWorldStore.new(source_folder+"/world.json")
 var source:=store.read_state();source.manifest=Snapshot.own_manifest(source.manifest)
 var actor: String=source.crew.owner_id;var body_id: String=source.location
 source.crew.members[actor].aboard=false;source.crew.members[actor].area="surface"
 source.weather=FrontierPlanetWeather.create()
 var body:=FrontierUniverse.body_from_id(source.manifest,body_id)
 FrontierPlanetWeather.ensure_planet(source,body).next_rain=0.0
 source.weather.planets.foreign={"marker":[1,2,3]}
 var at: Array=source.crew.members[actor].position
 var row:=incident(body_id,at,"seismic");row.phase="quake";row.time=100.0
 var foreign:=incident("foreign",at,"robot");foreign.carrier="disconnected"
 source.incidents={"version":1,"records":{"active":row,"foreign":foreign}}
 source.terrain_edits[body_id]=[{"center":at.duplicate(),"radius":1.0}]
 var cover_id: String=FrontierCombatCover.config().buildings.keys()[0]
 var cover: Dictionary={"type":cover_id,"position":at.duplicate()};FrontierCombatCover.create(cover,0.0)
 source.business.sites[body_id].buildings["scope_cover"]=cover
 source.business.sites["foreign"]={"inventory":{"stone":42},"buildings":{}}
 source.surface_water[body_id]={"cells":{"one":{"volume":1.0}}}
 source.ecology.planets[body_id].plot={"center":at.duplicate(),"environment":FrontierEcologyCatalog.config().habitats.keys()[0],"age_seconds":0.0,"biomass":0.0,"support_remaining":100.0}
 var original:=Snapshot.copy(source)
 Snapshot._freeze(source)
 var weather:=Draft.weather(source,[actor]);var full:=Snapshot.copy(source)
 var presence: Dictionary={};var full_presence: Dictionary={}
 var changed:=FrontierPlanetWeather.tick(weather,.25,[actor],Callable(),Callable(),presence)
 var full_changed:=FrontierPlanetWeather.tick(full,.25,[actor],Callable(),Callable(),full_presence)
 check(changed==full_changed and weather==full and presence==full_presence,"scoped weather matches full draft including no-save clock progress")
 FrontierPlanetWeather.hurt(weather,actor,100000,true)
 check(weather.crew.members[actor]!=source.crew.members[actor] and source==original,"weather damage and rescue leave original world intact")
 var events:=Draft.incidents(source,[actor]);full=Snapshot.copy(source)
 changed=FrontierExplorationIncidents.tick(events,.25,[actor]);full_changed=FrontierExplorationIncidents.tick(full,.25,[actor])
 check(changed==full_changed and events==full,"scoped incident tick matches full draft")
 check(events.terrain_edits[body_id].size()==10 and events.incidents.records.active.materialized,"seismic event opens actual terrain in candidate")
 check(events.incidents.records.foreign.carrier.is_empty() and source.incidents.records.foreign.carrier=="disconnected","foreign disconnected carrier drops only in candidate")
 FrontierCombatCover.damage({"row":events.business.sites[body_id].buildings.scope_cover},15.0)
 FrontierExplorationIncidents.hurt(events,actor,100000)
 check(events.business.sites[body_id].buildings.scope_cover.cover_hp<cover.cover_hp and source==original,"incident cover damage and rescue preserve original world")
 check(is_same(events.ecology,source.ecology) and is_same(events.business.sites.foreign,source.business.sites.foreign),"unrelated ecology and industry are shared read-only")
 var water:=Draft.water(events,[actor]);water.surface_water[body_id].cells.one.volume=2.0;water.business.sites[body_id].base_submerged=true
 var plots:=Draft.plots(water,[body_id]);FrontierEcology.advance(plots.ecology,body_id,1.0)
 check(source==original and plots.ecology.planets[body_id].plot.age_seconds==1.0,"later water flooding and plot updates preserve rollback baseline")
 var gear:=Draft.request(source,actor,"equipment_select")
 check(FrontierEquipment.apply(gear,actor,"equipment_select",{"slot":1}).is_empty(),"scoped equipment accepts selection")
 gear.crew.receipts["scope"]={"result":{"ok":true}}
 check(source==original and is_same(gear.ecology,source.ecology) and is_same(gear.terrain_edits,source.terrain_edits),"equipment and receipt changes stay isolated from unrelated domains")
 var unknown:=Draft.request(source,actor,"unrecognized")
 check(not is_same(unknown.ecology,source.ecology),"unknown requests retain full independent draft")
 # Unrelated history must not multiply the cost of a quarter-second local draft.
 var small:=timings(source,actor);var large:=Snapshot.copy(source)
 large.ecology["scope_history"]=[]
 for i in 10000:large.ecology.scope_history.append({"id":i,"samples":[1,2,3,4],"label":"unrelated"})
 var expanded:=timings(large,actor)
 var metrics: Dictionary={"small_median_ms":small,"unrelated_10000_median_ms":expanded,"failures":failures}
 print("WORLD_DRAFTS ",JSON.stringify(metrics))
 var file:=FileAccess.open(folder+"/draft-metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
 quit(1 if failures else 0)
