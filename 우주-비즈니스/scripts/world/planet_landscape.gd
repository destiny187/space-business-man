extends RefCounted
## Versioned macro shapes. Worker-local state; existing worlds never opt in implicitly.
var rules: Dictionary={}
var noise:=FastNoiseLite.new()
var seed_value:=0
var sites: Dictionary={}
var mode:=""
var height:=0.0
var span:=600.0
var retained_roughness:=.15
func configure(seed_number: int,definition: Dictionary) -> void:
 rules=definition;seed_value=seed_number;mode=str(rules.mode)
 height=float(rules.height);span=float(rules.scale);retained_roughness=float(rules.roughness)
 noise.seed=FrontierUniverse.derive(seed_number,"landscape-v1")
 noise.frequency=1.0/span;noise.fractal_octaves=2
 sites.clear()
func site_at(x: float,z: float) -> Vector4:
 var key:=Vector2i(floori(x/span),floori(z/span))
 if sites.has(key):return sites[key]
 var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(seed_value,"landmark-v1:%d:%d"%[key.x,key.y])
 var site:=Vector4((key.x+rng.randf_range(.35,.65))*span,(key.y+rng.randf_range(.35,.65))*span,span*rng.randf_range(.18,.23),rng.randf_range(.85,1.15))
 if sites.size()>=128:sites.erase(sites.keys()[0])
 sites[key]=site
 return site
func apply(rough: float,x: float,z: float) -> float:
 var distance:=Vector2(x,z).length()
 if distance<=110.0:return rough
 var n: float=noise.get_noise_2d(x,z) if mode in ["mesa","shelves","crevasse"] else 0.0
 var value:=rough*retained_roughness
 match mode:
  "mesa","shelves":
   var amount: float=(n+.35)*height*2.0
   var step_height: float=rules.step
   var level:=floorf(amount/step_height)
   var fraction:=amount/step_height-level
   value+=(level+smoothstep(.66,.94,fraction))*step_height-height*.45
  "rolling":
   var aspect: float=rules.get("aspect",1.0)
   value+=noise.get_noise_2d(x/aspect,z*aspect)*height
  "crevasse":
   value+=height*.30-(1.0-smoothstep(.018,.085,absf(n)))*height
  "impact","basin","volcanic","spire","karst":
   var site:=site_at(x,z)
   var d:=Vector2(x-site.x,z-site.y).length()/site.z
   if d<1.45:
    var inside:=1.0-smoothstep(.30,.95,d)
    var rim:=1.0-smoothstep(.0,.22,absf(d-1.0))
    match mode:
     "impact":value=lerpf(value,0.0,inside*.8)-inside*height*site.w+rim*float(rules.rim)
     "basin":value=lerpf(value,-height*site.w,inside)+rim*float(rules.rim)
     "volcanic":value+=pow(maxf(0.0,1.0-d/1.45),1.2)*height*site.w-(1.0-smoothstep(.08,.34,d))*height*.58
     "spire":value+=pow(maxf(0.0,1.0-d),2.8)*height*site.w
     "karst":value+=(1.0-smoothstep(.35,1.0,d))*height*site.w-(1.0-smoothstep(.12,.33,d))*height*.7
 return lerpf(rough,value,smoothstep(110.0,200.0,distance))
