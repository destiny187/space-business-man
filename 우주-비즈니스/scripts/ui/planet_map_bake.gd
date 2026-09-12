extends RefCounted
## Owns its terrain/cache and CPU image. Scene nodes and textures stay on the main thread.
var field: FrontierTerrainField
var body: Dictionary
var map_min: Vector2
var map_size: Vector2
var key: String
var result: Image
func configure(source: FrontierTerrainField,planet: Dictionary,origin: Vector2,extent: Vector2,bake_key: String) -> void:
 field=FrontierTerrainField.new()
 field.configure(source.seed_value,[],source.span,source.traits)
 body={"kind":planet.kind,"traits":planet.get("traits",{}).duplicate(true)}
 map_min=origin;map_size=extent;key=bake_key
func run() -> void:
 result=bake()
func bake() -> Image:
 var width:=160;var height:=100
 var image:=Image.create(width,height,false,Image.FORMAT_RGBA8)
 for z in height:
  for x in width:
   var point:=map_min+Vector2(float(x)/width,float(z)/height)*map_size
   var h:=field.height(point.x,point.y)
   var relief:=clampf((field.height(point.x+12,point.y)-h)*.035+(field.height(point.x,point.y+12)-h)*.02,-.25,.25)
   var color:=Color("596051").lerp(Color("ad9d79"),clampf((h+30)/180,0,1))
   if body.kind=="glacial":color=Color("607f91").lerp(Color("bed5d5"),clampf((h+40)/180,0,1))
   if body.kind=="sulfur":color=Color("665947").lerp(Color("a89054"),clampf((h+40)/180,0,1))
   color=color.lightened(relief) if relief>0 else color.darkened(-relief)
   var contour:=fposmod(h,20.0)
   if contour<.75:color=color.darkened(.20)
   if h< -3.9 and float(body.get("traits",{}).get("water",0))>15 and float(body.get("traits",{}).get("temperature",-100))>0:color=Color("28545b")
   if maxf(absf(point.x),absf(point.y))>8192:color=Color("10191f")
   image.set_pixel(x,z,color)
 return image
