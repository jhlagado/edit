"""Audit captured native editor frames; requires Python 3 and Pillow.

Default calibration: 1160x770 image, 80 columns, x=20, pitch=14,
first-row cursor rectangle y=78..105. Other geometry requires explicit flags.
Only derived audit files are written. Raw samples and PNGs remain unchanged.
"""
import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import statistics
from PIL import Image, ImageDraw


def check(condition, message):
    if not condition:
        raise ValueError(message)


def digest(value):
    return hashlib.sha256(value).hexdigest()


def physical_editor(disk):
    """Read user-zero EDIT.COM from the explicitly supported small-disk profile."""
    check(len(disk) == 256512, 'Unsupported private disk geometry')
    extents = []
    for index in range(64):
        entry = disk[6656 + index * 32:6656 + (index + 1) * 32]
        if entry[0] == 0 and bytes(x & 127 for x in entry[1:12]) == b'EDIT    COM':
            extents.append(((entry[12] & 31) + entry[14] * 32, entry))
    check(bool(extents), 'EDIT.COM is absent')
    result = bytearray()
    for expected, (number, entry) in enumerate(sorted(extents)):
        check(number == expected, 'Missing or duplicate EDIT extent')
        remaining = entry[15]
        check(remaining <= 128, 'Invalid extent record count')
        for block in entry[16:32]:
            if remaining == 0:
                break
            check(2 <= block <= 242, 'Invalid EDIT allocation block')
            count = min(8, remaining)
            offset = 6656 + block * 1024
            result.extend(disk[offset:offset + count * 128])
            remaining -= count
        check(remaining == 0, 'Incomplete EDIT extent')
    return bytes(result)


