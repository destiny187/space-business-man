extends RefCounted
## Pure projection: reading/visiting never advances stock or grants a second delivery.
static var _config:Dictionary={}
static func config()->Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/station_economy.json"))
 return _config
static func epoch(world:Dictionary)->int:
 return floori(float(world.crew.navigation.orbit_time)/float(config().cycle_seconds))
static func project(world:Dictionary,station:Dictionary,base:Dictionary)->Dictionary:
 var result:Dictionary=base.duplicate(true)
 result.stock=world.get("station_markets",{}).get(station.id,base.stock).duplicate()
 var current:=epoch(world)
 # Unvisited markets have full base stock. Legacy inventories are anchored at session start.
 var elapsed:=maxi(0,current-int(world.get("station_market_epochs",{}).get(station.id,current)))
 var goods:Array=[]
 for id in base.stock:
  if str(id).begins_with("hull:"):continue
  goods.append(str(id))
  var target:=mini(int(base.stock[id]),int(base.get("capacities",{}).get(id,FrontierSpaceStation.config().max_stock)))
  var step:=maxi(1,ceili(target*float(config().restock_fraction)))
  var difference:=target-int(result.stock[id])
  result.stock[id]=int(result.stock[id])+signi(difference)*mini(absi(difference),step*elapsed)
 goods.sort()
 result.demand="" if goods.is_empty() else str(goods[(int(station.seed)+current)%goods.size()])
 if not result.demand.is_empty():result.prices[result.demand]=maxi(1,roundi(float(base.prices[result.demand])*float(config().demand_multiplier)))
 result.base_stock=base.stock
 result.market_epoch=current
 result.cycle_seconds=int(config().cycle_seconds)
 result.refresh_seconds=ceili(float(config().cycle_seconds)-fmod(float(world.crew.navigation.orbit_time),float(config().cycle_seconds)))
 return result
static func commit(world:Dictionary,id:String,offers:Dictionary)->void:
 if not world.has("station_markets"):world.station_markets={}
 if not world.has("station_market_epochs"):world.station_market_epochs={}
 world.station_markets[id]=offers.stock
 world.station_market_epochs[id]=int(offers.market_epoch)
static func validate(world:Dictionary)->String:
 var clocks:Variant=world.get("station_market_epochs",{})
 if not clocks is Dictionary or clocks.size()>125002:return "정거장 갱신 시계 구조 오류"
 for id in clocks:
  if not id is String or not world.get("station_markets",{}).has(id) or not FrontierExpeditionBusiness.integer(clocks[id],0,epoch(world)):return "정거장 갱신 시계 오류"
 return ""

static func ensure(world:Dictionary)->void:
 var markets:Dictionary=world.get("station_markets",{})
 if markets.is_empty():return
 if not world.has("station_market_epochs"):world.station_market_epochs={}
 if not world.station_market_epochs is Dictionary:return # Validation reports malformed data.
 for id in markets:
  if not world.station_market_epochs.has(id):world.station_market_epochs[id]=epoch(world)
