"""Refresh one Chromium tab across all E8-T06 browser test phases."""

import argparse
import json
import re
import subprocess
import tempfile
import time
import urllib.request


def request(base, method, path, data=None):
    body = None if data is None else json.dumps(data).encode()
    call = urllib.request.Request(
        base + path,
        data=body,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(call, timeout=30) as response:
        result = json.load(response)
    value = result.get("value")
    if isinstance(value, dict) and value.get("error"):
        raise RuntimeError(value)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True, help="The running Flutter web-server URL")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--chromium", default="/usr/bin/chromium")
    parser.add_argument("--chromedriver", default="/usr/bin/chromedriver")
    parser.add_argument("--driver-port", type=int, default=9518)
    args = parser.parse_args()
    if re.fullmatch(r"[A-Za-z0-9_]+", args.run_id) is None:
        parser.error("--run-id must contain only letters, digits and underscores")
    base = f"http://127.0.0.1:{args.driver_port}"
    with tempfile.TemporaryDirectory(prefix=f"e8_t06_{args.run_id}_") as profile:
        with open(f"/tmp/e8_t06_chromedriver_{args.run_id}.log", "w") as log:
            driver = subprocess.Popen(
                [args.chromedriver, f"--port={args.driver_port}"],
                stdout=log,
                stderr=subprocess.STDOUT,
            )
            session = None
            try:
                for _ in range(50):
                    try:
                        if request(base, "GET", "/status")["value"]["ready"]:
                            break
                    except Exception:
                        time.sleep(0.1)
                else:
                    raise TimeoutError("ChromeDriver did not become ready")
                created = request(
                    base,
                    "POST",
                    "/session",
                    {
                        "capabilities": {
                            "alwaysMatch": {
                                "browserName": "chrome",
                                "goog:loggingPrefs": {"browser": "ALL"},
                                "goog:chromeOptions": {
                                    "binary": args.chromium,
                                    "args": [
                                        "--headless=new",
                                        "--no-sandbox",
                                        "--disable-dev-shm-usage",
                                        f"--user-data-dir={profile}",
                                    ],
                                },
                            }
                        }
                    },
                )["value"]
                session = created["sessionId"]
                print(
                    f"Browser version: {created['capabilities']['browserVersion']}",
                    flush=True,
                )
                request(base, "POST", f"/session/{session}/url", {"url": args.url})
                timezone = request(
                    base,
                    "POST",
                    f"/session/{session}/execute/sync",
                    {"script": "return Intl.DateTimeFormat().resolvedOptions().timeZone", "args": []},
                )["value"]
                print(f"Browser timezone: {timezone}", flush=True)
                for phase in range(1, 6):
                    deadline = time.monotonic() + 100
                    while time.monotonic() < deadline:
                        title = request(base, "GET", f"/session/{session}/title")["value"]
                        if title == f"E8-T06 phase {phase} passed":
                            print(f"Web phase {phase} passed at {args.url}", flush=True)
                            break
                        time.sleep(1)
                    else:
                        logs = request(
                            base, "POST", f"/session/{session}/log", {"type": "browser"}
                        )["value"]
                        for entry in logs:
                            print(entry["message"][-6000:], flush=True)
                        raise TimeoutError(f"Web phase {phase} did not pass; title={title!r}")
                    if phase < 5:
                        request(base, "POST", f"/session/{session}/refresh", {})
                        print(f"Refreshed the same tab for phase {phase + 1}", flush=True)
                print("Web E8-T06 refresh verification passed", flush=True)
            finally:
                if session is not None:
                    request(base, "DELETE", f"/session/{session}")
                driver.terminate()
                driver.wait(timeout=10)


if __name__ == "__main__":
    main()
