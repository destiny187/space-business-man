"""Edit the authored ElevenLabs cartoon tone into a compact contact warning.
Requires numpy. Original four takes remain unmodified in audio/source/elevenlabs/.
"""
from pathlib import Path
import hashlib,json,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'audio/source/elevenlabs/pirate-contact-cartoon/take-02.wav'
with wave.open(str(source)) as w:
 rate=w.getframerate();a=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,w.getnchannels()).mean(axis=1)/32768
# Keep the springy electronic onset, remove its long tail and give danger a clear rhythm.
result=np.zeros(round(rate*.96))
for offset,start,length,pitch,gain in [(0,0,.32,1,1),(.43,.025,.17,1.06,.84),(.70,.025,.17,1.06,.84)]:
 fragment=a[round(start*rate):round((start+length)*rate)]
 fragment=np.interp(np.arange(0,len(fragment)-1,pitch),np.arange(len(fragment)),fragment)
 attack=min(round(rate*.008),len(fragment)//2);release=min(round(rate*.045),len(fragment)//2)
 fragment[:attack]*=np.linspace(0,1,attack);fragment[-release:]*=np.linspace(1,0,release)
 at=round(offset*rate);result[at:at+len(fragment)]+=fragment*gain
result-=result.mean();result*=.63/max(abs(result).max(),.001)
out=ROOT/'우주-비즈니스/assets/audio/sfx_pirate_contact_warning.wav'
with wave.open(str(out),'wb') as w:
 w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes((result*32767).astype('<i2').tobytes())
print(json.dumps({'file':str(out),'seconds':len(result)/rate,'channels':1,'rate':rate,'peak':float(abs(result).max()),'rms':float(np.sqrt(np.mean(result*result))),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()},indent=2))
