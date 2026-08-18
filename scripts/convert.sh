#!/usr/bin/env bash
set -euo pipefail

dependencies_file=${1:?dependency file is required}
manifest_file=${2:-.repo/local_manifests/roomservice.xml}
test -f "$dependencies_file"
mkdir -p "$(dirname "$manifest_file")"

if [ -f "$manifest_file" ]; then
  sed -i '/<\/manifest>/d' "$manifest_file"
else
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' '<manifest>' > "$manifest_file"
fi

python3 - "$dependencies_file" "$manifest_file" <<'PY'
import json
import re
import sys
from pathlib import Path

source, target = map(Path, sys.argv[1:])
text = source.read_text()
try:
    entries = json.loads(text)
except json.JSONDecodeError:
    entries = []
    for match in re.finditer(r'<project\b([^>]*)/?>', text):
        attrs = dict(re.findall(r'(\w+)=["\']([^"\']+)["\']', match.group(1)))
        entries.append(attrs)

with target.open('a') as output:
    for project in entries:
        path = project.get('target_path') or project.get('path')
        repository = project.get('repository') or project.get('name')
        if not path or not repository:
            continue
        attrs = [f'target_path="{path}"', f'name="{repository}"']
        if project.get('remote'):
            attrs.append(f'remote="{project["remote"]}"')
        revision = project.get('branch') or project.get('revision')
        if revision:
            attrs.append(f'revision="{revision}"')
        output.write('  <project ' + ' '.join(attrs) + ' />\n')
    output.write('</manifest>\n')
PY
