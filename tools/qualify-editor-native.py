"""Measure actual native host PTY output arrival, never terminal drawing."""
import argparse, fcntl, hashlib, json, math, os, pathlib, pty, select
import signal, statistics, subprocess, termios, time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--triptych', default='/Users/johnhardy/projects/triptych')
parser.add_argument('--disk', required=True)
parser.add_argument('--output', required=True)
parser.add_argument('--samples', type=int, default=30)
args = parser.parse_args()
assert 30 <= args.samples <= 60
master, slave = pty.openpty()
environment = dict(os.environ)
for key in ('TRIPTYCH_CPM22_IMAGE', 'TRIPTYCH_CPM_CCP', 'TRIPTYCH_CPM22_WORK_DISK_B', 'TRIPTYCH_CPM_BOOTSTRAP_PROFILE'):
    environment.pop(key, None)
environment['TRIPTYCH_CPM22_WORK_DISK'] = str(pathlib.Path(args.disk).resolve())
def setup():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
process = subprocess.Popen(['node', 'tools/run-cpm22-native.mjs'], cwd=args.triptych,
    stdin=slave, stdout=slave, stderr=slave, env=environment, preexec_fn=setup)
transcript = bytearray()
def until(marker, required=None):
    data = bytearray()
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if select.select([master], [], [], .01)[0]:
            value = os.read(master, 65536)
            data.extend(value)
            transcript.extend(value)
            if data.endswith(marker) and (required is None or required in data):
                return data
        if process.poll() is not None:
            raise RuntimeError('host exited: '+repr(data[-1000:]))
    raise TimeoutError(repr(data[-1000:]))
try:
    until(b'\r\nA>')
    os.write(master, b'EDIT INPUT.TXT\r')
    until(b'\x1b[1;1H', required=b'^Q Quit')
    samples = []
    for index in range(args.samples+1):
        key = bytes([120 if index == 0 else 97+(index-1)%26])
        start = time.monotonic_ns()
        os.write(master, key)
        output = until(f'\x1b[1;{index+2}H'.encode())
        samples.append({'key':key.decode(), 'outputArrivalMs':(time.monotonic_ns()-start)/1e6,
                        'terminalBytes':len(output), 'outputSha256':hashlib.sha256(output).hexdigest()})
    cold, warm = samples[0], samples[1:]
    values = sorted(s['outputArrivalMs'] for s in warm)
    report = {'format':'edit-native-pty-qualification-v1',
        'boundary':'monotonic clock immediately before PTY input write through receipt of final ANSI cursor-position bytes; excludes terminal drawing',
        'diskSha256':hashlib.sha256(pathlib.Path(args.disk).read_bytes()).hexdigest(),
        'hostSha256':hashlib.sha256((pathlib.Path(args.triptych)/'target/debug/triptych-host-native').read_bytes()).hexdigest(),
        'cold':cold, 'samples':warm, 'summary':{'medianMs':statistics.median(values), 'p95Ms':values[math.ceil(len(values)*.95)-1]}}
    pathlib.Path(args.output).write_text(json.dumps(report,indent=2)+'\n')
    pathlib.Path(args.output+'.ansi').write_bytes(transcript)
    print(json.dumps(report['summary']))
finally:
    if process.poll() is None:
        os.killpg(process.pid,signal.SIGTERM)
        process.wait(timeout=10)
    os.close(master)
    os.close(slave)
