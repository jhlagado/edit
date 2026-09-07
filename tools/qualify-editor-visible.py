"""Dedicated Apple Terminal + native PTY + WindowServer frame-reference probe.

Requires existing capture/Terminal automation grants. Never requests permissions.
Build editor-window-capture.swift first, then pass --capture /absolute/helper.
"""
import argparse, ctypes, fcntl, hashlib, json, math, os, pathlib, pty, select
import shlex, signal, socket, statistics, subprocess, sys, termios, time
import platform, plistlib

lib = ctypes.CDLL('/usr/lib/libSystem.B.dylib')
lib.mach_absolute_time.restype = ctypes.c_uint64
class Timebase(ctypes.Structure):
    _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]
timebase = Timebase(); lib.mach_timebase_info(ctypes.byref(timebase))
ticks = lib.mach_absolute_time
def milliseconds(delta): return delta*timebase.numer/timebase.denom/1e6
def emit(channel, value): channel.write((json.dumps(value)+'\n').encode()); channel.flush()

def bridge(config_path):
    config = json.loads(pathlib.Path(config_path).read_text())
    saved_terminal = termios.tcgetattr(sys.stdout.fileno())
    active_terminal = termios.tcgetattr(sys.stdout.fileno())
    active_terminal[1] &= ~termios.OPOST
    termios.tcsetattr(sys.stdout.fileno(), termios.TCSANOW, active_terminal)
    listener = socket.socket(socket.AF_UNIX); listener.bind(config['socket']); listener.listen(1)
    connection, _ = listener.accept(); channel = connection.makefile('rwb')
    master, slave = pty.openpty()
    def setup(): os.setsid(); fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
    env = dict(os.environ)
    for key in ['TRIPTYCH_CPM22_IMAGE','TRIPTYCH_CPM_CCP','TRIPTYCH_CPM22_WORK_DISK_B','TRIPTYCH_CPM_BOOTSTRAP_PROFILE']: env.pop(key,None)
    env['TRIPTYCH_CPM22_WORK_DISK'] = config['disk']
    process = subprocess.Popen(['node','tools/run-cpm22-native.mjs'], cwd=config['triptych'], env=env,
        stdin=slave,stdout=slave,stderr=slave,preexec_fn=setup)
    def until(marker, required=None):
        data=bytearray(); deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            if select.select([master],[],[],.01)[0]:
                value=os.read(master,65536); data.extend(value)
                sys.stdout.buffer.write(value); sys.stdout.buffer.flush()
                if data.endswith(marker) and (required is None or required in data): return len(data)
            if process.poll() is not None: raise RuntimeError('native host exited')
        raise TimeoutError(repr(data[-1000:]))
    try:
        until(b'\r\nA>'); os.write(master,b'EDIT INPUT.TXT\r'); until(b'\x1b[1;1H', required=b'^Q Quit')
        emit(channel,{'ready':True,'nativePid':process.pid,'bridgePid':os.getpid()})
        for raw in channel:
            command=json.loads(raw)
            if command.get('stop'): break
            start=ticks(); os.write(master,command['key'].encode('ascii'))
            count=until(f"\x1b[1;{command['column']}H".encode())
            emit(channel,{'inputTicks':start,'ptyOutputTicks':ticks(),'terminalBytes':count})
    finally:
        if process.poll() is None: os.killpg(process.pid,signal.SIGTERM); process.wait(timeout=10)
        try: emit(channel,{'stopped':True,'nativeReturnCode':process.returncode})
        except (BrokenPipeError,OSError): pass
        os.close(master); os.close(slave); channel.close(); connection.close(); listener.close()
        termios.tcsetattr(sys.stdout.fileno(), termios.TCSANOW, saved_terminal)

def apple(script):
    return subprocess.check_output(['osascript','-e',script],text=True).strip()

def provenance(triptych,disk,capture,artifact=None):
    disk=pathlib.Path(disk).resolve(); triptych=pathlib.Path(triptych).resolve()
    if artifact is None:
        metadata=disk.parent/'private-disk-provenance.json'
        if metadata.exists(): artifact=json.loads(metadata.read_text()).get('artifactPath')
    code='''import {readFile} from "node:fs/promises"; import {pathToFileURL} from "node:url"; import {createHash} from "node:crypto";
const [root,diskPath,artifactPath]=process.argv.slice(1);const {readCpm22File}=await import(pathToFileURL(root+"/tools/lib/cpm22-disk.mjs"));
const value=readCpm22File(new Uint8Array(await readFile(diskPath)),"EDIT.COM");const bytes=Buffer.from(value.bytes??value);const hash=b=>createHash("sha256").update(b).digest("hex");
let result={physicalRecordsSha256:hash(bytes),physicalBytes:bytes.length};if(artifactPath){const a=JSON.parse(await readFile(artifactPath,"utf8"));const binary=Buffer.from(a.binaryBase64,"base64");if(hash(binary)!==a.sha256||!bytes.subarray(0,binary.length).equals(binary))throw Error("Private disk EDIT does not match requested frozen artifact");Object.assign(result,{artifactPath,sha256:a.sha256,bytes:binary.length});}console.log(JSON.stringify(result));'''
    editor=json.loads(subprocess.check_output(['node','--input-type=module','-e',code,str(triptych),str(disk),artifact or ''],text=True))
    digest=lambda path:hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()
    terminal=plistlib.loads(pathlib.Path('/System/Applications/Utilities/Terminal.app/Contents/Info.plist').read_bytes())
    return {'editor':editor,'diskSha256':digest(disk),'nativeHostSha256':digest(triptych/'target/debug/triptych-host-native'),
        'captureHelperSha256':digest(capture),'qualifierSha256':digest(__file__),
        'triptychHead':subprocess.check_output(['git','rev-parse','HEAD'],cwd=triptych,text=True).strip(),
        'terminalVersion':terminal.get('CFBundleShortVersionString'),'terminalBuild':terminal.get('CFBundleVersion'),
        'platform':platform.platform(),'machine':platform.machine(),'pythonVersion':platform.python_version()}

