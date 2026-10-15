#!/usr/bin/python3
"""Preserve local Windows VM permission and RDP performance adjustments."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile

PERMISSION_OLD = 'chmod 0700 -- "/proc/$BASHPID/fd/$storage_fd" "/proc/$BASHPID/fd/$shared_fd"'
RDP_OLD = '/dynamic-resolution /gfx:AVC444 /floatbar:'
PAIRS = (
    (PERMISSION_OLD, PERMISSION_OLD.replace('chmod 0700', 'chmod 00700')),
    (RDP_OLD, '/dynamic-resolution /gfx:AVC420 /network:lan -wallpaper -menu-anims -window-drag /floatbar:'),
)

def patched(source):
    for old, new in PAIRS:
        if source.count(new) == 1 and old not in source:
            continue
        if source.count(old) != 1 or new in source:
            raise RuntimeError('Windows VM helper changed; local adjustments NOT applied. Review the new version.')
        source = source.replace(old, new)
    return source

def patch(path):
    source = path.read_text()
    updated = patched(source)
    subprocess.run(['/usr/bin/bash', '-n'], input=updated, text=True, check=True)
    if updated != source:
        path.write_text(updated)
        print('Windows VM local adjustments applied.')
    else:
        print('Windows VM local adjustments already present.')

if '--self-test' in sys.argv:
    sample = '#!/bin/bash\n' + PERMISSION_OLD + '\n# ' + RDP_OLD + '\n'
    fixed = patched(sample)
    assert patched(fixed) == fixed
    assert patched(sample.replace(*PAIRS[0])) == fixed
    try:
        patched(sample.replace(RDP_OLD, 'upstream changed'))
    except RuntimeError:
        pass
    else:
        raise AssertionError('Unknown upstream code must be rejected')
    subprocess.run(['/usr/bin/bash', '-n'], input=fixed, text=True, check=True)
    print('Self-test passed: both adjustments, partial update, idempotence, changed-source rejection.')
else:
    if os.geteuid() != 0:
        sys.exit('Run as root.')
    target = Path('/usr/bin/omarchy-windows-vm')
    if target.is_symlink() or not target.is_file() or target.stat().st_uid != 0:
        sys.exit('Refusing an unexpected Windows VM helper.')
    try:
        patch(target)
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
