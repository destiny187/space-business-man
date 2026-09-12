class_name FrontierProductionPlan
extends RefCounted
## Read-only recipe expansion. One stock pool and one surplus pool for the whole order.
static func facility_cost(kind: String,from_tier: int) -> Dictionary:
 var result: Dictionary={}
 if from_tier==0:FrontierExpeditionBusiness.transfer(result,FrontierCatalog.entry("buildings",kind).get("cost",{}),1)
 if kind=="source_control":return result
 for tier in range(maxi(1,from_tier),3):
  FrontierExpeditionBusiness.transfer(result,FrontierProductionTier2.upgrade_definition({"type":kind,"tier":tier}).get("cost",{}),1)
 return result
static func estimate(cost: Dictionary,stock: Dictionary={}) -> Dictionary:
 var state: Dictionary={"available":stock.duplicate(true),"initial":stock.duplicate(true),"used":{},"raw":{},"steps":{},"order":[],"error":""}
 for id in cost:require_item(str(id),int(cost[id]),state,[])
 var steps: Array=[]
 for id in state.order:
  var recipe:=FrontierProductionTier2.product(id);var row: Dictionary=state.steps[id]
  row.id=id;row.role=str(recipe.get("supply_role",""));row.factory_tier=int(recipe.get("factory_tier",1));row.amount=int(recipe.amount)*int(row.batches);row.cost=FrontierProductionTier2.batch_cost(recipe,int(row.batches))
  steps.append(row)
 return {"cost":cost.duplicate(true),"used":state.used,"raw":state.raw,"steps":steps,"surplus":state.available,"error":state.error}
static func require_item(id: String,amount: int,state: Dictionary,trail: Array) -> void:
 if amount<=0 or not str(state.error).is_empty():return
 var used:=mini(amount,int(state.available.get(id,0)))
 state.available[id]=int(state.available.get(id,0))-used;amount-=used
 var owned:=mini(used,int(state.initial.get(id,0)))
 if owned>0:state.initial[id]-=owned;state.used[id]=int(state.used.get(id,0))+owned
 if amount==0:return
 var recipe:=FrontierProductionTier2.product(id)
 if recipe.is_empty():state.raw[id]=int(state.raw.get(id,0))+amount;return
 if id in trail:state.error="제작 경로가 순환합니다: "+id;return
 var batches:=ceili(float(amount)/float(recipe.amount));var next:=trail.duplicate();next.append(id)
 for input in recipe.cost:require_item(str(input),int(recipe.cost[input])*batches,state,next)
 if not state.steps.has(id):state.steps[id]={"batches":0};state.order.append(id)
 state.steps[id].batches+=batches
 state.available[id]=int(state.available.get(id,0))+int(recipe.amount)*batches-amount
