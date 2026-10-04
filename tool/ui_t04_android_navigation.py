"""Drive UI-T04 through real adb touch, keyboard/back and display rotation."""
import argparse
import json
import pathlib
import re
import subprocess
import time


def adb(*args):
    return subprocess.check_output(["adb", "-s", "emulator-5554", *args])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshots", required=True)
    args = parser.parse_args()
    output = pathlib.Path(args.screenshots)
    output.mkdir(parents=True, exist_ok=True)
    original = {name: adb("shell", "settings", "get", "system", name).decode().strip()
                for name in ["accelerometer_rotation", "user_rotation"]}
    adb("logcat", "-c")
    log = open('/tmp/ui-t04-android-flutter.log', 'w')
    proc = subprocess.Popen(['/home/tokiya/Projects/00-develop/flutter/bin/flutter', 'run', '--no-pub', '-d', 'emulator-5554', '-t', 'integration_test/ui_t04_navigation_test.dart'], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)
    seen = set()
    try:
        deadline = time.monotonic() + 420
        while time.monotonic() < deadline:
            text = adb('logcat', '-d', '-s', 'flutter:I').decode(errors='replace')
            for match in re.finditer(r'UI_T04_STEP (\{[^\n]+\})', text):
                event = json.loads(match[1])
                name = event['name']
                if name in seen:
                    continue
                seen.add(name)
                print('actual Android action:', name, flush=True)
                time.sleep(0.5)
                if name in ['portrait_create', 'cancel_creation', 'review', 'back_to_ledger', 'summary', 'input', 'keyboard_back', 'form_back', 'rotate_landscape', 'restore_portrait', 'finished']:
                    (output / f'android-{name}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
                if 'x' in event:
                    adb('shell', 'input', 'tap', str(event['x']), str(event['y']))
                    if name == 'input':
                        time.sleep(0.7)
                        adb('shell', 'input', 'text', '123456')
                elif name in ['cancel_creation', 'back_to_ledger', 'summary_back', 'keyboard_back', 'form_back']:
                    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                elif name == 'rotate_landscape':
                    adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
                    adb('shell', 'settings', 'put', 'system', 'user_rotation', '1')
                elif name == 'restore_portrait':
                    adb('shell', 'settings', 'put', 'system', 'user_rotation', '0')
            if 'UI-T04 Android actual input/back/rotation passed' in text and 'All tests passed!' in text:
                print('UI-T04 Android verification passed', flush=True)
                return
            if 'Some tests failed.' in text or proc.poll() is not None:
                raise RuntimeError(text[-10000:])
            time.sleep(0.5)
        raise TimeoutError('Android validation timed out; inspect Flutter and adb logs.')
    finally:
        for name, value in original.items():
            adb('shell', 'settings', 'put', 'system', name, value)
        proc.terminate()
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            proc.kill()
        log.close()


if __name__ == '__main__':
    main()
