#!/usr/bin/env python3
"""Keep PAServer's interactive stdin open while systemd manages it."""
import subprocess
import sys
from pathlib import Path

home = Path.home()
with subprocess.Popen([
    str(home / '.local/share/paserver/37.0/paserver'),
    '-config=' + str(home / '.config/paserver/paserver.config'),
], stdin=subprocess.PIPE) as server:
    sys.exit(server.wait())
