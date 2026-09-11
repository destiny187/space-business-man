class_name FrontierSurfaceRecovery
extends RefCounted
## Read-only presentation of the saved regional environment and managed ecology plot.
static var rules: Dictionary={}
static func config() -> Dictionary:
 if rules.is_empty():rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_presence.json"))
 return rules
static func conditions(values: Dictionary) -> Dictionary:
 var temperature: float=values.get("temperature",20)
 var pressure: float=values.get("pressure",0)
 var water: float=values.get("water",0)
 var air:=smoothstep(.08,.6,pressure)*(1-smoothstep(1.8,3.5,pressure))
 var warmth:=smoothstep(-8,10,temperature)*(1-smoothstep(32,65,temperature))
 var clean:=1-smoothstep(12,60,float(values.get("toxicity",100)))
 var wet:=smoothstep(8,55,water)
 var biology:=clampf(float(values.get("ecology",0))/100.0,0,1)
 var soil:=smoothstep(5,55,float(values.get("soil",100)))
 var salt:=1-smoothstep(20,70,float(values.get("salinity",0)))
 var viable:=minf(air,minf(warmth,minf(clean,minf(soil,salt))))
 return {"grass":viable*wet*smoothstep(.08,.55,biology),"trees":viable*wet*smoothstep(.55,.95,biology),"wet":wet*air*smoothstep(0,6,temperature)*(1-smoothstep(65,100,temperature)),"life":biology*viable,"air":1-exp(-pressure/.65),"temperature":temperature,"water":water/100.0,"pressure":pressure}
static func weight(point: Vector3,center: Vector3,radius: float) -> float:
 return 1-smoothstep(radius*.65,radius,Vector2(point.x-center.x,point.z-center.z).length())
static func region(body: Dictionary,ledger: Dictionary) -> Dictionary:
 var site: Dictionary=ledger.get("sites",{}).get(body.id,{})
 if site.is_empty():return {}
 var values: Dictionary=site.environment.duplicate(true)
 for key in ["soil","salinity"]:
  if site.get("restoration2",{}).has(key):values[key]=site.restoration2[key]
 return {"center":FrontierCrewWorld.vector(site.center),"radius":float(FrontierExpeditionBusiness.config().build_radius),"state":conditions(values),"environment":site.environment.duplicate(true)}

static func regions(body: Dictionary,ledger: Dictionary) -> Array:
 var site: Dictionary=ledger.get("sites",{}).get(body.id,{})
 if FrontierFreeTerraform.active(site):return FrontierFreeTerraform.visual_regions(site)
 if not FrontierRegionalTerraform.enabled(site):
  var old:=region(body,ledger);return [] if old.is_empty() else [old]
 var result: Array=[]
 for zone in site.regions.values():
  for cell in zone.cells:
   var values: Dictionary=cell.environment.duplicate()
   values.merge(cell.restoration2,true)
   values.toxicity=maxf(float(values.get("toxicity",0)),minf(100,float(cell.get("pollution",0))))
   result.append({"center":FrontierCrewWorld.vector(cell.position),"radius":38.0 if zone.cells.size()>1 else float(zone.radius),"state":conditions(values),"environment":cell.environment,"restoration2":cell.restoration2,"pollution":float(cell.get("pollution",0))})
 return result
static func sample_at(body: Dictionary,ledger: Dictionary,position: Vector3) -> Dictionary:
 var site: Dictionary=ledger.get("sites",{}).get(body.id,{})
 if FrontierFreeTerraform.active(site):
  var cell:=FrontierFreeTerraform.sample(site,Vector2(position.x,position.z));var values: Dictionary=cell.environment.duplicate();values.merge(cell.restoration2,true);return values
 return sample_regions(body,regions(body,ledger),position)
static func sample_regions(body: Dictionary,areas: Array,position: Vector3) -> Dictionary:
 var source: Dictionary=body.get("traits",{}).duplicate();source.ecology=0.0
 var best:=0.0
 for area in areas:
  var w:=weight(position,area.center,area.radius)
  if w<=best:continue
  best=w
  for key in area.environment:source[key]=lerpf(float(body.get("traits",{}).get(key,0)),float(area.environment[key]),w)
  for key in ["soil","salinity"]:source[key]=float(area.get("restoration2",{}).get(key,100 if key=="soil" else 0))
 return source
static func nearest_region(body: Dictionary,ledger: Dictionary,position: Vector3) -> Dictionary:
 var site: Dictionary=ledger.get("sites",{}).get(body.id,{})
 if not FrontierRegionalTerraform.enabled(site):return region(body,ledger)
 if FrontierFreeTerraform.active(site):
  var e:=sample_at(body,ledger,position);return {"center":position,"radius":float(site.free_terraform.rules.cell_size),"state":conditions(e),"environment":e,"id":FrontierFreeTerraform.key_at(site,Vector2(position.x,position.z))}
 var zone: Dictionary=site.regions[FrontierRegionalTerraform.region_id(site,position)]
 var values: Dictionary=zone.environment.duplicate();values.merge(zone.get("restoration2",{}),true)
 return {"center":FrontierCrewWorld.vector(zone.center),"radius":float(zone.radius),"state":conditions(values),"environment":zone.environment,"id":zone.id}
static func shader_regions(material: ShaderMaterial,body: Dictionary,ledger: Dictionary) -> void:
 var source: Dictionary=ledger.get("sites",{}).get(body.id,{})
 preload("res://scripts/world/terraform_surface_material.gd").bind(material,body,source)
 if FrontierFreeTerraform.active(source):FrontierFreeTerraform.shader(material,body,source);return
 material.set_shader_parameter("free_enabled",false)
 var areas: Array=regions(body,ledger) if FrontierRegionalTerraform.enabled(source) else []
 var points:=PackedVector4Array();var values:=PackedVector4Array();var extras:=PackedVector4Array()
 for area in areas:
  points.append(Vector4(area.center.x,area.center.y,area.center.z,area.radius))
  values.append(Vector4(float(area.environment.temperature),float(area.state.life),float(area.state.water),float(area.environment.pressure)))
  extras.append(Vector4(float(area.get("restoration2",{}).get("salinity",0))/100,float(area.get("restoration2",{}).get("soil",0))/100,float(area.environment.ecology)/100,clampf(float(area.get("pollution",0))/60,0,1)))
 var count:=points.size()
 while points.size()<20:points.append(Vector4.ZERO);values.append(Vector4.ZERO);extras.append(Vector4.ZERO)
 material.set_shader_parameter("region_count",count);material.set_shader_parameter("region_points",points);material.set_shader_parameter("region_values",values);material.set_shader_parameter("region_extras",extras)
