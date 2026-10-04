"""Capture the six approved HTML phones using an installed Chromium.

Run: python3 tool/capture_page_t01_prototypes.py /tmp/opencode/page-t01
Only temporary HTML copies and screenshots are written; the prototype is intact.
"""

from pathlib import Path
import shutil
import subprocess
import sys


root = Path(__file__).resolve().parents[1]
output = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/opencode/page-t01").resolve()
output.mkdir(parents=True, exist_ok=True)
chromium = shutil.which("chromium")
if not chromium:
    raise SystemExit("An installed chromium executable is required")
source = (root / "docs/planning/editor-visual-spec.html").read_text()
for number in range(1, 7):
    # Render the original DOM/CSS, isolating a phone without changing its layout.
    extra = """<style>
html,body{margin:0!important;width:360px!important;height:800px!important;overflow:hidden!important}
body>main{padding:0!important;margin:0!important}
body>main>*{display:none!important}
#capture-phone{display:flex!important;position:absolute;left:0;top:0;outline:0}
</style><script>
const selected=document.querySelectorAll('.phone')[INDEX];
selected.id='capture-phone';document.body.appendChild(selected);
</script>""".replace("INDEX", str(number - 1))
    html = output / f"prototype-V{number:02}.html"
    html.write_text(source + extra)
    subprocess.run([
        chromium, "--headless", "--no-sandbox", "--disable-gpu",
        "--no-pdf-header-footer", "--hide-scrollbars", "--force-device-scale-factor=1",
        "--window-size=360,800", "--virtual-time-budget=1000",
        f"--screenshot={output / f'prototype-V{number:02}.png'}", html.as_uri(),
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    html.unlink()
print(f"Captured V01–V06 prototypes in {output}")
