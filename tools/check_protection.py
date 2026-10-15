"""Read native functions from the tester's own dump; keep them only in memory."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from lua_runtime import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lua-dll', required=True, type=Path)
parser.add_argument('--dump-dir', required=True, type=Path)
args = parser.parse_args()
dump = args.dump_dir.resolve(strict=True)
hashes = []


def extract(relative, start, end):
    text = (dump / relative).read_text(encoding='utf-8-sig')
    if text.count(start) != 1:
        raise ValueError('Ambiguous native function boundary: ' + relative)
    begin = text.index(start)
    snippet = text[begin:text.index(end, begin)]
    hashes.append((relative, start, hashlib.sha256(snippet.encode('utf-8')).hexdigest()))
    return snippet


native = '\n'.join([
    extract('card.lua', 'function Card:save()', '\nfunction Card:remove()'),
    extract('card.lua', 'function Card:set_debuff(', '\nfunction Card:change_suit('),
    extract('card.lua', 'function Card:add_to_deck(', '\nfunction Card:generate_UIBox_unlock_table('),
    extract('functions/common_events.lua', 'function discover_card(', '\nfunction get_deck_from_name('),
    extract('functions/common_events.lua', 'function unlock_card(', '\nfunction fetch_achievements('),
    extract('functions/misc_functions.lua', 'function recursive_table_cull(', '\nfunction remove_save('),
])
game = (dump / 'game.lua').read_text(encoding='utf-8-sig')
restore = game.index('self.GAME = saveTable and saveTable.GAME or self:init_game_object()')
areas = game.index('local cardAreas = saveTable.cardAreas', restore)
assert restore < areas
runtime = LuaRuntime(args.lua_dll)
source = ('ROOT=' + json.dumps(ROOT.as_posix()) + '\nNATIVE=' + json.dumps(native) + '\n' +
          (ROOT / 'tests/test_protection.lua').read_text(encoding='utf-8')).encode('utf-8')
runtime.check(source, 'public run-only protection regressions', execute=True)
runtime.flush()
for relative, function, digest in hashes:
    print('Native fixture SHA256:', relative, function, digest)
print('PASS 13 protection regressions; no native source, profiles or saves written')
