"""Windows installer checks in disposable folders; never targets a real game."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SHELL = shutil.which('powershell.exe')
if not SHELL:
    raise SystemExit('Windows PowerShell is required for these Windows-only checks')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture(parent, version='1.0.1o-FULL'):
    game = parent / 'mock game'; game.mkdir(parents=True)
    # Generated identity-only fixture, not Balatro executable/source content.
    with zipfile.ZipFile(game / 'Balatro.exe', 'w') as archive:
        archive.writestr('version.jkr', version + '\n1.0.1o\nPROD_PC_Console')
        archive.writestr('main.lua', '-- identity fixture: LocalThunk')
        archive.writestr('card.lua', '-- identity fixture')
        archive.writestr('game.lua', '-- identity fixture')
    (game / 'steam_appid.txt').write_text('2379780', encoding='ascii')
    data = parent / 'data'; (data / '1').mkdir(parents=True)
    (data / '1/profile.jkr').write_bytes(b'private-profile-sentinel')
    return game, data


def run(game, data, *flags, package=ROOT, input_text=None, success=True):
    result = subprocess.run([SHELL, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                             str(package / 'install/Install.ps1'), '-GameDir', str(game),
                             '-DataDir', str(data), *flags], input=input_text,
                            text=True, encoding='utf-8', errors='replace', capture_output=True)
    if (result.returncode == 0) != success:
        raise AssertionError(result.stdout + '\n' + result.stderr)
    assert (data / '1/profile.jkr').read_bytes() == b'private-profile-sentinel'
    return result


passed = 0
def check(name):
    global passed
    passed += 1
    print('PASS installer:', name, flush=True)


with tempfile.TemporaryDirectory(prefix='bdc-installer-tests-') as temporary:
    work = Path(temporary)
    game, data = fixture(work / 'fresh')
    original_exe = digest(game / 'Balatro.exe')
    run(game, data, '-DryRun')
    assert not (game / 'winmm.dll').exists() and not (data / 'Mods').exists()
    check('dry run validates the bundle without installation writes')
    run(game, data, '-Yes')
    assert (game / 'winmm.dll').is_file()
    assert (data / 'Mods/smods/LICENSE').is_file()
    installed = data / 'Mods/BalatroDrawController'
    assert (installed / 'src/temporary_cards.lua').read_bytes() == (ROOT / 'src/temporary_cards.lua').read_bytes()
    assert not list((installed / 'vendor').glob('*.zip')) and not (installed / '.git').exists()
    for notice in ('THIRD_PARTY_NOTICES.md', 'vendor/DEPENDENCIES.record',
                   'vendor/LICENSE-Lovely-MIT.txt', 'vendor/LICENSE-SMODS-GPL-3.0.txt'):
        assert (installed / notice).read_bytes() == (ROOT / notice).read_bytes()
    assert digest(game / 'Balatro.exe') == original_exe
    check('fresh offline installation creates all three components and preserves game/profile')
    (installed / 'private-note.txt').write_text('retain existing folder', encoding='utf-8')
    dll_before = digest(game / 'winmm.dll')
    run(game, data, '-Yes')
    assert digest(game / 'winmm.dll') == dll_before
    assert list((data / 'BDCBackups').glob('*/BalatroDrawController/private-note.txt'))
    assert not (installed / 'private-note.txt').exists()
    check('repeat install reuses matching dependencies and retains old controller outside Mods')

    for label, setup in [
        ('wrong version', lambda g, d: None),
        ('unknown DLL', lambda g, d: (g / 'winmm.dll').write_bytes(b'unknown-dll')),
        ('old injector', lambda g, d: (g / 'version.dll').write_bytes(b'old-injector')),
        ('different SMODS', lambda g, d: ((d / 'Mods/smods').mkdir(parents=True), (d / 'Mods/smods/custom.txt').write_text('keep'))),
    ]:
        game, data = fixture(work / label, version='1.0.0' if label == 'wrong version' else '1.0.1o-FULL')
        setup(game, data)
        before = {str(p.relative_to(work / label)): digest(p) for p in (work / label).rglob('*') if p.is_file()}
        run(game, data, '-Yes', success=False)
        after = {str(p.relative_to(work / label)): digest(p) for p in (work / label).rglob('*') if p.is_file()}
        assert after == before
        check(label + ' is rejected without changing target files')

    game, data = fixture(work / 'cancel')
    run(game, data, input_text='NO\n', success=False)
    assert not (game / 'winmm.dll').exists() and not (data / 'Mods').exists()
    check('interactive cancellation leaves installation untouched')

    copied = work / 'tampered bundle'
    shutil.copytree(ROOT, copied, ignore=shutil.ignore_patterns('.git', '__pycache__'))
    with (copied / 'vendor/lovely-0.10.0-windows-x64.zip').open('ab') as handle:
        handle.write(b'tamper')
    game, data = fixture(work / 'tamper')
    run(game, data, '-Yes', package=copied, success=False)
    assert not (game / 'winmm.dll').exists() and not (data / 'Mods').exists()
    check('tampered archive is rejected before target writes')

    game, data = fixture(work / 'rollback')
    old = data / 'Mods/BalatroDrawController'; old.mkdir(parents=True)
    (old / 'BalatroDrawController.json').write_text(json.dumps({'id': 'balatro_draw_controller'}))
    (old / 'keep.txt').write_text('original controller')
    locked = game / 'Balatro-Lucky-Hand-Lovely-LICENSE.txt'
    locked.write_text('original notice')
    with locked.open('rb'):
        run(game, data, '-Yes', success=False)
    assert (old / 'keep.txt').read_text() == 'original controller'
    assert not (game / 'winmm.dll').exists() and not (data / 'Mods/smods').exists()
    assert locked.read_text() == 'original notice'
    check('late write failure restores old controller and removes new active dependencies')

print('Installer checks passed:', passed, flush=True)
