#!/usr/bin/env python3
"""从 `flutter test --reporter expanded` 日志提取失败测试的 file + name 列表。

用法：

    flutter test --reporter expanded > /tmp/timepet-tests.log 2>&1
    python3 extract_failures.py /tmp/timepet-tests.log > current_failures.json

输出为 JSON 数组：[{"file": "test/...", "name": "..."}, ...]。
与同目录 failures.json 的差集即“新增失败 / 已修复失败”，用于基线“只减不增”核对。
"""

import json
import re
import sys

path = sys.argv[1]
pattern = re.compile(r": (?:.*/)?(?P<file>test/[^:]+): (?P<name>.+?) \[E\]$")

entries = []
for line in open(path, encoding="utf-8"):
    if "[E]" not in line:
        continue
    match = pattern.search(line.rstrip("\n"))
    if match:
        entries.append({"file": match.group("file"), "name": match.group("name")})

print(json.dumps(entries, ensure_ascii=False, indent=1))
print(f"failures: {len(entries)}", file=sys.stderr)
