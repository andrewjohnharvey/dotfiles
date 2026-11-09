#!/usr/bin/env python3
"""Stream niri state and inexpensive system status to the Quickshell UI."""
import json, os, pathlib, selectors, socket, subprocess, sys, time

# Workspace IDs stay stable when niri renumbers the visible indices.
if len(sys.argv) == 3 and sys.argv[1] == "focus":
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(2)
        client.connect(os.environ["NIRI_SOCKET"])
        client.sendall((json.dumps({"Action": {"FocusWorkspace": {"reference": {"Id": int(sys.argv[2])}}}})+"\n").encode())
        reply = json.loads(client.makefile().readline())
        if "Err" in reply:
            print(reply["Err"], file=sys.stderr)
            sys.exit(1)
    sys.exit(0)

state = {'workspaces': [], 'title': '', 'volume': '', 'network': '', 'cpu': 0, 'memory': 0, 'battery': ''}
windows = {}
sel = selectors.DefaultSelector()
sock = None
buffer = b''
last_cpu = None

def command(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=1).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ''

def emit():
    focused = next((w for w in windows.values() if w.get('is_focused')), {})
    state['title'] = focused.get('title', '')
    print(json.dumps(state), flush=True)

def connect():
    global sock, buffer
    try:
        sock = socket.socket(socket.AF_UNIX)
        sock.connect(os.environ['NIRI_SOCKET'])
        sock.sendall(b'"EventStream"\n')
        sock.setblocking(False)
        sel.register(sock, selectors.EVENT_READ)
        buffer = b''
    except (OSError, KeyError):
        if sock: sock.close()
        sock = None

def event(e):
    if 'WorkspacesChanged' in e:
        state['workspaces'] = sorted(e['WorkspacesChanged']['workspaces'], key=lambda w: (w.get('output') or '', w['idx']))
    elif 'WorkspaceActivated' in e:
        change = e['WorkspaceActivated']
        target = next((w for w in state['workspaces'] if w['id'] == change['id']), {})
        for w in state['workspaces']:
            if w.get('output') == target.get('output'): w['is_active'] = w['id'] == change['id']
            if change.get('focused'): w['is_focused'] = w['id'] == change['id']
    elif 'WorkspaceUrgencyChanged' in e:
        for w in state['workspaces']:
            if w['id'] == e['WorkspaceUrgencyChanged']['id']: w['is_urgent'] = e['WorkspaceUrgencyChanged']['urgent']
    elif 'WindowsChanged' in e:
        windows.clear()
        windows.update({w['id']: w for w in e['WindowsChanged']['windows']})
    elif 'WindowOpenedOrChanged' in e:
        w = e['WindowOpenedOrChanged']['window']
        if w.get('is_focused'):
            for old in windows.values(): old['is_focused'] = False
        windows[w['id']] = w
    elif 'WindowClosed' in e:
        windows.pop(e['WindowClosed']['id'], None)
    elif 'WindowFocusChanged' in e:
        for w in windows.values(): w['is_focused'] = w['id'] == e['WindowFocusChanged']['id']

def status():
    global last_cpu
    values = list(map(int, pathlib.Path('/proc/stat').read_text().splitlines()[0].split()[1:]))
    # guest counters are already included in user/nice.
    total, idle = sum(values[:8]), values[3] + values[4]
    if last_cpu and total > last_cpu[0]:
        state['cpu'] = round(100 * (1 - (idle-last_cpu[1])/(total-last_cpu[0])))
    last_cpu = (total, idle)
    mem = {line.split(':')[0]: int(line.split()[1]) for line in pathlib.Path('/proc/meminfo').read_text().splitlines()}
    state['memory'] = round((mem['MemTotal']-mem['MemAvailable']) / 1048576, 1)
    v = command(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'])
    state['volume'] = 'MUTE' if 'MUTED' in v else (str(round(float(v.split()[1])*100))+'%' if v.startswith('Volume:') else '—')
    interfaces = pathlib.Path('/sys/class/net')
    active = [p.name for p in interfaces.iterdir() if p.name != 'lo' and (p/'operstate').read_text().strip() == 'up']
    state['network'] = ('WI-FI' if any((interfaces/n/'wireless').exists() for n in active) else 'ETH') if active else 'OFFLINE'
    state['battery'] = ''
    for p in pathlib.Path('/sys/class/power_supply').glob('*'):
        if (p/'type').read_text().strip() == 'Battery' and (p/'capacity').exists():
            state['battery'] = (p/'capacity').read_text().strip()+'%'
            break

next_status = 0
while True:
    if sock is None: connect()
    now = time.monotonic()
    if now >= next_status:
        try: status()
        except (OSError, ValueError, IndexError): pass
        emit()
        next_status = time.monotonic()+3
    for key, _ in sel.select(timeout=max(0, min(1, next_status-time.monotonic()))):
        try: data = key.fileobj.recv(65536)
        except OSError: data = b''
        if not data:
            sel.unregister(key.fileobj)
            key.fileobj.close()
            sock = None
            continue
        buffer += data
        while b'\n' in buffer:
            line, buffer = buffer.split(b'\n', 1)
            try: event(json.loads(line))
            except (ValueError, KeyError, TypeError): continue
        emit()
