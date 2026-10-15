"""Check the isolated public tree and run preview tests; no game/save writes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
from lua_runtime import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lua-dll', required=True, type=Path)
args = parser.parse_args()
runtime = LuaRuntime(args.lua_dll)
manifest = {}
for line in (ROOT / 'MANIFEST.sha256').read_text(encoding='utf-8').splitlines():
    digest, path = line.split('  ', 1)
    assert re.fullmatch('[0-9a-f]{64}', digest) and path not in manifest
    relative = Path(path)
    assert not relative.is_absolute() and '..' not in relative.parts
    manifest[path] = digest
files = {p.relative_to(ROOT).as_posix(): p for p in ROOT.rglob('*') if p.is_file()
         and '.git' not in p.relative_to(ROOT).parts}
assert set(files) == set(manifest) | {'MANIFEST.sha256'}, 'Unexpected or missing public files'
secret = re.compile(
    r'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|'
    r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|'
    r'sk-(?:proj-)?[A-Za-z0-9_-]{20,}|(?:AKIA|ASIA)[A-Z0-9]{16})\b')
absolute = re.compile(r'(?<![A-Za-z0-9_])(?:[A-Za-z]:[\\/]|\\\\[A-Za-z0-9_.-]+\\)')
for path, digest in manifest.items():
    data = files[path].read_bytes()
    assert hashlib.sha256(data).hexdigest() == digest, 'Manifest mismatch: ' + path
    text = data.decode('utf-8-sig')
    assert not secret.search(text), 'Possible credential; value withheld: ' + path
    assert not absolute.search(text), 'Local absolute path: ' + path
    assert files[path].suffix.lower() not in {'.exe', '.dll', '.jkr', '.log', '.pyc'}, path
    if files[path].suffix == '.lua':
        runtime.check(data, path)
meta = json.loads((ROOT / 'BalatroDrawController.json').read_text(encoding='utf-8'))
assert meta['id'] == 'balatro_draw_controller' and meta['prefix'] == 'bdctrl'
assert meta['version'] == '0.8.1' and meta['main_file'] == 'main.lua'
assert meta['dependencies'] == ['Steamodded (>=26.829.0)', 'Lovely (>=0.10.0)']
assert "version = '0.8.1'" in (ROOT / 'main.lua').read_text(encoding='utf-8')
source = ('ROOT=' + json.dumps(ROOT.as_posix()) + '\n' +
          (ROOT / 'tests/test_stone.lua').read_text(encoding='utf-8')).encode('utf-8')
runtime.check(source, 'public preview regressions', execute=True)
runtime.flush()
print('PASS public tree, manifest, privacy patterns, metadata and Lua syntax; 8 preview regressions')
