"""JSON-RPC client for the Windows connector; serializes shared mailbox access."""
import fcntl
import json
import os
from pathlib import Path
import time
import uuid

ROOT = Path(os.environ.get('DELPHI_BRIDGE_DIR', str(Path.home() / 'Windows' / 'Delphi-Connector')))

def request(method, params=None, timeout=190):
    identity = uuid.uuid4().hex
    with (ROOT / '.client.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with (ROOT / 'request.json').open('r+') as stream:
            stream.seek(0)
            json.dump({'id': identity, 'rpc': {'jsonrpc': '2.0', 'id': identity,
                      'method': method, 'params': params or {}}}, stream)
            stream.truncate()
            stream.flush()
            os.fsync(stream.fileno())
        until = time.monotonic() + timeout
        while time.monotonic() < until:
            try:
                response = json.loads((ROOT / 'response.json').read_text())
                if response.get('id') == identity:
                    if response.get('error'):
                        raise RuntimeError(response['error'])
                    return response['result']
            except (json.JSONDecodeError, FileNotFoundError):
                pass
            time.sleep(.15)
        raise TimeoutError('El conector de Windows no respondio.')

if __name__ == '__main__':
    print(json.dumps(request('tools/list'), ensure_ascii=False, indent=2))