def require_existing_automation_grant():
    class Descriptor(ctypes.Structure):
        _fields_=[('kind',ctypes.c_uint32),('handle',ctypes.c_void_p)]
    ae=ctypes.CDLL('/System/Library/Frameworks/CoreServices.framework/CoreServices')
    ae.AECreateDesc.argtypes=[ctypes.c_uint32,ctypes.c_void_p,ctypes.c_long,ctypes.POINTER(Descriptor)]
    ae.AEDeterminePermissionToAutomateTarget.argtypes=[ctypes.POINTER(Descriptor),ctypes.c_uint32,ctypes.c_uint32,ctypes.c_bool]
    ae.AEDeterminePermissionToAutomateTarget.restype=ctypes.c_int32
    code=lambda value:int.from_bytes(value.encode(),'big')
    descriptor=Descriptor(); target=b'com.apple.Terminal'
    assert ae.AECreateDesc(code('bund'),target,len(target),ctypes.byref(descriptor))==0
    status=ae.AEDeterminePermissionToAutomateTarget(ctypes.byref(descriptor),code('core'),code('dosc'),False)
    ae.AEDisposeDesc(ctypes.byref(descriptor))
    if status!=0: raise RuntimeError(f'Nonprompting Terminal automation preflight returned {status}; no Apple event sent. -600 can mean Terminal is not running; launch it explicitly, then retry. Other failures require checking the existing grant.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--triptych',default='/Users/johnhardy/projects/triptych')
    parser.add_argument('--disk',required=True); parser.add_argument('--capture',required=True)
    parser.add_argument('--output',required=True); parser.add_argument('--samples',type=int,default=30)
    parser.add_argument('--artifact',help='Frozen artifact JSON; otherwise discover private-disk-provenance.json beside disk')
    args=parser.parse_args(); assert 30<=args.samples<=60
    require_existing_automation_grant()
    output=pathlib.Path(args.output).resolve(); output.mkdir(parents=True,exist_ok=True)
    identity=provenance(args.triptych,args.disk,args.capture,args.artifact)
    (output/'provenance.json').write_text(json.dumps(identity,indent=2)+'\n')
    # Short socket path avoids the macOS AF_UNIX path-length limit.
    socket_path=f'/tmp/edit-visible-{os.getpid()}.sock'
    config={'socket':socket_path,'disk':str(pathlib.Path(args.disk).resolve()),'triptych':str(pathlib.Path(args.triptych).resolve())}
    config_path=output/'bridge.json'; config_path.write_text(json.dumps(config))
    command=' '.join(shlex.quote(s) for s in [sys.executable,str(pathlib.Path(__file__).resolve()),'--bridge',str(config_path)])
    window=None; capture=None; channel=None; connection=None; capture_error=None
    try:
        window=int(apple('tell application "Terminal"\nset t to do script '+json.dumps(command)+'\nset number of columns of t to 80\nset number of rows of t to 24\nset custom title of t to "Edit private native qualification"\nactivate\nreturn id of front window\nend tell'))
        (output/'live.json').write_text(json.dumps({'windowId':window,'socket':socket_path}))
        connection=socket.socket(socket.AF_UNIX)
        deadline=time.monotonic()+20
        while True:
            try: connection.connect(socket_path); break
            except (FileNotFoundError,ConnectionRefusedError):
                if time.monotonic()>deadline: raise
                time.sleep(.05)
        connection.settimeout(35); channel=connection.makefile('rwb')
        ready=json.loads(channel.readline()); assert ready['ready']
        frames_dir=output/'frames'; frames_dir.mkdir(exist_ok=True)
        capture_error=open(output/'capture.stderr','w')
        capture=subprocess.Popen([str(pathlib.Path(args.capture).resolve()),str(window),str(frames_dir)],stdout=subprocess.PIPE,stderr=capture_error,text=True)
        (output/'live.json').write_text(json.dumps({'windowId':window,'capturePid':capture.pid,**ready}))
        startup=''
        if select.select([capture.stdout],[],[],25)[0]: startup=capture.stdout.readline().strip()
        if startup!='CAPTURE_READY':
            capture_error.flush()
            diagnostic=(output/'capture.stderr').read_text()
            raise RuntimeError(f'Capture startup failed: helper={args.capture}, pid={capture.pid}, returnCode={capture.poll()}, stdout={startup!r}, stderr={diagnostic!r}')
        (output/'live.json').write_text(json.dumps({'windowId':window,'capturePid':capture.pid,**ready}))
        def frames():
            result=[]
            for line in (frames_dir/'frames.jsonl').read_text().splitlines():
                try: result.append(json.loads(line))
                except json.JSONDecodeError: pass
            return result
        time.sleep(.5)
        initial=apple(f'tell application "Terminal" to get contents of selected tab of window id {window}')
        initial_rows=initial.splitlines(); assert initial_rows[0].startswith('ordinary source line 0123456789'),repr(initial_rows[:2])
        prefix=''; samples=[]
        for index in range(args.samples+1):
            key='x' if index==0 else chr(97+(index-1)%26); prefix+=key
            expected=(prefix+initial_rows[0]).ljust(80)[:80]
            emit(channel,{'key':key,'column':index+2}); sample=json.loads(channel.readline())
            # Settling is outside latency; the earlier matching recorded frame supplies its timestamp.
            time.sleep(.35)
            text=apple(f'tell application "Terminal" to get contents of selected tab of window id {window}')
            assert text.splitlines()[0].ljust(80)[:80]==expected,repr(text.splitlines()[:2])
            available=[f for f in frames() if f['displayTicks']>=sample['inputTicks']]
            assert available,'No complete captured frame for key'
            reference=available[-1]
            matching=[f for f in available if f['sha256']==reference['sha256']]
            first=matching[0]
            assert reference['callbackTicks']>=sample['ptyOutputTicks'],'Reference predates completed output'
            sample.update({'key':key,'expectedFirstRow':expected,'expectedCursor':{'row':1,'column':index+2},
                'terminalContents':text,'reference':reference,'firstMatchingFrame':first,
                'presentationMs':milliseconds(first['displayTicks']-sample['inputTicks']),
                'callbackDelayMs':milliseconds(first['callbackTicks']-first['displayTicks']),
                'ptyOutputMs':milliseconds(sample['ptyOutputTicks']-sample['inputTicks']),
                'completeFramesObserved':len(available)})
            samples.append(sample)
        cold,warm=samples[0],samples[1:]; values=sorted(s['presentationMs'] for s in warm)
        report={'format':'edit-native-visible-reference-v1','windowId':window,'samples':warm,'cold':cold,
            'summary':{'medianMs':statistics.median(values),'p95Ms':values[math.ceil(len(values)*.95)-1]},
            'timebase':{'numer':timebase.numer,'denom':timebase.denom},'captureRequestedHz':60,
            'boundary':'PTY input write timestamp to first matching complete ScreenCaptureKit frame displayTime (WindowServer presentation, not physical scanout)',
            'oracle':'Exact entire-window pixel hash equals settled reference; independent Terminal contents confirms expected first row; final ANSI cursor position confirmed. Reference PNGs must be visually audited for cursor visibility.',
            'limitations':['Capture may miss earlier states; matching reference may be delayed by cursor blink, so results are observation bounds.','Reference cursor visibility requires image review; invisible-cursor reference is not qualified.','PNG encoding and capture observer add host load; callback delay is recorded separately.'],
            'diskSha256':hashlib.sha256(pathlib.Path(config['disk']).read_bytes()).hexdigest(),'provenance':identity}
        (output/'visible.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report['summary']))
    finally:
        cleanup={'dedicatedWindowId':window,'errors':[]}
        if channel:
            try:
                emit(channel,{'stop':True})
                connection.settimeout(12)
                response=channel.readline()
                cleanup['bridgeStop']=json.loads(response) if response else {'acknowledged':False}
            except (BrokenPipeError,OSError,ValueError) as error: cleanup['errors'].append('bridge stop: '+str(error))
            finally: channel.close()
        if connection: connection.close()
        if capture and capture.poll() is None:
            capture.terminate()
            try: capture.wait(timeout=10)
            except subprocess.TimeoutExpired: capture.kill(); capture.wait(timeout=5)
        if capture_error: capture_error.close()
        # Only the exact window created above is eligible for cleanup.
        if window:
            try:
                apple(f'tell application "Terminal" to close window id {window} saving no')
                cleanup['dedicatedWindowClosed']=True
            except subprocess.CalledProcessError as error: cleanup['errors'].append('window close: '+str(error))
        pathlib.Path(socket_path).unlink(missing_ok=True)
        cleanup['captureStopped']=capture is None or capture.poll() is not None
        cleanup['captureReturnCode']=capture.returncode if capture else None
        (output/'cleanup.json').write_text(json.dumps(cleanup,indent=2)+'\n')

if __name__=='__main__':
    if len(sys.argv)==3 and sys.argv[1]=='--bridge': bridge(sys.argv[2])
    else: main()
