extends RefCounted
static var active:=false
static var depth:=0
static var rows: Dictionary={}
static var spikes: Array=[]
static var frames: Dictionary={}
static func begin() -> void:depth+=1
static func finish(path: String,method: String,usec: int) -> void:
 depth-=1
 if depth>0:return
 var key:=path+":"+method
 if not rows.has(key):rows[key]={"path":path,"method":method,"usec":0,"calls":0,"max_usec":0}
 rows[key].usec+=usec;rows[key].calls+=1;rows[key].max_usec=maxi(rows[key].max_usec,usec)
 var frame:=Engine.get_process_frames();frames[frame]=int(frames.get(frame,0))+usec
 if usec>8000:spikes.append({"path":path,"method":method,"ms":usec/1000.0,"frame":frame})

static var skip_routes:=false
static var extra: Dictionary={}
static func record_extra(label: String,usec: int) -> void:
 if not active:return
 if not extra.has(label):extra[label]={"calls":0,"usec":0,"max_usec":0}
 extra[label].calls+=1;extra[label].usec+=usec;extra[label].max_usec=maxi(extra[label].max_usec,usec)
