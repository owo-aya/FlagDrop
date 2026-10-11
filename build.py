import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / 'FlagDrop-v0.9.zip'
ARCHIVE = '9ba626afa44a3aa3.patch_0'
LUA_TYPE = 0xA14E8DFA2CD117E2
ENTRY_ID = 0xF2791F0E3CB2A5BE

source = (ROOT / 'entry.lua').read_text(encoding='utf-8')
modules = '\n'.join('local ' + name + ' = (function()\n' +
                    (ROOT / (name + '.lua')).read_text(encoding='utf-8') + '\nend)()'
                    for name in ('mission', 'loadout', 'pod'))
body = source.replace('-- MODULES', modules).encode('utf-8')
resource = struct.pack('<II', len(body), 2) + body
size = (192 + len(resource) + 15) & ~15
header = struct.pack('<III20sQQ24s', 0xF0000011, 1, 1, b'', size, 0, b'')
types = struct.pack('<IIQIIII', 0, 0, LUA_TYPE, 1, 0, 16, 16)
entry = struct.pack('<7Q6I', ENTRY_ID, LUA_TYPE, 192, 0, 0, 0, 0,
                    len(resource), 0, 0, 16, 16, 0)
archive = header + types + entry + b'\0' * 8 + resource + b'\0' * (size - 192 - len(resource))
manifest = {'Version': 1, 'Guid': 'f91d7e58-e0db-4b9d-a86b-d6cdcd5d97a2',
            'Name': 'FlagDrop', 'Description': 'F11: Predator/BugAcid flag mission and appearance; apply weapons and stratagems after manual drop-point selection.',
            'Options': [{'Name': 'FlagDrop', 'Description': 'Requires Bingus Shared Loader v19.', 'Include': ['Addon']}]}
with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED) as package:
    package.writestr('manifest.json', json.dumps(manifest, indent=2))
    package.write(ROOT / 'README.md', 'README.md')
    package.writestr('Addon/' + ARCHIVE, archive)
    package.writestr('Addon/' + ARCHIVE + '.stream', b'')
    package.writestr('Addon/' + ARCHIVE + '.gpu_resources', b'')
(ROOT / 'FlagDrop.patch').write_bytes(archive)
print('Built ' + str(OUTPUT))
