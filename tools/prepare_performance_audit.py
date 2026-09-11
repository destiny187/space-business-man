#!/usr/bin/env python3
"""Create an instrumented temporary Godot project; never patch production scripts.
Run the generated project with --crew-ui-test and the printed --crew-folder.
The fixture must be an isolated world.json/profile.json pair from the benchmark.
"""
from pathlib import Path
import argparse
import json
import re
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture', type=Path, default=Path('/tmp/performance-audit-20260909'))
    parser.add_argument('--output', type=Path, default=Path('/tmp/performance-deep-audit-20260909'))
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    source = repo / '우주-비즈니스'
    output = args.output.resolve()
    if output == args.fixture.resolve() or output == source or source in output.parents:
        parser.error('Output must be outside the game project and separate from the fixture.')
    for name in ('world.json', 'profile.json'):
        if not (args.fixture / name).is_file():
            parser.error(f'Missing isolated fixture: {args.fixture / name}')
    project = output / 'project'
    project.mkdir(parents=True, exist_ok=True)
    for name in ('scripts', 'scenes', 'data', 'tests'):
        shutil.copytree(source / name, project / name, dirs_exist_ok=True)
    shutil.copy2(source / 'project.godot', project / 'project.godot')
    # Reuse large assets/import caches. Only scripts/data/scenes are private copies.
    for name in ('assets', '.godot'):
        target = project / name
        if not target.exists():
            target.symlink_to(source / name, target_is_directory=True)
    for name in ('world.json', 'profile.json'):
        shutil.copy2(args.fixture / name, output / name)
    world = json.loads((output / 'world.json').read_text())
    for member in world['crew']['members'].values():
        member['position'] = [0, 4, 0]
    (output / 'world.json').write_text(json.dumps(world))
    templates = repo / 'tools/performance_audit'
    shutil.copy2(templates / 'counters.gd', project / 'tests/perf_counters.gd')
    runner = (templates / 'run.gd').read_text().replace(
        'const OUT="/tmp/performance-deep-audit-20260909"', 'const OUT=' + json.dumps(str(output)))
    (project / 'tests/audit_current_bottlenecks.gd').write_text(runner)
    count = 0
    for path in (project / 'scripts').rglob('*.gd'):
        text = path.read_text()
        indent = '\t' if '\n\t' in text else ' '
        wrappers = []
        for method in ('_process', '_physics_process'):
            if not re.search(r'^func ' + method + r'\(', text, re.M):
                continue
            renamed = '_audit_' + method.strip('_') + '_' + path.stem
            text = re.sub(r'^func ' + method + r'\(', 'func ' + renamed + '(', text, flags=re.M)
            wrapper = f'''
func {method}(_audit_delta: float) -> void:
 var recorder=preload("res://tests/perf_counters.gd")
 if not recorder.active:
  {renamed}(_audit_delta);return
 recorder.begin()
 var started:=Time.get_ticks_usec()
 {renamed}(_audit_delta)
 recorder.finish("res://{path.relative_to(project)}","{method}",Time.get_ticks_usec()-started)
'''
            if indent == '\t':
                wrapper = re.sub(r'^( +)', lambda m: '\t' * len(m[1]), wrapper, flags=re.M)
            wrappers.append(wrapper)
            count += 1
        if wrappers:
            path.write_text(text + '\n'.join(wrappers))
    path = project / 'scripts/domain/stellar_routes.gd'
    text = re.sub(r'(static func build\([^\n]+\) -> void:\n)',
                  r'\1 if preload("res://tests/perf_counters.gd").skip_routes:return\n',
                  path.read_text(), count=1)
    path.write_text(text)
    path = project / 'scripts/app/crew_flight_view.gd'
    text = path.read_text()
    calls = [
        'orbit_clock+=delta;update_orbits(orbit_clock)',
        'transit_overlay.guidance=FrontierSpaceGuidance.read(state.manifest,navigation,camera,Vector2(get_viewport().get_visible_rect().size))',
        'orbital_presentation.update(delta,orbit_clock)',
        '_update_galactic_core()',
        'soundscape.update(delta,scan_target>=0 and scan_progress<1.0,scan_progress)',
    ]
    for i, line in enumerate(calls):
        text = text.replace('\t' + line + '\n', f'\tvar _probe_t{i}:=Time.get_ticks_usec()\n\t' + line + f'\n\tpreload("res://tests/perf_counters.gd").record_extra("flight_part_{i}",Time.get_ticks_usec()-_probe_t{i})\n', 1)
    path.write_text(text)
    for relative, method, arguments, passed, result_type, label in [
        ('scripts/persistence/world_store.gd', 'write', 'state: Dictionary', 'state', 'bool', 'world_store.write'),
        ('scripts/persistence/world_store.gd', '_read', 'candidate: String', 'candidate', 'Dictionary', 'world_store._read'),
        ('scripts/network/crew_authority.gd', 'snapshot', 'viewer: int=1,shared: Dictionary={}', 'viewer,shared', 'Dictionary', 'authority.snapshot'),
    ]:
        path = project / relative
        text = path.read_text().replace('func ' + method + '(', 'func _audit_core_' + method + '(', 1)
        text += f'''
func {method}({arguments}) -> {result_type}:
\tvar started:=Time.get_ticks_usec()
\tvar result: {result_type}=_audit_core_{method}({passed})
\tpreload("res://tests/perf_counters.gd").record_extra("{label}",Time.get_ticks_usec()-started)
\treturn result
'''
        path.write_text(text)
    for method in ('_apply_snapshot', '_surface_packet'):
        path = project / 'scripts/app/crew_expedition.gd'
        text = path.read_text().replace('func ' + method + '(', 'func _audit_core' + method + '(', 1)
        text += f'''
func {method}(value: Dictionary) -> void:
\tvar started:=Time.get_ticks_usec()
\t_audit_core{method}(value)
\tpreload("res://tests/perf_counters.gd").record_extra("app.{method}",Time.get_ticks_usec()-started)
'''
        path.write_text(text)
    print(f'Instrumented {count} callbacks in {project}')
    print(f'Godot arguments: --path {project} --script res://tests/audit_current_bottlenecks.gd -- --crew-ui-test --crew-folder={output}')
    print('Append --targeted to measure only the specific background-work probes.')


if __name__ == '__main__':
    main()
