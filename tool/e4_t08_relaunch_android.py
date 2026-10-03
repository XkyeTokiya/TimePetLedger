"""Run E4-T08 on one installed Android app, force-stopping between phases."""

import argparse
import re
import signal
import subprocess
import sys
import tempfile
import time


def command(*args, timeout=30):
    return subprocess.run(
        args, check=True, capture_output=True, text=True, timeout=timeout
    ).stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--device", default="emulator-5554")
    parser.add_argument("--package", default="com.tokiya.time_pet_ledger")
    args = parser.parse_args()
    if re.fullmatch(r"[A-Za-z0-9_]+", args.run_id) is None:
        parser.error("--run-id must contain only letters, digits and underscores")

    with tempfile.TemporaryFile(mode="w+t") as first_log:
        first = subprocess.Popen(
            [
                "flutter",
                "run",
                "--no-pub",
                "-d",
                args.device,
                "-t",
                "integration_test/recording_platform_test.dart",
                f"--dart-define=E4_T08_RUN_ID={args.run_id}",
            ],
            stdin=subprocess.DEVNULL,
            stdout=first_log,
            stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 300
            while time.monotonic() < deadline:
                first_log.flush()
                first_log.seek(0)
                first_output = first_log.read()
                if "E4-T08 phase=1 passed" in first_output and "All tests passed!" in first_output:
                    break
                if first.poll() is not None or "Some tests failed." in first_output:
                    print(first_output[-8000:], file=sys.stderr)
                    raise RuntimeError("Android initial phase failed")
                time.sleep(1)
            else:
                print(first_output[-8000:], file=sys.stderr)
                raise TimeoutError("Android initial phase did not complete")
        finally:
            if first.poll() is None:
                first.send_signal(signal.SIGINT)
            try:
                first.wait(timeout=15)
            except subprocess.TimeoutExpired:
                first.kill()
                first.wait()
    print("Android phase 1 passed after initial app launch", flush=True)

    for phase in range(2, 6):
        command("adb", "-s", args.device, "shell", "am", "force-stop", args.package)
        process = subprocess.run(
            ["adb", "-s", args.device, "shell", "pidof", args.package],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if process.stdout.strip():
            raise RuntimeError("Android app process remained after force-stop")
        command("adb", "-s", args.device, "logcat", "-c")
        command(
            "adb",
            "-s",
            args.device,
            "shell",
            "am",
            "start",
            "-n",
            f"{args.package}/.MainActivity",
        )
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            log = command("adb", "-s", args.device, "logcat", "-d", "-s", "flutter:I")
            if f"E4-T08 phase={phase} passed" in log and "All tests passed!" in log:
                print(f"Android phase {phase} passed after force-stop and Activity launch", flush=True)
                break
            if "Some tests failed." in log:
                print(log[-10000:], file=sys.stderr)
                raise RuntimeError(f"Android phase {phase} failed")
            time.sleep(1)
        else:
            print(log[-10000:], file=sys.stderr)
            raise TimeoutError(f"Android phase {phase} did not complete")
    command("adb", "-s", args.device, "shell", "am", "force-stop", args.package)
    print("Android E4-T08 lifecycle verification passed", flush=True)


if __name__ == "__main__":
    main()
