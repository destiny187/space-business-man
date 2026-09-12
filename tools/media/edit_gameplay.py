"""Trim actual Godot Movie Maker gameplay, preserving its recorded game audio."""
from pathlib import Path
import json
import subprocess
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/gameplay-reel'
WORK=OUT/'work'
FF=imageio_ffmpeg.get_ffmpeg_exe()

def run(args):
    subprocess.run([FF,'-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)

def main():
    record=json.loads((WORK/'segments.json').read_text())
    segments=record['segments']
    assert len(segments)==4,segments
    assert record['evidence']['mining']['after']<record['evidence']['mining']['before'],record
    assert record['evidence']['building']['after']>record['evidence']['building']['before'],record
    assert record['evidence']['creature']['known_after'],record
    assert record['evidence']['sample']['after']>record['evidence']['sample']['before'],record
    # Frame indices come from the running scene tree; no camera or HUD overlays.
    inputs=['-i',WORK/'gameplay-raw.avi']
    filters=[];labels=[];total_frames=0
    for i,clip in enumerate(segments):
        start,end=clip['start_frame'],clip['end_frame']
        total_frames+=end-start
        filters += [f'[0:v]trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS[v{i}]',
                    f'[0:a]atrim=start={start/30:.6f}:end={end/30:.6f},asetpts=PTS-STARTPTS[a{i}]']
        labels += [f'[v{i}][a{i}]']
    duration=total_frames/30
    filters += [''.join(labels)+f'concat=n={len(segments)}:v=1:a=1[v][a]',
                f'[a]afade=t=in:d=0.06,afade=t=out:st={duration-.2}:d=0.2,alimiter=limit=0.89:level=false[aout]']
    output=OUT/'gameplay-50s.mp4'
    run(inputs+['-filter_complex',';'.join(filters),'-map','[v]','-map','[aout]',
                '-c:v','libx264','-crf',18,'-preset','medium','-profile:v','high','-level','4.1','-pix_fmt','yuv420p',
                '-c:a','aac','-b:a','192k','-ar',48000,'-movflags','+faststart',output])
    run(['-ss',5,'-i',output,'-frames:v',1,'-q:v',2,OUT/'preview.jpg'])
    (OUT/'manifest.json').write_text(json.dumps({
        'date':'2026-09-10','scope':'현재 crew_expedition.tscn 실제 플레이 녹화의 4개 구간 편집 — 채광·건설·생물 스캔·표본 채집·귀환',
        'title':'미표기 — 게임명은 가제','overlay':'없음; 원래 게임 HUD 유지',
        'frame':'PC 기본 가로 화면 1280×800; 크롭·확대·세로 재배치 없음',
        'audio':'Godot Movie Maker가 기록한 현장 효과음·환경음. 추가 음악·별도 효과음 없음.',
        'duration_seconds':duration,'capture_record':record,
        'setup':'독립 임시 원정에서 시작 위치·낮 시간·기초 소지 재료를 준비했다. 녹화 중 이동·채광·건설·조사는 실제 게임 입력과 호스트 승인으로 진행했다. 준비 과정과 구간 간 이동 대기는 편집에서 제외했다.',
        'previous_version':'이전 홍보 영상·표지·중간 프레임과 전용 제작 스크립트 삭제 완료'
    },ensure_ascii=False,indent=2)+'\n')
    print(f'GAMEPLAY_EXPORT {duration:.2f}s {output}',flush=True)

if __name__=='__main__':main()
