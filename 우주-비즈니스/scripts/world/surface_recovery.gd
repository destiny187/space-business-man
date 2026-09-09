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
