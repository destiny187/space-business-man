extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var original:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--original="):original=arg.trim_prefix("--original=")
 assert(not original.is_empty())
 var legacy:=GDScript.new();legacy.source_code=FileAccess.get_file_as_string(original).replace("class_name FrontierTerrainField\n","")
 var error:=legacy.reload();assert(error==OK)
 var rules:=FrontierPlanetTraits.rules();var seen:=0;var compared:=0
 for id in rules.archetypes:
  var traits: Dictionary=rules.archetypes[id].duplicate(true)
  if not traits.has("terrain_layout"):continue
  var older: Dictionary=traits.duplicate(true);older.terrain_layout.erase("landscape")
  var a=legacy.new();a.configure(71503,[],24,older)
  var b:=FrontierTerrainField.new();b.configure(71503,[],24,older)
  var c:=FrontierTerrainField.new();c.configure(71503,[],24,traits)
  var d:=FrontierTerrainField.new();d.configure(71503,[],24,JSON.parse_string(JSON.stringify(traits)))
  var changed:=0
  for i in 160:
   var x: float=(i*71%1700)-850+.125;var z: float=(i*139%1700)-850+.375
   assert(a.height(x,z)==b.height(x,z),id+" legacy height changed")
   assert(c.height(x,z)==d.height(x,z) and is_finite(c.height(x,z)),id+" new height does not reproduce")
   if absf(c.height(x,z)-b.height(x,z))>.5:changed+=1
   compared+=1
  assert(changed>30,id+" lacks a distinct macro shape")
  for point in [Vector2.ZERO,Vector2(-30,20),Vector2(60,40)]:assert(c.height(point.x,point.y)==b.height(point.x,point.y),id+" changed the protected landing area")
  var point:=Vector3(330,c.height(330,370),370)
  assert(c.density(point+Vector3.UP)<0 and c.density(point-Vector3.UP)>0,id+" density disagrees with surface")
  c.add_edit({"center":[point.x,point.y,point.z],"radius":3.0})
  assert(c.density(point-Vector3.UP)<0,id+" excavation failed")
  seen+=1
 print("LANDSCAPE_CHECK ",seen," families; ",compared," exact legacy/serialized probes; landing/density/excavation preserved")
 quit()
