from pathlib import Path
from urllib.parse import unquote
import hashlib
import json
import re
import subprocess

root = Path(__file__).resolve().parents[4]
output = Path(__file__).with_name('document-check.json')
files = [root / p for p in [
    'design.md', 'TASKS.md', 'docs/DOCUMENT_REGISTER.md',
    'docs/planning/UI_REBUILD_PLAN.md',
    'docs/planning/HOME_PROPORTIONAL_TIMELINE_DESIGN.md',
    'docs/reports/HOME_PROPORTIONAL_TIMELINE_REPORT.md',
    'docs/reports/HOME_TIMELINE_VISUAL_REFINEMENT_REPORT.md',
]]


def slugs(path):
    result = set()
    for line in path.read_text().splitlines():
        match = re.match(r'^#{1,6}\s+(.+)$', line)
        if not match:
            continue
        heading = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', match.group(1))
        heading = heading.replace('`', '').replace('*', '')
        result.add(''.join(c for c in heading.lower()
                          if c.isalnum() or c.isspace() or c in '-_')
                   .strip().replace(' ', '-'))
    return result


links = 0
for path in files:
    for target in re.findall(r'\]\(([^)\n]+)\)', path.read_text()):
        target = target.strip('<>')
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target):
            continue
        raw, sep, fragment = unquote(target).partition('#')
        dest = (path.parent / raw).resolve() if raw else path
        assert dest.exists(), (str(path), target, 'missing')
        if sep and fragment and dest.suffix == '.md':
            assert fragment in slugs(dest), (str(path), fragment, 'anchor')
        links += 1

questions = (root / 'docs/domain/OPEN_QUESTIONS.md').read_text()
q_ids = re.findall(r'^## (Q-\d{3})', questions, re.M)
assert len(q_ids) == len(set(q_ids)) == 40, q_ids
for number in ['039', '040']:
    item = re.search(rf'^## Q-{number}\b.*?(?=^## Q-|\Z)',
                     questions, re.M | re.S).group()
    assert 'DECIDED' in item

refs = {
    'initial-state-reference.png': '71cb7ed7a4e90e2895ab680b0674dc187f22b5868f001b6a5be348f0bd13f454',
    'scrolled-state-reference.png': '486cda70637aba852da4bb4eeb37d607cbed1445e88d39d1ea7980e966803033',
    'user-design-v1-original.md': 'd1182cc87f220fd125403ca15d1e2d53ce1d14420ef206e2efec983e14ff1ee2',
}
for name, expected in refs.items():
    path = root / 'docs/planning/assets/home-proportional-timeline' / name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected
assert subprocess.run(['git', 'diff', '--check'], cwd=root,
                      capture_output=True).returncode == 0
report = {
    'documents': len(files), 'valid_local_links_and_anchors': links,
    'unique_questions': len(q_ids), 'Q-039': 'DECIDED', 'Q-040': 'DECIDED',
    'original_reference_sha256': refs, 'git_diff_check': 'passed',
    'HOME-TIME-VISUAL-01': 'COMPLETE', 'HOME-TIME-04': 'PARTIAL',
}
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False))