def audit(args):
    run = Path(args.output).resolve()
    report = json.loads((run / 'visible.json').read_text())
    frames = [json.loads(line) for line in (run / 'frames/frames.jsonl').read_text().splitlines()]
    check(len(report['samples']) >= 30, 'Fewer than 30 warm samples')
    check(len(frames) >= 2, 'Insufficient complete frames')
    check(len({f['sequence'] for f in frames}) == len(frames), 'Duplicate frame sequence')
    check(all(b['sequence'] > a['sequence'] and b['displayTicks'] > a['displayTicks'] for a, b in zip(frames, frames[1:])), 'Frame sequence/display timestamps are not increasing')
    by_sequence = {f['sequence']: f for f in frames}
    factor = report['timebase']['numer'] / report['timebase']['denom'] / 1e6
    check(factor > 0, 'Invalid mach timebase')
    geometry = (args.width, args.height)
    check(all((f['width'], f['height']) == geometry for f in frames), 'Unsupported capture size; provide an explicitly calibrated geometry')
    check(0 <= args.cursor_x and args.cursor_x + 80 * args.pitch <= args.width, 'Invalid horizontal calibration')
    check(0 <= args.cursor_y and args.cursor_y + args.cursor_height <= args.height, 'Invalid vertical calibration')
    samples = [report['cold']] + report['samples']
    rows = []
    contact = Image.new('RGB', (args.width, len(samples) * (args.cursor_height + 20)), 'white')
    draw = ImageDraw.Draw(contact)
    prefix = ''
    for index, sample in enumerate(samples):
        key = 'x' if index == 0 else chr(97 + (index - 1) % 26)
        prefix += key
        check(sample['key'] == key, f'Sample {index}: unexpected key')
        expected_row = (prefix + 'ordinary source line 0123456789').ljust(80)[:80]
        check(sample['expectedFirstRow'] == expected_row, f'Sample {index}: expected text is inconsistent')
        check(sample['terminalContents'].splitlines()[0].ljust(80)[:80] == expected_row, f'Sample {index}: Terminal contents differ')
        check(sample['expectedCursor'] == {'row': 1, 'column': index + 2}, f'Sample {index}: cursor contract differs')
        reference, first = sample['reference'], sample['firstMatchingFrame']
        check(reference == by_sequence[reference['sequence']] and first == by_sequence[first['sequence']], f'Sample {index}: frame metadata differs from capture log')
        reference_path, first_path = run / 'frames' / reference['png'], run / 'frames' / first['png']
        check(reference_path.parent == run / 'frames' and first_path.parent == run / 'frames', 'Frame path escapes frame directory')
        with Image.open(reference_path) as source:
            image = source.convert('RGB')
        with Image.open(first_path) as source:
            first_image = source.convert('RGB')
        check(image.size == geometry and first_image.size == geometry, f'Sample {index}: PNG size differs')
        check(image.tobytes() == first_image.tobytes(), f'Sample {index}: decoded pixels differ')
        check(reference['sha256'] == first['sha256'], f'Sample {index}: frame hashes differ')
        x0 = args.cursor_x + args.pitch * (index + 1)
        # The calibrated line immediately below the cursor top is above glyph ink.
        # Exactly one non-white band must span the expected cursor cell.
        band_y = args.cursor_y + 1
        dark = [x for x in range(args.cursor_x, args.cursor_x + 80 * args.pitch)
                if max(image.getpixel((x, band_y))) < 200]
        check(dark == list(range(x0, x0 + args.pitch)), f'Sample {index}: visible cursor is absent or at wrong column')
        check(all(max(image.getpixel((x, band_y))) - min(image.getpixel((x, band_y))) <= 3 for x in dark), f'Sample {index}: cursor color differs from gray calibration')
        check(first['displayTicks'] >= sample['inputTicks'], f'Sample {index}: presentation predates input')
        check(reference['callbackTicks'] >= sample['ptyOutputTicks'], f'Sample {index}: reference callback predates output completion')
        check(first['callbackTicks'] >= first['displayTicks'], f'Sample {index}: callback predates presentation')
        check(not any(f['sha256'] == reference['sha256'] for f in frames if sample['inputTicks'] <= f['displayTicks'] < first['displayTicks']), f'Sample {index}: earlier matching captured frame exists')
        for name, delta in [('presentationMs', first['displayTicks'] - sample['inputTicks']), ('callbackDelayMs', first['callbackTicks'] - first['displayTicks']), ('ptyOutputMs', sample['ptyOutputTicks'] - sample['inputTicks'])]:
            check(math.isclose(delta * factor, sample[name], abs_tol=1e-8), f'Sample {index}: {name} conversion differs')
        y = index * (args.cursor_height + 20)
        contact.paste(image.crop((0, args.cursor_y, args.width, args.cursor_y + args.cursor_height)), (0, y))
        draw.text((args.width // 2, y + args.cursor_height), f'{index}: column {index + 2}; {reference["png"]}', fill='black')
        rows.append({'sample': index, 'cursorColumn': index + 2, 'reference': reference['png'], 'firstMatchingFrame': first['png'], 'decodedPixelsSha256': digest(image.tobytes()), 'visibleCursorAndPixelsVerified': True})
    cleanup = json.loads((run / 'cleanup.json').read_text())
    check(not cleanup.get('errors'), 'Cleanup reported errors')
    check(cleanup.get('dedicatedWindowClosed') and cleanup.get('captureStopped') and cleanup.get('bridgeStop', {}).get('stopped'), 'Cleanup lacks window/capture/native termination acknowledgement')
    identity_path = run / 'provenance.json'
    if not identity_path.exists():
        identity_path = run / 'provenance-audit.json'
    identity = json.loads(identity_path.read_text())
    bridge = json.loads((run / 'bridge.json').read_text())
    disk = Path(bridge['disk']).read_bytes()
    check(digest(disk) == report['diskSha256'] == identity['diskSha256'], 'Private disk hash differs')
    physical = physical_editor(disk)
    check(digest(physical) == identity['editor']['physicalRecordsSha256'], 'Installed EDIT physical records differ')
    artifact = json.loads(Path(identity['editor']['artifactPath']).read_text())
    binary = base64.b64decode(artifact['binaryBase64'], validate=True)
    check(digest(binary) == artifact['sha256'] == identity['editor']['sha256'] and len(binary) == identity['editor']['bytes'] and physical[:len(binary)] == binary, 'Installed editor does not match frozen artifact')
    host = Path(bridge['triptych']) / 'target/debug/triptych-host-native'
    check(digest(host.read_bytes()) == identity['nativeHostSha256'], 'Current native host differs from recorded host; retain the matching executable for audit')
    summary = lambda values: {'medianMs': statistics.median(values), 'p95Ms': sorted(values)[math.ceil(len(values) * .95) - 1], 'minMs': min(values), 'maxMs': max(values)}
    presentation = summary([s['presentationMs'] for s in report['samples']])
    check(math.isclose(presentation['medianMs'], report['summary']['medianMs'], abs_tol=1e-8) and math.isclose(presentation['p95Ms'], report['summary']['p95Ms'], abs_tol=1e-8), 'Reported summary differs from raw samples')
    result = {'status': 'passed', 'warmSamples': len(report['samples']), 'samplesAudited': len(samples), 'captureFrames': len(frames),
        'geometry': {'width': args.width, 'height': args.height, 'cursorX': args.cursor_x, 'pitch': args.pitch, 'cursorY': args.cursor_y, 'cursorHeight': args.cursor_height},
        'presentation': presentation, 'captureInterval': summary([(b['displayTicks'] - a['displayTicks']) * factor for a, b in zip(frames, frames[1:])]),
        'callbackDelay': summary([s['callbackDelayMs'] for s in report['samples']]), 'provenanceSource': identity_path.name,
        'provenance': identity, 'cleanup': cleanup, 'samples': rows,
        'boundary': 'First matching captured WindowServer frame; physical display scanout is unmeasured. Capture censoring and observer load remain.'}
    (run / 'audit.json').write_text(json.dumps(result, indent=2) + '\n')
    (run / 'audit-failure.json').unlink(missing_ok=True)
    contact.save(run / 'cursor-audit-contact.png')
    (run / 'audit.md').write_text(f'''# Native visible frame audit

Passed {len(samples)} reference-image audits, including one cold edit and {len(report['samples'])} warm keys. Every image contains a unique visible gray cursor in the expected first-row column. Decoded first-match and reference pixels agree across the entire window. Public Terminal contents, raw mach timestamp conversions and earliest matching captured frames also agree.

Warm presentation median: **{presentation['medianMs']:.3f} ms**; p95: **{presentation['p95Ms']:.3f} ms**. This is a captured WindowServer presentation bound under instrumentation, not physical-panel or uninstrumented host latency.

Complete captured frames: {len(frames)}. Median frame interval: **{result['captureInterval']['medianMs']:.3f} ms**, maximum **{result['captureInterval']['maxMs']:.3f} ms**. Callback delay median: **{result['callbackDelay']['medianMs']:.3f} ms**, p95 **{result['callbackDelay']['p95Ms']:.3f} ms**. Callback delay is separate from the presentation timestamp; capture and PNG encoding can still affect host execution.

Calibration: {args.width} × {args.height}, first cell x={args.cursor_x}, pitch={args.pitch}, cursor y={args.cursor_y}–{args.cursor_y + args.cursor_height - 1}. The pixel test uses the calibrated band above glyph ink. Other dimensions are rejected unless explicit calibration arguments are supplied. The contact sheet retains the text and cursor evidence for visual review.

The private disk, extracted physical EDIT records, frozen artifact and native executable hashes passed verification against `{identity_path.name}`. Cleanup confirms native stop, capture stop and closure of the dedicated window, with no recorded errors. See `audit.json` for raw audit results and provenance, and `cursor-audit-contact.png` for all reference rows.
''')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, help='Existing visible-run directory')
    for name, default in [('width', 1160), ('height', 770), ('cursor-x', 20), ('pitch', 14), ('cursor-y', 78), ('cursor-height', 28)]:
        parser.add_argument('--' + name, type=int, default=default)
    args = parser.parse_args()
    try:
        result = audit(args)
    except Exception as error:
        failure = json.dumps({'status': 'failed', 'error': str(error)}, indent=2) + '\n'
        if Path(args.output).is_dir():
            Path(args.output, 'audit-failure.json').write_text(failure)
            Path(args.output, 'audit.json').write_text(failure)
            Path(args.output, 'audit.md').write_text('# Native visible frame audit\n\nFailed: ' + str(error) + '\n')
        raise
    print(json.dumps({key: result[key] for key in ['status', 'warmSamples', 'presentation', 'captureInterval', 'callbackDelay']}))


if __name__ == '__main__':
    main()
