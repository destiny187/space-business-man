extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var samples: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/native-incidents/samples.json"))
 var fixtures: Dictionary={};var errors:=0
 var manifest: Dictionary=FrontierUniverse.new_world(71491).manifest
 for kind in samples:
  var body: Dictionary=samples[kind].body;var f:=FrontierExplorationIncidents.field(body)
  for x in range(-2,3):
   for z in range(-2,3):
    for row in FrontierExplorationIncidents.tile(body,f,Vector2i(x,z)):
     var created:=FrontierExplorationIncidents.create(row)
     var reason:=FrontierExplorationIncidents.validate({"manifest":manifest,"crew":{"members":{}},"incidents":{"version":1,"records":{FrontierExplorationIncidents.key(created):created}}})
     if not reason.is_empty():print("NATIVE_TILE_ERROR ",row.template," ",reason);errors+=1
     if FrontierNativeIncidents.role(row.template)==kind:fixtures[kind]={"row":row,"body":body};break
    if fixtures.has(kind):break
   if fixtures.has(kind):break
  print("NATIVE_NATURAL ",kind," ",fixtures.has(kind))
 var out:=FileAccess.open("/tmp/native-incidents/play.json",FileAccess.WRITE);out.store_string(JSON.stringify(fixtures))
 print("NATIVE_NATURAL_COUNT ",fixtures.size());quit(0 if fixtures.size()==5 and errors==0 else 1)
