"""Compile the item dump, run it in one private test world and collect the result. Windows only: the world is staged with junctions.

The world is staged the way the isolated test harness does it: source folders are junctions into the checkout, except icons/map_icons, which is
copied because a booting world rewrites it. Junctions are removed one at a time, before anything else in the world folder is deleted. Only the
DreamDaemon this started is ever stopped, by PID. A reserved port, or any port in use, is refused.

The dump needs the unit test harness, because the uncreatables list lives there and that is what boots the world and ends the round, so
it compiles with -DCIBUILDING -DGEAR_CATALOG_DUMP. A build without that define never opens voidcrew/modules/unit_tests/gear_catalog_dump.dm.

If a kept world dies part way, data/gear_catalog/current.txt in it names the type it died on. Start dd.exe in that folder again and the dump carries
on from done.txt, recording that type as an error.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

NO_WINDOW = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
LINKED = ['_maps', 'code', 'html', 'interface', 'lua', 'sound', 'strings', 'tgui', 'voidcrew']
LIBRARIES = ['rust_g.dll', 'dreamluau.dll']
# Reserved ports: other servers use these.
RESERVED_PORTS = {1342, 1337, 2599}
DME = 'gear_catalog_dump'


def find_tool(name):
    """dm or dd: from BYOND_PATH, then PATH, then the standard install folder.

    A folder only counts if it holds both, because Git for Windows puts its own dd.exe, the disk copier, on PATH.
    """
    exe = f'{name}.exe'
    candidates = []
    byond_path = os.environ.get('BYOND_PATH')
    if byond_path:
        candidates += [Path(byond_path) / 'bin', Path(byond_path)]
    for tool in ['dm.exe', exe]:
        found = shutil.which(tool)
        if found:
            candidates.append(Path(found).parent)
    for program_files in ['ProgramFiles(x86)', 'ProgramFiles']:
        folder = os.environ.get(program_files)
        if folder:
            candidates.append(Path(folder) / 'BYOND' / 'bin')
    for folder in candidates:
        if (folder / 'dm.exe').is_file() and (folder / 'dd.exe').is_file():
            return str(folder / exe)
    sys.exit(f"Can't find {exe}. Set BYOND_PATH to your BYOND folder, or put its bin folder on PATH.")


def run(*cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, errors='replace', creationflags=NO_WINDOW, **kw)


def port_in_use(port):
    out = run('netstat', '-ano').stdout
    return any(f':{port} ' in line and 'LISTENING' in line for line in out.splitlines())


def is_link(path):
    return path.is_junction() or path.is_symlink()


def remove_build_files(checkout):
    for ext in ['.dme', '.dmb', '.rsc', '.dyn.rsc', '.lk', '.int']:
        (checkout / f'{DME}{ext}').unlink(missing_ok=True)


def compile_dump(checkout, dm):
    dme = checkout / f'{DME}.dme'
    shutil.copyfile(checkout / 'tgstation.dme', dme)
    started = time.time()
    result = run(dm, '-DCBT', '-DCIBUILDING', '-DGEAR_CATALOG_DUMP', str(dme), cwd=checkout)
    print(result.stdout[-1500:], flush=True)
    dme.unlink(missing_ok=True)
    if ' 0 errors' not in result.stdout:
        remove_build_files(checkout)
        sys.exit('compile failed')
    return time.time() - started


def link(world_path, target):
    run('cmd', '/c', 'mklink', '/J', str(world_path), str(target))
    if not world_path.is_junction():
        sys.exit(f'junction failed: {world_path}')


def stage(checkout, world):
    if world.exists():
        sys.exit(f'{world} already exists; remove it with --clean first')
    world.mkdir(parents=True)
    for name in LINKED:
        link(world / name, checkout / name)
    (world / 'icons').mkdir()
    for folder in sorted((checkout / 'icons').iterdir()):
        if not folder.is_dir():
            continue
        if folder.name == 'map_icons':
            shutil.copytree(folder, world / 'icons' / folder.name)
        else:
            link(world / 'icons' / folder.name, folder)
    shutil.copytree(checkout / 'config', world / 'config')
    (world / 'data').mkdir()
    for name in LIBRARIES:
        shutil.copy2(checkout / name, world / name)
    for ext in ['.dmb', '.rsc']:
        shutil.move(str(checkout / f'{DME}{ext}'), str(world / f'{DME}{ext}'))
    remove_build_files(checkout)


def launch(world, port, dd):
    # Start-Process is the launch that works: a DreamDaemon attached to a shell can stall before world/New.
    command = (f"$p = Start-Process -FilePath '{dd}' -ArgumentList '{DME}.dmb','-port','{port}','-trusted','-close','-invisible' "
               f"-WorkingDirectory '{world}' -PassThru -WindowStyle Hidden; Write-Output $p.Id")
    result = run('powershell', '-NoProfile', '-NonInteractive', '-Command', command)
    return int(result.stdout.strip().splitlines()[-1])


def alive(pid):
    return f'"{pid}"' in run('tasklist', '/FI', f'PID eq {pid}', '/FO', 'CSV', '/NH').stdout


def last_line(path):
    if not path.exists():
        return ''
    with path.open('rb') as f:
        f.seek(0, os.SEEK_END)
        f.seek(max(0, f.tell() - 4096))
        tail = f.read().decode('utf-8', 'replace').strip().splitlines()
    return tail[-1] if tail else ''


def wait_for_dump(world, pid, boot_minutes, dump_minutes):
    output = world / 'data/gear_catalog/dump.jsonl'
    started = time.time()
    boot_seconds = None
    last = 0
    while True:
        time.sleep(20)
        waited = time.time() - started
        if output.exists() and boot_seconds is None:
            boot_seconds = waited
            print(f'dump started after {waited:.0f}s', flush=True)
        if last_line(output).startswith('{"summary"'):
            return boot_seconds, waited, True
        if not alive(pid):
            print('world exited before the summary row', flush=True)
            return boot_seconds, waited, False
        limit = (boot_minutes if boot_seconds is None else boot_minutes + dump_minutes) * 60
        if waited > limit:
            print('timed out', flush=True)
            return boot_seconds, waited, False
        if waited - last > 120:
            last = waited
            size = output.stat().st_size if output.exists() else 0
            print(f'{waited:.0f}s, dump file {size} bytes', flush=True)


def world_children(world):
    icons = world / 'icons'
    return list(world.iterdir()) + (list(icons.iterdir()) if icons.exists() else [])


def clean(world):
    """Junctions first, on their own. Everything left is a real file we own."""
    if not world.exists():
        return
    for path in [p for p in world_children(world) if is_link(p)]:
        os.rmdir(path)
    leftover = [p for p in world_children(world) if is_link(p)]
    if leftover:
        sys.exit(f'junctions remain, not deleting: {leftover}')
    shutil.rmtree(world)


def default_world(checkout):
    return checkout.parent / f'{checkout.name}-gear-catalog-world'


def dump(checkout, out, port=3311, world=None, keep=False, boot_minutes=30, dump_minutes=90):
    if os.name != 'nt':
        sys.exit('The dump step is Windows only: it stages its world with junctions. build and sheet run anywhere.')
    world = Path(world).resolve() if world else default_world(checkout)
    if port in RESERVED_PORTS:
        sys.exit(f'port {port} is reserved')
    if port_in_use(port):
        sys.exit(f'port {port} is in use')
    dm, dd = find_tool('dm'), find_tool('dd')

    compile_seconds = compile_dump(checkout, dm)
    stage(checkout, world)
    started = time.time()
    pid = launch(world, port, dd)
    print(f'world pid {pid} on port {port} in {world}', flush=True)
    boot, total, finished = wait_for_dump(world, pid, boot_minutes, dump_minutes)

    # The harness ends the round on its own once the test returns.
    deadline = time.time() + 180
    while alive(pid) and time.time() < deadline:
        time.sleep(5)
    if alive(pid):
        run('taskkill', '/PID', str(pid), '/F')
        print('stopped our own world by PID', flush=True)

    target = Path(out) / 'dump'
    target.mkdir(parents=True, exist_ok=True)
    produced = world / 'data/gear_catalog/dump.jsonl'
    if produced.exists():
        shutil.copy2(produced, target / 'dump.jsonl')
    logs = sorted((world / 'data/logs').rglob('runtime.log')) if (world / 'data/logs').exists() else []
    if logs:
        shutil.copy2(logs[-1], target / 'runtime.log')
    commit = run('git', '-C', str(checkout), 'rev-parse', 'HEAD').stdout.strip()
    summary = json.loads(last_line(target / 'dump.jsonl')) if finished else {}
    (target / 'run.json').write_text(json.dumps({
        'commit': commit,
        'finished': finished,
        'compile_seconds': round(compile_seconds),
        'boot_seconds': round(boot) if boot else None,
        'dump_seconds': summary.get('seconds'),
        'world_seconds': round(time.time() - started),
        'counts': summary.get('counts'),
    }, indent=1) + '\n', encoding='utf-8')
    if not keep:
        clean(world)
    print('done' if finished else 'NOT FINISHED', flush=True)
    return 0 if finished else 1
