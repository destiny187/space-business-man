from pathlib import Path
import json,subprocess
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/game-overview';WORK=OUT/'work';CLIPS=WORK/'edit';CLIPS.mkdir(parents=True,exist_ok=True)
FF=imageio_ffmpeg.get_ffmpeg_exe()
def run(args):subprocess.run([FF,'-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)
records={}
for source in ['space','field','robot','cave']:
    records[source]=json.loads((WORK/source/'segments.json').read_text())
records['basic']=json.loads((ROOT/'output/gameplay-reel/work/segments.json').read_text())
# Source footage contains longer takes. Keep the action within each representative segment.
plan=[
 ('space','earth_sol_start',0,195,'지구·Sol에서 새 원정 시작'),
 ('space','galaxy_route',10,60,'은하 지도와 항로'),
 ('space','stellar_departure',185,105,'항성계 사이 이동'),
 ('space','landing',185,90,'행성 진입·하강'),
 ('basic','walk_and_mine',120,90,'직접 자원 채집'),
 ('cave','cave_entrance_0',15,90,'동굴 입구 탐사'),
 ('basic','place_and_inspect',65,90,'시설 배치와 건설'),
 ('robot','factory_production',25,90,'제작소 생산'),
 ('robot','robot_mining',45,120,'로봇 자동 채광'),
 ('robot','restored_industry',25,90,'환경 설비·복원 현장'),
 ('robot','terraform_map',15,60,'테라포밍 분포 지도'),
 ('field','rover_drive',10,90,'로버 주행'),
 ('basic','encounter_and_scan',105,90,'생물 스캔과 발견'),
 ('field','coopertech_encounter',60,90,'쿠퍼테크 전투로봇 교전'),
 ('space','ship_augmentation',50,90,'선내 신체 증강'),
 ('space','planet_approach',20,60,'다음 행성으로 이어지는 항해'),
]
assert sum(item[3] for item in plan)==1500
assert records['space']['evidence']['augmentation']==1 and records['space']['evidence']['landed']
assert sum(records['robot']['evidence']['robot_cargo'].values())>0,records['robot']['evidence']
manifest=[];paths=[];cursor=0
for index,(source,label,offset,length,description) in enumerate(plan):
    segment=next(s for s in records[source]['segments'] if s['id']==label)
    start=segment['start_frame']+offset
    assert start+length<=segment['end_frame'],(source,label)
    raw=(ROOT/'output/gameplay-reel/work/gameplay-raw.avi') if source=='basic' else WORK/source/'raw.avi'
    clip=CLIPS/f'{index:02d}.mp4'
    run(['-ss',f'{start/30:.9f}','-i',raw,'-t',f'{length/30:.9f}','-frames:v',length,
         '-map','0:v:0','-map','0:a:0','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',
         '-r','30','-fps_mode','cfr','-c:a','aac','-b:a','192k','-ar','48000','-ac','2',clip])
    paths.append(clip)
    manifest.append({'start_seconds':cursor/30,'seconds':length/30,'content':description,'source':source,'take':label,'source_start_frame':start})
    cursor+=length
    print('EDIT',index+1,len(plan),description,flush=True)
listing=CLIPS/'concat.txt';listing.write_text(''.join("file '"+str(p)+"'\n" for p in paths))
output=OUT/'game-overview-50s.mp4'
run(['-f','concat','-safe','0','-i',listing,'-t','50','-c:v','copy','-c:a','aac','-b:a','192k','-ar','48000',
     '-af','afade=t=in:d=0.06,afade=t=out:st=49.8:d=0.2','-movflags','+faststart',output])
run(['-ss','0.7','-i',output,'-frames:v','1',OUT/'preview.jpg'])
(OUT/'manifest.json').write_text(json.dumps({'duration_seconds':50,'resolution':[1280,800],'format':'PC 기본 가로 화면',
 'editing':'정상 속도 실제 게임 구간 컷 편집. 추가 제목·게임명·홍보 문구·자막·음악 없음. 원래 HUD·게임 소리 유지.',
 'scope':'새 원정 시작부터 현재 주요 콘텐츠를 16개 구간으로 요약. 모든 개별 아이템·티어·협동 상황을 열거한 영상은 아님.',
 'preparation':'사용자 저장과 분리한 임시 원정. 후반 장비·제작소·로봇·복원 상태는 촬영 전 준비한 진행 상태이며, 녹화 중 생산·채광·이동·조사·교전·증강은 현재 게임 실행 코드에서 처리했다. 50초 안에 이 성장이 모두 이루어진다는 의미는 아니다.',
 'timeline':manifest,'evidence':{key:value['evidence'] for key,value in records.items()}},ensure_ascii=False,indent=2)+'\n')
print('OVERVIEW_READY',output,flush=True)
